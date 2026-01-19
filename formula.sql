DROP DATABASE IF EXISTS formula;
CREATE DATABASE IF NOT EXISTS formula;

USE formula;


CREATE TABLE tim (
    id INT AUTO_INCREMENT PRIMARY KEY,
    naziv VARCHAR(100) NOT NULL UNIQUE,
    vlasnik VARCHAR(100) NOT NULL,
    baza VARCHAR(100) NOT NULL,
	drzava VARCHAR(50) NOT NULL,
    budzet DECIMAL(15,2) NOT NULL CHECK (budzet >= 0)
);


CREATE TABLE bolid (
    id INT AUTO_INCREMENT PRIMARY KEY,
    id_tim INT NOT NULL,
    model VARCHAR(100) NOT NULL,
    godina INT NOT NULL,
    motor VARCHAR(100) NOT NULL,
    sasija VARCHAR(100) NOT NULL,
    stanje VARCHAR(30) DEFAULT 'Ispravan',
    CONSTRAINT chk_stanje CHECK (stanje IN ('Ispravan', 'Neispravan', 'Na servisu', 'Otpisan')),
    FOREIGN KEY (id_tim) REFERENCES tim(id)
        ON DELETE CASCADE
        ON UPDATE CASCADE
);


CREATE TABLE vozac (
    id INT AUTO_INCREMENT PRIMARY KEY,
    id_tim INT NOT NULL,
    sifra CHAR(5) NOT NULL UNIQUE,
    ime VARCHAR(100) NOT NULL,
    prezime VARCHAR(100) NOT NULL,
    broj INT NOT NULL,
    drzava VARCHAR(100) NOT NULL,
    datum_rodjenja DATE NOT NULL,
    slika LONGBLOB,
    FOREIGN KEY (id_tim) REFERENCES tim(id)
        ON DELETE CASCADE
        ON UPDATE CASCADE,
    CONSTRAINT uniq_broj_tim UNIQUE(id_tim, broj),
    CONSTRAINT uniq_sifra_prezime UNIQUE (sifra, prezime)
);

CREATE TABLE sezona ( #specifično 2025
	id INT AUTO_INCREMENT PRIMARY KEY,
    godina INT NOT NULL,
	datum_pocetka DATE,
	datum_zavrsetka DATE,
    CONSTRAINT chk_datumi CHECK (datum_pocetka <= datum_zavrsetka)
 );
 
CREATE TABLE vozac_bolid (
	id INT AUTO_INCREMENT PRIMARY KEY,
	id_bolid INT NOT NULL,
    id_vozac INT NOT NULL,
    id_sezona INT NOT NULL,
	FOREIGN KEY (id_bolid) REFERENCES bolid(id)
        ON DELETE CASCADE
        ON UPDATE CASCADE,
	FOREIGN KEY (id_vozac) REFERENCES vozac(id)
        ON DELETE CASCADE
        ON UPDATE CASCADE,
	FOREIGN KEY (id_sezona) REFERENCES sezona(id)
        ON DELETE CASCADE
        ON UPDATE CASCADE
);
CREATE TABLE staza (
    id INT AUTO_INCREMENT PRIMARY KEY,
    naziv VARCHAR(100) NOT NULL UNIQUE,
    lokacija VARCHAR(100) NOT NULL,
    drzava VARCHAR(100) NOT NULL,
    duljina_km DECIMAL(5,2) NOT NULL,
    broj_krugova INT NOT NULL,
    CONSTRAINT chk_broj_krugova CHECK (broj_krugova > 0)
);




CREATE TABLE utrka (
    id INT AUTO_INCREMENT PRIMARY KEY,
    naziv VARCHAR(100) NOT NULL,
    id_staza INT NOT NULL, #gdje
    id_sezona INT NOT NULL, #ime natjecanja
    datum DATE NOT NULL,
    status ENUM('Najavljena','Traje','Zavrsena') DEFAULT 'Najavljena',
    FOREIGN KEY (id_staza) REFERENCES staza(id)
        ON DELETE CASCADE
        ON UPDATE CASCADE,
	FOREIGN KEY (id_sezona) REFERENCES sezona(id)
        ON DELETE CASCADE
        ON UPDATE CASCADE
	
);
CREATE TABLE sudjelovanje (
    id INT AUTO_INCREMENT PRIMARY KEY,
    id_utrka INT NOT NULL,
    id_vozac_bolid INT,
    FOREIGN KEY (id_utrka) REFERENCES utrka(id)
        ON DELETE CASCADE
        ON UPDATE CASCADE,
	FOREIGN KEY (id_vozac_bolid) REFERENCES vozac_bolid(id)
		ON DELETE CASCADE
        ON UPDATE CASCADE,
    CONSTRAINT uniq_utrka_vozac_bolid UNIQUE(id_utrka, id_vozac_bolid)
);


CREATE TABLE rezultat (
    id INT AUTO_INCREMENT PRIMARY KEY,
    id_utrka INT NOT NULL, #koja utrka
	id_vozac_bolid INT NOT NULL, #tko je pobijedio
    vrijeme TIME,
    bodovi INT,
    CONSTRAINT chk_bodovi CHECK (bodovi >= 0),
    FOREIGN KEY (id_utrka) REFERENCES utrka(id)
        ON DELETE CASCADE
        ON UPDATE CASCADE,
	FOREIGN KEY (id_vozac_bolid) REFERENCES vozac_bolid(id)
		ON DELETE CASCADE
        ON UPDATE CASCADE
);



CREATE TABLE strategija (
    id INT AUTO_INCREMENT PRIMARY KEY,
    id_sudjelovanje INT NOT NULL,
    broj_ulazaka_boks INT NOT NULL,
    tipovi_guma VARCHAR(100) NOT NULL,
    CONSTRAINT chk_ulasci_boks CHECK (broj_ulazaka_boks >= 0),
    FOREIGN KEY (id_sudjelovanje) REFERENCES sudjelovanje(id)
        ON DELETE CASCADE
        ON UPDATE CASCADE
);



CREATE TABLE kazna (
    id INT AUTO_INCREMENT PRIMARY KEY,
    id_sudjelovanje INT NOT NULL,
    opis TEXT NOT NULL,
    tip_kazne VARCHAR(30) NOT NULL,
    sekunde DECIMAL(4,1) NOT NULL,
    CONSTRAINT chk_sek CHECK (sekunde >= 0),
    CONSTRAINT chk_tip_kazne CHECK (tip_kazne in ('Time penalty', 'Drive-through penalty',
    'Stop-and-go penalty', 'Time added after race','Grid penalty',
    'Black flag', 'Disqualification', 'Warning', 'Penalty points' )),
    FOREIGN KEY (id_sudjelovanje) REFERENCES sudjelovanje(id)
        ON DELETE CASCADE
        ON UPDATE CASCADE
);

CREATE TABLE poredak (
	id INT AUTO_INCREMENT PRIMARY KEY,
	id_vozac INT NOT NULL,
    id_sezona INT NOT NULL,
    id_kazna INT,
	mjesto INT NOT NULL ,
    bodovi INT NOT NULL DEFAULT 0,
    pobjede INT NOT NULL DEFAULT 0,
    postolja INT DEFAULT 0,
    CONSTRAINT chk_mjesto CHECK (mjesto > 0),
    FOREIGN KEY (id_vozac) REFERENCES vozac(id)
        ON DELETE CASCADE
        ON UPDATE CASCADE,
	FOREIGN KEY (id_sezona) REFERENCES sezona(id)
        ON DELETE CASCADE
        ON UPDATE CASCADE,
	FOREIGN KEY (id_kazna) REFERENCES kazna(id)
        ON DELETE CASCADE
        ON UPDATE CASCADE
);

