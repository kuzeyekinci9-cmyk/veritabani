from PyQt5.QtWidgets import (QMainWindow, QWidget, QVBoxLayout, QTabWidget, 
                             QTableWidget, QTableWidgetItem, QLabel, QHeaderView, 
                             QPushButton, QDialog, QFormLayout, QComboBox, 
                             QLineEdit, QMessageBox, QDateEdit, QHBoxLayout, 
                             QTextEdit, QSpinBox,QAbstractItemView) 
from PyQt5.QtCore import Qt,QDate


class UserWindow(QMainWindow):
    def __init__ (self, db_manager):
        super().__init__()
        self.db = db_manager
        self.user_id = self.db.current_user_id #who is logged in
        self.init_ui()

    def init_ui(self):
        self.setWindowTitle(f"ToolShare - Kullanıcı Paneli")
        self.setGeometry(150, 100, 800, 500)

        #main layout
        central_widget = QWidget()
        self.setCentralWidget(central_widget)
        main_layout = QVBoxLayout()
        central_widget.setLayout(main_layout)

        header_frame = QWidget()
        header_frame.setStyleSheet("background-color: #f0f0f0; border-bottom: 1px solid #ccc;")

        header_layout = QHBoxLayout()
        header_frame.setLayout(header_layout)

        lbl_db_status = QLabel("Veritabanı: Bağlı")
        lbl_db_status.setStyleSheet("font-weight: bold; color: green;")
        header_layout.addWidget(lbl_db_status)

        header_layout.addStretch()

        user_name = self.db.current_user_name
        lbl_user = QLabel(f"Hoşgeldin, {user_name}")
        lbl_user.setStyleSheet("font-size: 14px; font-weight: bold;")
        header_layout.addWidget(lbl_user)

        header_layout.addStretch() # araya boşluk 

        # 3. Güvenlik Puanı
        current_score = self.db.get_my_score()
        self.lbl_score = QLabel(f"Güvenlik Puanın: {current_score}")
        self.lbl_score.setStyleSheet("color: #d35400; font-weight: bold; font-size: 14px;")
        header_layout.addWidget(self.lbl_score)

        main_layout.addWidget(header_frame)

        #tabs
        self.tabs = QTabWidget()
        main_layout.addWidget(self.tabs)

        #tools tab
        self.tab_my_tools = QWidget()
        self.setup_my_tools_tab()
        self.tabs.addTab(self.tab_my_tools, "Aletlerim")

        self.tab_market = QWidget()
        self.setup_market_tab()
        self.tabs.addTab(self.tab_market, "Vitrin")

        self.tab_rentals = QWidget()
        self.setup_rentals_tab()
        self.tabs.addTab(self.tab_rentals, "Kiralamalarım ve İadeler")

        self.tabs.currentChanged.connect(self.on_tab_change)

    def on_tab_change(self, index):
        self.lbl_score.setText(f"Güvenlik Puanın: {self.db.get_my_score()}")

        if index == 0: # My Tools Tab
            self.refresh_my_tools_table()
        elif index == 1: # Market Tab
            self.perform_search()
        elif index == 2: # Rentals Tab
            self.refresh_rentals_table()
