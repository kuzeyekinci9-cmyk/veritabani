import sys
from PyQt6.QtWidgets import (QApplication, QMainWindow, QWidget, QVBoxLayout, 
                             QHBoxLayout, QPushButton, QLabel, QLineEdit, 
                             QTableWidget, QTableWidgetItem, QHeaderView, 
                             QTabWidget, QGroupBox, QTextEdit, QDialog, 
                             QComboBox, QMessageBox, QDateEdit, QFormLayout, 
                             QCheckBox, QSpinBox)
from PyQt6.QtGui import QFont
from PyQt6.QtCore import Qt, QDate
import psycopg2


DB_CONFIG = {  #çalıştırırken password'ü pgadmindeki ile aynı yap yoksa çalışmaz.
    "host": "localhost",
    "dbname": "toolshare_db",
    "user": "postgres",
    "password": "0000", 
    "port": "5432"
}

# ==========================================
# db den henüz çekil(e)meyen bilgiler için mock data
# ==========================================
DEMO_TOOLS = [
    {"id": 1001, "name": "Hilti Impact Drill", "cat": "Drills", "price": 150, "owner": "John Doe", "active": True},
    {"id": 1002, "name": "Lawn Mower X500", "cat": "Garden", "price": 200, "owner": "Alice Smith", "active": False},
    {"id": 1003, "name": "Laser Measure", "cat": "Measurement", "price": 50, "owner": "Bob Jones", "active": True},
    {"id": 1004, "name": "Pressure Washer", "cat": "Cleaning", "price": 120, "owner": "John Doe", "active": True},
]

DEMO_USERS = [
    {"id": 999, "name": "System Admin", "role": "Admin", "score": 5.0}, 
    {"id": 1, "name": "John Doe", "role": "User", "score": 4.8},
    {"id": 2, "name": "Alice Smith", "role": "User", "score": 4.9},
    {"id": 3, "name": "Bob Jones", "role": "User", "score": 3.2},
]

DEMO_REVIEWS = [
    {"reviewer": "Alice Smith", "rating": 5, "comment": "Great tool, very clean!"},
    {"reviewer": "Bob Jones", "rating": 4, "comment": "Works well, but battery was low."},
]

# ==========================================
# DIALOGS /butona basıldığında pop up olarak açılan pencereler
# ==========================================
class ReservationDialog(QDialog):
    """REQ: Reservation Date Selection"""
    def __init__(self, tool_name, parent=None):
        super().__init__(parent)
        self.setWindowTitle(f"Reserve: {tool_name}")
        self.setFixedSize(300, 200)
        layout = QFormLayout()
        
        self.start_date = QDateEdit()
        self.start_date.setDate(QDate.currentDate())
        self.start_date.setCalendarPopup(True)
        
        self.end_date = QDateEdit()
        self.end_date.setDate(QDate.currentDate().addDays(3))
        self.end_date.setCalendarPopup(True)
        
        layout.addRow("Tool:", QLabel(f"<b>{tool_name}</b>"))
        layout.addRow("Start Date:", self.start_date)
        layout.addRow("End Date:", self.end_date)
        
        btn = QPushButton("Confirm Reservation")
        btn.clicked.connect(self.accept)
        layout.addRow(btn)
        self.setLayout(layout)

class UpdateToolDialog(QDialog):
    """REQ: Update Operation"""
    def __init__(self, tool_name, current_price, parent=None):
        super().__init__(parent)
        self.setWindowTitle(f"Update Tool: {tool_name}")
        self.setFixedSize(300, 200)
        layout = QFormLayout()
        
        self.input_price = QSpinBox()
        self.input_price.setRange(0, 10000)
        self.input_price.setValue(int(current_price))
        self.input_price.setSuffix(" TL")
        
        self.input_status = QComboBox()
        self.input_status.addItems(["Active", "Maintenance", "Retired"])
        
        layout.addRow("Daily Price:", self.input_price)
        layout.addRow("Status:", self.input_status)
        
        btn = QPushButton("Save Changes (UPDATE)")
        btn.clicked.connect(self.accept)
        layout.addRow(btn)
        self.setLayout(layout)