CREATE OR REPLACE VIEW view_poredak_sezone AS
SELECT
    vb.id_vozac,
    u.id_sezona,
    SUM(r.bodovi) AS bodovi,
    SUM(CASE WHEN r.bodovi = 25 THEN 1 ELSE 0 END) AS pobjede,
    SUM(CASE WHEN r.bodovi >= 15 THEN 1 ELSE 0 END) AS postolja,
    DENSE_RANK() OVER (
        PARTITION BY u.id_sezona
        ORDER BY SUM(r.bodovi) DESC
    ) AS mjesto
FROM vozac_bolid vb
JOIN rezultat r ON r.id_vozac_bolid = vb.id
JOIN utrka u ON u.id = r.id_utrka
GROUP BY vb.id_vozac, u.id_sezona;

CREATE TABLE sponzor (
    id INT AUTO_INCREMENT PRIMARY KEY,
    naziv VARCHAR(100) NOT NULL,
    drzava VARCHAR(50) NOT NULL,
    tip VARCHAR(100)
);



CREATE TABLE ugovor (
	id INT AUTO_INCREMENT PRIMARY KEY,
    id_tim INT NOT NULL,
    id_sponzor INT NOT NULL,
    godina_od YEAR NOT NULL,
    godina_do YEAR,
    vrijednost DECIMAL(15,2),
    CONSTRAINT chk_vrijendost  CHECK (vrijednost >= 0),
    FOREIGN KEY (id_tim) REFERENCES tim(id)
        ON DELETE CASCADE
        ON UPDATE CASCADE,
    FOREIGN KEY (id_sponzor) REFERENCES sponzor(id)
        ON DELETE CASCADE
        ON UPDATE CASCADE
);



CREATE TABLE osoblje (
    id INT AUTO_INCREMENT PRIMARY KEY,
    id_tim INT NOT NULL,
    ime VARCHAR(100)NOT NULL,
    prezime VARCHAR(100) NOT NULL,
    uloga VARCHAR(100) NOT NULL,
    FOREIGN KEY (id_tim) REFERENCES tim(id)
        ON DELETE CASCADE
        ON UPDATE CASCADE
);


CREATE TABLE zaduzenje (
    id INT AUTO_INCREMENT PRIMARY KEY,
    id_osoblje INT NOT NULL,
    id_utrka INT NOT NULL,
    opis TEXT,
    FOREIGN KEY (id_osoblje) REFERENCES osoblje(id)
        ON DELETE CASCADE
        ON UPDATE CASCADE,
    FOREIGN KEY (id_utrka) REFERENCES utrka(id)
        ON DELETE CASCADE
        ON UPDATE CASCADE
);



CREATE TABLE trosak_tima (
    id INT AUTO_INCREMENT PRIMARY KEY,
    id_tim INT NOT NULL,
    id_sezona INT NOT NULL,
    kategorija VARCHAR(100),
    iznos DECIMAL(15,2),
    CONSTRAINT chk_iznos CHECK (iznos >= 0),
    FOREIGN KEY (id_tim) REFERENCES tim(id)
        ON DELETE CASCADE
        ON UPDATE CASCADE,
	FOREIGN KEY (id_sezona) REFERENCES sezona(id)
        ON DELETE CASCADE
        ON UPDATE CASCADE
);
-- Tablica za web login
CREATE TABLE korisnici (
    id INT AUTO_INCREMENT PRIMARY KEY,
    username VARCHAR(50) NOT NULL UNIQUE,
    password VARCHAR(50) NOT NULL, 
    rola ENUM('admin', 'user') NOT NULL
);

-- Unos web korisnika --- S
INSERT INTO korisnici (username, password, rola) VALUES 
('sefe', 'sifra123', 'admin'),
('gost', 'gost123', 'user');


INSERT INTO tim ( naziv, vlasnik, baza, drzava, budzet) VALUES
( 'Red Bull Racing', 'Red Bull GmbH', 'Milton Keynes', 'UK', 145000000),
( 'Ferrari', 'Ferrari S.p.A.', 'Maranello', 'Italija', 150000000),
( 'Mercedes AMG F1', 'Mercedes-Benz', 'Brackley', 'UK', 140000000),
( 'McLaren', 'McLaren Group', 'Woking', 'UK', 135000000),
( 'Aston Martin', 'Lawrence Stroll', 'Silverstone', 'UK', 130000000);




INSERT INTO bolid ( id_tim, model, godina, motor, sasija) VALUES
( 1, 'RB20', 2024, 'Honda RBPT', 'RB20-Chassis'),
( 2, 'SF-24', 2024, 'Ferrari 066/10', 'SF24-Chassis'),
( 3, 'W15', 2024, 'Mercedes M15', 'W15-Chassis'),
( 4, 'MCL38', 2024, 'Mercedes M14', 'MCL38-Chassis'),
( 5, 'AMR24', 2024, 'Mercedes M14', 'AMR24-Chassis');


INSERT INTO vozac (id_tim, sifra, ime, prezime, broj, drzava, datum_rodjenja) VALUES
(1, 'VER01', 'Max', 'Verstappen', 1,  'Nizozemska', '1997-09-30'),
(1, 'TSU22', 'Yuki', 'Tsunoda',    22, 'Japan',      '2000-05-11'),

(2, 'LEC16', 'Charles', 'Leclerc', 16, 'Monako',    '1997-10-16'),
(2, 'HAM44', 'Lewis',   'Hamilton',44, 'Ujedinjeno Kraljevstvo', '1985-01-07'),

(3, 'ANT12', 'Kimi',   'Antonelli',12, 'Italija',   '2006-08-25'),
(3, 'RUS63', 'George', 'Russell',  63, 'Ujedinjeno Kraljevstvo', '1998-02-15'),

(4, 'NOR04', 'Lando',  'Norris',    4,  'Ujedinjeno Kraljevstvo', '1999-11-13'),
(4, 'PIA81', 'Oscar',  'Piastri',   81, 'Australija', '2001-04-06'),

(5, 'ALO14', 'Fernando','Alonso',   14, 'Španjolska', '1981-07-29'),
(5, 'STR18', 'Lance',  'Stroll',    18, 'Kanada',    '1998-10-29');



INSERT INTO sezona ( godina, datum_pocetka, datum_zavrsetka) VALUES
( 2025, '2025-03-14', '2025-12-07');



INSERT INTO vozac_bolid (id_bolid, id_vozac, id_sezona) VALUES
(1, 1, 1),(1, 2,1 ),
(2, 3, 1),(2, 4, 1),
(3, 5, 1),(3, 6,1),
(4, 7, 1),(4, 8, 1),
(5, 9, 1),(5, 10, 1);





INSERT INTO staza ( naziv, lokacija, drzava, duljina_km, broj_krugova) VALUES
('Bahrain International Circuit','Sakhir','Bahrain',5.41,57),
('Albert Park Circuit','Melbourne','Australia',5.28,58),
('Shanghai Circuit','Shanghai','China',5.45,56),
('Suzuka Circuit','Suzuka','Japan',5.81,53),
('Jeddah Corniche Circuit','Jeddah','Saudi Arabia',6.17,50),
('Miami International Autodrome','Miami','USA',5.41,57),
('Imola Circuit','Imola','Italy',4.91,63),
('Circuit de Monaco','Monte Carlo','Monaco',3.34,78),
('Circuit de Barcelona-Catalunya','Barcelona','Spain',4.66,66),
('Circuit Gilles Villeneuve','Montreal','Canada',4.36,70),
('Red Bull Ring','Spielberg','Austria',4.32,71),
('Silverstone Circuit','Silverstone','UK',5.89,52),
('Spa-Francorchamps','Spa','Belgium',7.00,44),
('Hungaroring','Budapest','Hungary',4.38,70),
('Zandvoort','Zandvoort','Netherlands',4.26,72),
('Monza','Monza','Italy',5.79,53),
('Baku City Circuit','Baku','Azerbaijan',6.00,51),
('Marina Bay','Singapore','Singapore',5.06,61),
('Circuit of the Americas','Austin','USA',5.51,56),
('Autodromo Hermanos Rodriguez','Mexico City','Mexico',4.30,71),
('Interlagos','São Paulo','Brazil',4.31,71),
('Las Vegas Strip Circuit','Las Vegas','USA',6.20,50),
('Lusail Circuit','Lusail','Qatar',5.42,57),
('Yas Marina Circuit','Abu Dhabi','UAE',5.28,58);



