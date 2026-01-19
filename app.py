from flask import Flask, render_template, request, redirect, url_for, session, flash
import mysql.connector
from mysql.connector import Error
import os

app = Flask(__name__)
app.secret_key = 'neka_tajna_kljuc_za_sesiju'

def get_db_connection(user_role='public'):
    db_host = os.environ.get('MYSQL_HOST', 'db') 
    
    if user_role == 'admin':
        db_user, db_pass = 'f1_admin', 'admin_pass'
    elif user_role == 'user':
        db_user, db_pass = 'f1_viewer', 'viewer_pass'
    else:
        db_user, db_pass = 'root', 'root' 

    try:
        conn = mysql.connector.connect(
            host=db_host,
            user=db_user,
            password=db_pass,
            database='formula',
            charset='utf8mb4',
            collation='utf8mb4_unicode_ci'
        )
        return conn
    except Error as e:
        print(f"Greška spajanja ({user_role}): {e}")
        return None

@app.route('/login', methods=['GET', 'POST'])
def login():
    if request.method == 'POST':
        username = request.form['username']
        password = request.form['password']
        
        conn = get_db_connection('root')
        if conn:
            cursor = conn.cursor(dictionary=True)
            cursor.execute("SELECT * FROM korisnici WHERE username=%s AND password=%s", (username, password))
            user = cursor.fetchone()
            conn.close()
            
            if user:
                session['loggedin'] = True
                session['username'] = user['username']
                session['role'] = user['rola']
                return redirect(url_for('dashboard'))
            else:
                return render_template('login.html', error="Krivi podaci!")
    return render_template('login.html')

@app.route('/logout')
def logout():
    session.clear()
    return redirect(url_for('login'))


@app.route('/')
def dashboard():
    if 'loggedin' not in session: return redirect(url_for('login'))
    
    conn = get_db_connection(session.get('role'))
    cursor = conn.cursor(dictionary=True)

    stats = {}
    try:
        cursor.callproc('DohvatiStatistiku')
        for result in cursor.stored_results():
            stats = result.fetchone()
    except: pass

    cursor.execute("SELECT * FROM tim")
    timovi = cursor.fetchall()
    
    try:
        cursor.execute("SELECT * FROM sistemski_log ORDER BY vrijeme DESC LIMIT 5")
        logovi = cursor.fetchall()
    except: logovi = []

    conn.close()
    return render_template('dashboard.html', stats=stats, timovi=timovi, logovi=logovi)

@app.route('/vozaci', methods=['GET', 'POST'])
def vozaci():
    if 'loggedin' not in session: return redirect(url_for('login'))
    role = session.get('role')
    conn = get_db_connection(role)
    
    if request.method == 'POST':
        try:
            ime = request.form['ime']
            prezime = request.form['prezime']
            broj = request.form['broj']
            tim_id = request.form['tim_id']
            sifra = request.form['sifra']
            datum_rodjenja = request.form['datum_rodjenja']
            nacionalnost = request.form['nacionalnost']
            
            
            cursor = conn.cursor()
            cursor.execute("""
                INSERT INTO vozac (ime, prezime, broj, id_tim, drzava, sifra, datum_rodjenja) 
                VALUES (%s, %s, %s, %s, %s, %s, %s)
            """, (ime, prezime, broj, tim_id, nacionalnost, sifra, datum_rodjenja))
            conn.commit()
            flash(f"Vozač {ime} {prezime} uspješno dodan!", "success")
        except Error as e:
            flash(f"Greška kod dodavanja: {e}", "danger")
        return redirect(url_for('vozaci'))

    cursor = conn.cursor(dictionary=True)
    query = """
        SELECT v.*, t.naziv as naziv_tima 
        FROM vozac v 
        LEFT JOIN tim t ON v.id_tim = t.id 
        ORDER BY t.naziv, v.broj
    """
    cursor.execute(query)
    vozaci_data = cursor.fetchall()
    
    cursor.execute("SELECT id, naziv FROM tim")
    timovi_lista = cursor.fetchall()
    
    conn.close()
    return render_template('vozaci.html', vozaci=vozaci_data, timovi=timovi_lista)

@app.route('/obrisi-vozaca/<int:id>', methods=['POST'])
def obrisi_vozaca(id):
    if 'loggedin' not in session or session.get('role') != 'admin':
        return redirect(url_for('login'))

    conn = get_db_connection('admin')
    cursor = conn.cursor()
    
    try:
        cursor.execute("DELETE FROM vozac WHERE id = %s", (id,))
        conn.commit()
        flash('Vozač uspješno obrisan!', 'success')
    except Exception as e:
        flash(f'Greška pri brisanju: {e}', 'danger')
    finally:
        conn.close()

    return redirect(url_for('vozaci'))

