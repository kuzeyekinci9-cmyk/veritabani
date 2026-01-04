from PyQt5.QtWidgets import (QMainWindow, QWidget, QVBoxLayout, QHBoxLayout, 
                             QTabWidget, QTableWidget, QTableWidgetItem, 
                             QPushButton, QLabel, QHeaderView, QMenu, 
                             QMessageBox, QDialog, QFormLayout, QLineEdit, 
                             QComboBox, QSpinBox, QGroupBox,QAbstractItemView)
from PyQt5.QtCore import Qt
from .user_window import ToolReviewDialog

class AdminWindow(QMainWindow):
    def __init__(self, db_manager):
        super().__init__()
        self.db = db_manager
        self.init_ui()

    def init_ui(self):
        self.setWindowTitle("ToolShare - Admin Paneli")
        self.setGeometry(100, 100, 900, 600)

        central_widget = QWidget()
        self.setCentralWidget(central_widget)
        layout = QVBoxLayout()
        central_widget.setLayout(layout)

        #baslik
        lbl_title = QLabel(f"Yönetici Paneli - Aktif Admin: {self.db.current_user_name}")
        lbl_title.setStyleSheet("font-weight: bold; font-size: 14px; color:darkred;")
        layout.addWidget(lbl_title)

        #sekmeler
        self.tabs = QTabWidget()
        layout.addWidget(self.tabs)

        #sekme 1 : kullanıcı yönetimi
        self.tab_users = QWidget()
        self.setup_users_tab()
        self.tabs.addTab(self.tab_users, "Kullanıcı Yönetimi")

        #sekme 2: raporlar
        self.tab_reports = QWidget()
        self.setup_reports_tab()
        self.tabs.addTab(self.tab_reports, "Raporlar ve Analizler")

         # Sekme 3: global kayıtlar
        self.tab_global = QWidget()
        self.setup_global_tab()
        self.tabs.addTab(self.tab_global, "Global Kayıtlar (Tüm Veriler)")

    #sekme 1: kullanıcı yönetimi

    def setup_users_tab(self):
        layout = QVBoxLayout()

        btn_add = QPushButton("Yeni Kullanıcı Ekle")
        btn_add.clicked.connect(self.open_add_user_dialog)
        layout.addWidget(btn_add)

        layout.addWidget(QLabel("Kullanıcı Listesi (Sağ tık ile yetki yönetimi yapabilirsiniz.)"))

        #tablo
        self.table_users = QTableWidget()
        self.table_users.setColumnCount(5)
        self.table_users.setHorizontalHeaderLabels(["ID", "Kullanıcı Adı", "Tam İsim", "Rol", "Güvenlik Puanı"])
        self.table_users.horizontalHeader().setSectionResizeMode(2,QHeaderView.Stretch)
        self.table_users.setSelectionBehavior(QTableWidget.SelectRows)

        #sağ tık menüsü
        self.table_users.setContextMenuPolicy(Qt.CustomContextMenu)
        self.table_users.customContextMenuRequested.connect(self.show_context_menu)

        layout.addWidget(self.table_users)
        self.tab_users.setLayout(layout)

        self.refresh_user_table()

    def refresh_user_table(self):
        self.table_users.setRowCount(0)
        users = self.db.get_all_users()
        for r, row_data in enumerate(users):
            self.table_users.insertRow(r)
            for c, data in enumerate(row_data):
                self.table_users.setItem(r, c, QTableWidgetItem(str(data)))

    
    def open_add_user_dialog(self):
        dialog = AddUserDialog(self.db, self)
        if dialog.exec_() == QDialog.Accepted:
            self.refresh_user_table()
    
    def show_context_menu(self, pos):
        #sağ tık menüsü
        row = self.table_users.rowAt(pos.y())

        if row < 0 : return

        user_id = int(self.table_users.item(row, 0).text())
        role = self.table_users.item(row, 3).text()
        user_name = self.table_users.item(row, 1).text()

        menu = QMenu()

        if role == 'user':
            action_make_admin = menu.addAction("Yönetici/Admin Yap")
            action = menu.exec_(self.table_users.mapToGlobal(pos))
            if action == action_make_admin:
                self.change_role(user_id,user_name,"admin")

        elif role == 'admin':
            action_revoke = menu.addAction("Admin Yetkisini Al")
            action = menu.exec_(self.table_users.mapToGlobal(pos))
            if action == action_revoke:
                self.change_role(user_id,user_name,"user")

    def change_role(self,user_id,name,new_role):
        reply = QMessageBox.question(self, "Onay",f"{name} kullancısının rolü '{new_role}' olarak değiştirilsin mi?", QMessageBox.Yes | QMessageBox.No)

        if reply != QMessageBox.Yes : return

        if new_role == 'admin':
            success, msg = self.db.make_admin(user_id)
        else:
            success,msg = self.db.revoke_admin(user_id)
        
        if success:
            QMessageBox.information(self,"Bilgi",msg)
            self.refresh_user_table()
        else:
            QMessageBox.critical(self,"Hata",msg)
    #-------------------- raporlar

    def setup_reports_tab(self):
        layout = QVBoxLayout()

        #aylık aktivite

        grp_activity = QGroupBox("Aylık Toplam Paylaşım")
        box1 = QVBoxLayout()

        h_layout = QHBoxLayout()
        self.combo_month = QComboBox()
        self.combo_month.addItems([str(i) for i in range(1,13)])
        self.spin_year = QSpinBox()
        self.spin_year.setRange(2020,2030); self.spin_year.setValue(2026)

        btn_calc = QPushButton("Hesapla")
        btn_calc.clicked.connect(self.calc_activity)

        h_layout.addWidget(QLabel("Ay:"))
        h_layout.addWidget(self.combo_month)
        h_layout.addWidget(QLabel("Yıl:"))
        h_layout.addWidget(self.spin_year)
        h_layout.addWidget(btn_calc)

        self.lbl_activity_result = QLabel("Sonuç: -")
        self.lbl_activity_result.setStyleSheet("font-weight: bold;font-size:14px")

        box1.addLayout(h_layout)
        box1.addWidget(self.lbl_activity_result)
        grp_activity.setLayout(box1)
        layout.addWidget(grp_activity)

        #most generous
        grp_top = QGroupBox("En Yardımsever Kullanıcılar(Top Sharers)")
        box2 = QVBoxLayout()

        h_layout2 = QHBoxLayout()
        self.spin_min_share = QSpinBox()
        self.spin_min_share.setValue(1)
        btn_list = QPushButton("Listele")       
        btn_list.clicked.connect(self.list_top_sharers)

        h_layout2.addWidget(QLabel("Minimum Paylaşım Sayısı"))
        h_layout2.addWidget(self.spin_min_share)
        h_layout2.addWidget(btn_list)

        self.table_top = QTableWidget()
        self.table_top.setColumnCount(2)
        self.table_top.setHorizontalHeaderLabels(["Komşu Adı", "Paylaşım Sayısı"])
        self.table_top.horizontalHeader().setSectionResizeMode(0, QHeaderView.Stretch)

        box2.addLayout(h_layout2)
        box2.addWidget(self.table_top)
        grp_top.setLayout(box2)
        layout.addWidget(grp_top)

        self.tab_reports.setLayout(layout)
    
    def calc_activity(self):
        m = int(self.combo_month.currentText())
        y = self.spin_year.value()
        days = self.db.get_monthly_activity(m, y)
        self.lbl_activity_result.setText(f"Sonuç: {m}/{y} döneminde toplam {days} gün paylaşım yapıldı.")

    def list_top_sharers(self):
        min_s = self.spin_min_share.value()
        data = self.db.get_top_sharers(min_s)
        
        self.table_top.setRowCount(0)
        for r, row in enumerate(data):
            self.table_top.insertRow(r)
            self.table_top.setItem(r, 0, QTableWidgetItem(str(row[0])))
            self.table_top.setItem(r, 1, QTableWidgetItem(str(row[1])))
    
    # =========================================================================
    # SEKME 3: GLOBAL KAYITLAR
    def setup_global_tab(self):
        layout = QVBoxLayout()

        # TUM ALETLER
        grp_tools = QGroupBox("Sistemdeki Tüm Aletler (Müsait / Kirada / Bakımda)")
        box1 = QVBoxLayout()
        
        self.table_all_tools = QTableWidget()
        self.table_all_tools.setColumnCount(8)
        self.table_all_tools.setHorizontalHeaderLabels(["ID", "Alet Adı", "Kategori", "Sahibi", "Durum", "Alet P.", "Sahip P.", "Açıklama"])
        self.table_all_tools.horizontalHeader().setSectionResizeMode(1, QHeaderView.Stretch)
        self.table_all_tools.setSelectionBehavior(QTableWidget.SelectRows)
        self.table_all_tools.setEditTriggers(QAbstractItemView.NoEditTriggers)

        h_layout_tools = QHBoxLayout()
        
        btn_refresh_tools = QPushButton("Aletleri Yenile")
        btn_refresh_tools.clicked.connect(self.refresh_all_tools_table)

        btn_read_reviews = QPushButton("Yorumları Oku")
        btn_read_reviews.clicked.connect(self.admin_read_reviews)
        
        # Admin icin alet silme butonu
        btn_delete_tool = QPushButton("Seçili Aleti Zorla Sil (Admin Yetkisiyle)")
        btn_delete_tool.setStyleSheet("background-color: #ffcccc;")
        btn_delete_tool.clicked.connect(self.admin_delete_tool)

        h_layout_tools.addWidget(btn_refresh_tools)
        h_layout_tools.addWidget(btn_read_reviews)
        h_layout_tools.addWidget(btn_delete_tool)
        
        box1.addWidget(self.table_all_tools)
        box1.addLayout(h_layout_tools)
        grp_tools.setLayout(box1)
        layout.addWidget(grp_tools)

        # TUM KIRALAMALAR
        grp_loans = QGroupBox("Sistemdeki Tüm Kiralama İşlemleri")
        box2 = QVBoxLayout()
        
        self.table_all_loans = QTableWidget()
        self.table_all_loans.setColumnCount(7)
        self.table_all_loans.setHorizontalHeaderLabels(["Loan ID", "Alet Adı", "Kiracı", "Sahibi", "Başlangıç", "Bitiş", "Durum"])
        self.table_all_loans.horizontalHeader().setSectionResizeMode(1, QHeaderView.Stretch)
        self.table_all_loans.setSelectionBehavior(QTableWidget.SelectRows)
        self.table_all_loans.setEditTriggers(QAbstractItemView.NoEditTriggers)

        h_layout_loans = QHBoxLayout()

        btn_refresh_loans = QPushButton("Kiralamaları Yenile")
        btn_refresh_loans.clicked.connect(self.refresh_all_loans_table)

        btn_force_return = QPushButton("Kiralamayı Zorla Bitir (Force Return)")
        btn_force_return.setStyleSheet("color: red; font-weight: bold;")
        btn_force_return.clicked.connect(self.admin_force_return)

        h_layout_loans.addWidget(btn_refresh_loans)
        h_layout_loans.addWidget(btn_force_return)
        
        box2.addWidget(self.table_all_loans)
        box2.addLayout(h_layout_loans)
        grp_loans.setLayout(box2)
        layout.addWidget(grp_loans)

        self.tab_global.setLayout(layout)

        self.refresh_all_tools_table()
        self.refresh_all_loans_table()

    def refresh_all_tools_table(self):
        self.table_all_tools.setRowCount(0)
        tools = self.db.get_all_tools_global()
        for r, row in enumerate(tools):
            self.table_all_tools.insertRow(r)
            for c, data in enumerate(row):
                self.table_all_tools.setItem(r, c, QTableWidgetItem(str(data)))

    def refresh_all_loans_table(self):
        self.table_all_loans.setRowCount(0)
        loans = self.db.get_all_loans_global()
        for r, row in enumerate(loans):
            self.table_all_loans.insertRow(r)
            for c, data in enumerate(row):
                self.table_all_loans.setItem(r, c, QTableWidgetItem(str(data)))

    def admin_delete_tool(self):
        row = self.table_all_tools.currentRow()
        if row < 0:
            QMessageBox.warning(self, "Hata", "Lütfen silinecek aleti seçin.")
            return

        tool_id = int(self.table_all_tools.item(row, 0).text())
        tool_name = self.table_all_tools.item(row, 1).text()
        
        reply = QMessageBox.question(self, "Admin Onayı", 
                                     f"DİKKAT: '{tool_name}' adlı aleti sistemden kalıcı olarak silmek üzeresiniz.\nOnaylıyor musunuz?",
                                     QMessageBox.Yes | QMessageBox.No, QMessageBox.No)
        
        if reply == QMessageBox.Yes:
            # delete_tool fonksiyonu sp_secure_delete_tool kullanir.
            # Admin oldugumuz icin yetki sorunu yasamayiz.
            success, msg = self.db.delete_tool(tool_id)
            if success:
                QMessageBox.information(self, "Başarılı", msg)
                self.refresh_all_tools_table()
            else:
                QMessageBox.critical(self, "Hata", msg)
   
    def admin_read_reviews(self):
        row = self.table_all_tools.currentRow()
        if row < 0:
            QMessageBox.warning(self,"Uyarı","Yorumlarını okumak için bir alet seç")
            return
        
        tool_id = int(self.table_all_tools.item(row,0).text())
        tool_name = self.table_all_tools.item(row,1).text()

        dialog = ToolReviewDialog(self.db,tool_id,tool_name,self)
        dialog.exec_()

    def admin_force_return(self):
        row = self.table_all_loans.currentRow()
        if row < 0:
            QMessageBox.warning(self,"Uyarı","Sonlandırılacak işlemi seçin")
            return
        
        status = self.table_all_loans.item(row,6).text() #bittiyse islem yapma
        if status == 'Tamamlandı':
            QMessageBox.information(self,"Bilgi","Bu işlem zaten tamamlanmış")
            return
        
        loan_id = int(self.table_all_loans.item(row,0).text())

        reply = QMessageBox.question(self,"Admin Yetkisi","Bu kiralamayı ZORLA sonlandırmak istiyor musunuz?\n Alet 'Müsait' durumuna geçecek", QMessageBox.Yes | QMessageBox.No)

        if reply == QMessageBox.Yes:
            #sp return tool'u admin id si ile çağır.
            success,msg = self.db.return_tool(loan_id)
            
            if success :
                QMessageBox.information(self,"Başarılı","Kiralama sonlandırıldı.\n" + msg)
                self.refresh_all_loans_table()
                self.refresh_all_tools_table() #alet durumu da değişti

            else:
                QMessageBox.critical(self,"Hata",msg)