INSERT INTO utrka (naziv, id_staza, id_sezona, datum) VALUES
('Bahrain GP',            1, 1, '2025-04-13'),
('Australian GP',        2, 1, '2025-03-16'),
('Chinese GP Sprint',    3, 1, '2025-03-23'),
('Japanese GP',          4, 1, '2025-04-06'),
('Saudi Arabian GP',     5, 1, '2025-04-20'),
('Miami GP Sprint',      6, 1, '2025-05-04'),
('Emilia Romagna GP',    7, 1, '2025-05-18'),
('Monaco GP',            8, 1, '2025-05-25'),
('Spanish GP',           9, 1, '2025-06-01'),
('Canadian GP',         10, 1, '2025-06-15'),
('Austrian GP',         11, 1, '2025-06-29'),
('British GP',          12, 1, '2025-07-06'),
('Belgian GP Sprint',   13, 1, '2025-07-27'),
('Hungarian GP',        14, 1, '2025-08-03'),
('Dutch GP',            15, 1, '2025-08-31'),
('Italian GP',          16, 1, '2025-09-07'),
('Azerbaijan GP',       17, 1, '2025-09-21'),
('Singapore GP',        18, 1, '2025-10-05'),
('United States GP',    19, 1, '2025-10-19'),
('Mexico City GP',      20, 1, '2025-10-26'),
('São Paulo GP',        21, 1, '2025-11-09'),
('Las Vegas GP',        22, 1, '2025-11-22'),
('Qatar GP Sprint',     23, 1, '2025-11-30'),
('Abu Dhabi GP',        24, 1, '2025-12-07');




INSERT INTO sudjelovanje (id_utrka, id_vozac_bolid) VALUES
-- Utrka 1
(1,1),(1,2),(1,3),(1,4),(1,5),(1,6),(1,7),(1,8),(1,9),(1,10),

-- Utrka 2
(2,1),(2,2),(2,3),(2,4),(2,5),(2,6),(2,7),(2,8),(2,9),(2,10),

-- Utrka 3
(3,1),(3,2),(3,3),(3,4),(3,5),(3,6),(3,7),(3,8),(3,9),(3,10),

-- Utrka 4
(4,1),(4,2),(4,3),(4,4),(4,5),(4,6),(4,7),(4,8),(4,9),(4,10),

-- Utrka 5
(5,1),(5,2),(5,3),(5,4),(5,5),(5,6),(5,7),(5,8),(5,9),(5,10),

-- Utrka 6
(6,1),(6,2),(6,3),(6,4),(6,5),(6,6),(6,7),(6,8),(6,9),(6,10),

-- Utrka 7
(7,1),(7,2),(7,3),(7,4),(7,5),(7,6),(7,7),(7,8),(7,9),(7,10),

-- Utrka 8
(8,1),(8,2),(8,3),(8,4),(8,5),(8,6),(8,7),(8,8),(8,9),(8,10),

-- Utrka 9
(9,1),(9,2),(9,3),(9,4),(9,5),(9,6),(9,7),(9,8),(9,9),(9,10),

-- Utrka 10
(10,1),(10,2),(10,3),(10,4),(10,5),(10,6),(10,7),(10,8),(10,9),(10,10),

-- Utrka 11
(11,1),(11,2),(11,3),(11,4),(11,5),(11,6),(11,7),(11,8),(11,9),(11,10),

-- Utrka 12
(12,1),(12,2),(12,3),(12,4),(12,5),(12,6),(12,7),(12,8),(12,9),(12,10),

-- Utrka 13
(13,1),(13,2),(13,3),(13,4),(13,5),(13,6),(13,7),(13,8),(13,9),(13,10),

-- Utrka 14
(14,1),(14,2),(14,3),(14,4),(14,5),(14,6),(14,7),(14,8),(14,9),(14,10),

-- Utrka 15
(15,1),(15,2),(15,3),(15,4),(15,5),(15,6),(15,7),(15,8),(15,9),(15,10),

-- Utrka 16
(16,1),(16,2),(16,3),(16,4),(16,5),(16,6),(16,7),(16,8),(16,9),(16,10),

-- Utrka 17
(17,1),(17,2),(17,3),(17,4),(17,5),(17,6),(17,7),(17,8),(17,9),(17,10),

-- Utrka 18
(18,1),(18,2),(18,3),(18,4),(18,5),(18,6),(18,7),(18,8),(18,9),(18,10),

-- Utrka 19
(19,1),(19,2),(19,3),(19,4),(19,5),(19,6),(19,7),(19,8),(19,9),(19,10),

-- Utrka 20
(20,1),(20,2),(20,3),(20,4),(20,5),(20,6),(20,7),(20,8),(20,9),(20,10),

-- Utrka 21
(21,1),(21,2),(21,3),(21,4),(21,5),(21,6),(21,7),(21,8),(21,9),(21,10),

-- Utrka 22
(22,1),(22,2),(22,3),(22,4),(22,5),(22,6),(22,7),(22,8),(22,9),(22,10),

-- Utrka 23
(23,1),(23,2),(23,3),(23,4),(23,5),(23,6),(23,7),(23,8),(23,9),(23,10),

-- Utrka 24
(24,1),(24,2),(24,3),(24,4),(24,5),(24,6),(24,7),(24,8),(24,9),(24,10);



INSERT INTO rezultat (id_utrka, id_vozac_bolid, vrijeme, bodovi) VALUES
(1,  8, '01:32:15', 25),
(2,  7, '01:31:48', 25),
(3,  4, '01:35:22', 8),
(4,  1, '01:30:55', 25),
(5,  1, '01:29:40', 25),
(6,  5, '01:36:10', 8),
(7,  8, '01:31:12', 25),
(8,  7, '01:30:58', 25),
(9,  8, '01:30:45', 25),
(10, 6, '01:32:01', 25),
(11, 7, '01:30:33', 25),
(12, 1, '01:29:55', 25),
(13, 8, '01:34:20', 8),
(14, 3, '01:31:05', 25),
(15, 8, '01:30:10', 25),
(16, 1, '01:29:30', 25),
(17, 1, '01:29:20', 25),
(19, 1, '01:29:15', 25),
(20, 7, '01:30:05', 25),
(21, 7, '01:30:00', 25),
(22, 7, '01:29:58', 25),
(23, 8, '01:33:50', 8),
(24, 1, '01:29:10', 25);




INSERT INTO strategija ( id_sudjelovanje, broj_ulazaka_boks, tipovi_guma) VALUES
( 1, 2, 'Soft-Medium'),
( 2, 2, 'Soft-Medium'),
(3, 1, 'Medium-Hard'),
( 4, 2, 'Soft-Hard'),
(5, 3, 'Soft-Soft-Medium');

INSERT INTO kazna ( id_sudjelovanje, opis, tip_kazne, sekunde) VALUES
( 2, 'Prebrzo u boksu', 'Time Penalty', 5.0),
( 6, 'Izguravanje protivnika', 'Time Penalty', 10.0),
( 8, 'Nedopuštena granica staze', 'Time Penalty', 5.0),
( 9, 'Prekasno vraćanje položaja', 'Drive-through Penalty', 20.0),
(10,'Nepravilno startanje', 'Time Penalty', 5.0);

DELIMITER //
CREATE PROCEDURE izracunaj_poredak_sezone( IN p_sezona INT)
    BEGIN
        START TRANSACTION;
        DELETE FROM poredak
        WHERE id_sezona = p_sezona;
        INSERT INTO poredak (id_vozac, id_sezona, bodovi, pobjede, postolja, mjesto)
        SELECT
            id_vozac,
            id_sezona,
            bodovi,
            pobjede,
            postolja,
            mjesto
        FROM view_poredak_sezone
        WHERE id_sezona = p_sezona;
        COMMIT;
