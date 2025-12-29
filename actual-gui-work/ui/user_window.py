from PyQt5.QtWidgets import (QMainWindow, QWidget, QVBoxLayout, QTabWidget, 
                             QTableWidget, QTableWidgetItem, QLabel, QHeaderView, 
                             QPushButton, QDialog, QFormLayout, QComboBox, QLineEdit, QMessageBox)
from PyQt5.QtCore import Qt

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

        #tabs
        self.tabs = QTabWidget()
        main_layout.addWidget(self.tabs)

        #tools tab
        self.tab_my_tools = QWidget()
        self.setup_my_tools_tab()
        self.tabs.addTab(self.tab_my_tools, "Aletlerim")

        self.tab_market = QWidget()
        self.tabs.addTab(self.tab_market, "Vitrin")

    def setup_my_tools_tab(self):
        layout = QVBoxLayout()

        self.btn_add = QPushButton("Yeni Alet Ekle")
        self.btn_add.clicked.connect(self.open_add_dialog)
        layout.addWidget(self.btn_add)

        self.btn_delete = QPushButton("Seçili Aleti Sil")
        self.btn_delete.setStyleSheet("background-color: #ffcccc;")
        self.btn_delete.clicked.connect(self.delete_selected_tool)
        layout.addWidget(self.btn_delete)

        self.btn_edit = QPushButton("Seçili Aleti Düzenle")
        self.btn_edit.clicked.connect(self.open_edit_dialog)
        layout.addWidget(self.btn_edit)
        
        lbl_info = QLabel("Sisteme eklediğiniz aletler:")
        layout.addWidget(lbl_info)

        self.table_tools = QTableWidget()
        self.table_tools.setColumnCount(5)
        self.table_tools.setHorizontalHeaderLabels(["ID", "Alet Adı", "Kategori", "Durum", "Puan"])

        self.table_tools.horizontalHeader().setSectionResizeMode(1, QHeaderView.Stretch)

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

        tool_id_item = self.table_tools.item(selected_row, 0)
        tool_id = int(tool_id_item.text())
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

    def open_edit_dialog(self):
        selected_row = self.table_tools.currentRow() # get selected row
        if selected_row < 0:
            QMessageBox.warning(self, "Hata", "Lütfen düzenlenecek bir alet seçin.")
            return
        
        try:
            tool_id = int(self.table_tools.item(selected_row, 0).text())
            name = self.table_tools.item(selected_row, 1).text()
            status = self.table_tools.item(selected_row, 3).text()
        except AttributeError:
            return
        
        desc_placeholder = "Yeni açıklama girin" # Placeholder, should fetch actual desc from DB if needed
        dialog = UpdateToolDialog(self.db, tool_id, name, desc_placeholder, status, self)
        if dialog.exec_() == QDialog.Accepted:
            self.refresh_my_tools_table()


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

        success = self.db.add_new_tool(self.db.current_user_id, cat_id, name, desc)

        if success:
            QMessageBox.information(self, "Başarılı", "Alet başarıyla eklendi.")
            self.accept() # close dialog
        else:
            QMessageBox.critical(self, "Hata", "Alet eklenirken bir hata oluştu.")                

class UpdateToolDialog(QDialog): # window for editing tools
    def __init__(self, db_manager, tool_id, current_name, current_desc, current_status, parent=None):
       super().__init__(parent)
       self.db = db_manager
       self.tool_id = tool_id
       
       self.setWindowTitle(f"Aleti Düzenle - ID: {tool_id}")
       self.setGeometry(250, 250, 300, 200)

       layout = QVBoxLayout()
       form_layout = QFormLayout()

       self.txt_name = QLineEdit(current_name) #tool name
       self.txt_name.setEnabled(False) #name cannot be changed
       form_layout.addRow("Alet Adı:", self.txt_name)

       self.txt_desc = QLineEdit(current_desc) #tool desc
       form_layout.addRow("Alet Açıklaması:", self.txt_desc)

       self.combo_status = QComboBox() #status
       self.combo_status.addItems(["Müsait","Bakımda","Kirada"])

       index = self.combo_status.findText(current_status)
       if index >= 0:
           self.combo_status.setCurrentIndex(index)

       form_layout.addRow("Durum:", self.combo_status)
       layout.addLayout(form_layout)

       #save button
       self.btn_update = QPushButton("Güncelle ve Kaydet")
       self.btn_update.clicked.connect(self.update_tool_action)
       layout.addWidget(self.btn_update)

       self.setLayout(layout)

    def update_tool_action(self):
        new_desc = self.txt_desc.text()
        new_status = self.combo_status.currentText()

        success, message = self.db.update_tool(self.tool_id, new_desc, new_status)

        if success:
            QMessageBox.information(self, "Başarılı", "Alet başarıyla güncellendi.")
            self.accept() # close dialog
        else:
            QMessageBox.critical(self, "Hata", f"Güncellenemedi: {message}")

       