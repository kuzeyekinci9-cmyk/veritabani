from PyQt5.QtWidgets import QWidget, QVBoxLayout, QLineEdit, QPushButton, QLabel, QMessageBox
from PyQt5.QtCore import Qt

class LoginWindow(QWidget):
    def __init__(self,db_manager,success_callback):
        super().__init__()
        self.db = db_manager
        self.success_callback = success_callback
        self.init_ui()
    
    def init_ui(self):
        self.setWindowTitle('Login')
        self.setGeometry(100, 100, 300, 180) # window size

        layout = QVBoxLayout()

        #title
        self.label_title = QLabel("ToolShare İmece Sistemi");
        self.label_title.setAlignment(Qt.AlignCenter)

        #username box
        self.txt_user = QLineEdit()
        self.txt_user.setPlaceholderText('Kullanıcı Adı')

        #password box
        self.txt_pass = QLineEdit()
        self.txt_pass.setPlaceholderText('Şifre')
        self.txt_pass.setEchoMode(QLineEdit.Password) # hide password input

        #login button
        self.btn_login = QPushButton('Giriş Yap')

        #add widgets to layout
        layout.addWidget(self.label_title)
        layout.addWidget(self.txt_user)
        layout.addWidget(self.txt_pass)
        layout.addWidget(self.btn_login)

        self.setLayout(layout)

        self.btn_login.clicked.connect(self.handle_login)

    def handle_login(self): # login button action
        username = self.txt_user.text()
        password = self.txt_pass.text()

        if self.db.check_login(username, password):
            self.success_callback()
            self.close()
        else:
            QMessageBox.warning(self, 'Hata', 'Geçersiz kullanıcı adı veya şifre')
