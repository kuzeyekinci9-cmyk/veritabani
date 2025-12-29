-- ============================================================================
-- PROJE ADI: TOOLSHARE (IMECE EDITION - FINAL)
-- ============================================================================
-- BU SQL DOSYASI AŞAĞIDAKİ ÖZELLİKLERİ İÇERİR:
-- 1. KARŞILIKLI PUANLAMA (Airbnb Modeli): Alan vereni, veren alanı puanlar.
-- 2. GÜVEN SKORU: Hem aletin hem de kişinin ayrı puanı vardır.
-- 3. MÜTEKABİLİYET İLKESİ: Sisteme alet eklemeyen, kiralama yapamaz.
-- 4. AKILLI ARAMA: Python'da SQL yazmadan veritabanı içinde arama/sıralama yapılır.
-- ============================================================================

-- [TEMİZLİK] Önce eski tabloları ve tipleri temizleyelim ki çakışma olmasın.
DROP SCHEMA public CASCADE;
CREATE SCHEMA public;

-- ============================================================================
-- 1. SEQUENCE (OTOMATİK SAYI ÜRETİCİLERİ)
-- [KURAL: Sequence Oluşturma]
-- Neden SERIAL kullanmadık? Çünkü sequence'ı elle yönettiğimizi göstermek istedik.
-- ============================================================================
CREATE SEQUENCE seq_users_id START 1;
CREATE SEQUENCE seq_category_id START 1;
CREATE SEQUENCE seq_tool_id START 1;
CREATE SEQUENCE seq_loan_id START 1;
CREATE SEQUENCE seq_review_id START 1;

-- ============================================================================
-- 2. TABLO TASARIMLARI
-- [KURAL: En az 4 tablo, PK ve FK kullanımı]
-- ============================================================================

-- A. USERS (KULLANICILAR) TABLOSU
CREATE TABLE Users (
    -- nextval(...) diyerek yukarıdaki sequence'ı bağlıyoruz.
    user_id INTEGER DEFAULT nextval('seq_users_id') PRIMARY KEY,
    username VARCHAR(50) UNIQUE NOT NULL, 
    password VARCHAR(50) NOT NULL,
    full_name VARCHAR(100) NOT NULL,
    
    -- [KURAL: Değer Kısıtı (Check Constraint)]
    -- Sadece 'admin' veya 'user' girilmesine izin veriyoruz.
    role VARCHAR(20) DEFAULT 'user' CHECK (role IN ('admin', 'user')),
    
    -- Bu puan hem satıcı hem alıcı güvenilirliğini temsil eder. Trigger ile güncellenir.
    security_score DECIMAL(3,2) DEFAULT 5.00
);

-- B. CATEGORIES (KATEGORİLER) TABLOSU
CREATE TABLE Categories (
    category_id INTEGER DEFAULT nextval('seq_category_id') PRIMARY KEY,
    category_name VARCHAR(50) NOT NULL
);

-- C. TOOLS (ALETLER) TABLOSU
CREATE TABLE Tools (
    tool_id INTEGER DEFAULT nextval('seq_tool_id') PRIMARY KEY,
    owner_id INTEGER,
    category_id INTEGER,
    tool_name VARCHAR(100) NOT NULL,
    description TEXT,
    
    -- Aletin kendi kondisyon puanı. Sahibinin puanından bağımsızdır.
    tool_score DECIMAL(3,2) DEFAULT 0.0,
    
    -- [KURAL: Check Constraint] Durum sadece bu 3 değerden biri olabilir.
    status VARCHAR(20) DEFAULT 'Müsait' CHECK (status IN ('Müsait', 'Kirada', 'Bakımda')),
    
    -- [KURAL: Silme Kısıtı (Cascade)]
    -- Kullanıcı silinirse, sahip olduğu aletler de otomatik silinsin.
    FOREIGN KEY (owner_id) REFERENCES Users(user_id) ON DELETE CASCADE,
    FOREIGN KEY (category_id) REFERENCES Categories(category_id)
);