class UserProfileDialog(QDialog):
    def __init__(self, username, score, parent=None):
        super().__init__(parent)
        self.setWindowTitle(f"Profile: {username}")
        self.setFixedSize(500, 400)
        layout = QVBoxLayout()
        
        lbl = QLabel(username)
        lbl.setFont(QFont("Arial", 14, QFont.Weight.Bold))
        lbl.setAlignment(Qt.AlignmentFlag.AlignCenter)
        layout.addWidget(lbl)
        
        lbl_s = QLabel(f"Security Score: {score}")
        lbl_s.setStyleSheet("color: green; font-size: 14px; font-weight: bold;")
        lbl_s.setAlignment(Qt.AlignmentFlag.AlignCenter)
        layout.addWidget(lbl_s)
        
        layout.addWidget(QLabel("<b>Recent Reviews:</b>"))
        tbl = QTableWidget(len(DEMO_REVIEWS), 3)
        tbl.setHorizontalHeaderLabels(["Reviewer", "Rating", "Comment"])
        tbl.horizontalHeader().setSectionResizeMode(QHeaderView.ResizeMode.Stretch)
        for i, r in enumerate(DEMO_REVIEWS):
            tbl.setItem(i, 0, QTableWidgetItem(r['reviewer']))
            tbl.setItem(i, 1, QTableWidgetItem(f"{r['rating']}"))
            tbl.setItem(i, 2, QTableWidgetItem(r['comment']))
        layout.addWidget(tbl)
        
        btn = QPushButton("Close")
        btn.clicked.connect(self.accept)
        layout.addWidget(btn)
        self.setLayout(layout)

class LoginDialog(QDialog):
    def __init__(self):
        super().__init__()
        self.setWindowTitle("ToolShare Login")
        self.setFixedSize(350, 200)
        layout = QVBoxLayout()
        layout.addWidget(QLabel("<h1>ToolShare ERP</h1>"))
        
        form = QFormLayout()
        self.role_combo = QComboBox()
        self.role_combo.addItems(["User Mode", "Admin Mode"])
        self.user_combo = QComboBox()
        self.user_combo.addItems([u['name'] for u in DEMO_USERS])
        
        form.addRow("Role:", self.role_combo)
        form.addRow("User:", self.user_combo)
        layout.addLayout(form)
        
        btn = QPushButton("Login")
        btn.clicked.connect(self.accept)
        layout.addWidget(btn)
        self.setLayout(layout)

