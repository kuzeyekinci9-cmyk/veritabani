import psycopg2

class DatabaseManager:
    def __init__(self):
        self.conn = None
        self.cursor = None
        self.current_user_id = None
        self.current_role = None # 'admin' or 'user'

    def connect(self):
        #connect to the PostgreSQL database
        try:
            self.conn = psycopg2.connect(
                host="localhost",
                database="toolshare_db",
                user="postgres",
                password="0000" # Update this with your actual password
            )
            self.cursor = self.conn.cursor()
            print("Database connection established.")
            return True
        except Exception as e:
            print(f"Error connecting to database: {e}")
            return False
        
    def disconnect(self):
        # disconnect from the PostgreSQL database
        if self.conn:
            self.conn.close()
            print("Database connection closed.")

    def check_login(self, username, password):
        # check user credentials for login
        
        sql = "SELECT user_id, role, full_name FROM Users WHERE username=%s AND password=%s"

        try:
            self.cursor.execute(sql, (username, password))
            result = self.cursor.fetchone() #bring back one record

            if result:
                # found a matching user
                self.current_user_id = result[0]
                self.current_role = result[1]
                print(f"Entry approved: {result[2]} logged in as {self.current_role}.")
                return True 
            else:
                print("Entry denied: Invalid username or password.")
                return False   
        except Exception as e:
            print(f"Error during login check: {e}")
            return False
    
    def get_user_tools(self, user_id):
        try:
            self.cursor.callproc('sp_get_my_tools', [user_id])

            return self.cursor.fetchall() # dönen tabloyu al
        
        except Exception as e:
            self.conn.rollback()
            print(f"Error fetching user tools: {e}")
            return []
    
    def get_all_categories(self): #get all cats while adding tools.
        sql = "SELECT category_id, category_name FROM Categories ORDER BY category_id"

        try:
            self.cursor.execute(sql)
            return self.cursor.fetchall()
        except Exception as e:
            print(f"Error fetching categories: {e}")
            return []
        
    def add_new_tool(self, owner_id, category_id, name, description):
        
        try:
            self.cursor.callproc('sp_add_tool', [owner_id, category_id, name, description])
            self.conn.commit()
            print("New tool added successfully.")
            return True, 
        except Exception as e:
            self.conn.rollback()
            print(f"Error adding new tool: {e}")
            return False
    
    def delete_tool(self, tool_id):
        try:
            self.cursor.callproc('sp_delete_tool', [tool_id])
            self.conn.commit()
            print("Tool deleted successfully.")
            return True, "Alet başarıyla silindi." 
            
        except Exception as e:
            self.conn.rollback()
            return False, str(e)
    
    def update_tool(self, tool_id, new_desc, new_status):
        try:
            self.cursor.callproc('sp_update_tool_info', [tool_id, new_desc, new_status])
            self.conn.commit()
            print("Tool updated successfully.")
            return True, "Alet başarıyla güncellendi."
        except Exception as e:
            self.conn.rollback()
            return False, f"Güncelleme hatası: {e}"













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