END //

DELIMITER ;



INSERT INTO sponzor (naziv, drzava, tip) VALUES
('Oracle','USA','Tehnologija'),
('Shell','UK','Gorivo'),
('Petronas','Malaysia','Gorivo'),
('Google','USA','Tehnologija'),
('Aramco','Saudi Arabia','Nafta');


INSERT INTO ugovor (id_tim, id_sponzor, godina_od, godina_do, vrijednost) VALUES
(1,1,2022,2026,150000000),
(2,2,2021,2025,120000000),
(3,3,2020,2024,140000000),
(4,4,2023,2025,80000000),
(5,5,2022,2026,90000000);


INSERT INTO osoblje (id_tim, ime, prezime, uloga) VALUES
( 1, 'Adrian', 'Newey', 'Chief Designer'),
( 2, 'Toto', 'Wolff', 'Team Principal'),
(3, 'Fred', 'Vasseur', 'Team Principal'),
(4, 'Peter', 'Prodromou', 'Technical Director'),
(5, 'Dan', 'Fallows', 'Technical Director');

INSERT INTO zaduzenje ( id_osoblje, id_utrka, opis) VALUES
( 1, 1, 'Setup bolida'),
( 2, 2, 'Strategija utrke'),
( 3, 3, 'Operativno vodstvo'),
(4, 1, 'Aerodinamički razvoj'),
(5, 2, 'Operativno vodstvo');


INSERT INTO trosak_tima ( id_tim, id_sezona, kategorija, iznos) VALUES
( 1, 1, 'Razvoj bolida', 120000000),
( 2, 1, 'Motor', 95000000),
( 3, 1, 'Aerodinamika', 110000000),
( 4, 1, 'Logistika', 50000000),
( 5, 1, 'Plaće osoblja', 70000000);


CREATE INDEX idx_strategija_sudjelovanje
ON strategija (id_sudjelovanje);

CREATE INDEX idx_sudjelovanje_utrka
ON sudjelovanje (id_utrka);

CREATE INDEX idx_sudjelovanje_vozac_bolid
ON sudjelovanje (id_vozac_bolid);

-- ---------------------------------------------------------------------------------------
#PROCEDURA 1
# Procedura koja vozaču s najvećim brojem bodova doda postolje koje označava da je bio prvi u pojedinoj utrci.
#POPRAVIIIIIIIIIIIII

DELIMITER //
CREATE PROCEDURE dodaj_postolje_najboljem (IN p_sezona INT)
BEGIN
    DECLARE v_vozac INT;

    SELECT id_vozac
    INTO v_vozac
    FROM poredak
    WHERE id_sezona = p_sezona
    ORDER BY bodovi DESC
    LIMIT 1;

    UPDATE poredak
    SET postolja = postolja + 1
    WHERE id_vozac = v_vozac
      AND id_sezona = p_sezona;
END //
DELIMITER ;



-- bodovi u sezoni
-- SELECT SUM(bodovi)
-- FROM rezultat r
-- JOIN utrka u ON r.id_utrka = u.id
-- WHERE u.id_sezona = 1
--   AND r.id_vozac_bolid = 8;
CREATE INDEX idx_rezultat_utrka
ON rezultat (id_utrka);

CREATE INDEX idx_rezultat_vozac
ON rezultat (id_vozac_bolid);

CREATE INDEX idx_rezultat_utrka_vozac
ON rezultat (id_utrka, id_vozac_bolid);


-- ------------------------------------------------------------
#Funkcija koja računa ukupne bodove vozača u jednoj sezoni - M

DROP FUNCTION IF EXISTS bodovi_vozaca_sezona;

DELIMITER //
CREATE FUNCTION bodovi_vozaca_sezona(p_id_vozac INT,p_id_sezona INT)
RETURNS INT
DETERMINISTIC
BEGIN
    DECLARE ukupno INT;
    SELECT SUM(rezultat.bodovi)
    INTO ukupno
    FROM rezultat
    JOIN vozac_bolid ON rezultat.id_vozac_bolid = vozac_bolid.id
    JOIN utrka ON rezultat.id_utrka = utrka.id
    WHERE vozac_bolid.id_vozac = p_id_vozac
      AND utrka.id_sezona = p_id_sezona;
    RETURN IFNULL(ukupno, 0);
END //
DELIMITER ;



-- ---------------------------------------------------------
#Procedura za automatsko izračunavanje najbržeg vozača po timu u utrci - M

DROP VIEW IF EXISTS najbrzi_vozac_tima_u_utrci;

CREATE VIEW najbrzi_vozac_tima_u_utrci AS
SELECT
    tim.id AS id_tim,
    rezultat.id_utrka,
    vozac.id AS vozac_id,
    vozac.ime,
    vozac.prezime,
    rezultat.vrijeme AS najbolje_vrijeme
FROM rezultat
JOIN vozac_bolid ON rezultat.id_vozac_bolid = vozac_bolid.id
JOIN vozac ON vozac_bolid.id_vozac = vozac.id
JOIN tim ON vozac.id_tim = tim.id
WHERE (rezultat.id_utrka, tim.id, rezultat.vrijeme) IN (
    SELECT
        r.id_utrka,
        t.id,
        MIN(r.vrijeme)
    FROM rezultat r
    JOIN vozac_bolid vb ON r.id_vozac_bolid = vb.id
    JOIN vozac v ON vb.id_vozac = v.id
    JOIN tim t ON v.id_tim = t.id
    GROUP BY r.id_utrka, t.id
);

-- ----------------------------------------
# Okidač koji automatski dodaje bonus bodove za najbrži krug u utrci - M

DROP TRIGGER IF EXISTS dodaj_bonus_najbrzi_krug;

DELIMITER //

CREATE TRIGGER dodaj_bonus_najbrzi_krug
BEFORE INSERT ON rezultat  -- 1. Promjena: BEFORE umjesto AFTER
FOR EACH ROW
BEGIN
    DECLARE v_min_vrijeme TIME;
    
    -- 2. Dohvaćamo najbrže vrijeme koje POSTOJI u bazi (prije ovog novog)
    SELECT MIN(vrijeme) 
    INTO v_min_vrijeme
    FROM rezultat
    WHERE id_utrka = NEW.id_utrka;

    -- 3. Logika: Ako je ovo prvo vrijeme (NULL) ili je novi vozač brži od dosadašnjeg rekorda
    -- Dodajemo mu +1 bod ODMAH, prije nego se redak spremi
    IF min_vrijeme IS NULL OR NEW.vrijeme < min_vrijeme THEN
        SET NEW.bodovi = NEW.bodovi + 1;
    END IF;

END //

DELIMITER ;

-- ----------------------------------------------------
#Vozači koji su osvojili bodove u više od jedne utrke u sezoni i njihov prosjek bodova po utrci - M

-- SELECT 
--     vozac.ime AS ime_vozaca,
--     vozac.prezime AS prezime_vozaca,
--     tim.naziv AS ime_tima,
--     sezona.godina AS sezona,
--     COUNT(rezultat.id) AS broj_utrka_sa_bodovima,
--     AVG(rezultat.bodovi) AS prosjek_bodova
-- FROM vozac
-- JOIN vozac_bolid ON vozac.id = vozac_bolid.id_vozac
-- JOIN sudjelovanje ON vozac_bolid.id = sudjelovanje.id_vozac_bolid
-- JOIN rezultat ON sudjelovanje.id = rezultat.id
-- JOIN utrka ON rezultat.id_utrka = utrka.id
-- JOIN sezona ON utrka.id_sezona = sezona.id
-- JOIN tim ON vozac.id_tim = tim.id
-- WHERE rezultat.bodovi > 0
-- GROUP BY vozac.id, sezona.id
-- HAVING COUNT(rezultat.id) > 1
-- ORDER BY prosjek_bodova DESC;

