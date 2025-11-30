
-- 1. KULLANICILAR
INSERT INTO Users (username, sifre, ad_soyad, rol, guvenlik_puani) VALUES
('admin', '1234', 'admin admin', 'admin'),
('ayse_d',      '1234', 'Ayşe Demir',   'user'),
('mehmet_k',    '1234', 'Mehmet Kaya',  'user'),
('fatma_celik', '1234', 'Fatma Çelik',  'user'),
('caner_erkin', '1234', 'Caner Erkin',  'user'),
('selin_yurt',  '1234', 'Selin Yurt',   'user'),
('burak_ylmz',  '1234', 'Burak Yılmaz', 'user'),
('pelin_su',    '1234', 'Pelin Su',     'user'),
('cem_ozer',    '1234', 'Cem Ozer',     'user'),
('ali_veli',    '1234', 'Ali Veli',     'user');

-- 2. KATEGORİLER 
INSERT INTO Categories (kategori_adi) VALUES
('Elektrikli El Aletleri'), 
('Bahçe'), 
('Temizlik'), 
('Tamirat'), 
('Kamp & Outdoor'), 
('Otomotiv'), 
('Boya & Badana'), 
('Elektronik'), 
('Hobi'), 
('Diğer');

-- 3. ALETLER
INSERT INTO Tools (owner_id, category_id, baslik, aciklama, durum) VALUES
(1, 1, 'Bosch Darbeli Matkap', '750W uç setli', 'Müsait'),
(2, 2, 'Çim Biçme Makinesi', 'Benzinli, 45 litre sepet hacimli', 'Müsait'),
(3, 2, 'Yaprak Üfleme Makinesi', 'Elektrikli, 3000W üfleme ve toplama', 'Kirada'), -- (ID:3 - Kirada)
(1, 4, 'Takım Çantası', '120 parça set (Pense, tornavida, anahtar)', 'Müsait'),
(4, 2, 'Kürek', 'Çelik uçlu, ahşap saplı', 'Müsait'),
(5, 2, 'Bahçe Tırmığı', 'Metal uçlu, yaprak ve çim toplamak için', 'Kirada'), -- (ID:6 - Kirada)
(2, 5, 'Kamp Baltası', 'Paslanmaz çelik, ergonomik saplı', 'Müsait'),
(5, 5, 'Kamp Çadırı', '4 mevsim, 3 kişilik otomatik kurulum', 'Müsait'),
(2, 7, 'Boya Tabancası', 'Elektrikli püskürtme sistemi, ayarlanabilir uç', 'Müsait'),
(6, 3, 'Basınçlı Yıkama Makinesi', '120 bar basınç, araç ve teras yıkamak için', 'Müsait'),
(7, 2, 'Su Hortumu', '20 metre, kırılmaz örgülü, makaralı', 'Müsait'),
(8, 4, 'El Testeresi', 'Ahşap kesimi için', 'Müsait');
-- 4. ÖDÜNÇ ALMA

INSERT INTO Loans (tool_id, renter_id, baslangic_tar, bitis_tar, durum) VALUES
(1, 2, '2025-10-01', '2025-10-03', 'Tamamlandı'),
(2, 3, '2025-10-05', '2025-10-06', 'Tamamlandı'),
(3, 4, '2025-11-01', '2025-11-05', 'Aktif'),     
(4, 5, '2025-11-10', '2025-11-12', 'Tamamlandı'),
(5, 1, '2025-11-15', '2025-11-16', 'Tamamlandı'),
(6, 2, '2025-11-20', '2025-11-25', 'Aktif'),     
(7, 3, '2025-12-01', '2025-12-02', 'Tamamlandı'),
(1, 4, '2025-12-05', '2025-12-06', 'Tamamlandı'),
(8, 5, '2025-12-10', '2025-12-11', 'Tamamlandı'),
(9, 6, '2025-12-12', '2025-12-13', 'Tamamlandı');

-- 5. DEĞERLENDİRMELER
INSERT INTO Reviews (loan_id, puan, yorum, tarih) VALUES
(1, 5, 'Matkabı uçlarıyla beraber eksiksiz ve temiz teslim etti.', '2025-10-04'),
(2, 3, 'Makinenin haznesini tam temizlenmemiş.', '2025-10-07'),
(4, 5, 'Tornavidaları ve penseleri yerli yerine koymuş.', '2025-11-13'),
(5, 5, 'Küreği temizleyip getirdi.', '2025-11-17'),
(7, 4, 'Balta biraz körelmiş.', '2025-12-03'),
(8, 5, 'Teslim saatine tam uydu.', '2025-12-07'),
(9, 4, 'Temiz kullanılmış.', '2025-12-12'),
(10, 5, 'Tabancayı tinerle temizleyip getirmiş, harika.', '2025-12-14'),
