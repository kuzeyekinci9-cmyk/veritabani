-- ============================================================================
-- PROJE ADI: TOOLSHARE (ADMIN-SECURE & IMECE EDITION - ULTIMATE v7.0)
-- ============================================================================
-- BU SQL DOSYASI AŞAĞIDAKİ TÜM ÖZELLİKLERİ İÇERİR:
-- 1. GÜVENLİK & RBAC: Admin/User rol ayrımı, yetkisiz erişim engelleme.
-- 2. KARŞILIKLI PUANLAMA (Airbnb Modeli): Alan vereni, veren alanı puanlar.
-- 3. MÜTEKABİLİYET İLKESİ (İMECE): Sisteme alet eklemeyen, kiralama yapamaz.
-- 4. RAPORLAMA & ANALİZ: Big Data mantığı ile veritabanı içi analizler.
-- 5. VERİ BÜTÜNLÜĞÜ: Triggerlar ile tarih çakışması ve silme koruması.
-- ============================================================================

-- [TEMİZLİK] Önce eski şemayı temizleyip sıfırdan oluşturuyoruz.
DROP SCHEMA public CASCADE;
CREATE SCHEMA public;

-- ============================================================================
-- 1. SEQUENCE (OTOMATİK SAYI ÜRETİCİLERİ)
-- [KURAL: Sequence Oluşturma]
-- Neden SERIAL kullanmadık? Çünkü sequence'ı elle yöneterek veritabanı 
-- hakimiyetimizi göstermek ve farklı tablolarda ortak sayaç kullanabilme esnekliği istedik.
-- ============================================================================
CREATE SEQUENCE seq_users_id START 1;
CREATE SEQUENCE seq_category_id START 1;
CREATE SEQUENCE seq_tool_id START 1;
CREATE SEQUENCE seq_loan_id START 1;
CREATE SEQUENCE seq_review_id START 1;

-- ============================================================================
-- 2. TABLO TASARIMLARI
-- [KURAL: En az 4 tablo, PK (Primary Key) ve FK (Foreign Key) kullanımı]
-- ============================================================================

-- A. USERS (KULLANICILAR)
CREATE TABLE Users (
    -- nextval(...) diyerek yukarıdaki sequence'ı manuel bağlıyoruz.
    user_id INTEGER DEFAULT nextval('seq_users_id') PRIMARY KEY,
    username VARCHAR(50) UNIQUE NOT NULL, 
    password VARCHAR(50) NOT NULL, 
    full_name VARCHAR(100) NOT NULL,
    
    -- [KURAL: Değer Kısıtı (Check Constraint)]
    -- Sadece 'admin' veya 'user' girilmesine izin veriyoruz (RBAC Temeli).
    role VARCHAR(20) DEFAULT 'user' CHECK (role IN ('admin', 'user')),
    
    -- Bu puan hem satıcı hem alıcı güvenilirliğini temsil eder. Trigger ile güncellenir.
    security_score DECIMAL(3,2) DEFAULT 5.00
);

-- B. CATEGORIES (KATEGORİLER)
CREATE TABLE Categories (
    category_id INTEGER DEFAULT nextval('seq_category_id') PRIMARY KEY,
    category_name VARCHAR(50) NOT NULL
);

-- C. TOOLS (ALETLER)
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
    -- Kullanıcı silinirse, sahip olduğu aletler de otomatik silinsin (Referential Integrity).
    FOREIGN KEY (owner_id) REFERENCES Users(user_id) ON DELETE CASCADE,
    FOREIGN KEY (category_id) REFERENCES Categories(category_id)
);

-- D. LOANS (ÖDÜNÇ/KİRALAMA)
CREATE TABLE Loans (
    loan_id INTEGER DEFAULT nextval('seq_loan_id') PRIMARY KEY,
    tool_id INTEGER,
    renter_id INTEGER,
    start_date TIMESTAMP NOT NULL,
    end_date TIMESTAMP NOT NULL,
    
    loan_status VARCHAR(20) DEFAULT 'Aktif' CHECK (loan_status IN ('Aktif', 'Tamamlandı')),
    
    -- [KURAL] Mantıksal Tutarlılık: Bitiş tarihi başlangıçtan önce olamaz.
    CHECK (end_date >= start_date), 
    FOREIGN KEY (tool_id) REFERENCES Tools(tool_id) ON DELETE CASCADE,
    FOREIGN KEY (renter_id) REFERENCES Users(user_id)
);

-- E. REVIEWS (ÇİFT YÖNLÜ PUANLAMA SİSTEMİ)
-- Burası sistemin en karmaşık tablosu. Kimin kime puan verdiğini yönetir.
CREATE TABLE Reviews (
    review_id INTEGER DEFAULT nextval('seq_review_id') PRIMARY KEY,
    loan_id INTEGER,
    
    -- [YENİ ÖZELLİK] Puanı veren KİRALAYAN mı yoksa SAHİBİ mi?
    reviewer_type VARCHAR(10) CHECK (reviewer_type IN ('Renter', 'Owner')),
    
    user_rating INTEGER CHECK (user_rating BETWEEN 1 AND 5),
    tool_rating INTEGER CHECK (tool_rating BETWEEN 1 AND 5), 
    comment TEXT,
    review_date DATE DEFAULT CURRENT_DATE,
    
    FOREIGN KEY (loan_id) REFERENCES Loans(loan_id) ON DELETE CASCADE,
    
    -- [KURAL] Bir kişi aynı işlemi iki kere puanlayamasın (Veri Tekilliği).
    UNIQUE (loan_id, reviewer_type),
    
    -- [KURAL] Eğer puanlayan 'Owner' ise, kendi aletine puan veremez (tool_rating NULL olmalı).
    CHECK ( (reviewer_type = 'Owner' AND tool_rating IS NULL) OR (reviewer_type = 'Renter') )
);

-- ============================================================================
-- 3. INDEX
-- [KURAL: Index Oluşturma]
-- Arayüzde alet adına göre arama yapıldığında performansı artırmak için.
-- ============================================================================
CREATE INDEX idx_tool_name ON Tools(tool_name);

-- ============================================================================
-- 4. VIEWS (GÖRÜNÜMLER)
-- [KURAL: View Oluşturma]
-- Karmaşık JOIN sorgularını saklayarak Python tarafında kod tekrarını önlüyoruz.
-- ============================================================================

-- View 1: Müsait Aletler Vitrini
CREATE OR REPLACE VIEW v_available_tools AS
SELECT 
    t.tool_id, t.tool_name, c.category_name, 
    u.full_name AS owner_name, u.security_score AS owner_score,
    t.tool_score, t.status
FROM Tools t
JOIN Users u ON t.owner_id = u.user_id
JOIN Categories c ON t.category_id = c.category_id
WHERE t.status = 'Müsait';

-- View 2: Cömertler (Sadece Verenler) - EXCEPT Kullanımı Örneği
-- [KURAL: Set Operatörleri] İki sorgu sonucunun farkını alır.
CREATE OR REPLACE VIEW v_givers_not_takers AS
SELECT user_id, username, full_name 
FROM Users 
WHERE user_id IN (
    SELECT owner_id FROM Tools -- Aleti olanlar
    EXCEPT 
    SELECT renter_id FROM Loans -- Kiralama yapanlar
);

