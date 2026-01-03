-- ============================================================================
-- PROJE ADI: TOOLSHARE (ADMIN-SECURE & IMECE EDITION - ULTIMATE v7.1)
-- NOT: UI Entegrasyonu için Helper Fonksiyonlar Eklendi.
-- ============================================================================

DROP SCHEMA public CASCADE;
CREATE SCHEMA public;

-- ============================================================================
-- 1. SEQUENCE (OTOMATİK SAYI ÜRETİCİLERİ)
-- ============================================================================
CREATE SEQUENCE seq_users_id START 1;
CREATE SEQUENCE seq_category_id START 1;
CREATE SEQUENCE seq_tool_id START 1;
CREATE SEQUENCE seq_loan_id START 1;
CREATE SEQUENCE seq_review_id START 1;

-- ============================================================================
-- 2. TABLO TASARIMLARI
-- ============================================================================

-- A. USERS
CREATE TABLE Users (
    user_id INTEGER DEFAULT nextval('seq_users_id') PRIMARY KEY,
    username VARCHAR(50) UNIQUE NOT NULL, 
    password VARCHAR(50) NOT NULL, 
    full_name VARCHAR(100) NOT NULL,
    role VARCHAR(20) DEFAULT 'user' CHECK (role IN ('admin', 'user')),
    security_score DECIMAL(3,2) DEFAULT 5.00
);

-- B. CATEGORIES
CREATE TABLE Categories (
    category_id INTEGER DEFAULT nextval('seq_category_id') PRIMARY KEY,
    category_name VARCHAR(50) NOT NULL
);

-- C. TOOLS
CREATE TABLE Tools (
    tool_id INTEGER DEFAULT nextval('seq_tool_id') PRIMARY KEY,
    owner_id INTEGER,
    category_id INTEGER,
    tool_name VARCHAR(100) NOT NULL,
    description TEXT,
    tool_score DECIMAL(3,2) DEFAULT 0.0,
    status VARCHAR(20) DEFAULT 'Müsait' CHECK (status IN ('Müsait', 'Kirada', 'Bakımda')),
    FOREIGN KEY (owner_id) REFERENCES Users(user_id) ON DELETE CASCADE,
    FOREIGN KEY (category_id) REFERENCES Categories(category_id)
);

-- D. LOANS
CREATE TABLE Loans (
    loan_id INTEGER DEFAULT nextval('seq_loan_id') PRIMARY KEY,
    tool_id INTEGER,
    renter_id INTEGER,
    start_date TIMESTAMP NOT NULL,
    end_date TIMESTAMP NOT NULL,
    loan_status VARCHAR(20) DEFAULT 'Aktif' CHECK (loan_status IN ('Aktif', 'Tamamlandı')),
    CHECK (end_date >= start_date), 
    FOREIGN KEY (tool_id) REFERENCES Tools(tool_id) ON DELETE CASCADE,
    FOREIGN KEY (renter_id) REFERENCES Users(user_id)
);

-- E. REVIEWS
CREATE TABLE Reviews (
    review_id INTEGER DEFAULT nextval('seq_review_id') PRIMARY KEY,
    loan_id INTEGER,
    reviewer_type VARCHAR(10) CHECK (reviewer_type IN ('Renter', 'Owner')),
    user_rating INTEGER CHECK (user_rating BETWEEN 1 AND 5),
    tool_rating INTEGER CHECK (tool_rating BETWEEN 1 AND 5), 
    comment TEXT,
    review_date DATE DEFAULT CURRENT_DATE,
    FOREIGN KEY (loan_id) REFERENCES Loans(loan_id) ON DELETE CASCADE,
    UNIQUE (loan_id, reviewer_type),
    CHECK ( (reviewer_type = 'Owner' AND tool_rating IS NULL) OR (reviewer_type = 'Renter') )
);

-- ============================================================================
-- 3. INDEX
-- ============================================================================
CREATE INDEX idx_tool_name ON Tools(tool_name);

-- ============================================================================
-- 4. VIEWS (GÖRÜNÜMLER)
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

-- View 2: Cömertler (Sadece Verenler)
CREATE OR REPLACE VIEW v_givers_not_takers AS
SELECT user_id, username, full_name 
FROM Users 
WHERE user_id IN (
    SELECT owner_id FROM Tools 
    EXCEPT 
    SELECT renter_id FROM Loans
);