#==============================================================

    def setup_my_tools_tab(self):
        layout = QVBoxLayout()

        btn_layout = QHBoxLayout()

        self.btn_add = QPushButton("Yeni Alet Ekle")
        self.btn_add.clicked.connect(self.open_add_dialog)
        layout.addWidget(self.btn_add)

        self.btn_toggle = QPushButton("Alet Durumunu Değiştir")
        self.btn_toggle.clicked.connect(self.toggle_maintenance_action)
        btn_layout.addWidget(self.btn_toggle)

        self.btn_edit = QPushButton("Seçili Aleti Düzenle")
        self.btn_edit.clicked.connect(self.open_edit_dialog)
        layout.addWidget(self.btn_edit)

        self.btn_delete = QPushButton("Seçili Aleti Sil")
        self.btn_delete.setStyleSheet("background-color: #ffcccc;")
        self.btn_delete.clicked.connect(self.delete_selected_tool)
        layout.addWidget(self.btn_delete)

        layout.addLayout(btn_layout)
        layout.addWidget(QLabel("Sisteme eklediğiniz aletler:"))      
        


        self.table_tools = QTableWidget()
        self.table_tools.setColumnCount(6)
        self.table_tools.setHorizontalHeaderLabels(["ID", "Alet Adı", "Kategori", "Durum", "Puan","Açıklama"])
        self.table_tools.horizontalHeader().setSectionResizeMode(1, QHeaderView.Stretch)

        self.table_tools.setSelectionBehavior(QTableWidget.SelectRows)
        self.table_tools.setEditTriggers(QAbstractItemView.NoEditTriggers)

        layout.addWidget(self.table_tools)
        self.tab_my_tools.setLayout(layout)

        self.refresh_my_tools_table()

    def refresh_my_tools_table(self):
        self.table_tools.setRowCount(0) #clear existing

        tools = self.db.get_user_tools(self.user_id)

        for row_index, row_data in enumerate(tools):
            self.table_tools.insertRow(row_index)
            for col_index, data in enumerate(row_data):
                self.table_tools.setItem(row_index, col_index, QTableWidgetItem(str(data)))

    def open_add_dialog(self): # open dialog to add new tool
        dialog = AddToolDialog(self.db, self)
        if dialog.exec_() == QDialog.Accepted:
            self.refresh_my_tools_table()
    
    def delete_selected_tool(self):
        selected_row = self.table_tools.currentRow()

        if selected_row < 0:
            QMessageBox.warning(self, "Hata", "Lütfen silinecek bir alet seçin.")
            return

        tool_id = int(self.table_tools.item(selected_row, 0).text())
        tool_name = self.table_tools.item(selected_row, 1).text()

        reply = QMessageBox.question(self, "Onay",
                                     f"'{tool_name}' adlı aleti silmek istediğinize emin misiniz?",
                                        QMessageBox.Yes | QMessageBox.No, QMessageBox.No)
        if reply == QMessageBox.Yes:
            success, message = self.db.delete_tool(tool_id)

            if success:
                QMessageBox.information(self, "Başarılı", "Alet başarıyla silindi.")
                self.refresh_my_tools_table()
            else:
                QMessageBox.critical(self, "Hata", f"Silinemedi: {message}")
    
    def toggle_maintenance_action(self):
        row = self.table_tools.currentRow()
        if row < 0: return

        tool_id = int(self.table_tools.item(row, 0).text())
        success, message = self.db.toggle_maintenance(tool_id)
        if success:
            QMessageBox.information(self, "Bilgi", message)
            self.refresh_my_tools_table()
        else:
            QMessageBox.critical(self, "Hata", f"İşlem başarısız: {message}")


    def open_edit_dialog(self):
        # Only for editing description (Status is handled by the Toggle button)
        row = self.table_tools.currentRow()
        if row < 0:
            QMessageBox.warning(self, "Hata", "Lütfen düzenlenecek bir alet seçin.")
            return
        
        tool_id = int(self.table_tools.item(row, 0).text())
        current_name = self.table_tools.item(row, 1).text()
        current_desc = self.table_tools.item(row, 5).text()
        
        dialog = UpdateToolDescriptionDialog(self.db, tool_id, current_name, current_desc, self)
        if dialog.exec_() == QDialog.Accepted:
            self.refresh_my_tools_table()