-- ============================================================================
-- 5. FONKSİYONLAR (BUSINESS LOGIC & SECURITY)
-- [KURAL: PL/pgSQL Fonksiyonları]
-- İş mantığını veritabanına gömerek uygulamanın daha güvenli olmasını sağlıyoruz.
-- ============================================================================


-- [FONKSİYON 1] GÜVENLİ LOGIN (ID ile Giriş)
-- Değişiklik: Artık p_username yerine p_user_id alıyor.
CREATE OR REPLACE FUNCTION sp_login(
    p_user_id INTEGER,          -- String değil, Integer ID alıyoruz
    p_password VARCHAR, 
    p_interface_type VARCHAR
) 
RETURNS TABLE(user_id INTEGER, role VARCHAR, full_name VARCHAR) AS $$
DECLARE v_real_role VARCHAR;
BEGIN
    -- Kullanıcıyı Username ile değil, ID ile buluyoruz
    SELECT u.role INTO v_real_role 
    FROM Users u 
    WHERE u.user_id = p_user_id AND u.password = p_password;
    
    IF NOT FOUND THEN 
        RAISE EXCEPTION 'HATA: Giriş başarısız! Kullanıcı ID veya şifre yanlış.'; 
    END IF;
    
    -- Rol tabanlı erişim kontrolü
    IF v_real_role != p_interface_type THEN 
        RAISE EXCEPTION 'ERİŞİM REDDEDİLDİ: % rolü ile % paneline girilemez!', v_real_role, p_interface_type; 
    END IF;
    
    RETURN QUERY SELECT u.user_id, u.role, u.full_name FROM Users u WHERE u.user_id = p_user_id;
END;
$$ LANGUAGE plpgsql;

-- [FONKSİYON 2] ADMIN YETKİSİ VERME (Sadece Adminler Kullanabilir)
CREATE OR REPLACE FUNCTION sp_grant_admin_role(p_requester_id INTEGER, p_target_user_id INTEGER) RETURNS VOID AS $$
DECLARE v_requester_role VARCHAR;
BEGIN
    SELECT role INTO v_requester_role FROM Users WHERE user_id = p_requester_id;
    IF v_requester_role != 'admin' THEN RAISE EXCEPTION 'YETKİSİZ İŞLEM!'; END IF;
    UPDATE Users SET role = 'admin' WHERE user_id = p_target_user_id;
END;
$$ LANGUAGE plpgsql;

-- [FONKSİYON 3] ADMIN YETKİSİ ALMA
CREATE OR REPLACE FUNCTION sp_revoke_admin_role(p_requester_id INTEGER, p_target_user_id INTEGER) RETURNS VOID AS $$
DECLARE v_requester_role VARCHAR;
BEGIN
    SELECT role INTO v_requester_role FROM Users WHERE user_id = p_requester_id;
    IF v_requester_role != 'admin' THEN RAISE EXCEPTION 'YETKİSİZ İŞLEM!'; END IF;
    IF p_requester_id = p_target_user_id THEN RAISE EXCEPTION 'HATA: Kendini silemezsin!'; END IF;
    UPDATE Users SET role = 'user' WHERE user_id = p_target_user_id;
END;
$$ LANGUAGE plpgsql;

-- [FONKSİYON 4] GÜVENLİ ALET SİLME
-- Bir kullanıcı sadece kendi aletini silebilir, ancak Admin herkesinkini silebilir.
CREATE OR REPLACE FUNCTION sp_secure_delete_tool(p_tool_id INTEGER, p_requester_id INTEGER) RETURNS TEXT AS $$
DECLARE v_owner_id INTEGER; v_requester_role VARCHAR;
BEGIN
    SELECT owner_id INTO v_owner_id FROM Tools WHERE tool_id = p_tool_id;
    SELECT role INTO v_requester_role FROM Users WHERE user_id = p_requester_id;
    
    IF (v_owner_id != p_requester_id) AND (v_requester_role != 'admin') THEN 
        RAISE EXCEPTION 'YETKİSİZ İŞLEM! Başkasının aletini silemezsiniz.'; 
    END IF;
    
    DELETE FROM Tools WHERE tool_id = p_tool_id;
    RETURN 'Başarılı: Alet silindi.';
END;
$$ LANGUAGE plpgsql;

-- [FONKSİYON 5] GÜVENLİ ALET EKLEME
CREATE OR REPLACE FUNCTION sp_secure_add_tool(p_requester_id INTEGER, p_owner_id INTEGER, p_category_id INTEGER, p_tool_name VARCHAR, p_description TEXT) RETURNS VOID AS $$
DECLARE v_requester_role VARCHAR;
BEGIN
    SELECT role INTO v_requester_role FROM Users WHERE user_id = p_requester_id;
    -- Kişi ya kendisi için ekliyordur ya da Admindir.
    IF (p_requester_id != p_owner_id) AND (v_requester_role != 'admin') THEN 
        RAISE EXCEPTION 'YETKİSİZ İŞLEM!'; 
    END IF;
    INSERT INTO Tools (owner_id, category_id, tool_name, description, status) VALUES (p_owner_id, p_category_id, p_tool_name, p_description, 'Müsait');
END;
$$ LANGUAGE plpgsql;

-- [FONKSİYON 6] GÜVENLİ KULLANICI EKLEME (Sadece Admin)
-- Bu fonksiyon yeni sürümde eklendi.
CREATE OR REPLACE FUNCTION sp_add_user(
    p_requester_id INTEGER, -- Kim ekliyor?
    p_username VARCHAR,
    p_password VARCHAR,
    p_full_name VARCHAR,
    p_role VARCHAR DEFAULT 'user'
) RETURNS VOID AS $$
DECLARE 
    v_requester_role VARCHAR;
BEGIN
    -- 1. İstek yapanın rolünü kontrol et
    SELECT role INTO v_requester_role FROM Users WHERE user_id = p_requester_id;
    
    -- 2. Eğer admin değilse hata ver
    IF v_requester_role != 'admin' THEN
        RAISE EXCEPTION 'YETKİSİZ İŞLEM: Sadece adminler yeni kullanıcı oluşturabilir!';
    END IF;

    -- 3. Kullanıcıyı ekle
    INSERT INTO Users (username, password, full_name, role) 
    VALUES (p_username, p_password, p_full_name, p_role);
END;
$$ LANGUAGE plpgsql;

-- [FONKSİYON 7] GELİŞMİŞ ARAMA VE SIRALAMA (Herkes Kullanabilir)
-- SQL içinde dinamik sıralama mantığı (CASE WHEN kullanımı).
CREATE OR REPLACE FUNCTION sp_search_and_sort_tools(p_search_term VARCHAR, p_sort_option INTEGER)
RETURNS TABLE(id INTEGER, isim VARCHAR, kategori VARCHAR, sahip VARCHAR, sahip_puani DECIMAL, alet_puani DECIMAL, durum VARCHAR) AS $$
BEGIN
    RETURN QUERY SELECT * FROM v_available_tools 
    WHERE (p_search_term IS NULL OR tool_name ILIKE '%' || p_search_term || '%')
    ORDER BY 
        CASE WHEN p_sort_option = 1 THEN tool_name END ASC, 
        CASE WHEN p_sort_option = 2 THEN tool_name END DESC, 
        CASE WHEN p_sort_option = 3 THEN tool_score END DESC, 
        CASE WHEN p_sort_option = 4 THEN owner_score END DESC;