-- ============================================================================
-- 5. FONKSİYONLAR (BUSINESS LOGIC & SECURITY)
-- ============================================================================

-- [FONKSİYON 1] GÜVENLİ LOGIN
CREATE OR REPLACE FUNCTION sp_login(
    p_user_id INTEGER,
    p_password VARCHAR, 
    p_interface_type VARCHAR
) 
RETURNS TABLE(user_id INTEGER, role VARCHAR, full_name VARCHAR) AS $$
DECLARE v_real_role VARCHAR;
BEGIN
    SELECT u.role INTO v_real_role 
    FROM Users u 
    WHERE u.user_id = p_user_id AND u.password = p_password;
    
    IF NOT FOUND THEN 
        RAISE EXCEPTION 'HATA: Giriş başarısız! Kullanıcı ID veya şifre yanlış.'; 
    END IF;
    
    IF v_real_role != p_interface_type THEN 
        RAISE EXCEPTION 'ERİŞİM REDDEDİLDİ: % rolü ile % paneline girilemez!', v_real_role, p_interface_type; 
    END IF;
    
    RETURN QUERY SELECT u.user_id, u.role, u.full_name FROM Users u WHERE u.user_id = p_user_id;
END;
$$ LANGUAGE plpgsql;

-- [FONKSİYON 2] ADMIN YETKİSİ VERME
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
    IF (p_requester_id != p_owner_id) AND (v_requester_role != 'admin') THEN 
        RAISE EXCEPTION 'YETKİSİZ İŞLEM!'; 
    END IF;
    INSERT INTO Tools (owner_id, category_id, tool_name, description, status) VALUES (p_owner_id, p_category_id, p_tool_name, p_description, 'Müsait');
END;
$$ LANGUAGE plpgsql;

-- [FONKSİYON 6] GÜVENLİ KULLANICI EKLEME
CREATE OR REPLACE FUNCTION sp_add_user(
    p_requester_id INTEGER,
    p_username VARCHAR,
    p_password VARCHAR,
    p_full_name VARCHAR,
    p_role VARCHAR DEFAULT 'user'
) RETURNS VOID AS $$
DECLARE v_requester_role VARCHAR;
BEGIN
    SELECT role INTO v_requester_role FROM Users WHERE user_id = p_requester_id;
    IF v_requester_role != 'admin' THEN
        RAISE EXCEPTION 'YETKİSİZ İŞLEM: Sadece adminler yeni kullanıcı oluşturabilir!';
    END IF;
    INSERT INTO Users (username, password, full_name, role) VALUES (p_username, p_password, p_full_name, p_role);
END;
$$ LANGUAGE plpgsql;

-- [FONKSİYON 7] GELİŞMİŞ ARAMA VE SIRALAMA
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

-- [FONKSİYON 8] AYLIK PAYLAŞIM RAPORU
CREATE OR REPLACE FUNCTION monthly_sharing_activity(p_requester_id INTEGER, p_month INTEGER, p_year INTEGER) RETURNS INTEGER AS $$
DECLARE total_days INTEGER := 0; r_loan RECORD; v_days INTEGER; v_requester_role VARCHAR;
BEGIN
    SELECT role INTO v_requester_role FROM Users WHERE user_id = p_requester_id;
    IF v_requester_role != 'admin' THEN RAISE EXCEPTION 'YETKİSİZ İŞLEM!'; END IF;

    FOR r_loan IN SELECT start_date, end_date FROM Loans WHERE EXTRACT(MONTH FROM start_date) = p_month AND EXTRACT(YEAR FROM start_date) = p_year LOOP
        v_days := CEIL(EXTRACT(EPOCH FROM (r_loan.end_date - r_loan.start_date)) / 86400); 
        IF v_days < 1 THEN v_days := 1; END IF; total_days := total_days + v_days;
    END LOOP; RETURN total_days;
END;
$$ LANGUAGE plpgsql;

-- [FONKSİYON 9] CÖMERT KOMŞULAR ANALİZİ
CREATE OR REPLACE FUNCTION get_top_sharers(p_requester_id INTEGER, min_shares INTEGER)
RETURNS TABLE(neighbor_name VARCHAR, share_count BIGINT) AS $$
DECLARE v_requester_role VARCHAR;
BEGIN
    SELECT role INTO v_requester_role FROM Users WHERE user_id = p_requester_id;
    IF v_requester_role != 'admin' THEN RAISE EXCEPTION 'YETKİSİZ İŞLEM!'; END IF;

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