#==============================================================


    def setup_market_tab(self):
            layout = QVBoxLayout()

            filter_layout = QVBoxLayout() 
            
            self.txt_search = QLineEdit()
            self.txt_search.setPlaceholderText("Alet ara...")
            self.txt_search.returnPressed.connect(self.perform_search)
            
            self.combo_sort = QComboBox()
            self.combo_sort.addItems(["İsim (A-Z)", "İsim (Z-A)", "Alet Puanı (Yüksek)", "Sahip Puanı (Yüksek)"])
            
            btn_search = QPushButton("Ara / Yenile")
            btn_search.clicked.connect(self.perform_search)

            filter_layout.addWidget(QLabel("Ara:"))
            filter_layout.addWidget(self.txt_search)
            filter_layout.addWidget(QLabel("Sırala:"))
            filter_layout.addWidget(self.combo_sort)
            filter_layout.addWidget(btn_search)
            layout.addLayout(filter_layout)

            # market tablosu
            self.table_market = QTableWidget()
            self.table_market.setColumnCount(7)
            self.table_market.setHorizontalHeaderLabels(["ID", "Alet Adı", "Kategori", "Sahibi", "Sahip P.", "Alet P.", "Durum"])
            self.table_market.horizontalHeader().setSectionResizeMode(1, QHeaderView.Stretch)
            self.table_market.setSelectionBehavior(QTableWidget.SelectRows)
            self.table_market.setEditTriggers(QAbstractItemView.NoEditTriggers)
            layout.addWidget(self.table_market)

            # kiralama butonu
            btn_layout = QHBoxLayout() # Yan yana dizmek için

            self.btn_rent = QPushButton("Seçili Aleti Kirala")
            self.btn_rent.setStyleSheet("font-weight: bold; color: green;")
            self.btn_rent.clicked.connect(self.open_rent_dialog)
            btn_layout.addWidget(self.btn_rent)

            self.btn_show_reviews = QPushButton("Yorumları Oku")
            self.btn_show_reviews.clicked.connect(self.open_reviews_dialog) 
            btn_layout.addWidget(self.btn_show_reviews)

            layout.addLayout(btn_layout)
            self.tab_market.setLayout(layout)
            self.perform_search() #ilk yüklemede göster


    def perform_search(self):
            keyword = self.txt_search.text()
            sort_opt = self.combo_sort.currentIndex() + 1
            
            results = self.db.search_tools(keyword, sort_opt)
            self.table_market.setRowCount(0)
            
            for row_idx, row_data in enumerate(results):
                self.table_market.insertRow(row_idx)
                for col_idx, data in enumerate(row_data):
                    self.table_market.setItem(row_idx, col_idx, QTableWidgetItem(str(data)))

    def open_rent_dialog(self):
            row = self.table_market.currentRow()
            if row < 0:
                QMessageBox.warning(self, "Uyarı", "Lütfen kiralamak için bir alet seçin.")
                return
            
            tool_id = int(self.table_market.item(row, 0).text())
            tool_name = self.table_market.item(row, 1).text()
            
            dialog = RentToolDialog(self.db, tool_id, tool_name, self)
            if dialog.exec_() == QDialog.Accepted:
                self.perform_search()

    def open_reviews_dialog(self):
            row = self.table_market.currentRow()
            if row < 0:
                QMessageBox.warning(self, "Uyarı", "Lütfen yorumlarını görmek istediğiniz bir alet seçin.")
                return
            
            tool_id = int(self.table_market.item(row, 0).text())
            tool_name = self.table_market.item(row, 1).text()
            
            dialog = ToolReviewDialog(self.db, tool_id, tool_name, self)
            dialog.exec_()
    #==============================================================

    def setup_rentals_tab(self):
        layout = QVBoxLayout()
            
        layout.addWidget(QLabel("Başkasından Kiraladığınız Aletler"))
        self.table_rentals_out = QTableWidget()
        self.table_rentals_out.setColumnCount(5)
        self.table_rentals_out.setHorizontalHeaderLabels(["Kiralama ID", "Alet Adı", "Kiralanma Tarihi", "Bitiş", "Durum"])
        self.table_rentals_out.horizontalHeader().setSectionResizeMode(1, QHeaderView.Stretch)
        self.table_rentals_out.setEditTriggers(QAbstractItemView.NoEditTriggers)
        self.table_rentals_out.setSelectionBehavior(QTableWidget.SelectRows)
        layout.addWidget(self.table_rentals_out)

        btn_layout_1 = QHBoxLayout()
        self.btn_return_out = QPushButton("Seçili Aleti İade Et")
        self.btn_return_out.clicked.connect(lambda: self.return_tool_action(is_owner=False))
        btn_layout_1.addWidget(self.btn_return_out)

        self.btn_review_out = QPushButton("Seçili Aleti ve Sahibini Puanla")
        self.btn_review_out.clicked.connect(lambda: self.review_tool_action(is_owner=False))
        btn_layout_1.addWidget(self.btn_review_out)
        layout.addLayout(btn_layout_1)

        line = QLabel(); line.setFixedHeight(2); line.setStyleSheet("background-color: #ccc;")
        layout.addWidget(line)

        layout.addWidget(QLabel("Sizden Kiralanan Aletler"))
        self.table_rentals_in = QTableWidget()
        self.table_rentals_in.setColumnCount(6)
        self.table_rentals_in.setHorizontalHeaderLabels(["Kiralama ID", "Alet Adı", "Kiracı", "Kiralanma Tarihi", "Bitiş", "Durum"])
        self.table_rentals_in.horizontalHeader().setSectionResizeMode(1, QHeaderView.Stretch)
        self.table_rentals_in.setEditTriggers(QAbstractItemView.NoEditTriggers)
        self.table_rentals_in.setSelectionBehavior(QTableWidget.SelectRows)
        layout.addWidget(self.table_rentals_in)

        btn_layout_2 = QHBoxLayout()
        self.btn_return_in = QPushButton("Kiralanan Aleti Teslim Al (Sahip Olarak)")
        self.btn_return_in.clicked.connect(lambda: self.return_tool_action(is_owner=True))
        btn_layout_2.addWidget(self.btn_return_in)

        self.btn_review_in = QPushButton("Kiracıyı Puanla(Sahip Olarak)")
        self.btn_review_in.clicked.connect(lambda: self.review_tool_action(is_owner=True))
        btn_layout_2.addWidget(self.btn_review_in)
        layout.addLayout(btn_layout_2)

        self.tab_rentals.setLayout(layout)
        self.refresh_rentals_table()

    def refresh_rentals_table(self):
        #refresh both tables
        self.table_rentals_out.setRowCount(0)
        rentals = self.db.get_my_rentals()
        for r, row_data in enumerate(rentals):
            self.table_rentals_out.insertRow(r)
            for c, data in enumerate(row_data):
                self.table_rentals_out.setItem(r, c, QTableWidgetItem(str(data)))

        # refresh verilen aletler tablosu
        self.table_rentals_in.setRowCount(0)
        lending = self.db.get_loans_of_my_tools() 
        for r, row_data in enumerate(lending):
            self.table_rentals_in.insertRow(r)
            for c, data in enumerate(row_data):
                self.table_rentals_in.setItem(r, c, QTableWidgetItem(str(data)))
                    
    def return_tool_action(self,is_owner):
        table = self.table_rentals_in if is_owner else self.table_rentals_out
        row = table.currentRow()
        if row < 0:
            QMessageBox.warning(self, "Uyarı", "Lütfen işlem yapılacak satırı seçin.")
            return

        loan_id = int(table.item(row, 0).text())

        reply = QMessageBox.question(self, "Onay",
                                     "Seçili aletin iade edildiğini onaylıyor musunuz?",
                                     QMessageBox.Yes | QMessageBox.No, QMessageBox.No)
        if reply != QMessageBox.Yes:
            return
        
        success, msg = self.db.return_tool(loan_id)
        if success:
            QMessageBox.information(self, "Başarılı", msg)
            self.refresh_rentals_table()
            self.perform_search() # update market availability
            self.refresh_my_tools_table() # update my tools status
        else:
            QMessageBox.critical(self, "Hata", msg)

    def review_tool_action(self, is_owner):
        table = self.table_rentals_in if is_owner else self.table_rentals_out
        row = table.currentRow()
        if row < 0: 
            QMessageBox.warning(self,"Uyarı","Lütfen puanlanacak işlemi seçin.")
            return
        
        status_col = 5 if is_owner else 4
        status = table.item(row, status_col).text()

        if status != 'Tamamlandı':
            QMessageBox.warning(self, "Uyarı", "Sadece tamamlanmış kiralamalar için puan verebilirsiniz.")
            return
        
        loan_id = int(table.item(row, 0).text())
        #target name: if i am owner, i am rating the renter(col 2), if renter i am rating tool col 1.
        target_name = table.item(row, 2).text() if is_owner else table.item(row, 1).text()

        dialog = ReviewDialog(self.db, loan_id, target_name, is_owner, self)
        dialog.exec_()