-- D. LOANS (ÖDÜNÇ/KİRALAMA) TABLOSU
CREATE TABLE Loans (
    loan_id INTEGER DEFAULT nextval('seq_loan_id') PRIMARY KEY,
    tool_id INTEGER,
    renter_id INTEGER,
    start_date TIMESTAMP NOT NULL,
    end_date TIMESTAMP NOT NULL,
    
    loan_status VARCHAR(20) DEFAULT 'Aktif' CHECK (loan_status IN ('Aktif', 'Tamamlandı')),
    
    -- Bitiş tarihi başlangıçtan önce olamaz mantığı.
    CHECK (end_date >= start_date), 
    FOREIGN KEY (tool_id) REFERENCES Tools(tool_id),
    FOREIGN KEY (renter_id) REFERENCES Users(user_id)
);

-- E. REVIEWS (ÇİFT YÖNLÜ PUANLAMA) TABLOSU
-- Burası sistemin en karmaşık tablosu. Kimin kime puan verdiğini yönetir.
CREATE TABLE Reviews (
    review_id INTEGER DEFAULT nextval('seq_review_id') PRIMARY KEY,
    loan_id INTEGER,
    
    -- [YENİ ÖZELLİK] Puanı veren KİRALAYAN mı yoksa SAHİBİ mi?
    reviewer_type VARCHAR(10) CHECK (reviewer_type IN ('Renter', 'Owner')),
    
    -- Karşı tarafın puanı (Owner -> Renter'a veya Renter -> Owner'a)
    user_rating INTEGER CHECK (user_rating BETWEEN 1 AND 5),
    
    -- Aletin puanı (Sadece Kiralayan kişi aleti puanlayabilir)
    tool_rating INTEGER CHECK (tool_rating BETWEEN 1 AND 5), 
    
    comment TEXT,
    review_date DATE DEFAULT CURRENT_DATE,
    
    FOREIGN KEY (loan_id) REFERENCES Loans(loan_id) ON DELETE CASCADE,
    
    -- [KURAL] Bir kişi aynı işlemi iki kere puanlayamasın.
    UNIQUE (loan_id, reviewer_type),
    
    -- [KURAL] Eğer puanlayan 'Owner' ise, kendi aletine puan veremez (tool_rating NULL olmalı).
    CHECK ( (reviewer_type = 'Owner' AND tool_rating IS NULL) OR (reviewer_type = 'Renter') )
);

-- ============================================================================
-- 3. INDEX
-- [KURAL: Index Oluşturma]
-- Arayüzde "Matkap" diye aratınca performansı artırmak için.
-- ============================================================================
CREATE INDEX idx_tool_name ON Tools(tool_name);

-- ============================================================================
-- 4. VIEW (SANAL TABLO)
-- [KURAL: View Oluşturma]
-- Python tarafında JOIN yazmamak için "Müsait Aletler Vitrini" oluşturuyoruz.
-- Ayrıca kullanıcının güven puanını (owner_score) da buraya ekliyoruz.
-- ============================================================================
CREATE OR REPLACE VIEW v_available_tools AS
SELECT 
    t.tool_id, 
    t.tool_name, 
    c.category_name, 
    u.full_name AS owner_name, 
    u.security_score AS owner_score, -- Satıcının Puanı (Sıralama için lazım)
    t.tool_score,                    -- Aletin Puanı
    t.status
FROM Tools t
JOIN Users u ON t.owner_id = u.user_id
JOIN Categories c ON t.category_id = c.category_id
WHERE t.status = 'Müsait';

-- EXCEPT KULLANIMI ÖRNEĞİ: Sadece Alet Sahibi Olup Hiç Kiralama Yapmamış Kullanıcılar
CREATE OR REPLACE VIEW v_givers_not_takers AS
SELECT user_id, username, full_name 
FROM Users 
WHERE user_id IN (
    -- 1. Alet Sahibi Olanlar (Katkı Sağlayanlar)
    SELECT owner_id FROM Tools
    
    EXCEPT
    
    -- 2. Kiralama Yapmış Olanlar (Faydalananlar)
    SELECT renter_id FROM Loans
);


-- ============================================================================
-- 5. FONKSİYONLAR (BUSINESS LOGIC)
-- ============================================================================

