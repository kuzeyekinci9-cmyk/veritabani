import psycopg2

class DatabaseManager:
    def __init__(self):
        self.conn = None
        self.cursor = None
        self.current_user_id = None
        self.current_role = None 
        self.current_user_name = ""

    def connect(self):
        try:
            self.conn = psycopg2.connect(
                host="localhost",
                database="toolshare_db",
                user="postgres",
                password="0000"  # sifreni buraya yaz
            )
            self.cursor = self.conn.cursor()
            print("Veritabanı bağlantısı başarılı.")
            return True
        except Exception as e:
            print(f"Veritabanı bağlantı hatası: {e}")
            return False
        
    def disconnect(self):
        if self.conn:
            self.cursor.close()
            self.conn.close()
            print("Veritabanı bağlantısı kesildi.")

    # --- GIRIS ISLEMLERI ---
    
    def check_login(self, username, password):
        try:
            # 1. username -> id cevrimi
            self.cursor.callproc('sp_get_id_by_username', [username])
            user_id = self.cursor.fetchone()[0]

            if not user_id:
                return False

            # 2. sp_login cagrisi
            self.cursor.callproc('sp_login', [user_id, password, 'user'])
            result = self.cursor.fetchone()
            
            if result:
                self.current_user_id = result[0]
                self.current_role = result[1]
                self.current_user_name = result[2]
                return True
            return False

        except Exception as e:
            self.conn.rollback()
            print(f"Login Hatası: {e}")
            return False
        
    def get_my_score(self):
        try:
            sql = "SELECT security_score FROM Users WHERE user_id =%s"
            self.cursor.execute(sql, (self.current_user_id,))  
            return self.cursor.fetchone()[0]
        except Exception:
            return 0.0          

    # --- ALET YONETIMI (CRUD) ---

    def get_user_tools(self, user_id):
        # kullanicinin aletlerini listele
        try:
            self.cursor.callproc('sp_get_user_tools', [user_id])
            return self.cursor.fetchall()
        except Exception:
            self.conn.rollback()
            return []
    
    def get_all_categories(self):
        # combobox icin kategori listesi
        try:
            self.cursor.callproc('sp_get_categories', [])
            return self.cursor.fetchall()
        except Exception:
            self.conn.rollback()
            return []
        
    def add_new_tool(self, category_id, name, description):
        # yeni alet ekle
        try:
            self.cursor.callproc('sp_secure_add_tool', [self.current_user_id, self.current_user_id, category_id, name, description])
            self.conn.commit()
            return True, "Alet eklendi."
        except Exception as e:
            self.conn.rollback()
            return False, str(e).split('\n')[0]
    
    def delete_tool(self, tool_id):
        # alet sil
        try:
            self.cursor.callproc('sp_secure_delete_tool', [tool_id, self.current_user_id])
            self.conn.commit()
            return True, "Alet silindi."
        except Exception as e:
            self.conn.rollback()
            return False, str(e).split('\n')[0]
    
    def toggle_maintenance(self, tool_id):
        # bakim modu ac/kapa
        try:
            self.cursor.callproc('sp_toggle_maintenance', [tool_id, self.current_user_id])
            msg = self.cursor.fetchone()[0]
            self.conn.commit()
            return True, msg
        except Exception as e:
            self.conn.rollback()
            return False, str(e).split('\n')[0]

    def update_tool_description(self, tool_id, new_desc):
        # sadece aciklama guncelle
        try:
            self.cursor.callproc('sp_update_tool_description', [tool_id, self.current_user_id, new_desc])
            msg = self.cursor.fetchone()[0]
            self.conn.commit()
            return True, msg
        except Exception as e:
            self.conn.rollback()
            return False, str(e).split('\n')[0]

    # --- VITRIN VE ARAMA ---

    def search_tools(self, keyword, sort_option=1):
        # arama ve siralama
        try:
            term = keyword if keyword.strip() != "" else None
            self.cursor.callproc('sp_search_and_sort_tools', [term, sort_option])
            return self.cursor.fetchall()
        except Exception:
            self.conn.rollback()
            return []

    def get_tool_reviews(self, tool_id):
        # alet yorumlarini getir
        try:
            self.cursor.callproc('sp_get_tool_reviews', [tool_id])
            return self.cursor.fetchall()
        except Exception:
            self.conn.rollback()
            return []

    # --- KIRALAMA VE IADE ---

    def rent_tool(self, tool_id, start_date, end_date):
        # kiralama yap (triggerlar calisir)
        try:
            self.cursor.callproc('sp_rent_tool', [self.current_user_id, tool_id, start_date, end_date])
            msg = self.cursor.fetchone()[0]
            self.conn.commit()
            
            if "HATA" in msg: return False, msg
            return True, msg
        except Exception as e:
            self.conn.rollback()
            return False, str(e).split('\n')[0]

    def get_my_rentals(self):
        # kiraladiklarim
        try:
            self.cursor.callproc('sp_get_my_rentals', [self.current_user_id])
            return self.cursor.fetchall()
        except Exception:
            self.conn.rollback()
            return []

    def return_tool(self, loan_id):
        # iade et
        try:
            self.cursor.callproc('sp_return_tool', [self.current_user_id, loan_id])
            msg = self.cursor.fetchone()[0]
            self.conn.commit()
            
            if "HATA" in msg: return False, msg
            return True, msg
        except Exception as e:
            self.conn.rollback()
            return False, str(e).split('\n')[0]

    def add_review(self, loan_id, user_rating, tool_rating, comment):
        # puan ver
        try:
            self.cursor.callproc('sp_add_review', [loan_id, 'Renter', user_rating, tool_rating, comment])
            msg = self.cursor.fetchone()[0]
            self.conn.commit()
            return True, msg
        except Exception as e:
            self.conn.rollback()
            return False, str(e).split('\n')[0]

    def get_loans_of_my_tools(self):
        # benim aletlerimin kiralamalari
        try:
            self.cursor.callproc('sp_get_loans_of_my_tools', [self.current_user_id])
            return self.cursor.fetchall()
        except Exception:
            self.conn.rollback()
            return []
    
    def add_owner_review(self, loan_id, rating, comment):
        # owner puan ver
        try:
            self.cursor.callproc('sp_add_review', [loan_id, 'Owner', rating, None, comment])
            msg = self.cursor.fetchone()[0]
            self.conn.commit()
            return True, msg
        except Exception as e:
            self.conn.rollback()
            return False, str(e).split('\n')[0]









#test code

if __name__ == "__main__":
    print("Testing DatabaseManager...")
    db = DatabaseManager()

    if db.connect():
        #try a login
        db.check_login("ali_y","1234")

        db.disconnect()

    else:
        print("Failed to connect to the database.")