-- [10] KİRALAMA YAPMA
CREATE OR REPLACE FUNCTION sp_rent_tool(p_renter_id INTEGER, p_tool_id INTEGER, p_start_date TIMESTAMP, p_end_date TIMESTAMP) RETURNS TEXT AS $$
BEGIN
    INSERT INTO Loans (tool_id, renter_id, start_date, end_date, loan_status) VALUES (p_tool_id, p_renter_id, p_start_date, p_end_date, 'Aktif');
    RETURN 'Başarılı: Kiralama tamamlandı.';
EXCEPTION WHEN OTHERS THEN RETURN 'HATA: ' || SQLERRM;
END;
$$ LANGUAGE plpgsql;

-- [11] KİRALAMA BİTİRME
CREATE OR REPLACE FUNCTION sp_return_tool(p_requester_id INTEGER, p_loan_id INTEGER) RETURNS TEXT AS $$
DECLARE v_renter_id INTEGER; v_owner_id INTEGER; v_role VARCHAR;
BEGIN
    SELECT l.renter_id, t.owner_id INTO v_renter_id, v_owner_id 
    FROM Loans l JOIN Tools t ON l.tool_id = t.tool_id WHERE l.loan_id = p_loan_id;
    SELECT role INTO v_role FROM Users WHERE user_id = p_requester_id;
    
    IF (p_requester_id != v_renter_id) AND (p_requester_id != v_owner_id) AND (v_role != 'admin') THEN 
        RETURN 'HATA: Bu işlemi yapmaya yetkiniz yok.'; 
    END IF;

    UPDATE Loans SET loan_status = 'Tamamlandı' WHERE loan_id = p_loan_id;
    RETURN 'Başarılı: Alet iade edildi.';
END;
$$ LANGUAGE plpgsql;

-- [12] YORUM YAPMA
CREATE OR REPLACE FUNCTION sp_add_review(p_loan_id INTEGER, p_reviewer_type VARCHAR, p_user_rating INTEGER, p_tool_rating INTEGER, p_comment TEXT) RETURNS TEXT AS $$
BEGIN
    INSERT INTO Reviews (loan_id, reviewer_type, user_rating, tool_rating, comment)
    VALUES (p_loan_id, p_reviewer_type, p_user_rating, p_tool_rating, p_comment);
    RETURN 'Başarılı: Yorum kaydedildi.';
EXCEPTION WHEN OTHERS THEN RETURN 'HATA: ' || SQLERRM;
END;
$$ LANGUAGE plpgsql;

-- [13] KİRALADIKLARIMI GETİR
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

-- [14] BENİM ALETİMİ KİRALAYANLARI GETİR
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

-- [15] ALET YORUMLARINI GETİR
CREATE OR REPLACE FUNCTION sp_get_tool_reviews(p_tool_id INTEGER)
RETURNS TABLE(reviewer_name VARCHAR, rating INTEGER, comment TEXT, r_date DATE) AS $$
BEGIN
    RETURN QUERY
    SELECT u.full_name, r.tool_rating, r.comment, r.review_date
    FROM Reviews r
    JOIN Loans l ON r.loan_id = l.loan_id
    JOIN Users u ON l.renter_id = u.user_id 
    WHERE l.tool_id = p_tool_id AND r.reviewer_type = 'Renter';
END;
$$ LANGUAGE plpgsql;

-- [16] BAKIM MODU TOGGLE
CREATE OR REPLACE FUNCTION sp_toggle_maintenance(p_tool_id INTEGER, p_owner_id INTEGER) RETURNS TEXT AS $$
DECLARE v_current_status VARCHAR; v_real_owner INTEGER;
BEGIN
    SELECT status, owner_id INTO v_current_status, v_real_owner FROM Tools WHERE tool_id = p_tool_id;
    IF v_real_owner != p_owner_id THEN RAISE EXCEPTION 'HATA: Bu işlem için yetkiniz yok!'; END IF;
    IF v_current_status = 'Kirada' THEN RAISE EXCEPTION 'HATA: Alet şu an kirada, bakıma alınamaz!';
    ELSIF v_current_status = 'Müsait' THEN UPDATE Tools SET status = 'Bakımda' WHERE tool_id = p_tool_id; RETURN 'Bilgi: Alet bakıma alındı.';
    ELSIF v_current_status = 'Bakımda' THEN UPDATE Tools SET status = 'Müsait' WHERE tool_id = p_tool_id; RETURN 'Bilgi: Alet bakımdan çıktı.';
    END IF; RETURN 'İşlem başarısız.';
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- [YENİ EKLENEN UI HELPER FONKSİYONLAR]
-- callproc ile uyumluluk için eklendi.
-- ============================================================================