-- [FONKSİYON 1] Arama ve Sıralama Motoru
-- Python'dan "mat" kelimesi ve sıralama kodu (1,2,3,4) gelir.
-- Fonksiyon tüm filtrelemeyi yapar ve sonucu döner.
CREATE OR REPLACE FUNCTION sp_search_and_sort_tools(
    p_search_term VARCHAR, 
    p_sort_option INTEGER
)
RETURNS TABLE(
    id INTEGER, isim VARCHAR, kategori VARCHAR, sahip VARCHAR, 
    sahip_puani DECIMAL, alet_puani DECIMAL, durum VARCHAR
) AS $$
BEGIN
    RETURN QUERY
    SELECT * FROM v_available_tools
    WHERE 
        -- İsim Arama: Boşsa hepsini getir, doluysa içinde geçenleri bul (Harf duyarsız ILIKE)
        (p_search_term IS NULL OR tool_name ILIKE '%' || p_search_term || '%')
    ORDER BY
        -- Dinamik Sıralama Mantığı
        CASE WHEN p_sort_option = 1 THEN tool_name END ASC,   -- İsim (A-Z)
        CASE WHEN p_sort_option = 2 THEN tool_name END DESC,  -- İsim (Z-A)
        CASE WHEN p_sort_option = 3 THEN tool_score END DESC, -- Alet Puanı (En yüksek)
        CASE WHEN p_sort_option = 4 THEN owner_score END DESC; -- Satıcı Puanı (En yüksek)
END;
$$ LANGUAGE plpgsql;

-- [FONKSİYON 2] İmece Raporu
-- [KURAL: Record ve Cursor Kullanımı]
-- O ay toplam kaç gün alet paylaşımı yapıldığını hesaplar.
-- [FONKSİYON 2 - GÜNCELLENMİŞ] İmece Raporu
CREATE OR REPLACE FUNCTION monthly_sharing_activity(p_month INTEGER, p_year INTEGER)
RETURNS INTEGER AS $$
DECLARE
    total_days INTEGER := 0; 
    r_loan RECORD; 
    v_loan_duration INTERVAL; -- Değişiklik: Integer yerine Interval
    v_days INTEGER;
BEGIN
    -- Cursor sorgusunda da EXTRACT kullanarak filtreleme yapıyoruz
    FOR r_loan IN 
        SELECT start_date, end_date FROM Loans 
        WHERE EXTRACT(MONTH FROM start_date) = p_month 
          AND EXTRACT(YEAR FROM start_date) = p_year
    LOOP
        -- Zaman farkını al
        v_loan_duration := (r_loan.end_date - r_loan.start_date);
        
        -- Interval'i gün sayısına çevir (Saatlik kiralamaları yukarı yuvarlayalım)
        -- Veya en az 1 gün sayılsın diyorsan:
        v_days := CEIL(EXTRACT(EPOCH FROM v_loan_duration) / 86400); 
        
        IF v_days < 1 THEN v_days := 1; END IF;
        
        total_days := total_days + v_days;
    END LOOP;
    
    RETURN total_days;
END;
$$ LANGUAGE plpgsql;

-- [FONKSİYON 3] Cömert Komşular
-- [KURAL: Aggregate ve Having Kullanımı]
-- En az X kere alet paylaşan kullanıcıları listeler.
CREATE OR REPLACE FUNCTION get_top_sharers(min_shares INTEGER)
RETURNS TABLE(neighbor_name VARCHAR, share_count BIGINT) AS $$
BEGIN
    RETURN QUERY
    SELECT u.full_name, COUNT(l.loan_id) -- [Aggregate: COUNT]
    FROM Loans l
    JOIN Tools t ON l.tool_id = t.tool_id
    JOIN Users u ON t.owner_id = u.user_id
    GROUP BY u.full_name
    HAVING COUNT(l.loan_id) >= min_shares -- [Having Şartı]
    ORDER BY COUNT(l.loan_id) DESC;
END;
$$ LANGUAGE plpgsql;

-- FONKSİYON 4 Alet ekleme fonksiyonu
CREATE OR REPLACE FUNCTION sp_add_tool(
    p_owner_id INTEGER,
    p_category_id INTEGER,
    p_tool_name VARCHAR,
    p_description TEXT
) RETURNS VOID AS $$
BEGIN
    INSERT INTO Tools (owner_id, category_id, tool_name, description, status)
    VALUES (p_owner_id, p_category_id, p_tool_name, p_description, 'Müsait');
END;
$$ LANGUAGE plpgsql;