#==============================================================

class AddToolDialog(QDialog): # window for adding tools
    def __init__(self, db_manager, parent=None):
       super().__init__(parent)
       self.db = db_manager
       self.setWindowTitle("Yeni Alet Ekle")
       self.setGeometry(200, 200, 300, 200)
       self.init_ui()

    def init_ui(self):
        layout = QVBoxLayout()
        form_layout = QFormLayout()

        self.txt_name = QLineEdit() #tool name
        form_layout.addRow("Alet Adı:", self.txt_name)

        self.txt_desc = QLineEdit() #tool desc
        form_layout.addRow("Alet Açıklaması:", self.txt_desc)

        self.combo_cat = QComboBox() #categories
        cats = self.db.get_all_categories()
        for cat_id, cat_name in cats:
            self.combo_cat.addItem(cat_name, cat_id) #display name, store id

        form_layout.addRow("Kategori:", self.combo_cat)

        layout.addLayout(form_layout)

        #save button
        
        self.btn_save = QPushButton("Ekle ve Kaydet") 
        self.btn_save.clicked.connect(self.save_tool)
        layout.addWidget(self.btn_save)

        self.setLayout(layout)

    def save_tool(self):
        name = self.txt_name.text()
        desc = self.txt_desc.text()
        cat_id = self.combo_cat.currentData() # get selected category id

        if not name or not desc:
            QMessageBox.warning(self, "Hata", "Lütfen tüm alanları doldurun.")
            return

        success = self.db.add_new_tool(cat_id, name, desc)

        if success:
            QMessageBox.information(self, "Başarılı", "Alet başarıyla eklendi.")
            self.accept() # close dialog
        else:
            QMessageBox.critical(self, "Hata", "Alet eklenirken bir hata oluştu.")                

