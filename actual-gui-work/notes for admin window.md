Admin'in User'ın yapabildiği ama kendisinin yapamadığı ve yetkisi olduğu halde arayüzde olmayan eksiklikleri

Admin Tarafındaki Eksiklikler 

1. Yorum ve Detay Görme Eksikliği
Yorumları Okuyamama: User, bir alete sağ tıklayıp (veya butona basıp) o alete yapılan yorumları okuyabiliyor. Admin, "Global Aletler" listesinde aleti görüyor ama ona gelen yorumları okuyabileceği bir pencere açamıyor.
Kiralama Detayı: User, kiralama geçmişinde kimden aldığını, kaça aldığını görüp yorum yapabiliyor. Admin global kiralama listesini görüyor ama o işleme ait yorum yapılmış mı, ne yazılmış göremiyor.

2. Müdahale Eksikliği 
Zorla Kiralama Bitirme (Force Return): Bir alet çalındı veya kiracı ulaşılamaz durumda. User (Mal Sahibi) iade almadan işlem bitmiyor. Admin'in arayüzde bir kiralamayı seçip "Bu kiralamayı sonlandır (Aleti boşa çıkar)" diyebileceği bir buton yok.
Yorum Silme: Admin yorumları göremediği gibi (Madde 1), kötü niyetli bir yorumu silme yetkisine (SQL fonksiyonu olsa bile) arayüzde sahip değil.

3. Kullanıcı Yönetimi Eksikliği
Kullanıcı Banlama/Silme: Admin bir kullanıcıyı sistemden atamıyor. (Sadece yetkisini alabiliyor ama user olarak kalıyorlar). SQL tarafında DELETE FROM Users çalışırsa o kişinin tüm geçmişi (Foreign Key) patlayacağı için "Soft Delete" (Pasifize Etme) mekanizması lazım ama bu arayüzde yok.


Bu eksikleri kapatmak için ui/admin_window.py dosyasında şu küçük eklemeler yapılabilir:
"Yorumları Oku" Butonu: Global Aletler tablosunun altına, ToolReviewDialog'u açan bir buton konabilir. (UserWindow'daki sınıfı buraya da import ederek).
"Zorla Bitir" Butonu: Global Kiralamalar tablosunun altına, sp_return_tool fonksiyonunu (Admin ID'si ile) çağıran bir buton konabilir. Çünkü SQL fonksiyonumuz (sp_return_tool) Admin'in başkasının kiralamasını bitirmesine izin veriyor.