-- FONKSİYON 5 . Alet Durumu Güncelleme Fonksiyonu
CREATE OR REPLACE FUNCTION sp_update_tool_status(
    p_tool_id INTEGER,
    p_new_status VARCHAR
) RETURNS TEXT AS $$
BEGIN
    UPDATE Tools SET status = p_new_status WHERE tool_id = p_tool_id;
    IF NOT FOUND THEN RETURN 'Hata: Alet bulunamadı.'; END IF;
    RETURN 'Başarılı: Durum güncellendi.';
END;
$$ LANGUAGE plpgsql;

-- FONKSİYON 6 Alet Silme Fonksiyonu 
CREATE OR REPLACE FUNCTION sp_delete_tool(p_tool_id INTEGER) RETURNS VOID AS $$
BEGIN
    DELETE FROM Tools WHERE tool_id = p_tool_id;
END;
$$ LANGUAGE plpgsql;

-- AGGRAGATE İÇİN REVİEW PUANI İÇİN ORTALAMADA 
-- ============================================================================
-- 6. TRIGGERLAR (OTOMASYON KURALLARI)
-- ============================================================================

-- [TRIGGER 1] Çift Yönlü Puan Güncelleme Sistemi
-- Bu trigger, Review tablosuna veri girildiğinde çalışır ve ortalamaları hesaplar.
CREATE OR REPLACE FUNCTION fn_update_mutual_scores() RETURNS TRIGGER AS $$
DECLARE
    v_tool_id INTEGER;
    v_owner_id INTEGER;
    v_renter_id INTEGER;
    v_new_score DECIMAL(3,2);
BEGIN
    -- Önce puanlanan işlemin detaylarını (Hangi alet? Sahibi kim? Kiralayan kim?) bulalım.
    SELECT t.tool_id, t.owner_id, l.renter_id 
    INTO v_tool_id, v_owner_id, v_renter_id
    FROM Loans l JOIN Tools t ON l.tool_id = t.tool_id
    WHERE l.loan_id = NEW.loan_id;

    -- SENARYO A: Yorumu yapan KİRALAYAN (Renter) ise...
    -- Hem aleti hem de alet sahibini puanlamıştır.
    IF NEW.reviewer_type = 'Renter' THEN
        
        -- 1. Aletin ortalama puanını güncelle
        SELECT AVG(tool_rating) INTO v_new_score FROM Reviews 
        WHERE loan_id IN (SELECT loan_id FROM Loans WHERE tool_id = v_tool_id) 
        AND reviewer_type = 'Renter';
        UPDATE Tools SET tool_score = COALESCE(v_new_score, 0) WHERE tool_id = v_tool_id;

        -- 2. Alet Sahibinin (Owner) ortalama puanını güncelle
        SELECT AVG(r.user_rating) INTO v_new_score
        FROM Reviews r JOIN Loans l ON r.loan_id = l.loan_id JOIN Tools t ON l.tool_id = t.tool_id
        WHERE t.owner_id = v_owner_id AND r.reviewer_type = 'Renter';
        UPDATE Users SET security_score = COALESCE(v_new_score, 0) WHERE user_id = v_owner_id;

    -- SENARYO B: Yorumu yapan ALET SAHİBİ (Owner) ise...
    -- Sadece kiralayanı (Renter) puanlamıştır.
    ELSIF NEW.reviewer_type = 'Owner' THEN
        
        -- 1. Kiralayanın (Renter) ortalama puanını güncelle
        SELECT AVG(r.user_rating) INTO v_new_score
        FROM Reviews r JOIN Loans l ON r.loan_id = l.loan_id
        WHERE l.renter_id = v_renter_id AND r.reviewer_type = 'Owner';
        UPDATE Users SET security_score = COALESCE(v_new_score, 0) WHERE user_id = v_renter_id;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_update_mutual_scores
AFTER INSERT ON Reviews
FOR EACH ROW
EXECUTE FUNCTION fn_update_mutual_scores();


-- [TRIGGER 2] Mütekabiliyet İlkesi (İmece Kuralı)
-- Kural: "Aletin yoksa, başkasından alet kiralayamazsın."
CREATE OR REPLACE FUNCTION fn_check_contribution() RETURNS TRIGGER AS $$
DECLARE
    my_tool_count INTEGER;