@app.route('/utrke')
def utrke():
    user_role = session.get('role', 'public')
    conn = get_db_connection(user_role)
    cursor = conn.cursor(dictionary=True)

    query = """
        SELECT 
            u.id, u.naziv, u.datum, u.status,
            s.naziv AS naziv_staze, s.drzava, s.duljina_km, s.broj_krugova
        FROM utrka u
        JOIN staza s ON u.id_staza = s.id
        ORDER BY u.datum ASC
    """
    cursor.execute(query)
    sve_utrke = cursor.fetchall()

    cursor.execute("SELECT * FROM sezona ORDER BY godina DESC")
    sezone = cursor.fetchall()

    cursor.execute("SELECT id, naziv, drzava FROM staza ORDER BY naziv")
    staze = cursor.fetchall()
    
    conn.close()

    najavljene = [u for u in sve_utrke if u['status'] == 'Najavljena']
    uzivo = [u for u in sve_utrke if u['status'] == 'Traje'] 
    zavrsene = [u for u in sve_utrke if u['status'] == 'Zavrsena']

    return render_template('utrke.html', 
                           najavljene=najavljene, 
                           uzivo=uzivo, 
                           zavrsene=zavrsene,
                           sezone=sezone,
                           staze=staze) 

@app.route('/dodaj-utrku', methods=['POST'])
def dodaj_utrku():
    if 'loggedin' not in session or session.get('role') != 'admin':
        return redirect(url_for('login'))

    naziv = request.form.get('naziv')
    datum = request.form.get('datum')
    id_sezona = request.form.get('id_sezona')
    id_staza = request.form.get('id_staza')

    conn = get_db_connection('admin')
    cursor = conn.cursor()
    
    try:
        cursor.callproc('dodaj_utrku', [naziv, datum, id_sezona, id_staza])
        conn.commit()
        flash('Nova utrka uspješno dodana!', 'success')
        
    except Exception as e:
        print(f"SQL Error: {e}")
        flash(f'Greška pri dodavanju: {e}', 'danger')
        
    finally:
        conn.close()
    
    return redirect(url_for('utrke'))

@app.route('/promijeni-status-utrke', methods=['POST'])
def promijeni_status_utrke():
    if 'loggedin' not in session or session.get('role') != 'admin':
        return redirect(url_for('login'))
        
    utrka_id = request.form.get('utrka_id')
    novi_status = request.form.get('novi_status') 
    
    dozvoljeni = ['Najavljena', 'Traje', 'Zavrsena']
    if novi_status not in dozvoljeni:
         flash('Neispravan status!', 'danger')
         return redirect(url_for('utrke'))
    
    conn = get_db_connection('admin')
    cursor = conn.cursor()
    try:
        cursor.execute("UPDATE utrka SET status = %s WHERE id = %s", (novi_status, utrka_id))
        conn.commit()
    except Exception as e:
        flash(f"Greška statusa: {e}", "danger")
    finally:
        conn.close()
    
    return redirect(url_for('utrke'))

@app.route('/promijeni-budzet', methods=['POST'])
def promijeni_budzet():
    if 'loggedin' not in session: return redirect(url_for('login'))
    tim_id = request.form['tim_id']
    novi_iznos = request.form['iznos']
    
    conn = get_db_connection(session.get('role'))
    try:
        cursor = conn.cursor()
        cursor.execute("UPDATE tim SET budzet = %s WHERE id = %s", (novi_iznos, tim_id))
        conn.commit()
        flash("Budžet ažuriran!", "success")
    except Error as e:
        flash(f"Nemate ovlasti! ({e})", "danger")
    conn.close()
    return redirect(url_for('dashboard'))


@app.route('/transfer')
def transfer_page():
    if 'loggedin' not in session or session.get('role') != 'admin':
        return redirect(url_for('login'))
        
    conn = get_db_connection(session.get('role'))
    cursor = conn.cursor(dictionary=True)
    
    cursor.execute("SELECT v.id, v.ime, v.prezime, t.naziv as naziv_tima FROM vozac v JOIN tim t ON v.id_tim = t.id")
    vozaci = cursor.fetchall()
    
    cursor.execute("SELECT * FROM tim")
    timovi = cursor.fetchall()

    cursor.execute("SELECT * FROM bolid")
    bolidi = cursor.fetchall()

    cursor.execute("SELECT * FROM sezona ORDER BY godina DESC")
    sezone = cursor.fetchall()
    
    conn.close()
    return render_template('transfer.html', vozaci=vozaci, timovi=timovi, bolidi=bolidi, sezone=sezone)