class UpdateToolDescriptionDialog(QDialog): # window for editing tools
    def __init__(self, db_manager, tool_id, current_name, current_desc, parent=None):
       super().__init__(parent)
       self.db = db_manager
       self.tool_id = tool_id
       
       self.setWindowTitle(f"Açıklama Düzenle")
       self.setGeometry(250, 250, 300, 150)

       layout = QVBoxLayout()
       form_layout = QFormLayout()

       self.lbl_name = QLabel(current_name)
       form_layout.addRow("Alet Adı:", self.lbl_name)

       self.txt_desc = QLineEdit(current_desc)
       form_layout.addRow("Yeni Açıklama:", self.txt_desc)

       layout.addLayout(form_layout)

       self.btn_update = QPushButton("Kaydet")
       self.btn_update.clicked.connect(self.update_action)
       layout.addWidget(self.btn_update)

       self.setLayout(layout)

    def update_action(self):
        new_desc = self.txt_desc.text()
        success, message = self.db.update_tool_description(self.tool_id, new_desc)

        if success:
            QMessageBox.information(self, "Başarılı", message)
            self.accept()
        else:
            QMessageBox.critical(self, "Hata", message)

class RentToolDialog(QDialog): # window for renting tools
    def __init__(self, db_manager, tool_id, tool_name, parent=None):
        super().__init__(parent)
        self.db = db_manager
        self.tool_id = tool_id
        
        self.setWindowTitle(f"Kirala: {tool_name}")
        self.setGeometry(300, 300, 300, 200)
        
        layout = QVBoxLayout()
        form = QFormLayout()
        
        self.date_start = QDateEdit()
        self.date_start.setDate(QDate.currentDate())
        self.date_start.setCalendarPopup(True)
        
        self.date_end = QDateEdit()
        self.date_end.setDate(QDate.currentDate().addDays(1))
        self.date_end.setCalendarPopup(True)
        
        form.addRow("Başlangıç:", self.date_start)
        form.addRow("Bitiş:", self.date_end)
        layout.addLayout(form)
        
        btn = QPushButton("Kiralamayı Tamamla")
        btn.clicked.connect(self.rent)
        layout.addWidget(btn)
        self.setLayout(layout)

    def rent(self):
        start = self.date_start.dateTime().toPyDateTime()
        end = self.date_end.dateTime().toPyDateTime()
        
        success, msg = self.db.rent_tool(self.tool_id, start, end)
        if success:
            QMessageBox.information(self, "Başarılı", msg)
            self.accept()
        else:
            QMessageBox.critical(self, "Kiralama Başarısız", msg)