BEGIN
    -- Kiralama yapmak isteyen kişinin alet sayısını kontrol et
    SELECT COUNT(*) INTO my_tool_count FROM Tools WHERE owner_id = NEW.renter_id;
    
    -- Eğer sayı 0 ise işlemi durdur ve hata ver
    IF my_tool_count = 0 THEN
        RAISE EXCEPTION 'HATA: İmece kuralı! Ödünç alabilmek için sisteme en az 1 alet eklemelisiniz.';
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_check_contribution_rule
BEFORE INSERT ON Loans
FOR EACH ROW
EXECUTE FUNCTION fn_check_contribution();


-- [TRIGGER 3] Veri Bütünlüğü Koruması
-- Kural: "Alet şu an birindeyse (Kirada), o aleti sistemden silemezsin."
CREATE OR REPLACE FUNCTION fn_prevent_delete_rented() RETURNS TRIGGER AS $$
BEGIN
    IF OLD.status = 'Kirada' THEN
        RAISE EXCEPTION 'HATA: Bu alet şu an kirada olduğu için silinemez!';
    END IF;
    RETURN OLD;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_prevent_delete
BEFORE DELETE ON Tools
FOR EACH ROW
EXECUTE FUNCTION fn_prevent_delete_rented();

CREATE OR REPLACE FUNCTION fn_check_date_overlap() RETURNS TRIGGER AS $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM Loans
        WHERE tool_id = NEW.tool_id
        AND loan_id != NEW.loan_id -- Update yaparken kendini hariç tut
        AND loan_status = 'Aktif'
        -- Tarih Aralığı Çakışma Formülü:
        AND (NEW.start_date < end_date AND NEW.end_date > start_date)
    ) THEN
        RAISE EXCEPTION 'HATA: Seçilen tarihlerde bu alet zaten rezerve edilmiş!';
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_check_date_overlap
BEFORE INSERT OR UPDATE ON Loans
FOR EACH ROW
EXECUTE FUNCTION fn_check_date_overlap();

-- ============================================================================
-- 7. TEST VERİLERİ (SEED DATA)
-- [KURAL: Her tabloda en az 10 kayıt]
-- ============================================================================

-- Kullanıcılar: Hem puanları hem rolleri test etmek için çeşitli profiller
INSERT INTO Users (username, password, full_name, role) VALUES
('admin', '1234', 'Sistem Yöneticisi', 'admin'), -- ID:1
('ali_y', '1234', 'Ali Yılmaz', 'user'),   -- ID:2
('ayse_k', '1234', 'Ayşe Kaya', 'user'),    -- ID:3
('mehmet_d', '1234', 'Mehmet Demir', 'user'), -- ID:4
('fatma_s', '1234', 'Fatma Şahin', 'user'), -- ID:5
('can_b', '1234', 'Can Bulut', 'user'),     -- ID:6
('elif_t', '1234', 'Elif Tekin', 'user'),   -- ID:7
('burak_o', '1234', 'Burak Öz', 'user'),    -- ID:8
('selin_a', '1234', 'Selin Ak', 'user'),    -- ID:9
('cem_g', '1234', 'Cem Gül', 'user'),       -- ID:10
('deniz_m', '1234', 'Deniz Mavi', 'user'),  -- ID:11
('emre_s', '1234', 'Emre Sarı', 'user');    -- ID:12

-- Kategoriler
INSERT INTO Categories (category_name) VALUES 
('Elektrikli Aletler'), ('Bahçe'), ('Kamp'), ('Temizlik'), 
('Otomotiv'), ('Ölçüm Cihazları'), ('Boya & Badana'), 
('Hobi'), ('Marangozluk'), ('Tesisat');

-- Aletler: İmece kuralını test etmek için herkesin en az 1 aleti var
INSERT INTO Tools (owner_id, category_id, tool_name, description, status) VALUES
(2, 1, 'Darbeli Matkap', 'Profesyonel', 'Müsait'),
(3, 2, 'Çim Biçme Makinesi', 'Benzinli', 'Kirada'),
(4, 3, 'Kamp Çadırı', '4 Kişilik', 'Müsait'),
(2, 4, 'Basınçlı Yıkama', 'Araç için', 'Müsait'),
(5, 5, 'Akü Şarj', '12V', 'Müsait'),
(6, 6, 'Lazer Metre', '50m', 'Müsait'),
(7, 7, 'Boya Tabancası', 'Elektrikli', 'Kirada'),
(8, 8, 'Dremel Set', 'Hobi', 'Müsait'),
(9, 9, 'Dekupaj', 'Kesim', 'Müsait'),
(2, 10, 'Boru Anahtarı', 'Büyük', 'Müsait'),
(3, 1, 'Vidalama', 'Şarjlı', 'Müsait'),
(4, 2, 'Budama Makası', 'Teleskopik', 'Bakımda');