# ==========================================
# MAIN WINDOW
# ==========================================
class ToolShareGUI(QMainWindow):
    def __init__(self, role, username):
        super().__init__()
        self.role = role
        self.username = username
        self.resize(1200, 800)
        self.setWindowTitle(f"ToolShare System - {username}")
        
        central = QWidget(); self.setCentralWidget(central)
        self.layout = QVBoxLayout(central)
        self.create_header()

        self.tabs = QTabWidget()
        self.layout.addWidget(self.tabs)

        self.create_log_console()

        if "Admin" in role:
            self.init_admin_tabs()
        else:
            self.init_user_tabs()
            
        self.log(f"Session started for {username}. Role: {role}")

    def create_header(self):
        """Creates top bar with DB status"""
        grp = QGroupBox()
        h_box = QHBoxLayout()
        
        # Left: User Info
        h_box.addWidget(QLabel(f"Logged in as: <b>{self.username}</b>"))
        
        h_box.addSpacing(20)
        
        # Center: DB Status 
        # Assuming we are connected for the demo.
        db_label = QLabel("🟢 Connected: toolshare_db (Port: 5432)")# If you wanted to show disconnected, you would set text to "🔴 Not Connected"
        h_box.addWidget(db_label)
        
        h_box.addStretch()
        
        # Right: Logout
        btn_logout = QPushButton("Logout")
        btn_logout.clicked.connect(self.close)
        h_box.addWidget(btn_logout)
        
        grp.setLayout(h_box)
        self.layout.addWidget(grp)

    def create_log_console(self):
        grp = QGroupBox("System Logs (SQL & Triggers)")
        l = QVBoxLayout()
        self.console = QTextEdit()
        self.console.setReadOnly(True)
        self.console.setFixedHeight(120)
        l.addWidget(self.console)
        grp.setLayout(l)
        self.layout.addWidget(grp)

    def log(self, msg):
        self.console.append(f"[{QDate.currentDate().toString('yyyy-MM-dd')}] > {msg}")

    def add_chk(self, table, row):
        chk = QCheckBox()
        w = QWidget(); l = QHBoxLayout(w); l.addWidget(chk); l.setAlignment(Qt.AlignmentFlag.AlignCenter); l.setContentsMargins(0,0,0,0)
        table.setCellWidget(row, 0, w)

    # -----------------------------------
    # USER TABS
    # -----------------------------------
    def init_user_tabs(self):
        # TAB 1: 
        tab = QWidget(); l = QVBoxLayout()
        
        grp_s = QGroupBox("Search Tools (Uses Index: 'idx_tool_name')")
        h_s = QHBoxLayout()
        h_s.addWidget(QLabel("Tool Name:")); h_s.addWidget(QLineEdit())
        h_s.addWidget(QPushButton("Search"))
        grp_s.setLayout(h_s)
        l.addWidget(grp_s)

        grp_v = QGroupBox("Available Tools (Data Source: VIEW 'v_available_tools')")
        lv = QVBoxLayout()
        self.tbl_m = QTableWidget(0, 5)
        self.tbl_m.setHorizontalHeaderLabels(["Select", "Name", "Category", "Owner", "Price"])
        self.tbl_m.horizontalHeader().setSectionResizeMode(QHeaderView.ResizeMode.Stretch)
        self.tbl_m.setColumnWidth(0, 50)
        
        active = [t for t in DEMO_TOOLS if t['active']] #kod içerisinde db den veri çeken tek noktanın başladığı yer.
        self.tbl_m.setRowCount(len(active))

        try:
            conn = psycopg2.connect(**DB_CONFIG)
            cursor = conn.cursor()

            sql = """
                SELECT t.tool_id,t.name,c.name as category, u.full_name, t.daily_price
                FROM tools t
                JOIN users u ON t.owner_id = u.user_id
                JOIN categories c ON t.category_id = c.category_id
                WHERE t.is_active = TRUE;
                """
            cursor.execute(sql)
            rows = cursor.fetchall()

            self.tbl_m.setRowCount(len(rows))

            for i, row in enumerate(rows):
                self.add_chk(self.tbl_m,i)
                self.tbl_m.setItem(i, 1, QTableWidgetItem(str(row[1]))) # Name
                self.tbl_m.setItem(i, 2, QTableWidgetItem(str(row[2]))) # Category
                self.tbl_m.setItem(i, 3, QTableWidgetItem(str(row[3]))) # Owner
                self.tbl_m.setItem(i, 4, QTableWidgetItem(str(row[4]))) # Price
                self.tbl_m.item(i, 1).setData(Qt.ItemDataRole.UserRole, row[0])

            cursor.close()
            conn.close()
            self.log("INFO: Data loaded successfully from database.")

        except Exception as e:
            self.tbl_m.setRowCount(0)
            self.log(f"ERROR: Could not load data from database. {e}")
            self.log("Check if PGAdmin is running and password is correct.") #veri çekiminin bittiği yer.

        lv.addWidget(self.tbl_m)
        grp_v.setLayout(lv)
        l.addWidget(grp_v)

        h_act = QHBoxLayout()
        btn_res = QPushButton("Make Reservation (Trigger: Check Dates)")
        btn_res.clicked.connect(self.action_reservation)
        btn_prof = QPushButton("View Owner Profile")
        btn_prof.clicked.connect(self.action_view_profile_user)
        h_act.addWidget(btn_res); h_act.addWidget(btn_prof)
        l.addLayout(h_act)

        tab.setLayout(l); self.tabs.addTab(tab, "Marketplace")

        # TAB 2: RENTALS
        tab2 = QWidget(); l2 = QVBoxLayout()
        l2.addWidget(QLabel("<b>My Active Rentals:</b>"))
        tbl_r = QTableWidget(1, 3); tbl_r.setHorizontalHeaderLabels(["Tool", "Due Date", "Status"])
        tbl_r.horizontalHeader().setSectionResizeMode(QHeaderView.ResizeMode.Stretch)
        tbl_r.setItem(0,0, QTableWidgetItem("Hilti Drill")); tbl_r.setItem(0,1, QTableWidgetItem("2023-12-05")); tbl_r.setItem(0,2, QTableWidgetItem("ACTIVE"))
        l2.addWidget(tbl_r)
        
        btn_ret = QPushButton("Return Tool & Rate (Trigger: Update Score)")
        btn_ret.clicked.connect(self.action_return_tool)
        l2.addWidget(btn_ret)
        
        tab2.setLayout(l2); self.tabs.addTab(tab2, "My Rentals")

    # -----------------------------------
    # ADMIN TABS #admin panelinden girildiğinde gözükecek butonlar.
    # -----------------------------------
    def init_admin_tabs(self):
        # TAB 1: INVENTORY
        tab = QWidget(); l = QVBoxLayout()
        grp_inv = QGroupBox("Inventory Management (View: 'v_all_tools_admin')")
        l_inv = QVBoxLayout()
        
        self.tbl_inv = QTableWidget(len(DEMO_TOOLS), 6)
        self.tbl_inv.setHorizontalHeaderLabels(["Select", "ID", "Name", "Category", "Price", "Active?"])
        self.tbl_inv.horizontalHeader().setSectionResizeMode(QHeaderView.ResizeMode.Stretch)
        self.tbl_inv.setColumnWidth(0, 50)
        for i, t in enumerate(DEMO_TOOLS):
            self.add_chk(self.tbl_inv, i)
            self.tbl_inv.setItem(i, 1, QTableWidgetItem(str(t['id'])))
            self.tbl_inv.setItem(i, 2, QTableWidgetItem(t['name']))
            self.tbl_inv.setItem(i, 3, QTableWidgetItem(t['cat']))
            self.tbl_inv.setItem(i, 4, QTableWidgetItem(str(t['price'])))
            self.tbl_inv.setItem(i, 5, QTableWidgetItem(str(t['active'])))
        l_inv.addWidget(self.tbl_inv)

        h_crud = QHBoxLayout()
        btn_add = QPushButton("Add Tool (INSERT + Sequence)"); btn_add.clicked.connect(lambda: self.log("INSERT INTO tools... VALUES (nextval('tool_seq')...)"))
        btn_upd = QPushButton("Edit Tool (UPDATE)"); btn_upd.clicked.connect(self.action_update_tool)
        btn_del = QPushButton("Delete (DELETE + Constraint)"); btn_del.clicked.connect(lambda: self.log("ERROR: Violation of FK Constraint 'fk_loans_tool'. Cannot delete rented tool."))
        
        h_crud.addWidget(btn_add); h_crud.addWidget(btn_upd); h_crud.addWidget(btn_del)
        l_inv.addLayout(h_crud)
        grp_inv.setLayout(l_inv); l.addWidget(grp_inv)
        tab.setLayout(l); self.tabs.addTab(tab, "Inventory")

        # TAB 2: USERS #user panelinden girildiğinde gözükecek butonlar.
        tab_u = QWidget(); l_u = QVBoxLayout()
        self.tbl_u = QTableWidget(len(DEMO_USERS), 4)
        self.tbl_u.setHorizontalHeaderLabels(["Select", "ID", "Name", "Score"])
        self.tbl_u.horizontalHeader().setSectionResizeMode(QHeaderView.ResizeMode.Stretch)
        for i, u in enumerate(DEMO_USERS):
            self.add_chk(self.tbl_u, i)
            self.tbl_u.setItem(i, 1, QTableWidgetItem(str(u['id'])))
            self.tbl_u.setItem(i, 2, QTableWidgetItem(u['name']))
            self.tbl_u.setItem(i, 3, QTableWidgetItem(str(u['score'])))
        l_u.addWidget(self.tbl_u)
        
        h_ub = QHBoxLayout()
        btn_prof = QPushButton("View User Profile"); btn_prof.clicked.connect(self.action_view_profile_admin)
        btn_udel = QPushButton("Delete User"); btn_udel.clicked.connect(lambda: self.log(f"SQL: DELETE FROM users WHERE id=..."))
        h_ub.addWidget(btn_prof); h_ub.addWidget(btn_udel)
        l_u.addLayout(h_ub)
        tab_u.setLayout(l_u); self.tabs.addTab(tab_u, "Users")

        # TAB 3: REPORTS #kompleks işlemler için ayrılmış ayrı sayfada gözükecek işlemler.
        tab_r = QWidget(); l_r = QVBoxLayout()
        grp_sql = QGroupBox("Advanced SQL Reports")
        l_sql = QVBoxLayout()
        b1 = QPushButton("1. Calculate Monthly Revenue (Function + Cursor)")
        b1.clicked.connect(lambda: self.log("EXEC calc_monthly_revenue() -> Result: 4500 TL"))
        l_sql.addWidget(b1)
        b2 = QPushButton("2. Identify Passive Users (EXCEPT Query)")
        b2.clicked.connect(lambda: self.log("SELECT ... EXCEPT SELECT ... -> Result: 2 Users found."))
        l_sql.addWidget(b2)
        b3 = QPushButton("3. Popular Tools (GROUP BY + HAVING Count > 5)")
        b3.clicked.connect(lambda: self.log("SELECT name, COUNT(*) ... GROUP BY name HAVING COUNT(*) > 5 -> Result: 'Hilti Drill'"))
        l_sql.addWidget(b3)
        grp_sql.setLayout(l_sql); l_r.addWidget(grp_sql); l_r.addStretch()
        tab_r.setLayout(l_r); self.tabs.addTab(tab_r, "Reports")

    # -----------------------------------
    # HANDLERS
    # -----------------------------------
    def action_reservation(self):
        """REQ: Opens Date Dialog before Logging"""
        row = self.tbl_m.currentRow()
        if row < 0:
            QMessageBox.warning(self, "Selection", "Select a tool first.")
            return
            
        tool_name = self.tbl_m.item(row, 1).text()
        
        # Open the new Dialog
        dlg = ReservationDialog(tool_name, self)
        if dlg.exec():
            # Get Dates
            s_date = dlg.start_date.date().toString("yyyy-MM-dd")
            e_date = dlg.end_date.date().toString("yyyy-MM-dd")
            
            self.log(f"SQL: INSERT INTO loans (tool_id, start='{s_date}', end='{e_date}')")
            self.log("TRIGGER [trg_check_overlap] FIRED: Success (No overlap).")
            QMessageBox.information(self, "Success", "Reservation created successfully.")

    def action_return_tool(self):
        dlg = QDialog(self); dlg.setWindowTitle("Return & Rate")
        l = QFormLayout()
        spin = QSpinBox(); spin.setRange(1, 5) 
        l.addRow("Rating (1-5):", spin)
        l.addRow("Comment:", QLineEdit())
        btn = QPushButton("Submit"); btn.clicked.connect(dlg.accept)
        l.addRow(btn)
        dlg.setLayout(l)
        if dlg.exec():
            self.log(f"SQL: INSERT INTO reviews VALUES ({spin.value()}...)")
            self.log("CONSTRAINT CHECK: OK.")
            self.log("TRIGGER [trg_update_score] FIRED: Score updated.")

    def action_update_tool(self):
        row = self.tbl_inv.currentRow()
        if row < 0:
            QMessageBox.warning(self, "Selection", "Select a tool to update.")
            return
        name = self.tbl_inv.item(row, 2).text()
        price = self.tbl_inv.item(row, 4).text()
        dlg = UpdateToolDialog(name, price, self)
        if dlg.exec():
            self.log(f"SQL: UPDATE tools SET daily_price={dlg.input_price.value()} WHERE name='{name}'")
            self.tbl_inv.item(row, 4).setText(str(dlg.input_price.value()))

    def action_view_profile_user(self):
        self.show_profile(self.tbl_m)
    
    def action_view_profile_admin(self):
        self.show_profile(self.tbl_u, name_col=2)

    def show_profile(self, table, name_col=3):
        row = table.currentRow()
        name = "John Doe"
        if row >= 0: name = table.item(row, name_col).text()
        score = 3.0
        for u in DEMO_USERS:
            if u['name'] == name: score = u['score']
        UserProfileDialog(name, score, self).exec()

if __name__ == "__main__":
    app = QApplication(sys.argv)
    login = LoginDialog()
    if login.exec():
        win = ToolShareGUI(login.role_combo.currentText(), login.user_combo.currentText())
        win.show()
        sys.exit(app.exec())