-- --------------------------------------------------------------
DROP PROCEDURE IF EXISTS imena_staza_u_sezoni;
DELIMITER //

CREATE PROCEDURE imena_staza_u_sezoni (
    IN p_id_sezona INT,
    OUT p_staze TEXT
)
BEGIN
    DECLARE v_naziv VARCHAR(100);
    DECLARE gotovo BOOLEAN DEFAULT FALSE;

    DECLARE cur_staze CURSOR FOR
        SELECT DISTINCT s.naziv
        FROM utrka u
        JOIN staza s ON s.id = u.id_staza
        WHERE u.id_sezona = p_id_sezona
        ORDER BY s.naziv;

    DECLARE CONTINUE HANDLER FOR NOT FOUND
        SET gotovo = TRUE;

    SET p_staze = '';
    OPEN cur_staze;

    petlja: LOOP
        FETCH cur_staze INTO v_naziv;

        IF gotovo THEN
            LEAVE petlja;
        END IF;

        IF p_staze = '' THEN
            SET p_staze = v_naziv;
        ELSE
            SET p_staze = CONCAT(p_staze, '; ', v_naziv);
        END IF;
    END LOOP;

    CLOSE cur_staze;
END//

DELIMITER ;


-- ------------------------------------------------------------------------------------------------------------------------------------
-- Pogled: Statistika vozača po sezoni - M
DROP VIEW IF EXISTS statistika_vozaca_po_sezoni;

CREATE VIEW statistika_vozaca_po_sezoni AS
SELECT
    vozac.id AS vozac_id,
    vozac.ime AS ime_vozaca,
    vozac.prezime AS prezime_vozaca,
    tim.id AS tim_id,
    tim.naziv AS ime_tima,
    sezona.godina AS sezona,
    COUNT(DISTINCT utrka.id) AS broj_utrka,
    SUM(rezultat.bodovi) AS ukupni_bodovi,
    SUM(IF(rezultat.bodovi = 25, 1, 0)) AS broj_pobjeda,
    SUM(IF(rezultat.bodovi >= 15, 1, 0)) AS broj_postolja,
    SUM(kazna.sekunde) AS ukupne_kazne_sekunde,
    AVG(TIME_TO_SEC(rezultat.vrijeme) / staza.broj_krugova) AS prosjecno_vrijeme_po_krugu
FROM vozac
JOIN vozac_bolid ON vozac.id = vozac_bolid.id_vozac
JOIN sudjelovanje ON vozac_bolid.id = sudjelovanje.id_vozac_bolid
JOIN rezultat ON sudjelovanje.id = rezultat.id
JOIN utrka ON rezultat.id_utrka = utrka.id
JOIN staza ON utrka.id_staza = staza.id
JOIN sezona ON utrka.id_sezona = sezona.id
JOIN tim ON vozac.id_tim = tim.id
LEFT JOIN kazna ON sudjelovanje.id = kazna.id_sudjelovanje
GROUP BY vozac.id, sezona.id, tim.id
ORDER BY ukupni_bodovi DESC, broj_pobjeda DESC;

-- ------------------------------------------------------------------------------------------------------------------------------------
-- Trigger: Ne dopušta promjenu imena tima tijekom aktivne sezone --- L
DELIMITER //

CREATE TRIGGER bu_naziv
BEFORE UPDATE ON tim
FOR EACH ROW
BEGIN
    DECLARE cur_s INT DEFAULT 0; 

    IF NEW.naziv != OLD.naziv THEN
        SELECT count(*)
            INTO cur_s
            FROM sezona
            WHERE sezona.godina = YEAR(CURDATE())
            AND MONTH(CURDATE()) BETWEEN 3 AND 12;
            
        IF cur_s > 0 THEN
            SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Zabranjeno mjenjanje imena tima tijekom sezone!';
        END IF;
    END IF;
END //

DELIMITER ;

-- --------------------------------------------------------------------------------------------------------------------------
-- automatski dodaje kaznu na vrijeme -- L
DELIMITER //
CREATE TRIGGER ai_vrijeme
	AFTER INSERT ON kazna
	FOR EACH ROW
BEGIN
	DECLARE trka_id INT;
    DECLARE vozac_id INT;
    
    SELECT id_utrka, id_vozac_bolid
		INTO trka_id, vozac_id
        FROM sudjelovanje
        WHERE id = NEW.id_sudjelovanje;
    
	UPDATE rezultat 
    SET vrijeme	= addtime(vrijeme, sec_to_time(NEW.sekunde)) 
    WHERE id_utrka = trka_id AND id_vozac_bolid = vozac_id;
    
END//
DELIMITER ;

-- --------------------------------------------------------------------------------------------------------------------------
-- automatski dodaje bodove vozacima u prvih 10, pobjede i podiume -- L
DELIMITER //
CREATE TRIGGER au_poredak
	AFTER UPDATE ON utrka
	FOR EACH ROW
    
BEGIN

	DECLARE kraj INT DEFAULT 0;
    DECLARE pozicija INT;
    DECLARE bod_add INT;
    DECLARE vozac_id INT;
    DECLARE sezona_id INT;
    DECLARE vb_id INT;
    
	DECLARE cur CURSOR FOR
		SELECT id_vozac_bolid
			FROM rezultat
			WHERE id_utrka = NEW.id
			ORDER BY vrijeme ASC, id ASC;
	DECLARE CONTINUE HANDLER FOR NOT FOUND SET kraj = 1;
	
	IF OLD.status = 'Traje' AND NEW.status = 'Zavrsena' THEN
		SELECT id_sezona 
			INTO sezona_id 
			FROM utrka 
			WHERE id = NEW.id;
            
		SET pozicija = 0;
        
        OPEN cur;
        
        read_loop: LOOP
        FETCH cur INTO vb_id;
                
		IF kraj = 1 THEN
			LEAVE read_loop;
		END IF;
        
        SET pozicija = pozicija + 1;
        
		SET bod_add = CASE pozicija
			WHEN 1 THEN 25
			WHEN 2 THEN 18
			WHEN 3 THEN 15
			WHEN 4 THEN 12
			WHEN 5 THEN 10
			WHEN 6 THEN 8
			WHEN 7 THEN 6
			WHEN 8 THEN 4
			WHEN 9 THEN 2
			WHEN 10 THEN 1
			ELSE 0
		END;
        
		IF pozicija = 1 THEN
			UPDATE poredak
				SET pobjede = pobjede + 1
				WHERE id_vozac = vozac_id
				AND id_sezona = sezona_id;
		END IF;
            
		IF pozicija <= 3 THEN
			UPDATE poredak
				SET postolja = postolja + 1
				WHERE id_vozac = vozac_id
				AND id_sezona = sezona_id;
		END IF;
        
        IF bod_add > 0 THEN
			SELECT id_vozac
				INTO vozac_id
				FROM vozac_bolid
				WHERE id = vb_id;
                
			UPDATE poredak 
				SET bodovi = bodovi + bod_add
				WHERE id_vozac = vozac_id AND id_sezona = sezona_id;
		END IF;
        END LOOP;
        CLOSE cur;
	END IF;
END//
DELIMITER ;

-- --------------------------------------------------------------------------------------------------------------------------
-- smanjuje budžet nakon troškova i sprječava prelazak tog budžeta -- L

-- --------------------------------------------------------------------------------------------------------------------------
-- ne dopušta insert mlađir od 18 -- L
DELIMITER //
CREATE TRIGGER bi_datum_rodenja
	BEFORE INSERT ON vozac
    FOR EACH ROW
BEGIN
 
	IF NEW.datum_rodjenja > date_sub(curdate(), interval 18 year) THEN
		SIGNAL SQLSTATE '40000'
		SET MESSAGE_TEXT = 'Vozač premlad';
	END IF;
    
END//
DELIMITER ;

-- --------------------------------------------------------------------------------------------------------------------------------