-- [17] KULLANICI ID BULUCU (Login İçin)
CREATE OR REPLACE FUNCTION sp_get_id_by_username(p_username VARCHAR)
RETURNS INTEGER AS $$
DECLARE v_id INTEGER;
BEGIN
    SELECT user_id INTO v_id FROM Users WHERE username = p_username;
    RETURN v_id; 
END;
$$ LANGUAGE plpgsql;

-- [18] KULLANICININ ALETLERİNİ GETİR (Yönetim Ekranı İçin)
CREATE OR REPLACE FUNCTION sp_get_user_tools(p_user_id INTEGER)
RETURNS TABLE(tool_id INTEGER, tool_name VARCHAR, category_name VARCHAR, status VARCHAR, tool_score DECIMAL, description TEXT) AS $$
BEGIN
    RETURN QUERY
    SELECT t.tool_id, t.tool_name, c.category_name, t.status, t.tool_score, t.description
    FROM Tools t
    JOIN Categories c ON t.category_id = c.category_id
    WHERE t.owner_id = p_user_id
    ORDER BY t.tool_id DESC;
END;
$$ LANGUAGE plpgsql;

-- [19] KATEGORİLERİ GETİR (Combobox İçin)
CREATE OR REPLACE FUNCTION sp_get_categories()
RETURNS TABLE(category_id INTEGER, category_name VARCHAR) AS $$
BEGIN
    RETURN QUERY SELECT * FROM Categories ORDER BY category_id ASC;
END;
$$ LANGUAGE plpgsql;

-- [20] ALET AÇIKLAMASINI GÜNCELLE
CREATE OR REPLACE FUNCTION sp_update_tool_description(p_tool_id INTEGER, p_owner_id INTEGER, p_new_desc TEXT)
RETURNS TEXT AS $$
DECLARE v_real_owner INTEGER;
BEGIN
    SELECT owner_id INTO v_real_owner FROM Tools WHERE tool_id = p_tool_id;
    IF v_real_owner != p_owner_id THEN RETURN 'HATA: Bu aleti düzenleme yetkiniz yok.'; END IF;
    UPDATE Tools SET description = p_new_desc WHERE tool_id = p_tool_id;
    RETURN 'Başarılı: Açıklama güncellendi.';
END;
$$ LANGUAGE plpgsql;

--[21] TÜM KULLANICILARI LİSTELE
CREATE OR REPLACE FUNCTION sp_get_all_users()
RETURNS TABLE(user_id INTEGER, username VARCHAR, full_name VARCHAR, role VARCHAR, security_score DECIMAL) AS $$
BEGIN
    RETURN QUERY SELECT u.user_id, u.username, u.full_name, u.role, u.security_score FROM Users u ORDER BY u.user_id ASC;
END;
$$ LANGUAGE plpgsql;

-- [22] GLOBAL ALET LİSTESİ (ADMIN İÇİN)
-- Tüm aletleri durum fark etmeksizin (Kirada, Bakımda, Müsait) getirir.
CREATE OR REPLACE FUNCTION sp_get_all_tools_global()
RETURNS TABLE(tool_id INTEGER, tool_name VARCHAR, category_name VARCHAR, owner_name VARCHAR, status VARCHAR, tool_score DECIMAL, owner_score DECIMAL, description TEXT) AS $$
BEGIN
    RETURN QUERY 
    SELECT 
        t.tool_id, t.tool_name, c.category_name, u.full_name AS owner_name, 
        t.status, t.tool_score, u.security_score AS owner_score, t.description
    FROM Tools t
    JOIN Users u ON t.owner_id = u.user_id
    JOIN Categories c ON t.category_id = c.category_id
    ORDER BY t.tool_id ASC;
END;
$$ LANGUAGE plpgsql;