END;
$$ LANGUAGE plpgsql;

-- [FONKSİYON 8] AYLIK PAYLAŞIM RAPORU (SADECE ADMIN)
-- [KURAL: Record ve Döngü Kullanımı]
-- O ay toplam kaç gün paylaşım yapıldığını hesaplar.
CREATE OR REPLACE FUNCTION monthly_sharing_activity(
    p_requester_id INTEGER, -- Güvenlik parametresi
    p_month INTEGER, 
    p_year INTEGER
) RETURNS INTEGER AS $$
DECLARE 
    total_days INTEGER := 0; r_loan RECORD; v_days INTEGER;
    v_requester_role VARCHAR;
BEGIN
    -- Güvenlik Kontrolü
    SELECT role INTO v_requester_role FROM Users WHERE user_id = p_requester_id;
    IF v_requester_role != 'admin' THEN RAISE EXCEPTION 'YETKİSİZ İŞLEM: Raporları sadece adminler görebilir!'; END IF;

    FOR r_loan IN SELECT start_date, end_date FROM Loans WHERE EXTRACT(MONTH FROM start_date) = p_month AND EXTRACT(YEAR FROM start_date) = p_year LOOP
        -- Tarih farkını saniye cinsinden alıp güne çeviriyoruz (Tavana yuvarlama).
        v_days := CEIL(EXTRACT(EPOCH FROM (r_loan.end_date - r_loan.start_date)) / 86400); 
        IF v_days < 1 THEN v_days := 1; END IF; total_days := total_days + v_days;
    END LOOP; RETURN total_days;
END;
$$ LANGUAGE plpgsql;

-- [FONKSİYON 9] CÖMERT KOMŞULAR ANALİZİ (SADECE ADMIN)
-- [KURAL: Aggregate Functions (COUNT) ve HAVING kullanımı]
CREATE OR REPLACE FUNCTION get_top_sharers(
    p_requester_id INTEGER, 
    min_shares INTEGER
)
RETURNS TABLE(neighbor_name VARCHAR, share_count BIGINT) AS $$
DECLARE
    v_requester_role VARCHAR;
BEGIN
    SELECT role INTO v_requester_role FROM Users WHERE user_id = p_requester_id;
    IF v_requester_role != 'admin' THEN 
        RAISE EXCEPTION 'YETKİSİZ İŞLEM: Bu analizi sadece adminler görebilir!'; 
    END IF;

    RETURN QUERY
    SELECT u.full_name, COUNT(l.loan_id)
    FROM Loans l
    JOIN Tools t ON l.tool_id = t.tool_id
    JOIN Users u ON t.owner_id = u.user_id
    GROUP BY u.full_name
    HAVING COUNT(l.loan_id) >= min_shares
    ORDER BY COUNT(l.loan_id) DESC;
END;
$$ LANGUAGE plpgsql;

-- [7] KİRALAMA YAPMA (EKSİKTİ - EKLENDİ)
CREATE OR REPLACE FUNCTION sp_rent_tool(p_renter_id INTEGER, p_tool_id INTEGER, p_start_date TIMESTAMP, p_end_date TIMESTAMP) RETURNS TEXT AS $$
BEGIN
    INSERT INTO Loans (tool_id, renter_id, start_date, end_date, loan_status) VALUES (p_tool_id, p_renter_id, p_start_date, p_end_date, 'Aktif');
    RETURN 'Başarılı: Kiralama tamamlandı.';
EXCEPTION WHEN OTHERS THEN RETURN 'HATA: ' || SQLERRM;
END;
$$ LANGUAGE plpgsql;

-- [8] KİRALAMA BİTİRME / İADE (EKSİKTİ - EKLENDİ)
CREATE OR REPLACE FUNCTION sp_return_tool(p_requester_id INTEGER, p_loan_id INTEGER) RETURNS TEXT AS $$
DECLARE v_renter_id INTEGER; v_owner_id INTEGER; v_role VARCHAR;
BEGIN
    SELECT l.renter_id, t.owner_id INTO v_renter_id, v_owner_id 
    FROM Loans l JOIN Tools t ON l.tool_id = t.tool_id WHERE l.loan_id = p_loan_id;
    SELECT role INTO v_role FROM Users WHERE user_id = p_requester_id;
    
    -- Kiralayan, Sahibi veya Admin bitirebilir
    IF (p_requester_id != v_renter_id) AND (p_requester_id != v_owner_id) AND (v_role != 'admin') THEN 
        RETURN 'HATA: Bu işlemi yapmaya yetkiniz yok.'; 
    END IF;

    UPDATE Loans SET loan_status = 'Tamamlandı' WHERE loan_id = p_loan_id;
    RETURN 'Başarılı: Alet iade edildi.';
END;
$$ LANGUAGE plpgsql;

-- [9] YORUM YAPMA (EKSİKTİ - EKLENDİ)
CREATE OR REPLACE FUNCTION sp_add_review(
    p_loan_id INTEGER, 
    p_reviewer_type VARCHAR, -- 'Renter' veya 'Owner'
    p_user_rating INTEGER, 
    p_tool_rating INTEGER, -- Owner puanlıyorsa buraya NULL yolla
    p_comment TEXT
) RETURNS TEXT AS $$
BEGIN
    INSERT INTO Reviews (loan_id, reviewer_type, user_rating, tool_rating, comment)
    VALUES (p_loan_id, p_reviewer_type, p_user_rating, p_tool_rating, p_comment);
    RETURN 'Başarılı: Yorum kaydedildi.';
EXCEPTION WHEN OTHERS THEN RETURN 'HATA: ' || SQLERRM;
END;
$$ LANGUAGE plpgsql;

--[10] Kullanıcının başkasından kiraladığı aletleri getirir
CREATE OR REPLACE FUNCTION sp_get_my_rentals(p_user_id INTEGER)
RETURNS TABLE(loan_id INTEGER, tool_name VARCHAR, start_d TIMESTAMP, end_d TIMESTAMP, stat VARCHAR) AS $$
BEGIN
    RETURN QUERY 
    SELECT l.loan_id, t.tool_name, l.start_date, l.end_date, l.loan_status
    FROM Loans l
    JOIN Tools t ON l.tool_id = t.tool_id
    WHERE l.renter_id = p_user_id
    ORDER BY l.start_date DESC;
END;
$$ LANGUAGE plpgsql;

--[11] Kullanıcının başkasına kiraladığı (sahibi olduğu) işlemleri getirir
CREATE OR REPLACE FUNCTION sp_get_loans_of_my_tools(p_owner_id INTEGER)
RETURNS TABLE(loan_id INTEGER, tool_name VARCHAR, renter_name VARCHAR, start_d TIMESTAMP, end_d TIMESTAMP, stat VARCHAR) AS $$
BEGIN
    RETURN QUERY 
    SELECT l.loan_id, t.tool_name, u.full_name, l.start_date, l.end_date, l.loan_status
    FROM Loans l
    JOIN Tools t ON l.tool_id = t.tool_id
    JOIN Users u ON l.renter_id = u.user_id
    WHERE t.owner_id = p_owner_id
    ORDER BY l.start_date DESC;
END;
$$ LANGUAGE plpgsql;