--  NOVA TABLICA ZA LOGIRANJE --- S
CREATE TABLE sistemski_log (
    id INT AUTO_INCREMENT PRIMARY KEY,
    tablica VARCHAR(50),
    akcija VARCHAR(50),
    poruka TEXT,
    vrijeme TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- TRIGGER: Prati promjene budžeta --- S
DELIMITER //
CREATE TRIGGER prati_budzet
AFTER UPDATE ON tim
FOR EACH ROW
BEGIN
    IF OLD.budzet <> NEW.budzet THEN
        INSERT INTO sistemski_log (tablica, akcija, poruka)
        VALUES ('tim', 'UPDATE', CONCAT('Budzet tima ', OLD.naziv, ' promijenjen sa ', OLD.budzet, ' na ', NEW.budzet));
    END IF;
END;
//
DELIMITER ;

-- PROCEDURA: Dohvati sažetak sezone --- S
-- Ovo vraća tablicu s izračunatim podacima
DELIMITER //
CREATE PROCEDURE DohvatiStatistiku()
BEGIN
    SELECT 
        (SELECT COUNT(*) FROM tim) as broj_timova,
        (SELECT COUNT(*) FROM vozac) as broj_vozaca,
        (SELECT AVG(budzet) FROM tim) as prosjecni_budzet,
        (SELECT naziv FROM tim ORDER BY budzet DESC LIMIT 1) as najbogatiji_tim;
END;
//
DELIMITER ;



-- Kreiranje MySQL korisnika za Python konekciju --- S
CREATE USER IF NOT EXISTS 'f1_admin'@'%' IDENTIFIED BY 'admin_pass';
CREATE USER IF NOT EXISTS 'f1_viewer'@'%' IDENTIFIED BY 'viewer_pass';

-- Davanje prava --- S
GRANT ALL PRIVILEGES ON formula.* TO 'f1_admin'@'%';
GRANT SELECT ON formula.* TO 'f1_viewer'@'%';
FLUSH PRIVILEGES;

-- -----------------------------------------------------------------------------------------------------------------
#MILA

-- ----------------------------------------------------------- FUNKCIJE: -----------------------------------------------------------
-- pretvori brzinu u mph
DELIMITER //

CREATE FUNCTION kmh_u_mph(brzina_kmh DECIMAL(6,2))
RETURNS DECIMAL(6,2)
DETERMINISTIC
BEGIN
    RETURN brzina_kmh * 0.621371;
END//

DELIMITER ;




-- odvozene utrke
DELIMITER //

CREATE FUNCTION broj_ucestvovanja_vozaca(p_id_vozac INT)
RETURNS INT
DETERMINISTIC
BEGIN
    DECLARE br INT;

    SELECT COUNT(DISTINCT s.id)
    INTO br
    FROM vozac_bolid vb
    JOIN sudjelovanje s ON s.id_vozac_bolid = vb.id
    JOIN rezultat r ON r.id_utrka = s.id_utrka
    WHERE vb.id_vozac = p_id_vozac;

    RETURN br;
END//

DELIMITER ;





-- najbolji vozac po nastupima

DELIMITER //
CREATE FUNCTION najbolji_vozac_po_nastupima(
    p_id_tim INT
)
RETURNS INT
DETERMINISTIC
BEGIN
    DECLARE vozac_id INT;

    SELECT vb.id_vozac
    INTO vozac_id
    FROM vozac_bolid vb
    JOIN vozac v ON v.id = vb.id_vozac
    JOIN sudjelovanje s ON s.id_vozac_bolid = vb.id
    WHERE v.id_tim = p_id_tim
    GROUP BY vb.id_vozac
    ORDER BY COUNT(s.id) DESC
    LIMIT 1;

    RETURN vozac_id;
END//
DELIMITER ;




-- najbolji vozac u timu
DELIMITER //
CREATE FUNCTION najbolji_vozac_u_timu(
    p_id_tim INT,
    p_id_sezona INT
)
RETURNS INT
DETERMINISTIC
BEGIN
    DECLARE vozac_id INT;
    SELECT vb.id_vozac
    INTO vozac_id
    FROM view_bodovi_vozaca vb
    JOIN vozac v ON v.id = vb.id_vozac
    WHERE v.id_tim = p_id_tim
      AND vb.id_sezona = p_id_sezona
    ORDER BY vb.bodovi DESC
    LIMIT 1;
    RETURN vozac_id;
END //
DELIMITER ;


-- --------------------------------------------------------------------------------------------------------------------------------------------------- 


-- ------------------------------------------------------------------------------ VIEW ------------------------------------------------------------------------------

#1

CREATE OR REPLACE VIEW view_statistika_timova AS
SELECT 
    t.id AS id_tim,
    t.naziv AS tim,
    COUNT(DISTINCT v.id) AS broj_vozaca,
    t.budzet AS ukupni_budzet,
    AVG(TIMESTAMPDIFF(YEAR, v.datum_rodjenja, CURDATE())) AS prosjecna_starost_vozaca,
    COUNT(DISTINCT u.id_sponzor) AS broj_sponzora
FROM tim t
LEFT JOIN vozac v ON v.id_tim = t.id
LEFT JOIN ugovor u ON u.id_tim = t.id
GROUP BY t.id, t.naziv, t.budzet;



#2 

CREATE OR REPLACE VIEW view_bodovi_vozaca AS
SELECT
    t.id AS id_tim,
    t.naziv AS tim,
    SUM(p.bodovi) AS ukupni_bodovi
FROM poredak p
JOIN vozac v ON v.id = p.id_vozac
JOIN tim t ON t.id = v.id_tim
GROUP BY t.id, t.naziv;



#3 

CREATE OR REPLACE VIEW view_najbrzi_vozaci AS
SELECT 
    r.id_utrka,
    vb.id_vozac,
    MIN(r.vrijeme) AS najbrze_vrijeme
FROM rezultat r
JOIN vozac_bolid vb ON vb.id = r.id_vozac_bolid
GROUP BY r.id_utrka, vb.id_vozac;





#4

CREATE OR REPLACE VIEW view_broj_utrka_sezona AS
SELECT
    s.godina,
    COUNT(u.id) AS broj_utrka
FROM sezona s
LEFT JOIN utrka u ON u.id_sezona = s.id
GROUP BY s.godina;

#5

CREATE OR REPLACE VIEW view_prosjecna_starost_timova AS
SELECT
    t.id AS id_tim,
    t.naziv AS tim,
    ROUND(AVG(TIMESTAMPDIFF(YEAR, v.datum_rodjenja, CURDATE())),2) AS prosjecna_starost
FROM tim t
JOIN vozac v ON v.id_tim = t.id
GROUP BY t.id, t.naziv;


#6
CREATE OR REPLACE VIEW view_trosak_tima AS
SELECT id_tim, id_sezona, SUM(iznos) AS ukupni_trosak
FROM trosak_tima
GROUP BY id_tim, id_sezona;



-- --------------------------------------------------------------------------------- PROCEDURE -----------------------------------------------------------------------------

-- dodavanje utrke
DELIMITER //

CREATE PROCEDURE dodaj_utrku(
    p_naziv VARCHAR(100),
    p_datum DATE,
    p_id_sezona INT,
    p_id_staza INT
)
BEGIN
    INSERT INTO utrka (naziv, datum, id_sezona, id_staza)
    VALUES (p_naziv, p_datum, p_id_sezona, p_id_staza);
END//

DELIMITER ;


-- starost vozaca

DELIMITER //

CREATE TRIGGER bi_utrka_datum
BEFORE INSERT ON utrka
FOR EACH ROW
BEGIN
    IF NEW.datum < (
        SELECT datum_pocetka
        FROM sezona
        WHERE id = NEW.id_sezona
    )
    OR NEW.datum > (
        SELECT datum_zavrsetka
        FROM sezona
        WHERE id = NEW.id_sezona
    ) THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Datum utrke mora biti unutar trajanja sezone';
    END IF;
END//

DELIMITER ;




-- -------------------------------------------------------------------------------------------------------------------------------


############################################33
#TRANSAKCIJA 1. 
#Napisati transakciju koja će unijeti podatke za pobjednika utrke te ovisno o tome ažurirati relaciju poredak
DELIMITER //

CREATE PROCEDURE upisi_pobjednika (
    IN p_utrka INT,
    IN p_vozac_bolid INT,
    IN p_vrijeme TIME
)
BEGIN
    DECLARE v_id_vozac INT;
    DECLARE v_id_sezona INT;

    START TRANSACTION;

    SELECT id_sezona INTO v_id_sezona
    FROM utrka WHERE id = p_utrka;

    SELECT id_vozac INTO v_id_vozac
    FROM vozac_bolid WHERE id = p_vozac_bolid;

    INSERT INTO rezultat (id_utrka, id_vozac_bolid, vrijeme, bodovi)
    VALUES (p_utrka, p_vozac_bolid, p_vrijeme, 25);

    UPDATE poredak
    SET bodovi = bodovi + 25,
        pobjede = pobjede + 1
    WHERE id_vozac = v_id_vozac
      AND id_sezona = v_id_sezona;

    COMMIT;
END//

DELIMITER ;

############################################33
#TRANSAKCIJA 2.
#Napisati transakciju koja će obrisati fiksih 5 bodova za zasluženu kaznu 
START TRANSACTION;

INSERT INTO kazna (id_sudjelovanje, opis, tip_kazne, sekunde)
VALUES (11, 'Opasna vožnja', 'Time Penalty', 10.0);

SET @kazna_id = LAST_INSERT_ID();

UPDATE poredak
SET id_kazna = @kazna_id,
    bodovi = bodovi - 5
WHERE id_vozac = (
    SELECT vb.id_vozac
    FROM sudjelovanje s
    JOIN vozac_bolid vb ON s.id_vozac_bolid = vb.id
    WHERE s.id = 11
)
AND id_sezona = 1;

COMMIT;

############################################
#TRANSAKCIJA 3.
#Napisati transakciju koja će promijeniti stanje bolida u 'Na servisu' te vozaču s idjem 1 dodati novi bolid.
-- START TRANSACTION;
-- UPDATE bolid
-- SET stanje = 'Na servisu'
-- WHERE id = (
--     SELECT id_bolid
--     FROM vozac_bolid
--     WHERE id_vozac = 2 AND id_sezona = 1
-- );

-- INSERT INTO vozac_bolid (id_bolid, id_vozac, id_sezona)
-- -- VALUES (3, 2, 1);

-- COMMIT;

############################################
#PROCEDURA 
#Napisati proceduru koja će uvećati pobjede kad vozač ostvari prvo mjesto u utrci.
DELIMITER //

CREATE PROCEDURE dodaj_pobjedu_pobjedniku (IN p_id_utrka INT)
BEGIN
    DECLARE v_id_vozac INT DEFAULT NULL;
    DECLARE v_id_sezona INT;

    SELECT id_sezona
    INTO v_id_sezona
    FROM utrka
    WHERE id = p_id_utrka;

    SELECT vozac_bolid.id_vozac
    INTO v_id_vozac
    FROM rezultat 
    JOIN vozac_bolid  ON rezultat.id_vozac_bolid = vozac_bolid.id
    WHERE rezultat.id_utrka = p_id_utrka
    ORDER BY rezultat.bodovi DESC
    LIMIT 1;

    IF v_id_vozac IS NOT NULL THEN
        UPDATE poredak
        SET pobjede = pobjede + 1
        WHERE id_vozac = v_id_vozac
          AND id_sezona = v_id_sezona;
    END IF;

END //

DELIMITER ;

#########################################
#PROCEDURA + TRANSAKCIJA
#Napisati proceduru koja pri prelasku vozača u drugi tim, brišu mu bolid i dodaju novi
DELIMITER //

CREATE PROCEDURE transfer_vozaca (
    IN p_vozac INT,
    IN p_novi_tim INT,
    IN p_novi_bolid INT,
    IN p_sezona INT
)
BEGIN
    START TRANSACTION;

    UPDATE vozac
    SET id_tim = p_novi_tim
    WHERE id = p_vozac;

    DELETE FROM vozac_bolid WHERE id_vozac = p_vozac;

    INSERT INTO vozac_bolid(id_bolid, id_vozac, id_sezona)
    VALUES (p_novi_bolid, p_vozac, p_sezona);

    COMMIT;
END //

DELIMITER ;


#########################################
#PROCEDURA + TRANSAKCIJA
#Napisati transakciju koja poništava plaćanja ako tim prekorači budžet.
DELIMITER //

CREATE PROCEDURE dodaj_trosak_timu (
    IN p_tim INT,
    IN p_sezona INT,
    IN p_kategorija VARCHAR(100),
    IN p_iznos DECIMAL(15,2)
)
BEGIN
    DECLARE v_budzet DECIMAL(15,2);

    START TRANSACTION;

    SELECT budzet INTO v_budzet FROM tim WHERE id = p_tim FOR UPDATE;

    IF v_budzet < p_iznos THEN
        ROLLBACK;
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Nedovoljno stanje budžeta!';
    ELSE
        UPDATE tim
        SET budzet = budzet - p_iznos
        WHERE id = p_tim;

        INSERT INTO trosak_tima(id_tim, id_sezona, kategorija, iznos)
        VALUES (p_tim, p_sezona, p_kategorija, p_iznos);

        COMMIT;
    END IF;
END //

DELIMITER ;


-- ------------------------------------------------------------------------------------------------------------------------------------------------------------

-- ---------------------------------------------------------
# REA

-- 1) Vozači bez ijedne kazne u sezoni