-- [23] GLOBAL KİRALAMA LİSTESİ (ADMIN İÇİN)
-- Tüm kiralama işlemlerini (Aktif/Tamamlandı) getirir.
CREATE OR REPLACE FUNCTION sp_get_all_loans_global()
RETURNS TABLE(loan_id INTEGER, tool_name VARCHAR, renter_name VARCHAR, owner_name VARCHAR, start_d TIMESTAMP, end_d TIMESTAMP, stat VARCHAR) AS $$
BEGIN
    RETURN QUERY 
    SELECT 
        l.loan_id, t.tool_name, 
        u_renter.full_name AS renter_name, 
        u_owner.full_name AS owner_name, 
        l.start_date, l.end_date, l.loan_status
    FROM Loans l
    JOIN Tools t ON l.tool_id = t.tool_id
    JOIN Users u_renter ON l.renter_id = u_renter.user_id
    JOIN Users u_owner ON t.owner_id = u_owner.user_id
    ORDER BY l.start_date DESC;
END;
$$ LANGUAGE plpgsql;
-- ============================================================================
-- 6. TRIGGERLAR
-- ============================================================================
CREATE OR REPLACE FUNCTION fn_update_mutual_scores() RETURNS TRIGGER AS $$
DECLARE v_tool_id INTEGER; v_owner_id INTEGER; v_renter_id INTEGER; v_new_score DECIMAL(3,2);
BEGIN
    SELECT t.tool_id, t.owner_id, l.renter_id INTO v_tool_id, v_owner_id, v_renter_id FROM Loans l JOIN Tools t ON l.tool_id = t.tool_id WHERE l.loan_id = NEW.loan_id;
    IF NEW.reviewer_type = 'Renter' THEN
        SELECT AVG(tool_rating) INTO v_new_score FROM Reviews WHERE loan_id IN (SELECT loan_id FROM Loans WHERE tool_id = v_tool_id) AND reviewer_type = 'Renter';
        UPDATE Tools SET tool_score = COALESCE(v_new_score, 0) WHERE tool_id = v_tool_id;
        SELECT AVG(r.user_rating) INTO v_new_score FROM Reviews r JOIN Loans l ON r.loan_id = l.loan_id JOIN Tools t ON l.tool_id = t.tool_id WHERE t.owner_id = v_owner_id AND r.reviewer_type = 'Renter';
        UPDATE Users SET security_score = COALESCE(v_new_score, 0) WHERE user_id = v_owner_id;
    ELSIF NEW.reviewer_type = 'Owner' THEN
        SELECT AVG(r.user_rating) INTO v_new_score FROM Reviews r JOIN Loans l ON r.loan_id = l.loan_id WHERE l.renter_id = v_renter_id AND r.reviewer_type = 'Owner';
        UPDATE Users SET security_score = COALESCE(v_new_score, 0) WHERE user_id = v_renter_id;
    END IF; RETURN NEW;
END;
$$ LANGUAGE plpgsql;
CREATE TRIGGER trg_update_mutual_scores AFTER INSERT ON Reviews FOR EACH ROW EXECUTE FUNCTION fn_update_mutual_scores();

CREATE OR REPLACE FUNCTION fn_check_contribution() RETURNS TRIGGER AS $$
DECLARE my_tool_count INTEGER; v_owner_id INTEGER;
BEGIN
    SELECT owner_id INTO v_owner_id FROM Tools WHERE tool_id = NEW.tool_id;
    IF v_owner_id = NEW.renter_id THEN RAISE EXCEPTION 'HATA: Etik Kural! Kendi aletini kiralayamazsın.'; END IF;
    SELECT COUNT(*) INTO my_tool_count FROM Tools WHERE owner_id = NEW.renter_id;
    IF my_tool_count = 0 THEN RAISE EXCEPTION 'HATA: İmece kuralı! Önce sisteme 1 alet ekle.'; END IF; RETURN NEW;
END;
$$ LANGUAGE plpgsql;
CREATE TRIGGER trg_check_contribution_rule BEFORE INSERT ON Loans FOR EACH ROW EXECUTE FUNCTION fn_check_contribution();

CREATE OR REPLACE FUNCTION fn_check_date_overlap() RETURNS TRIGGER AS $$
BEGIN
    IF NEW.loan_status = 'Aktif' AND NEW.start_date < CURRENT_TIMESTAMP THEN RAISE EXCEPTION 'HATA: Geçmişe rezervasyon yapılamaz!'; END IF;
    IF EXISTS (SELECT 1 FROM Loans WHERE tool_id = NEW.tool_id AND loan_id != NEW.loan_id AND loan_status = 'Aktif' AND (NEW.start_date < end_date AND NEW.end_date > start_date)) THEN RAISE EXCEPTION 'HATA: Tarihler çakışıyor! Bu aralıkta alet dolu.'; END IF; RETURN NEW;