#dialogs
class AddUserDialog(QDialog):
    def __init__(self, db, parent= None):
        super().__init__(parent)
        self.db = db
        self.setWindowTitle("Kullanıcı Ekle")
        self.setGeometry(300,300,300,250)

        layout = QFormLayout()

        self.txt_user = QLineEdit()
        self.txt_pass = QLineEdit()
        self.txt_full = QLineEdit()
        self.combo_role = QComboBox()
        self.combo_role.addItems(["user", "admin"])

        layout.addRow("Kullanıcı Adı:", self.txt_user)
        layout.addRow("Şifre:", self.txt_pass)
        layout.addRow("Ad Soyad:", self.txt_full)
        layout.addRow("Rol:", self.combo_role)

        btn = QPushButton("Kaydet")
        btn.clicked.connect(self.save)
        layout.addRow(btn)
        
        self.setLayout(layout)
    
    def save(self):
        u = self.txt_user.text()
        p = self.txt_pass.text()
        f = self.txt_full.text()
        r = self.combo_role.currentText()
    
        if not u or not p or not f:
            QMessageBox.warning(self, "Hata", "Eksik alan var.")
            return
            
        success, msg = self.db.add_user(u, p, f, r)
        if success:
            QMessageBox.information(self, "Başarılı", msg)
            self.accept()
        else:
            QMessageBox.critical(self, "Hata", msg)