-- SELECT vozac.sifra, vozac.ime, vozac.prezime
-- 	FROM vozac
-- 	WHERE vozac.id NOT IN (
-- 		SELECT vozac_bolid.id_vozac
-- 			FROM kazna
-- 				JOIN sudjelovanje ON sudjelovanje.id = kazna.id_sudjelovanje
-- 				JOIN vozac_bolid ON vozac_bolid.id = sudjelovanje.id_vozac_bolid
-- 				JOIN utrka ON utrka.id = sudjelovanje.id_utrka
-- 				WHERE utrka.id_sezona = 1
-- );



-- 2) VIEW: Učinkovitost timova

DROP VIEW IF EXISTS ucinkovitost_timova;

CREATE VIEW ucinkovitost_timova AS
SELECT tim.id AS id_tim, tim.naziv AS tim, sezona.id AS id_sezona, sezona.godina, tim.budzet, 
		SUM(rezultat.bodovi) AS ukupni_bodovi,
		SUM(
			CASE 
				WHEN rezultat.bodovi = 25 THEN 1 
				ELSE 0 
			END
		) AS pobjede,
		ROUND(
			SUM(rezultat.bodovi) / NULLIF(tim.budzet / 1000000, 0),
			2
		) AS bodovi_po_milijunu
	FROM tim
		JOIN vozac ON vozac.id_tim = tim.id
		JOIN vozac_bolid ON vozac_bolid.id_vozac = vozac.id
		JOIN rezultat ON rezultat.id_vozac_bolid = vozac_bolid.id
		JOIN utrka ON utrka.id = rezultat.id_utrka
		JOIN sezona ON sezona.id = utrka.id_sezona
    
		GROUP BY tim.id, tim.naziv, sezona.id, sezona.godina, tim.budzet;



-- 3) VIEW: Detaljni poredak po utrci

DROP VIEW IF EXISTS poredak_utrke;