--[12] alete tıklandığında yorumları getirsin diye
CREATE OR REPLACE FUNCTION sp_get_tool_reviews(p_tool_id INTEGER)
RETURNS TABLE(reviewer_name VARCHAR, rating INTEGER, comment TEXT, r_date DATE) AS $$
BEGIN
    RETURN QUERY
    SELECT u.full_name, r.tool_rating, r.comment, r.review_date
    FROM Reviews r
    JOIN Loans l ON r.loan_id = l.loan_id
    JOIN Users u ON l.renter_id = u.user_id -- Yorumu yapan kiracıyı buluyoruz
    WHERE l.tool_id = p_tool_id AND r.reviewer_type = 'Renter';
END;
$$ LANGUAGE plpgsql;

--[13] alet kirada değilse müsait gibi bir durum oluşuyor. sahibi pasife çekmek de isteyebilir,
--tatile gitti diyelim. üzerindeki aletleri "bakımda" olarak set edebilsin. bu bir toggle fonksiyon, 
-- müsaitse bakıma alır, bakımdaysa müsaite çeker.
CREATE OR REPLACE FUNCTION sp_toggle_maintenance(
    p_tool_id INTEGER, 
    p_owner_id INTEGER -- Güvenlik: Sadece sahibi yapabilir
) RETURNS TEXT AS $$
DECLARE 
    v_current_status VARCHAR;
    v_real_owner INTEGER;
BEGIN
    -- 1. Aletin durumunu ve sahibini çekelim
    SELECT status, owner_id INTO v_current_status, v_real_owner 
    FROM Tools WHERE tool_id = p_tool_id;

    -- 2. Yetki Kontrolü
    IF v_real_owner != p_owner_id THEN
        RAISE EXCEPTION 'HATA: Bu işlem için yetkiniz yok!';
    END IF;

    -- 3. Durum Değiştirme Mantığı
    IF v_current_status = 'Kirada' THEN
        RAISE EXCEPTION 'HATA: Alet şu an kirada, bakıma alınamaz!';
        
    ELSIF v_current_status = 'Müsait' THEN
        UPDATE Tools SET status = 'Bakımda' WHERE tool_id = p_tool_id;
        RETURN 'Bilgi: Alet bakıma alındı, artık listelenmeyecek.';
        
    ELSIF v_current_status = 'Bakımda' THEN
        UPDATE Tools SET status = 'Müsait' WHERE tool_id = p_tool_id;
        RETURN 'Bilgi: Alet bakımdan çıktı, tekrar kiralanabilir.';
    END IF;

    RETURN 'İşlem başarısız.';
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- 6. TRIGGERLAR (OTOMASYON KURALLARI)
-- ============================================================================

-- [TRIGGER 1] Çift Yönlü Puan Güncelleme Sistemi (Airbnb Modeli)
-- Yorum yapıldığında hem aletin hem de kullanıcının puanını otomatik günceller.
CREATE OR REPLACE FUNCTION fn_update_mutual_scores() RETURNS TRIGGER AS $$
DECLARE v_tool_id INTEGER; v_owner_id INTEGER; v_renter_id INTEGER; v_new_score DECIMAL(3,2);
BEGIN
    SELECT t.tool_id, t.owner_id, l.renter_id INTO v_tool_id, v_owner_id, v_renter_id FROM Loans l JOIN Tools t ON l.tool_id = t.tool_id WHERE l.loan_id = NEW.loan_id;
    
    IF NEW.reviewer_type = 'Renter' THEN
        -- Renter yorum yaptıysa -> Alet Puanı ve Sahip Puanı güncellenir.
        SELECT AVG(tool_rating) INTO v_new_score FROM Reviews WHERE loan_id IN (SELECT loan_id FROM Loans WHERE tool_id = v_tool_id) AND reviewer_type = 'Renter';
        UPDATE Tools SET tool_score = COALESCE(v_new_score, 0) WHERE tool_id = v_tool_id;
        
        SELECT AVG(r.user_rating) INTO v_new_score FROM Reviews r JOIN Loans l ON r.loan_id = l.loan_id JOIN Tools t ON l.tool_id = t.tool_id WHERE t.owner_id = v_owner_id AND r.reviewer_type = 'Renter';
        UPDATE Users SET security_score = COALESCE(v_new_score, 0) WHERE user_id = v_owner_id;
        
    ELSIF NEW.reviewer_type = 'Owner' THEN
        -- Owner yorum yaptıysa -> Renter (Kiracı) Puanı güncellenir.
        SELECT AVG(r.user_rating) INTO v_new_score FROM Reviews r JOIN Loans l ON r.loan_id = l.loan_id WHERE l.renter_id = v_renter_id AND r.reviewer_type = 'Owner';
        UPDATE Users SET security_score = COALESCE(v_new_score, 0) WHERE user_id = v_renter_id;
    END IF; RETURN NEW;
END;
$$ LANGUAGE plpgsql;
CREATE TRIGGER trg_update_mutual_scores AFTER INSERT ON Reviews FOR EACH ROW EXECUTE FUNCTION fn_update_mutual_scores();

-- [TRIGGER 2] İmece Kuralı + Kendi Malını Kiralama Engeli
-- Kural: "Sisteme katkı sağlamayan (alet eklemeyen), sistemden faydalanamaz."
CREATE OR REPLACE FUNCTION fn_check_contribution() RETURNS TRIGGER AS $$
DECLARE my_tool_count INTEGER; v_owner_id INTEGER;
BEGIN
    SELECT owner_id INTO v_owner_id FROM Tools WHERE tool_id = NEW.tool_id;
    IF v_owner_id = NEW.renter_id THEN RAISE EXCEPTION 'HATA: Etik Kural! Kendi aletini kiralayamazsın.'; END IF;
    
    -- İmece Kontrolü
    SELECT COUNT(*) INTO my_tool_count FROM Tools WHERE owner_id = NEW.renter_id;
    IF my_tool_count = 0 THEN RAISE EXCEPTION 'HATA: İmece kuralı! Önce sisteme 1 alet ekle.'; END IF; RETURN NEW;
END;
$$ LANGUAGE plpgsql;
CREATE TRIGGER trg_check_contribution_rule BEFORE INSERT ON Loans FOR EACH ROW EXECUTE FUNCTION fn_check_contribution();

-- [TRIGGER 3] Tarih Çakışması Kontrolü
CREATE OR REPLACE FUNCTION fn_check_date_overlap() RETURNS TRIGGER AS $$
BEGIN
    IF NEW.loan_status = 'Aktif' AND NEW.start_date < CURRENT_TIMESTAMP THEN RAISE EXCEPTION 'HATA: Geçmişe rezervasyon yapılamaz!'; END IF;
    -- Tarih aralığı çakışma formülü: (StartA < EndB) and (EndA > StartB)
    IF EXISTS (SELECT 1 FROM Loans WHERE tool_id = NEW.tool_id AND loan_id != NEW.loan_id AND loan_status = 'Aktif' AND (NEW.start_date < end_date AND NEW.end_date > start_date)) THEN RAISE EXCEPTION 'HATA: Tarihler çakışıyor! Bu aralıkta alet dolu.'; END IF; RETURN NEW;
END;
$$ LANGUAGE plpgsql;
CREATE TRIGGER trg_check_date_overlap BEFORE INSERT OR UPDATE ON Loans FOR EACH ROW EXECUTE FUNCTION fn_check_date_overlap();

