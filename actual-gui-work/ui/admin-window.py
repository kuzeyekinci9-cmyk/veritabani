#admin window için gereksinimler
# -----------------------------------------------------------------------------
# ASAMA 1: BACKEND GUNCELLEMELERI (database.py)
# -----------------------------------------------------------------------------
#
# Mevcut DatabaseManager sinifina, sadece Adminlerin kullanacagi asagidaki metodlar eklenmelidir.
# Tum islemler try-except blogu icinde olmali ve SQL dosyasindaki prosedur isimleri
# birebir kullanilmalidir.
#
# 1. Kullanici Yonetimi Metodlari
#    - get_all_users()
#      SQL: SELECT user_id, username, full_name, role, security_score FROM Users ORDER BY user_id ASC
#
#    - add_user(username, password, full_name, role)
#      Prosedur: sp_add_user(p_requester_id, p_username, p_password, p_full_name, p_role)
#      Not: requester_id olarak self.current_user_id gonderilmeli.
#
#    - make_admin(target_user_id)
#      Prosedur: sp_grant_admin_role(p_requester_id, p_target_user_id)
#
#    - revoke_admin(target_user_id)
#      Prosedur: sp_revoke_admin_role(p_requester_id, p_target_user_id)
#
#    - get_givers_report()
#      SQL: SELECT * FROM v_givers_not_takers (Bu bir View'dur).
#
# 2. Raporlama ve Analiz Metodlari
#    - get_monthly_activity(month, year)
#      Fonksiyon: monthly_sharing_activity(p_requester_id, p_month, p_year)
#      Donus: Integer (Toplam gun sayisi).
#
#    - get_top_sharers(min_shares)
#      Fonksiyon: get_top_sharers(p_requester_id, min_shares)
#      Donus: Tablo (Isim, Paylasim Sayisi).
#
# -----------------------------------------------------------------------------
# ASAMA 2: FRONTEND TASARIMI (ui/admin_window.py)
# -----------------------------------------------------------------------------
#
# UserWindow benzeri, sekmeli (Tabbed) bir yapi kurulmalidir.
#
# SEKME 1: Kullanici Yonetimi (User Management)
#    - Gorunum:
#      * Sol/Ust tarafta: "Yeni Kullanici Ekle" butonu (Dialog acar).
#      * Orta: Tum kullanicilarin listelendigi QTableWidget (ID, Username, Isim, Rol, Puan).
#      * Alt: "Sadece Comertleri (Givers) Goster" butonu.
#
#    - Aksiyonlar (Sag Tik Menusu):
#      * Tablodaki bir kullaniciya sag tiklandiginda:
#        - "Admin Yap" (Eger rolu user ise).
#        - "Admin Yetkisini Al" (Eger rolu admin ise).
#
#    - Mantik:
#      * Tablo yuklendiginde get_all_users cagirilir.
#      * Ekleme islemi sp_add_user ile yapilir.
#
# SEKME 2: Raporlar & Analiz
#    - Bu sekme ikiye bolunmus (Splitter veya GroupBox) olmalidir.
#
#    - Bolum A: Aylik Aktivite Raporu
#      * Input: Ay (ComboBox 1-12), Yil (SpinBox).
#      * Buton: "Analiz Et".
#      * Cikti: Bir Label icinde sonuc (Orn: "Bu ay toplam 45 gun paylasim yapildi").
#      * Baglanti: monthly_sharing_activity fonksiyonu.
#
#    - Bolum B: En Yardimsever Komsular
#      * Input: "Minimum Paylasim Sayisi" (SpinBox, varsayilan 1).
#      * Buton: "Listele".
#      * Cikti: QTableWidget (Komsu Adi, Paylasim Sayisi).
#      * Baglanti: get_top_sharers fonksiyonu.
#
# -----------------------------------------------------------------------------
# ASAMA 3: ENTEGRASYON (main.py)
# -----------------------------------------------------------------------------
#
# main.py dosyasindaki open_main_window fonksiyonu guncellenmelidir.
# Rol 'admin' oldugunda AdminWindow sinifi import edilip baslatilmalidir.
#
# Ornek Entegrasyon Kodu:
# elif role == 'admin':
#     from ui.admin_window import AdminWindow
#     self.main_window = AdminWindow(self.db)
#     self.main_window.show()
#
# -----------------------------------------------------------------------------