CREATE VIEW poredak_utrke AS
SELECT utrka.id AS id_utrka, utrka.naziv AS utrka, vozac.id AS id_vozac, vozac.ime, vozac.prezime, 
	   tim.naziv AS tim, rezultat.vrijeme, rezultat.bodovi, 
	   COUNT(rezultat2.id) + 1 AS pozicija, IFNULL(SUM(kazna.sekunde), 0) AS kaznene_sekunde
	FROM rezultat
		JOIN utrka ON utrka.id = rezultat.id_utrka
		JOIN vozac_bolid ON vozac_bolid.id = rezultat.id_vozac_bolid
		JOIN vozac ON vozac.id = vozac_bolid.id_vozac
		JOIN tim ON tim.id = vozac.id_tim

	LEFT JOIN rezultat AS rezultat2
		ON rezultat2.id_utrka = rezultat.id_utrka
		AND rezultat2.vrijeme < rezultat.vrijeme

	LEFT JOIN sudjelovanje
		ON sudjelovanje.id_utrka = utrka.id
	   AND sudjelovanje.id_vozac_bolid = vozac_bolid.id
       
	LEFT JOIN kazna
		ON kazna.id_sudjelovanje = sudjelovanje.id

	GROUP BY
		utrka.id,
		utrka.naziv,
		vozac.id,
		vozac.ime,
		vozac.prezime,
		tim.naziv,
		rezultat.id,
		rezultat.vrijeme,
		rezultat.bodovi;



-- 4) VIEW: Vozači po najvećim brojem kaznenih bodova u sezoni

DROP VIEW IF EXISTS top_vozaci_po_kaznama;

CREATE VIEW top_vozaci_po_kaznama AS
SELECT vozac.id AS id_vozac, vozac.ime, vozac.prezime, tim.naziv AS tim, COUNT(kazna.id) AS broj_kazni,
    IFNULL(SUM(kazna.sekunde),0) AS ukupno_sekundi, utrka.id_sezona
	FROM vozac
		JOIN tim ON tim.id = vozac.id_tim
		JOIN vozac_bolid ON vozac_bolid.id_vozac = vozac.id
		JOIN sudjelovanje ON sudjelovanje.id_vozac_bolid = vozac_bolid.id
		JOIN utrka ON utrka.id = sudjelovanje.id_utrka
		LEFT JOIN kazna ON kazna.id_sudjelovanje = sudjelovanje.id
	GROUP BY vozac.id, tim.naziv, utrka.id_sezona;


-- 5) VIEW: sezona u državama (broj utrka u državi)

DROP VIEW IF EXISTS sezona_u_drzavama;

CREATE VIEW sezona_u_drzavama AS
SELECT utrka.id_sezona, staza.drzava, COUNT(utrka.id) AS broj_utrka
	FROM utrka
	JOIN staza ON staza.id = utrka.id_staza
	GROUP BY utrka.id_sezona, staza.drzava;




-- 6) OKIDAČ: provjera sudjelovanja natjecatelja po id-u prije unosa rezultata

DROP TRIGGER IF EXISTS bi_provjera_sudjelovanja;

DELIMITER //

CREATE TRIGGER bi_provjera_sudjelovanja
BEFORE INSERT ON rezultat
FOR EACH ROW
BEGIN
    DECLARE postoji INT;

    SELECT COUNT(*) INTO postoji
    FROM sudjelovanje
    WHERE id_utrka = NEW.id_utrka AND id_vozac_bolid = NEW.id_vozac_bolid;

    IF postoji = 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Vozač nije prijavljen za ovu utrku';
    END IF;
END//

DELIMITER ;



-- 7) FUNKCIJA: prosječne kaznene sekunde vozača po utrci u sezoni

DROP FUNCTION IF EXISTS prosjek_kazni_po_utrci_vozaca;

DELIMITER //

CREATE FUNCTION prosjek_kazni_po_utrci_vozaca(p_id_vozac INT, p_id_sezona INT) RETURNS DECIMAL(8,2)
DETERMINISTIC
BEGIN
    DECLARE ukupno_kazni DECIMAL(10,2);
    DECLARE nastupi INT;
    
    SELECT SUM(kazna.sekunde) INTO ukupno_kazni
		FROM kazna
			JOIN sudjelovanje ON sudjelovanje.id = kazna.id_sudjelovanje
			JOIN vozac_bolid ON vozac_bolid.id = sudjelovanje.id_vozac_bolid
			JOIN utrka ON utrka.id = sudjelovanje.id_utrka
		WHERE vozac_bolid.id_vozac = p_id_vozac AND utrka.id_sezona = p_id_sezona;

    SELECT COUNT(DISTINCT sudjelovanje.id_utrka) INTO nastupi
    FROM vozac_bolid
		JOIN sudjelovanje ON sudjelovanje.id_vozac_bolid = vozac_bolid.id
		JOIN utrka ON utrka.id = sudjelovanje.id_utrka
    WHERE vozac_bolid.id_vozac = p_id_vozac AND utrka.id_sezona = p_id_sezona;
    
	IF nastupi = 0 THEN
		RETURN 0;
	END IF;

	RETURN ROUND(COALESCE(ukupno_kazni, 0) / nastupi, 2);

END//

DELIMITER ;




-- 8) FUNKCIJA: postotak sprint utrka u sezoni za vozača

DROP FUNCTION IF EXISTS postotak_sprint_utrka_vozaca;

DELIMITER //

CREATE FUNCTION postotak_sprint_utrka_vozaca (p_id_vozac INT, p_id_sezona INT) RETURNS DECIMAL(5,2)
DETERMINISTIC
BEGIN
    DECLARE ukupno INT;
    DECLARE sprint INT;

    SELECT COUNT(DISTINCT sudjelovanje.id_utrka) INTO ukupno
    FROM vozac_bolid
		JOIN sudjelovanje ON sudjelovanje.id_vozac_bolid = vozac_bolid.id
		JOIN utrka ON utrka.id = sudjelovanje.id_utrka
    WHERE vozac_bolid.id_vozac = p_id_vozac AND utrka.id_sezona = p_id_sezona;

    SELECT COUNT(DISTINCT sudjelovanje.id_utrka) INTO sprint
    FROM vozac_bolid
		JOIN sudjelovanje ON sudjelovanje.id_vozac_bolid = vozac_bolid.id
		JOIN utrka ON utrka.id = sudjelovanje.id_utrka
    WHERE vozac_bolid.id_vozac = p_id_vozac AND utrka.id_sezona = p_id_sezona AND utrka.naziv LIKE '%Sprint%';

    IF ukupno = 0 THEN
        RETURN 0;
    END IF;

    RETURN ROUND((sprint / ukupno) * 100, 2);
END//

DELIMITER ;




-- 9) PROCEDURA: Prosječna kazna po utrci za tim po sezoni

DROP PROCEDURE IF EXISTS prosjek_kazni_tima;

DELIMITER //

CREATE PROCEDURE prosjek_kazni_tima(
    IN p_id_tim INT,
    IN p_id_sezona INT,
    OUT p_broj_utrka INT,
    OUT p_ukupne_kazne DECIMAL(10,2),
    OUT p_prosjek DECIMAL(8,2)
)
BEGIN
    SELECT 
        COUNT(DISTINCT utrka.id),
        IFNULL(SUM(kazna.sekunde), 0)
    INTO 
        p_broj_utrka,
        p_ukupne_kazne
    FROM tim
        JOIN vozac ON vozac.id_tim = tim.id
        JOIN vozac_bolid ON vozac_bolid.id_vozac = vozac.id
        JOIN sudjelovanje ON sudjelovanje.id_vozac_bolid = vozac_bolid.id
        JOIN utrka ON utrka.id = sudjelovanje.id_utrka
        LEFT JOIN kazna ON kazna.id_sudjelovanje = sudjelovanje.id
    WHERE tim.id = p_id_tim
      AND utrka.id_sezona = p_id_sezona;

    IF p_broj_utrka = 0 THEN
        SET p_prosjek = 0;
    ELSE
        SET p_prosjek = ROUND(p_ukupne_kazne / p_broj_utrka, 2);
    END IF;
END//

DELIMITER ;