-- [TRIGGER 4] Otomatik Statü Güncelleyici
-- Kiralama başladığında alet 'Kirada', bittiğinde 'Müsait' olsun.
CREATE OR REPLACE FUNCTION fn_auto_update_status() RETURNS TRIGGER AS $$
BEGIN
    IF (TG_OP = 'INSERT' AND NEW.loan_status = 'Aktif') THEN UPDATE Tools SET status = 'Kirada' WHERE tool_id = NEW.tool_id;
    ELSIF (TG_OP = 'UPDATE' AND NEW.loan_status = 'Tamamlandı') THEN UPDATE Tools SET status = 'Müsait' WHERE tool_id = NEW.tool_id; END IF; RETURN NEW;
END;
$$ LANGUAGE plpgsql;
CREATE TRIGGER trg_auto_update_status AFTER INSERT OR UPDATE ON Loans FOR EACH ROW EXECUTE FUNCTION fn_auto_update_status();

-- [TRIGGER 5] Yorum Zamanlaması
-- Kiralama bitmeden yorum yapılamaz kuralı.
CREATE OR REPLACE FUNCTION fn_check_review_timing() RETURNS TRIGGER AS $$
DECLARE v_end_date TIMESTAMP; v_status VARCHAR;
BEGIN
    SELECT end_date, loan_status INTO v_end_date, v_status FROM Loans WHERE loan_id = NEW.loan_id;
    IF v_status = 'Aktif' AND CURRENT_TIMESTAMP < v_end_date THEN RAISE EXCEPTION 'HATA: Kiralama bitmeden yorum yapılamaz!'; END IF; RETURN NEW;
END;
$$ LANGUAGE plpgsql;
CREATE TRIGGER trg_check_review_timing BEFORE INSERT ON Reviews FOR EACH ROW EXECUTE FUNCTION fn_check_review_timing();

-- [TRIGGER 6] Veri Bütünlüğü / Silme Koruması
-- "Kirada olan alet silinemez" kuralı.
CREATE OR REPLACE FUNCTION fn_prevent_delete_rented() RETURNS TRIGGER AS $$
BEGIN
    IF OLD.status = 'Kirada' THEN RAISE EXCEPTION 'HATA: Alet kirada olduğu için silinemez.'; END IF; RETURN OLD;
END;
$$ LANGUAGE plpgsql;
CREATE TRIGGER trg_prevent_delete BEFORE DELETE ON Tools FOR EACH ROW EXECUTE FUNCTION fn_prevent_delete_rented();

-- ============================================================================
-- 7. TEST VERİLERİ (SEED DATA)
-- [KURAL: Her tabloda en az 10 kayıt]
-- Test ve demo için genişletilmiş veri seti.
-- ============================================================================

-- KULLANICILAR (50+ Kayıt)
INSERT INTO Users (username, password, full_name, role) VALUES
('admin', 'admin123', 'System Administrator', 'admin'),
('user1', 'pass1', 'Ahmet Yılmaz', 'user'),  ('user2', 'pass2', 'Ayşe Demir', 'user'),
('user3', 'pass3', 'Mehmet Kaya', 'user'),   ('user4', 'pass4', 'Fatma Çelik', 'user'),
('user5', 'pass5', 'Can Yıldız', 'user'),    ('user6', 'pass6', 'Elif Öztürk', 'user'),
('user7', 'pass7', 'Burak Aydın', 'user'),   ('user8', 'pass8', 'Selin Arslan', 'user'),
('user9', 'pass9', 'Cem Doğan', 'user'),     ('user10', 'pass10', 'Deniz Koç', 'user'),
('user11', 'pass11', 'Emre Şahin', 'user'),  ('user12', '1234', 'Zeynep Kara', 'user'),
('user13', '1234', 'Hakan Ak', 'user'),      ('user14', '1234', 'Derya Polat', 'user'),
('user15', '1234', 'Murat Kurt', 'user'),    ('user16', '1234', 'Gizem Aslan', 'user'),
('user17', '1234', 'Oğuzhan Tekin', 'user'), ('user18', '1234', 'Esra Yavuz', 'user'),
('user19', '1234', 'Kemal Öz', 'user'),      ('user20', '1234', 'Berna Taş', 'user'),
('user21', '1234', 'Tolga Ünal', 'user'),    ('user22', '1234', 'Seda Güneş', 'user'),
('user23', '1234', 'Onur Bulut', 'user'),    ('user24', '1234', 'Pınar Erdem', 'user'),
('user25', '1234', 'Serkan Yiğit', 'user'),  ('user26', '1234', 'Nilay Sönmez', 'user'),
('user27', '1234', 'Levent Baş', 'user'),    ('user28', '1234', 'Duygu Şen', 'user'),
('user29', '1234', 'Koray Avcı', 'user'),    ('user30', '1234', 'Büşra Can', 'user'),
('user31', '1234', 'Tamer Karaca', 'user'),  ('user32', '1234', 'Melis Duran', 'user'),
('user33', '1234', 'Volkan Tunç', 'user'),   ('user34', '1234', 'Yasemin Ekinci', 'user'),
('user35', '1234', 'Gökhan Köse', 'user'),   ('user36', '1234', 'Ebru Çetin', 'user'),
('user37', '1234', 'Sinan Varol', 'user'),   ('user38', '1234', 'İrem Aktaş', 'user'),
('user39', '1234', 'Barış Güler', 'user'),   ('user40', '1234', 'Gamze Uçar', 'user'),
('user41', '1234', 'Metin Sarı', 'user'),    ('user42', '1234', 'Hülya Keleş', 'user'),
('user43', '1234', 'Arda Bingöl', 'user'),   ('user44', '1234', 'Merve Tezel', 'user'),
('user45', '1234', 'Ozan Çakır', 'user'),    ('user46', '1234', 'Nazlı Özer', 'user'),
('user47', '1234', 'Uğur Bilgin', 'user'),   ('user48', '1234', 'Sibel Yalçın', 'user'),
('user49', '1234', 'Fatih Erdoğan', 'user'), ('user50', '1234', 'Ceren Soylu', 'user');

-- KATEGORİLER
INSERT INTO Categories (category_name) VALUES 
('Elektrikli Aletler'), ('Bahçe'), ('Kamp'), ('Temizlik'), ('Otomotiv'), 
('Ölçüm Cihazları'), ('Boya & Badana'), ('Hobi'), ('Marangozluk'), ('Tesisat'),
('Elektronik'), ('Mutfak Gereçleri'), ('Spor Ekipmanları'), ('Fotoğrafçılık'), ('Müzik Aletleri');

