from PyQt5.QtWidgets import (QMainWindow, QWidget, QVBoxLayout, QTabWidget, 
                             QTableWidget, QTableWidgetItem, QLabel, QHeaderView, 
                             QPushButton, QDialog, QFormLayout, QComboBox, 
                             QLineEdit, QMessageBox, QDateEdit, QHBoxLayout, 
                             QTextEdit, QSpinBox) 
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
            layout.addWidget(self.table_market)

            # kiralama butonu
            self.btn_rent = QPushButton("Seçili Aleti Kirala")
            self.btn_rent.clicked.connect(self.open_rent_dialog)
            layout.addWidget(self.btn_rent)

            self.tab_market.setLayout(layout)


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

    #==============================================================

    def setup_rentals_tab(self):
            layout = QVBoxLayout()
            layout.addWidget(QLabel("Başkasından kiraladığınız aletler:"))
            
            self.table_rentals = QTableWidget()
            self.table_rentals.setColumnCount(5)
            self.table_rentals.setHorizontalHeaderLabels(["Kira ID", "Alet Adı", "Başlangıç", "Bitiş", "Durum"])
            self.table_rentals.horizontalHeader().setSectionResizeMode(1, QHeaderView.Stretch)
            self.table_rentals.setSelectionBehavior(QTableWidget.SelectRows)
            layout.addWidget(self.table_rentals)

            btn_layout = QHBoxLayout()
            self.btn_return = QPushButton("Aleti İade Et")
            self.btn_return.clicked.connect(self.return_tool_action)
            btn_layout.addWidget(self.btn_return)

            self.btn_review = QPushButton("Puanla ve Yorum Yap")
            self.btn_review.clicked.connect(self.review_tool_action)
            btn_layout.addWidget(self.btn_review)
            
            layout.addLayout(btn_layout)
            self.tab_rentals.setLayout(layout)

    def refresh_rentals_table(self):
            self.table_rentals.setRowCount(0)
            rentals = self.db.get_my_rentals()
            for row_idx, row_data in enumerate(rentals):
                self.table_rentals.insertRow(row_idx)
                for col_idx, data in enumerate(row_data):
                    self.table_rentals.setItem(row_idx, col_idx, QTableWidgetItem(str(data)))
                    
    def return_tool_action(self):
        row = self.table_rentals.currentRow()
        if row < 0: return

        loan_id = int(self.table_rentals.item(row, 0).text())
        success, msg = self.db.return_tool(loan_id)
        if success:
            QMessageBox.information(self, "Bilgi", msg)
            self.refresh_rentals_table()
        else:
            QMessageBox.critical(self, "Hata", msg)

    def review_tool_action(self):
        row = self.table_rentals.currentRow()
        if row < 0: return
        
        # Bu satırların hepsi 'def' hizasından içeride olmalı (1 tab veya 4 boşluk)
        status = self.table_rentals.item(row, 4).text()
        if status != 'Tamamlandı':
            QMessageBox.warning(self, "Uyarı", "Yorum yapmak için önce aleti iade etmelisiniz.")
            return

        loan_id = int(self.table_rentals.item(row, 0).text())
        tool_name = self.table_rentals.item(row, 1).text()

        dialog = ReviewDialog(self.db, loan_id, tool_name, self)
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
    def __init__(self, db_manager, loan_id, tool_name, parent=None):
        super().__init__(parent)
        self.db = db_manager
        self.loan_id = loan_id
        
        self.setWindowTitle("Puan Ver")
        self.setGeometry(300, 300, 300, 300)
        
        layout = QVBoxLayout()
        layout.addWidget(QLabel(f"{tool_name} için değerlendirmeniz:"))
        
        form = QFormLayout()
        
        self.spin_tool = QSpinBox()
        self.spin_tool.setRange(1, 5)
        self.spin_tool.setValue(5)
        
        self.spin_user = QSpinBox()
        self.spin_user.setRange(1, 5)
        self.spin_user.setValue(5)
        
        self.txt_comment = QTextEdit()
        
        form.addRow("Alet Puanı (1-5):", self.spin_tool)
        form.addRow("Sahip Puanı (1-5):", self.spin_user)
        layout.addLayout(form)
        
        layout.addWidget(QLabel("Yorum:"))
        layout.addWidget(self.txt_comment)
        
        btn = QPushButton("Yorumu Gönder")
        btn.clicked.connect(self.send_review)
        layout.addWidget(btn)
        self.setLayout(layout)
        
    def send_review(self):
        comment = self.txt_comment.toPlainText()
        tool = self.spin_tool.value()
        user = self.spin_user.value()
        
        success, msg = self.db.add_review(self.loan_id, user, tool, comment)
        if success:
            QMessageBox.information(self, "Teşekkürler", msg)
            self.accept()
        else:
            QMessageBox.critical(self, "Hata", msg)