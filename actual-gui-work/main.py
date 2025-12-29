import sys
from PyQt5.QtWidgets import QApplication, QMessageBox
from database import DatabaseManager
from ui.login_window import LoginWindow
from ui.user_window import UserWindow

class MainApp:
    def __init__(self):
        self.app = QApplication(sys.argv)

        self.db = DatabaseManager()

        if not self.db.connect():
            print("Database connection failed")
            sys.exit(1)

        self.login_window = LoginWindow(self.db, self.open_main_window)
        self.login_window.show()

        self.main_window = None

    def open_main_window(self):
        #will start if login is successful
        role = self.db.current_role
        user_id = self.db.current_user_id

        print(f"Login successful. Rol: {role}, User ID: {user_id}")

        if role == 'user':
            self.main_window = UserWindow(self.db)
            self.main_window.show()
        elif role == 'admin':
            QMessageBox.information(None, "Bilgi", "Admin paneli hazır değil.")
        else:
            QMessageBox.warning(None, "Hata", "Bilinmeyen kullanıcı rolü.")

    def run(self):
        sys.exit(self.app.exec_())

if __name__ == "__main__":
    program = MainApp()
    program.run()           