@app.route('/izvrsi-transfer', methods=['POST'])
def izvrsi_transfer():
    if 'loggedin' not in session or session.get('role') != 'admin':
        return redirect(url_for('login'))

    vozac_id = request.form['vozac_id']
    novi_tim_id = request.form['novi_tim_id']
    novi_bolid_id = request.form['novi_bolid_id']
    sezona_id = request.form['sezona_id']

    conn = get_db_connection('admin')
    cursor = conn.cursor()

    try:
        cursor.callproc('transfer_vozaca', [vozac_id, novi_tim_id, novi_bolid_id, sezona_id])
        
        conn.commit() 
        flash(f'Transfer uspješno obavljen! Vozač je sada u novom timu.', 'success')
        
    except Error as e:
        flash(f'Greška pri transferu: {e}', 'danger')
        print(f"SQL Error: {e}")

    conn.close()
    return redirect(url_for('vozaci'))

@app.route('/financije')
def financije():
    if 'loggedin' not in session or session.get('role') != 'admin':
        return redirect(url_for('login'))
        
    conn = get_db_connection('admin')
    cursor = conn.cursor(dictionary=True)
    
    cursor.execute("SELECT * FROM tim")
    timovi = cursor.fetchall()
    cursor.execute("SELECT * FROM sezona")
    sezone = cursor.fetchall()


    
    conn.close()
    return render_template('financije.html', timovi=timovi, sezone=sezone)

@app.route('/dodaj-trosak', methods=['POST'])
def dodaj_trosak():
    if 'loggedin' not in session or session.get('role') != 'admin':
        return redirect(url_for('login'))

    tim_id = request.form['tim_id']
    kategorija = request.form['kategorija']
    iznos = request.form['iznos']
    sezona = request.form['sezona']

    conn = get_db_connection('admin')
    cursor = conn.cursor()

    try:
        cursor.callproc('dodaj_trosak_timu', [tim_id, sezona, kategorija, iznos])
        conn.commit()
        
        flash('Trošak uspješno proknjižen! Budžet je ažuriran.', 'success')

    except Error as e:
        flash(f'Greška transakcije: {e}', 'danger')
        print(f"SQL Error: {e}")

    conn.close()
    return redirect(url_for('financije'))


@app.route('/statistika')
def statistika():
    user_role = session.get('role', 'public')
    conn = get_db_connection(user_role)
    
    if not conn:
        return "Greška pri spajanju na bazu", 500

    cursor = conn.cursor(dictionary=True)

    sql_timovi = """
        SELECT 
            t.naziv, 
            SUM(p.bodovi) as ukupno_bodova,
            SUM(p.pobjede) as ukupno_pobjeda,
            SUM(p.postolja) as ukupno_postolja
        FROM view_poredak_sezone p
        JOIN vozac v ON p.id_vozac = v.id
        JOIN tim t ON v.id_tim = t.id
        WHERE p.id_sezona = (SELECT MAX(id) FROM sezona)
        GROUP BY t.id
        ORDER BY ukupno_bodova DESC;
    """
    cursor.execute(sql_timovi)
    timovi = cursor.fetchall()

    timovi_labels = [t['naziv'] for t in timovi]
    timovi_bodovi = [t['ukupno_bodova'] for t in timovi]

    sql_vozaci = """
        SELECT 
            v.ime, v.prezime, t.naziv AS tim, 
            p.bodovi, p.pobjede, p.postolja, p.mjesto
        FROM view_poredak_sezone p
        JOIN vozac v ON p.id_vozac = v.id
        JOIN tim t ON v.id_tim = t.id
        WHERE p.id_sezona = (SELECT MAX(id) FROM sezona)
        ORDER BY p.bodovi DESC;
    """
    cursor.execute(sql_vozaci)
    vozaci = cursor.fetchall()

    top_vozaci = vozaci[:10]
    vozaci_labels = [f"{v['ime'][0]}. {v['prezime']}" for v in top_vozaci]
    vozaci_bodovi = [v['bodovi'] for v in top_vozaci]

    sql_kazne = """
        SELECT ime, prezime, tim, broj_kazni, ukupno_sekundi
        FROM view_top_vozaci_po_kaznama
        WHERE id_sezona = (SELECT MAX(id) FROM sezona)
        ORDER BY broj_kazni DESC
        LIMIT 5;
    """
    cursor.execute(sql_kazne)
    kazne = cursor.fetchall()

    conn.close()

    return render_template('statistika.html', 
                           vozaci=vozaci,
                           timovi=timovi,
                           kazne=kazne,
                           timovi_labels=timovi_labels,
                           timovi_bodovi=timovi_bodovi,
                           vozaci_labels=vozaci_labels,
                           vozaci_bodovi=vozaci_bodovi)

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000, debug=True)