-- ALETLER (50 Kayıt)
INSERT INTO Tools (owner_id, category_id, tool_name, description, status) VALUES
(2, 1, 'Darbeli Matkap Bosch', 'Profesyonel', 'Müsait'), (2, 4, 'Basınçlı Yıkama', 'Araba için', 'Müsait'),
(3, 2, 'Çim Biçme Makinesi', 'Benzinli', 'Müsait'), (3, 12, 'Katı Meyve Sıkacağı', 'Sanayi', 'Müsait'),
(4, 3, 'Kamp Çadırı (4 Kişilik)', 'Su geçirmez', 'Müsait'), (4, 3, 'Uyku Tulumu', 'Kışlık', 'Müsait'),
(5, 5, 'Akü Şarj', '12V', 'Müsait'), (5, 10, 'İngiliz Anahtarı', 'Paslanmaz', 'Müsait'),
(6, 6, 'Lazer Metre', '50m', 'Müsait'), (7, 7, 'Boya Tabancası', 'Elektrikli', 'Müsait'),
(8, 8, 'Dremel Set', 'Hobi', 'Müsait'), (9, 9, 'Dekupaj', 'Ahşap', 'Müsait'),
(10, 10, 'Boru Anahtarı', 'Büyük', 'Müsait'), (11, 1, 'Şarjlı Vidalama', 'Çift batarya', 'Müsait'),
(12, 2, 'Budama Makası', 'Teleskopik', 'Bakımda'), (13, 14, 'Canon Kamera', 'DSLR', 'Müsait'),
(14, 14, 'Tripod', 'Manfrotto', 'Müsait'), (15, 13, 'Tenis Raketi', 'Wilson', 'Müsait'),
(16, 13, 'Dağ Bisikleti', '26 jant', 'Müsait'), (17, 11, 'Projeksiyon', 'HD', 'Müsait'),
(18, 11, 'PlayStation 5', '2 kol', 'Müsait'), (19, 15, 'Klasik Gitar', 'Yamaha', 'Müsait'),
(20, 15, 'Bateri Seti', 'Elektronik', 'Müsait'), (21, 1, 'Lehim Seti', 'Tamir', 'Müsait'),
(22, 2, 'Kürek Seti', 'Bahçe', 'Müsait'), (23, 3, 'Kamp Sandalyesi', 'Katlanır', 'Müsait'),
(24, 4, 'Halı Yıkama', 'Ev tipi', 'Müsait'), (25, 5, 'Kriko', '2 Ton', 'Müsait'),
(26, 6, 'Su Terazisi', 'Dijital', 'Müsait'), (27, 7, 'Merdiven', '3m', 'Müsait'),
(28, 8, 'Silikon Tabancası', 'Sıcak', 'Müsait'), (29, 9, 'Zımpara Makinesi', 'Titreşimli', 'Müsait'),
(30, 10, 'Lavabo Açma', 'Spiral', 'Müsait'), (31, 1, 'Matkap Ucu', 'Set', 'Müsait'),
(32, 2, 'Hortum', '20m', 'Müsait'), (33, 3, 'Mangal', 'Portatif', 'Müsait'),
(34, 4, 'Buharlı Temizleyici', 'Karcher', 'Müsait'), (35, 5, 'Lastik Pompası', 'Dijital', 'Müsait'),
(36, 6, 'Multimetre', 'Ölçüm', 'Müsait'), (37, 7, 'Rulo Fırça', 'Set', 'Müsait'),
(38, 8, 'Maket Bıçağı', 'Yedekli', 'Müsait'), (39, 9, 'İşkence', 'Marangoz', 'Müsait'),
(40, 10, 'Teflon Bant', 'Tesisat', 'Müsait'), (41, 11, 'HDMI Kablo', '10m', 'Müsait'),
(42, 12, 'Blender', 'Mutfak', 'Müsait'), (43, 13, 'Yoga Matı', 'Kaymaz', 'Müsait'),
(44, 14, 'Softbox', 'Işık', 'Müsait'), (45, 15, 'Bağlama', 'Kısa sap', 'Müsait'),
(46, 1, 'Spiral Taşlama', 'Avuç içi', 'Müsait'), (47, 2, 'Balta', 'Kamp', 'Müsait'),
(48, 3, 'Termos', '2L', 'Müsait'), (49, 4, 'Cam Silme Robotu', 'Oto', 'Müsait'),
(50, 5, 'Polisaj', 'Cila', 'Müsait');

-- KİRALAMALAR (50+ Kayıt)
INSERT INTO Loans (tool_id, renter_id, start_date, end_date, loan_status) VALUES
-- Aktifler (Gelecek Tarih)
(1, 12, '2026-10-01 10:00:00', '2026-10-05 18:00:00', 'Aktif'), 
(3, 13, '2026-11-01 09:00:00', '2026-11-02 09:00:00', 'Aktif'), 
(17, 50, '2026-12-15 14:00:00', '2026-12-16 10:00:00', 'Aktif'), 
(20, 15, '2027-01-01 10:00:00', '2027-01-05 12:00:00', 'Aktif'), 
-- Tamamlananlar
(2, 6, '2025-01-10 10:00:00', '2025-01-12 10:00:00', 'Tamamlandı'),
(4, 7, '2025-02-05 09:00:00', '2025-02-06 18:00:00', 'Tamamlandı'),
(5, 8, '2025-03-01 08:00:00', '2025-03-05 20:00:00', 'Tamamlandı'),
(6, 9, '2025-03-10 12:00:00', '2025-03-11 12:00:00', 'Tamamlandı'),
(7, 10, '2025-04-01 14:00:00', '2025-04-02 10:00:00', 'Tamamlandı'),
(8, 11, '2025-04-15 10:00:00', '2025-04-16 16:00:00', 'Tamamlandı'),
(9, 12, '2025-05-01 09:00:00', '2025-05-03 18:00:00', 'Tamamlandı'),
(10, 13, '2025-05-10 11:00:00', '2025-05-10 17:00:00', 'Tamamlandı'),
(11, 14, '2025-06-01 10:00:00', '2025-06-05 10:00:00', 'Tamamlandı'),
(12, 15, '2025-06-15 08:00:00', '2025-06-16 20:00:00', 'Tamamlandı'),
(13, 16, '2025-07-01 09:00:00', '2025-07-03 18:00:00', 'Tamamlandı'),
(14, 17, '2025-07-10 13:00:00', '2025-07-12 11:00:00', 'Tamamlandı'),
(15, 18, '2025-08-01 10:00:00', '2025-08-01 18:00:00', 'Tamamlandı'),
(16, 19, '2025-08-05 09:00:00', '2025-08-10 09:00:00', 'Tamamlandı'),
(18, 20, '2025-08-20 14:00:00', '2025-08-22 10:00:00', 'Tamamlandı'),
(19, 21, '2025-09-01 10:00:00', '2025-09-02 10:00:00', 'Tamamlandı'),
(21, 22, '2025-09-10 08:00:00', '2025-09-11 20:00:00', 'Tamamlandı'),
(22, 23, '2025-10-01 09:00:00', '2025-10-05 18:00:00', 'Tamamlandı'),
(23, 24, '2025-10-15 10:00:00', '2025-10-17 10:00:00', 'Tamamlandı'),
(24, 25, '2025-11-01 11:00:00', '2025-11-02 11:00:00', 'Tamamlandı'),
(25, 26, '2025-11-10 09:00:00', '2025-11-11 18:00:00', 'Tamamlandı'),
(26, 27, '2025-12-01 10:00:00', '2025-12-05 10:00:00', 'Tamamlandı'),
(27, 28, '2025-12-15 08:00:00', '2025-12-16 20:00:00', 'Tamamlandı'),
(28, 29, '2026-01-01 12:00:00', '2026-01-02 12:00:00', 'Tamamlandı'),
(29, 30, '2026-01-10 14:00:00', '2026-01-11 10:00:00', 'Tamamlandı'),
(30, 31, '2026-02-01 10:00:00', '2026-02-03 16:00:00', 'Tamamlandı'),
(31, 32, '2026-02-15 09:00:00', '2026-02-16 18:00:00', 'Tamamlandı'),
(32, 33, '2026-03-01 10:00:00', '2026-03-02 10:00:00', 'Tamamlandı'),
(33, 34, '2026-03-10 11:00:00', '2026-03-10 19:00:00', 'Tamamlandı'),
(34, 35, '2026-04-01 08:00:00', '2026-04-05 08:00:00', 'Tamamlandı'),
(35, 36, '2026-04-15 10:00:00', '2026-04-16 10:00:00', 'Tamamlandı'),
(36, 37, '2026-05-01 09:00:00', '2026-05-02 18:00:00', 'Tamamlandı'),
(37, 38, '2026-05-10 13:00:00', '2026-05-12 11:00:00', 'Tamamlandı'),
(38, 39, '2026-06-01 10:00:00', '2026-06-05 18:00:00', 'Tamamlandı'),
(39, 40, '2026-06-15 09:00:00', '2026-06-16 09:00:00', 'Tamamlandı'),
(40, 41, '2026-07-01 10:00:00', '2026-07-02 10:00:00', 'Tamamlandı'),
(41, 42, '2026-07-10 14:00:00', '2026-07-11 10:00:00', 'Tamamlandı'),
(42, 43, '2026-08-01 08:00:00', '2026-08-05 20:00:00', 'Tamamlandı'),
(43, 44, '2026-08-15 09:00:00', '2026-08-16 18:00:00', 'Tamamlandı'),
(44, 45, '2026-09-01 10:00:00', '2026-09-02 10:00:00', 'Tamamlandı'),
(45, 46, '2026-09-10 11:00:00', '2026-09-10 17:00:00', 'Tamamlandı'),
(46, 47, '2026-09-15 10:00:00', '2026-09-16 10:00:00', 'Tamamlandı'),
(47, 48, '2026-09-20 09:00:00', '2026-09-22 18:00:00', 'Tamamlandı'),
(48, 49, '2026-09-25 12:00:00', '2026-09-26 12:00:00', 'Tamamlandı'),
(49, 50, '2026-09-28 14:00:00', '2026-09-29 10:00:00', 'Tamamlandı'),
(50, 2,  '2026-09-30 10:00:00', '2026-10-01 10:00:00', 'Tamamlandı');