END;
$$ LANGUAGE plpgsql;
CREATE TRIGGER trg_check_date_overlap BEFORE INSERT OR UPDATE ON Loans FOR EACH ROW EXECUTE FUNCTION fn_check_date_overlap();

CREATE OR REPLACE FUNCTION fn_auto_update_status() RETURNS TRIGGER AS $$
BEGIN
    IF (TG_OP = 'INSERT' AND NEW.loan_status = 'Aktif') THEN UPDATE Tools SET status = 'Kirada' WHERE tool_id = NEW.tool_id;
    ELSIF (TG_OP = 'UPDATE' AND NEW.loan_status = 'Tamamlandı') THEN UPDATE Tools SET status = 'Müsait' WHERE tool_id = NEW.tool_id; END IF; RETURN NEW;
END;
$$ LANGUAGE plpgsql;
CREATE TRIGGER trg_auto_update_status AFTER INSERT OR UPDATE ON Loans FOR EACH ROW EXECUTE FUNCTION fn_auto_update_status();

CREATE OR REPLACE FUNCTION fn_check_review_timing() RETURNS TRIGGER AS $$
DECLARE v_end_date TIMESTAMP; v_status VARCHAR;
BEGIN
    SELECT end_date, loan_status INTO v_end_date, v_status FROM Loans WHERE loan_id = NEW.loan_id;
    IF v_status = 'Aktif' AND CURRENT_TIMESTAMP < v_end_date THEN RAISE EXCEPTION 'HATA: Kiralama bitmeden yorum yapılamaz!'; END IF; RETURN NEW;
END;
$$ LANGUAGE plpgsql;
CREATE TRIGGER trg_check_review_timing BEFORE INSERT ON Reviews FOR EACH ROW EXECUTE FUNCTION fn_check_review_timing();

CREATE OR REPLACE FUNCTION fn_prevent_delete_rented() RETURNS TRIGGER AS $$
BEGIN
    IF OLD.status = 'Kirada' THEN RAISE EXCEPTION 'HATA: Alet kirada olduğu için silinemez.'; END IF; RETURN OLD;
END;
$$ LANGUAGE plpgsql;
CREATE TRIGGER trg_prevent_delete BEFORE DELETE ON Tools FOR EACH ROW EXECUTE FUNCTION fn_prevent_delete_rented();

-- ============================================================================
-- 7. TEST VERİLERİ (SEED DATA)
-- ============================================================================
INSERT INTO Users (username, password, full_name, role) VALUES
('admin', 'admin123', 'System Administrator', 'admin'),
('user1', '1234', 'Ahmet Yılmaz', 'user'),  ('user2', '1234', 'Ayşe Demir', 'user'),
('user3', '1234', 'Mehmet Kaya', 'user'),   ('user4', '1234', 'Fatma Çelik', 'user'),
('user50', '1234', 'Veli Beleşçi', 'user');

INSERT INTO Categories (category_name) VALUES 
('Elektrikli Aletler'), ('Bahçe'), ('Kamp'), ('Temizlik'), ('Otomotiv'), 
('Ölçüm Cihazları'), ('Boya & Badana'), ('Hobi'), ('Marangozluk'), ('Tesisat');

INSERT INTO Tools (owner_id, category_id, tool_name, description, status) VALUES
(2, 1, 'Darbeli Matkap Bosch', 'Profesyonel', 'Müsait'), (2, 4, 'Basınçlı Yıkama', 'Araba için', 'Müsait'),
(3, 2, 'Çim Biçme Makinesi', 'Benzinli', 'Müsait'), (4, 3, 'Kamp Çadırı (4 Kişilik)', 'Su geçirmez', 'Müsait');

INSERT INTO Loans (tool_id, renter_id, start_date, end_date, loan_status) VALUES
(1, 4, '2026-10-01 10:00:00', '2026-10-05 18:00:00', 'Aktif');

-- SEQUENCE SENKRONİZASYONU
SELECT setval('seq_users_id', (SELECT MAX(user_id) FROM Users));
SELECT setval('seq_category_id', (SELECT MAX(category_id) FROM Categories));
SELECT setval('seq_tool_id', (SELECT MAX(tool_id) FROM Tools));
SELECT setval('seq_loan_id', (SELECT MAX(loan_id) FROM Loans));
SELECT setval('seq_review_id', (SELECT MAX(review_id) FROM Reviews));