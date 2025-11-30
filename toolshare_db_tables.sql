--DROP SEQUENCE IF EXISTS seq_users_id;
CREATE SEQUENCE seq_users_id START 1 INCREMENT 1;
--DROP TABLE IF EXISTS Users CASCADE;
CREATE TABLE Users (
    user_id INTEGER DEFAULT nextval('seq_users_id') PRIMARY KEY,
    username VARCHAR(50) UNIQUE NOT NULL, 
    sifre VARCHAR(50) NOT NULL,
    ad_soyad VARCHAR(100) NOT NULL,
    rol VARCHAR(20) DEFAULT 'user',
    guvenlik_puani DECIMAL(3,2) DEFAULT 5.00
);

--DROP SEQUENCE IF EXISTS seq_category_id;
--DROP TABLE IF EXISTS Categories CASCADE;
CREATE SEQUENCE seq_category_id START 1 INCREMENT 1;
CREATE TABLE Categories (
    category_id INTEGER DEFAULT nextval('seq_category_id') PRIMARY KEY,
    kategori_adi VARCHAR(50) NOT NULL
);
--DROP SEQUENCE IF EXISTS seq_tool_id;
--DROP TABLE IF EXISTS Tools CASCADE;
CREATE SEQUENCE seq_tool_id START 1 INCREMENT 1;
CREATE TABLE Tools (
    tool_id INTEGER DEFAULT nextval('seq_tool_id') PRIMARY KEY,
    owner_id INTEGER,
    category_id INTEGER,
    baslik VARCHAR(100) NOT NULL,
    aciklama TEXT,
    durum VARCHAR(20) DEFAULT 'Müsait', -- 'Müsait', 'Kirada'
    
    FOREIGN KEY (owner_id) REFERENCES Users(user_id) ON DELETE CASCADE,
    FOREIGN KEY (category_id) REFERENCES Categories(category_id)
);

-- ÖDÜNÇ ALMA
--DROP SEQUENCE IF EXISTS seq_loan_id;
--DROP TABLE IF EXISTS Loans CASCADE;
CREATE SEQUENCE seq_loan_id START 1 INCREMENT 1;
CREATE TABLE Loans (
    loan_id INTEGER DEFAULT nextval('seq_loan_id') PRIMARY KEY,
    tool_id INTEGER,
    renter_id INTEGER,
    baslangic_tar DATE NOT NULL,
    bitis_tar DATE NOT NULL,
    durum VARCHAR(20) DEFAULT 'Aktif', -- 'Aktif', 'Tamamlandı'
    
    CHECK (bitis_tar >= baslangic_tar),
    FOREIGN KEY (tool_id) REFERENCES Tools(tool_id),
    FOREIGN KEY (renter_id) REFERENCES Users(user_id)
);

-- DEĞERLENDİRMELER
--DROP SEQUENCE IF EXISTS seq_review_id;
--DROP TABLE IF EXISTS Reviews CASCADE;
CREATE SEQUENCE seq_review_id START 1 INCREMENT 1;
CREATE TABLE Reviews (
    review_id INTEGER DEFAULT nextval('seq_review_id') PRIMARY KEY,
    loan_id INTEGER,
    puan INTEGER CHECK (puan >= 1 AND puan <= 5),
    yorum TEXT,
    tarih DATE DEFAULT CURRENT_DATE,
    
    FOREIGN KEY (loan_id) REFERENCES Loans(loan_id) ON DELETE CASCADE
);