-- Kiralamalar: TIMESTAMP formatında (Yıl-Ay-Gün Saat:Dakika:Saniye)
INSERT INTO Loans (tool_id, renter_id, start_date, end_date, loan_status) VALUES
(2, 5, '2025-10-01 09:00:00', '2025-10-05 18:00:00', 'Aktif'),      -- Fatma, 4 günlüğüne
(7, 2, '2025-10-02 10:00:00', '2025-10-04 14:00:00', 'Aktif'),      -- Ali, 2 günlüğüne
(1, 6, '2025-09-10 14:00:00', '2025-09-12 10:00:00', 'Tamamlandı'), -- Can, 2 günlüğüne
(3, 7, '2025-09-15 08:30:00', '2025-09-20 20:00:00', 'Tamamlandı'),
(4, 8, '2025-09-01 12:00:00', '2025-09-02 12:00:00', 'Tamamlandı'), -- Tam 24 saat
(5, 9, '2025-08-20 09:00:00', '2025-08-25 17:00:00', 'Tamamlandı'),
(6, 3, '2025-08-10 10:00:00', '2025-08-11 10:00:00', 'Tamamlandı'),
(8, 4, '2025-08-05 15:00:00', '2025-08-08 11:00:00', 'Tamamlandı'),
(9, 2, '2025-07-20 08:00:00', '2025-07-22 22:00:00', 'Tamamlandı'),
(10, 5,'2025-07-01 09:00:00', '2025-07-03 18:00:00', 'Tamamlandı');

-- Yorumlar: Trigger 1'i test etmek için karşılıklı puanlar
-- Senaryo: Can (Renter), Ali'nin matkabına yorum yapıyor.
INSERT INTO Reviews (loan_id, reviewer_type, user_rating, tool_rating, comment) 
VALUES (3, 'Renter', 5, 4, 'Ali bey çok ilgili, matkap biraz eski ama sağlam.');

-- Senaryo: Ali (Owner), Can'ın kullanımına yorum yapıyor.
INSERT INTO Reviews (loan_id, reviewer_type, user_rating, tool_rating, comment) 
VALUES (3, 'Owner', 5, NULL, 'Can aleti temiz getirdi, teşekkürler.');

-- Diğer yorumlar
INSERT INTO Reviews (loan_id, reviewer_type, user_rating, tool_rating, comment) 
VALUES (4, 'Renter', 4, 3, 'Çadır iyiydi ama sahibi geç cevap verdi.');

INSERT INTO Reviews (loan_id, reviewer_type, user_rating, tool_rating, comment) 
VALUES (5, 'Renter', 5, 5, 'Harika deneyim.');

INSERT INTO Reviews (loan_id, reviewer_type, user_rating, tool_rating, comment)
VALUES (6, 'Renter', 4, 4, 'Temiz ve bakımlı, tavsiye ederim.');

INSERT INTO Reviews (loan_id, reviewer_type, user_rating, tool_rating, comment)
VALUES (7, 'Renter', 5, 5, 'İşimi fazlasıyla gördü.');

INSERT INTO Reviews (loan_id, reviewer_type, user_rating, tool_rating, comment)
VALUES (8, 'Renter', 3, 2, 'Alet biraz ağırdı ama çalışıyor.');

INSERT INTO Reviews (loan_id, reviewer_type, user_rating, tool_rating, comment)
VALUES (9, 'Owner', 5, NULL, 'Zamanında teslim etti, güvenilir.');

INSERT INTO Reviews (loan_id, reviewer_type, user_rating, tool_rating, comment)
VALUES (10, 'Renter', 5, 5, 'Süper alet, teşekkürler.');

INSERT INTO Reviews (loan_id, reviewer_type, user_rating, tool_rating, comment)
VALUES (1, 'Owner', 5, NULL, 'Sorunsuz alışveriş.');