class ReviewDialog(QDialog): # window for reviewing tools
    def __init__(self, db_manager, loan_id, target_name, is_owner, parent=None):
        super().__init__(parent)
        self.db = db_manager
        self.loan_id = loan_id
        self.is_owner = is_owner

        type_str = "Kiracıyı" if is_owner else "Aleti ve Sahibini"
        self.setWindowTitle(f"{type_str} Puanla")
        self.setGeometry(300, 300, 300, 300)

        layout = QVBoxLayout()
        layout.addWidget(QLabel(f"{target_name} için değerlendirmeniz:"))

        form = QFormLayout()

        self.spin_user = QSpinBox()
        self.spin_user.setRange(1, 5); self.spin_user.setValue(5)
        user_label = "Kiracı Puanı (1-5):" if is_owner else "Sahip Puanı (1-5):"
        form.addRow(user_label, self.spin_user)

        self.spin_tool = None
        if not is_owner:
            self.spin_tool = QSpinBox()
            self.spin_tool.setRange(1, 5); self.spin_tool.setValue(5)
            form.addRow("Alet Puanı (1-5):", self.spin_tool)
        
        layout.addLayout(form)

        layout.addWidget(QLabel("Yorum:"))
        self.txt_comment = QTextEdit()
        layout.addWidget(self.txt_comment)

        btn = QPushButton("Yorumu Gönder")
        btn.clicked.connect(self.send_review)
        layout.addWidget(btn)
        self.setLayout(layout)
        
    def send_review(self):
        comment = self.txt_comment.toPlainText()
        user_rating = self.spin_user.value()

        if self.is_owner:
            success, msg = self.db.add_owner_review(self.loan_id, user_rating, comment) 
        else:
            tool_rating = self.spin_tool.value()
            success, msg = self.db.add_review(self.loan_id, user_rating, tool_rating, comment)
        
        if success:
            QMessageBox.information(self, "Başarılı", msg)
            self.accept()
        else:
            QMessageBox.critical(self, "Hata", msg)

class ToolReviewDialog(QDialog):
    def __init__(self, db_manager, tool_id, tool_name, parent=None):
        super().__init__(parent)
        self.setWindowTitle(f"Yorumlar: {tool_name}")
        self.setGeometry(350, 350, 400, 300)

        layout = QVBoxLayout()

        reviews = db_manager.get_tool_reviews(tool_id)

        if not reviews:
            layout.addWidget(QLabel("Bu alet için henüz yorum yapılmamış."))
        else:
            table = QTableWidget()
            table.setColumnCount(4)
            table.setHorizontalHeaderLabels(["Kullanıcı", "Puan", "Yorum", "Tarih"])
            table.horizontalHeader().setSectionResizeMode(2, QHeaderView.Stretch)
            table.setEditTriggers(QAbstractItemView.NoEditTriggers)
            table.setSelectionBehavior(QTableWidget.SelectRows)

            table.setRowCount(len(reviews))
            for r, row_data in enumerate(reviews):
                
                table.setItem(r, 0, QTableWidgetItem(str(row_data[0]))) # user name
                table.setItem(r, 1, QTableWidgetItem(str(row_data[1]))) #puan
                table.setItem(r, 2, QTableWidgetItem(str(row_data[2]))) #yorum
                table.setItem(r, 3, QTableWidgetItem(str(row_data[3]))) #tarih
            
            layout.addWidget(table)

        btn_close = QPushButton("Kapat")
        btn_close.clicked.connect(self.accept)
        layout.addWidget(btn_close)

        self.setLayout(layout)