-- YORUMLAR (Puanlama Algoritmasını Test Etmek İçin)
INSERT INTO Reviews (loan_id, reviewer_type, user_rating, tool_rating, comment) VALUES
(5, 'Renter', 5, 5, 'İyi'), (5, 'Owner', 5, NULL, 'İyi'), (6, 'Renter', 4, 3, 'Eski'),
(7, 'Renter', 5, 5, 'Tam'), (7, 'Owner', 4, NULL, 'Geç'), (8, 'Renter', 1, 1, 'Bozuk'),
(8, 'Owner', 1, NULL, 'Bozdu'), (9, 'Renter', 5, 5, 'Harika'), (10, 'Renter', 4, 4, 'Memnun'),
(11, 'Renter', 5, 5, 'Tşk'), (12, 'Owner', 5, NULL, 'Güvenilir'), (13, 'Renter', 3, 3, 'İdare'),
(14, 'Renter', 5, 5, 'Süper'), (15, 'Renter', 5, 5, 'Temiz'), (16, 'Owner', 5, NULL, 'Bekleriz'),
(17, 'Renter', 4, 5, 'Kolay'), (18, 'Renter', 5, 5, 'PlayStation'), (19, 'Owner', 5, NULL, 'Temiz'),
(20, 'Renter', 5, 5, 'Davul'), (21, 'Renter', 2, 2, 'Kör'), (22, 'Renter', 5, 5, 'Bahçe'),
(23, 'Owner', 4, NULL, 'İletişim'), (24, 'Renter', 5, 5, 'Halı'), (25, 'Renter', 5, 5, 'Sorunsuz'),
(26, 'Renter', 4, 4, 'İşlevsel'), (27, 'Owner', 5, NULL, 'Tşk'), (28, 'Renter', 5, 5, 'Yardımcı'),
(29, 'Renter', 5, 5, 'Zımpara'), (30, 'Renter', 3, 3, 'Ağır'), (31, 'Owner', 5, NULL, 'Sorun yok'),
(32, 'Renter', 5, 5, 'Hortum'), (33, 'Renter', 5, 5, 'Mangal'), (34, 'Renter', 4, 4, 'Buhar'),
(35, 'Owner', 5, NULL, 'Zamanında'), (36, 'Renter', 5, 5, 'Ölçüm'), (37, 'Renter', 5, 5, 'Boya'),
(38, 'Renter', 5, 5, 'Bıçak'), (39, 'Owner', 3, NULL, 'Geç'), (40, 'Renter', 5, 5, 'Tamir'),
(41, 'Renter', 5, 5, 'Kablo'), (42, 'Renter', 5, 5, 'Blender'), (43, 'Owner', 5, NULL, 'Temiz'),
(44, 'Renter', 5, 5, 'Foto'), (45, 'Renter', 5, 5, 'Saz'), (46, 'Renter', 4, 4, 'Güçlü'),
(47, 'Renter', 5, 5, 'Kamp'), (48, 'Owner', 5, NULL, 'Sorunsuz'), (49, 'Renter', 5, 5, 'Cam'),
(50, 'Renter', 5, 5, 'Araba');

-- 8. SEQUENCE SENKRONİZASYONU (KRİTİK ADIM!)
-- [KURAL] Elle girilen test verilerinden sonra sayaçları güncellemek zorundayız.
-- Aksi takdirde yeni kayıt eklerken "Duplicate Key" hatası alınır.
-- ============================================================================
SELECT setval('seq_users_id', (SELECT MAX(user_id) FROM Users));
SELECT setval('seq_category_id', (SELECT MAX(category_id) FROM Categories));
SELECT setval('seq_tool_id', (SELECT MAX(tool_id) FROM Tools));
SELECT setval('seq_loan_id', (SELECT MAX(loan_id) FROM Loans));
SELECT setval('seq_review_id', (SELECT MAX(review_id) FROM Reviews));




--------------------------------------------------------------------
-- ÖRNEK KULLANIMLAR
-- 1. Admin yetkisiyle yeni bir kullanıcı ekleyelim (Ali)
-- Fonksiyon: sp_add_user
SELECT sp_add_user(1, 'ali_yilmaz', 'sifre123', 'Ali Yılmaz', 'user');

-- 2. Admin yetkisiyle bir kullanıcı daha ekleyelim (Veli - Aletsiz/Beleşçi)
SELECT sp_add_user(1, 'veli_beleci', '1234', 'Veli Beleşçi', 'user');

-- 3. Hatalı Giriş Denemesi (Yanlış Şifre)
-- Beklenen: "HATA: Giriş başarısız..." mesajı.
SELECT * FROM sp_login((SELECT user_id FROM Users WHERE username='ali_yilmaz'), 'yanlis_sifre', 'user');

-- 4. Başarılı Giriş Denemesi
-- Fonksiyon: sp_login
SELECT * FROM sp_login((SELECT user_id FROM Users WHERE username='ali_yilmaz'), 'sifre123', 'user');

-- 5. Yetki Yükseltme (Admin, Ali'yi Admin yapıyor)
-- Fonksiyon: sp_grant_admin_role
SELECT sp_grant_admin_role(1, (SELECT user_id FROM Users WHERE username='ali_yilmaz'));

-- Ali artık admin mi? Kontrol edelim.
SELECT username, role FROM Users WHERE username = 'ali_yilmaz';

-- 1. Ali sisteme yeni bir alet ekliyor (Güvenli Ekleme)
-- Fonksiyon: sp_secure_add_tool
SELECT sp_secure_add_tool(
    (SELECT user_id FROM Users WHERE username='ali_yilmaz'), -- İsteyen
    (SELECT user_id FROM Users WHERE username='ali_yilmaz'), -- Sahibi
    1, -- Kategori ID (Elektrikli Aletler)
    'Süper Matkap 3000', 
    'Hiç kullanılmamış kutusunda'
);

-- 2. Alet Arama ve Sıralama (İsimde 'at' geçenler, Alet puanına göre sıralı)
-- Fonksiyon: sp_search_and_sort_tools
SELECT * FROM sp_search_and_sort_tools('at', 3);

-- 3. Bakım Modu Testi (Toggle)
-- Fonksiyon: sp_toggle_maintenance
-- Ali aletini bakıma alıyor (Listeden kalkmalı)
SELECT sp_toggle_maintenance(
    (SELECT tool_id FROM Tools WHERE tool_name='Süper Matkap 3000')::INTEGER, 
    (SELECT user_id FROM Users WHERE username='ali_yilmaz')::INTEGER
);

-- Aletin durumu 'Bakımda' mı?
SELECT tool_name, status FROM Tools WHERE tool_name='Süper Matkap 3000';

-- Tekrar çalıştırıp Müsait yapalım
SELECT sp_toggle_maintenance(
    (SELECT tool_id FROM Tools WHERE tool_name='Süper Matkap 3000'), 
    (SELECT user_id FROM Users WHERE username='ali_yilmaz')
);

-- SENARYO: Veli (Hiç aleti yok) Ali'nin matkabını kiralamaya çalışıyor.
-- Fonksiyon: sp_rent_tool
-- Trigger: trg_check_contribution_rule
-- BEKLENEN SONUÇ: HATA! "İmece kuralı! Önce sisteme 1 alet ekle."

SELECT sp_rent_tool(
    (SELECT user_id FROM Users WHERE username='veli_beleci'), -- Kiracı Veli
    (SELECT tool_id FROM Tools WHERE tool_name='Süper Matkap 3000'), 
    '2026-05-01 10:00:00', 
    '2026-05-05 18:00:00'
);

-- ÇÖZÜM: Veli mecburen sisteme bir alet ekliyor (Kural işliyor).
SELECT sp_secure_add_tool(
    (SELECT user_id FROM Users WHERE username='veli_beleci'),
    (SELECT user_id FROM Users WHERE username='veli_beleci'),
    2, 'Eski Çekiç', 'İdare eder'
);

-- KENDİ ALETİNİ KİRALAMA TESTİ
-- Veli kendi çekicini kiralamaya çalışıyor.
-- BEKLENEN SONUÇ: HATA! "Etik Kural! Kendi aletini kiralayamazsın."
SELECT sp_rent_tool(
    (SELECT user_id FROM Users WHERE username='veli_beleci'),
    (SELECT tool_id FROM Tools WHERE tool_name='Eski Çekiç'),
    '2026-06-01 10:00:00', '2026-06-02 10:00:00'
);

-- 1. BAŞARILI KİRALAMA (Veli artık Ali'nin matkabını kiralayabilir)
-- Trigger: trg_auto_update_status (Alet 'Kirada' moduna geçmeli)
SELECT sp_rent_tool(
    (SELECT user_id FROM Users WHERE username='veli_beleci'),
    (SELECT tool_id FROM Tools WHERE tool_name='Süper Matkap 3000'),
    '2026-05-01 10:00:00', 
    '2026-05-05 18:00:00'
);

-- Kontrol: Aletin statüsü 'Kirada' oldu mu?
SELECT tool_name, status FROM Tools WHERE tool_name='Süper Matkap 3000';

-- 2. TARİH ÇAKIŞMASI TESTİ
-- Başka biri (User3) aynı tarihlerde aynı aleti kiralamaya çalışıyor.
-- Trigger: trg_check_date_overlap
-- BEKLENEN: HATA! "Tarihler çakışıyor!"
SELECT sp_rent_tool(3, (SELECT tool_id FROM Tools WHERE tool_name='Süper Matkap 3000'), '2026-05-02 10:00:00', '2026-05-03 10:00:00');

-- 3. GÜVENLİ SİLME TESTİ (Kiradaki Alet Silinemez)
-- Ali, Veli'de olan matkabı silmeye çalışıyor.
-- Trigger: trg_prevent_delete
-- BEKLENEN: HATA! "Alet kirada olduğu için silinemez."
SELECT sp_secure_delete_tool(
    (SELECT tool_id FROM Tools WHERE tool_name='Süper Matkap 3000'),
    (SELECT user_id FROM Users WHERE username='ali_yilmaz')
);

-- 1. ALETİ İADE ETME
-- Fonksiyon: sp_return_tool
-- Trigger: trg_auto_update_status (Alet tekrar 'Müsait' olmalı)
SELECT sp_return_tool(
    (SELECT user_id FROM Users WHERE username='veli_beleci'), -- Kiracı iade ediyor
    (SELECT loan_id FROM Loans WHERE tool_id = (SELECT tool_id FROM Tools WHERE tool_name='Süper Matkap 3000') AND loan_status='Aktif')
);

-- 2. YORUM YAPMA VE PUANLAMA (AIRBNB MODELİ)
-- Veli (Kiracı), Matkaba ve Ali'ye 5 puan veriyor.
-- Fonksiyon: sp_add_review
-- Trigger: trg_update_mutual_scores (Ali'nin ve Matkabın puanı artmalı)

SELECT sp_add_review(
    (SELECT loan_id FROM Loans WHERE tool_id = (SELECT tool_id FROM Tools WHERE tool_name='Süper Matkap 3000') LIMIT 1),
    'Renter', -- Yorumu yapan kiracı
    4,        -- User Rating (Ali'ye)
    5,        -- Tool Rating (Matkaba)
    'Mükemmel bir alet, Ali bey çok ilgiliydi.'
);

-- 3. PUAN KONTROLÜ
-- Ali'nin Security Score'u ve Matkabın Tool Score'u değişti mi?
SELECT full_name, security_score FROM Users WHERE username='ali_yilmaz';
SELECT tool_name, tool_score FROM Tools WHERE tool_name='Süper Matkap 3000';

-- 1. Ali'nin kiraladığı aletlerin geçmişi
SELECT * FROM sp_get_my_rentals((SELECT user_id FROM Users WHERE username='veli_beleci'));

-- 2. Matkaba yapılan yorumları görelim
SELECT * FROM sp_get_tool_reviews((SELECT tool_id FROM Tools WHERE tool_name='Süper Matkap 3000'));

-- 3. Cömert Komşular Analizi (En az 1 paylaşım yapanlar)
-- Fonksiyon: get_top_sharers
SELECT * FROM get_top_sharers(1, 1);

-- 4. Aylık Paylaşım Aktivitesi (2026 Mayıs ayı için toplam gün sayısı)
-- Fonksiyon: monthly_sharing_activity
SELECT monthly_sharing_activity(1, 5, 2026);