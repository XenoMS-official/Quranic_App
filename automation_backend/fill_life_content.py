import os
import firebase_admin
from firebase_admin import credentials, firestore
import requests
import datetime
from hijridate import Gregorian
import re
import random
from googleapiclient.discovery import build

# --- SETUP FIREBASE ---
if not firebase_admin._apps:
    cred = credentials.Certificate("serviceAccountKey.json")
    firebase_admin.initialize_app(cred)
db = firestore.client()

# --- HARDCODED API KEYS ---
HADITH_API_KEY = "$2y$10$7pxAs5ypGrY3VU1oDVcA4DrkXwfcAwmN0y3eT9CIzUAQkbS7vY2"
GOOGLE_DRIVE_API_KEY = "AIzaSyCPD67w9DxhhyiPuu4zoDy0_Gf3Yj0a67M"

# Initialize Drive Service for Audio Library syncing
drive_service = None
if GOOGLE_DRIVE_API_KEY:
    drive_service = build('drive', 'v3', developerKey=GOOGLE_DRIVE_API_KEY)


def get_hijri_date():
    today = datetime.date.today()
    h = Gregorian(today.year, today.month, today.day).to_hijri()
    return f"{h.day} {h.month_name()} {h.year} AH"

def clean_html(raw_html):
    if not raw_html: return ""
    return re.sub('<.*?>', '', raw_html).strip()

def delete_collection(coll_ref):
    for doc in coll_ref.stream():
        doc.reference.delete()

# ==========================================
# BATCH MANAGER FOR DRIVE AUDIO FOLDERS
# ==========================================
class BatchManager:
    def __init__(self, db):
        self.db = db
        self.batch = db.batch()
        self.count = 0

    def set(self, doc_ref, data):
        self.batch.set(doc_ref, data)
        self.count += 1
        self._check_commit()

    def delete(self, doc_ref):
        self.batch.delete(doc_ref)
        self.count += 1
        self._check_commit()

    def _check_commit(self):
        if self.count >= 400:
            self.commit()

    def commit(self):
        if self.count > 0:
            self.batch.commit()
            self.batch = self.db.batch()
            self.count = 0

def clear_collection_batch(collection_ref):
    docs = collection_ref.stream()
    batch_manager = BatchManager(db)
    count = 0
    for doc in docs:
        batch_manager.delete(doc.reference)
        count += 1
    batch_manager.commit()
    if count > 0:
        print(f"    🧹 Cleared {count} old documents from: '{collection_ref.id}'")

# ==========================================
# 1. HOMEPAGE SYNC
# ==========================================
def sync_homepage():
    print("📡 Step 1: Syncing Homepage Data (Ayah, Quote, Hadith)...")
    today_seed = datetime.date.today().toordinal()
    random.seed(today_seed)

    # 1. AYAH
    try:
        ayah_num = random.randint(1, 6236)
        ayah_url = f"http://api.alquran.cloud/v1/ayah/{ayah_num}/editions/quran-uthmani,en.asad"
        ayah_res = requests.get(ayah_url, timeout=10).json()
        arabic_ayah = ayah_res['data'][0]['text']
        english_ayah = ayah_res['data'][1]['text']
        ayah_reference = f"({ayah_res['data'][0]['surah']['number']}:{ayah_res['data'][0]['numberInSurah']})"
    except:
        arabic_ayah, english_ayah, ayah_reference = "إِنَّ مَعَ الْعُسْرِ يُسْرًا", "Indeed, with hardship [will be] ease.", "(94:6)"

    # 2. QUOTE
    try:
        quote_res = requests.get("https://zenquotes.io/api/today", timeout=10).json()
        quote_text = f'"{quote_res[0]["q"]} — {quote_res[0]["a"]}"'
    except:
        quote_text = '"I can live without money, but I cannot live without love. — Judy Garland"'

    # 3. HADITH
    try:
        hadith_page = random.randint(1, 1000)
        h_url = f"https://hadithapi.com/api/hadiths?apiKey={HADITH_API_KEY}&paginate=1&page={hadith_page}"
        h_res = requests.get(h_url, timeout=15).json()
        h = h_res.get('hadiths', {}).get('data', [])[0]
        daily_hadith_arabic = clean_html(h.get('hadithArabic', ''))
        daily_hadith_english = clean_html(h.get('hadithEnglish', ''))
        daily_hadith_ref = f"({h.get('bookName', 'Hadith')})"
    except:
        daily_hadith_arabic, daily_hadith_english, daily_hadith_ref = "الدُّعَاءُ هُوَ الْعِبَادَةُ", "Dua (supplication) is worship.", "(Abu Dawud)"

    # SAVE TO FIREBASE
    db.collection("app_data").document("homepage").set({
        "english_date": datetime.datetime.now().strftime("%A, %b %d"),
        "islamic_date": get_hijri_date(),
        "verse_arabic": arabic_ayah, "verse_translation": english_ayah, "verse_reference": ayah_reference,
        "quote_text": quote_text,
        "hadith_arabic": daily_hadith_arabic, "hadith_translation": daily_hadith_english, "hadith_reference": daily_hadith_ref,
        "updatedAt": firestore.SERVER_TIMESTAMP
    }, merge=True)
    print("✅ Homepage Synced!")

# ==========================================
# 2. DUAS SYNC
# ==========================================
def sync_unified_duas():
    print("📡 Step 2: Syncing authentic Duas into ONE collection (via HadithAPI)...")
    dua_ref = db.collection("all_duas")
    delete_collection(dua_ref)
    
    search_terms =["morning", "evening", "health", "travel", "forgiveness", "success", "protection", "parents"]
    count = 0

    for term in search_terms:
        try:
            h_url = f"https://hadithapi.com/api/hadiths?apiKey={HADITH_API_KEY}&hadithEnglish={term}&paginate=15"
            h_res = requests.get(h_url, timeout=15).json()
            hadiths = h_res.get('hadiths', {}).get('data',[])
            
            for h in hadiths:
                chapter_title = h.get('chapter', {}).get('chapterEnglish') 
                if not chapter_title:
                    chapter_title = f'Supplication regarding {term.capitalize()}'
                    
                dua_ref.document(f"dua_{count}").set({
                    "title": clean_html(chapter_title),
                    "purpose": f"Dua for {term.capitalize()}",
                    "arabic": clean_html(h.get('hadithArabic')),
                    "translation": clean_html(h.get('hadithEnglish')),
                    "reference": h.get('bookName', 'Authentic Hadith'),
                    "search_keywords": [term.lower(), clean_html(h.get('hadithEnglish')).lower()]
                })
                count += 1
        except Exception as e:
            print(f" ⚠️ Error fetching {term}: {e}")
            
    print(f"✅ Synced {count} authentic Duas into the 'all_duas' collection.")

# ==========================================
# 3. GOOGLE DRIVE MODULES SYNC
# ==========================================
def fetch_drive_folder_contents(folder_id):
    """Recursively fetches items from a Google Drive folder. Keeps PDFs, Audio files, Folders."""
    if not GOOGLE_DRIVE_API_KEY:
        return[{"name": "Error: API Key Missing", "type": "pdf", "url": ""}]

    url = f"https://www.googleapis.com/drive/v3/files?q='{folder_id}'+in+parents&key={GOOGLE_DRIVE_API_KEY}&fields=files(id,name,mimeType)"
    
    try:
        res = requests.get(url).json()
        files = res.get('files', [])
        valid_items =[]
        
        for f in files:
            mime = f.get('mimeType', '')
            name = f['name']
            file_id = f['id']
            
            if mime == 'application/pdf':
                valid_items.append({
                    "name": name.replace('.pdf', ''),
                    "type": "pdf",
                    "url": f"https://drive.google.com/uc?export=download&id={file_id}"
                })
            elif mime.startswith('audio/'):
                valid_items.append({
                    "name": name.replace('.mp3', '').replace('.wav', ''),
                    "type": "audio",
                    "url": f"https://drive.google.com/uc?export=download&id={file_id}"
                })
            elif mime == 'application/vnd.google-apps.folder':
                sub_contents = fetch_drive_folder_contents(file_id)
                valid_items.append({
                    "name": name,
                    "type": "folder",
                    "subfolders": sub_contents
                })
            else:
                continue
                
        return valid_items
    except Exception as e:
        print(f"⚠️ Error fetching from Drive ID {folder_id}: {e}")
        return[]

def sync_drive_modules():
    print("📡 Step 3: Fetching Tareeka, Sunnah, and Ebook Folders from Google Drive...")
    
    if not GOOGLE_DRIVE_API_KEY:
        print("❌ STOPPING STEP 3: Google Drive API Key is missing!")
        return

    modules_ref = db.collection("islamic_modules")
    delete_collection(modules_ref)
    
    main_folders =[
        {"id": "1", "title": "Tareeka", "drive_id": "1hHvmZBa1nl4X3Q4521U00Csz8P_jTt9-"},
        {"id": "2", "title": "Sunnah", "drive_id": "1hNoEWDiMATKqIxXc3BvbVN05ZO8VMz6L"},
        {"id": "3", "title": "Ebooks", "drive_id": "1GjIWs1nCYelplrIi3hLYzwfzUCtXejU7"}
    ]

    for f in main_folders:
        print(f"   -> Fetching contents for {f['title']}...")
        folder_contents = fetch_drive_folder_contents(f['drive_id'])
        
        modules_ref.document(f["id"]).set({
            "id": f["id"],
            "title": f["title"],
            "subfolders": folder_contents
        })
        
    print("✅ Drive Learning Modules mapped to UI!")

# ==========================================
# 4. AUDIO LIBRARY SYNC
# ==========================================
def process_drive_audio_folder(folder_id, folder_name, parent_id, batch_manager, collection_ref):
    if not drive_service: return
    print(f"  -> Processing Drive Folder: {folder_name}")
    
    doc_ref = collection_ref.document(folder_id)
    batch_manager.set(doc_ref, {
        "id": folder_id,
        "name": folder_name,
        "type": "folder",
        "parentId": parent_id
    })

    page_token = None
    while True:
        try:
            results = drive_service.files().list(
                q=f"'{folder_id}' in parents and trashed=false",
                fields="nextPageToken, files(id, name, mimeType)",
                pageSize=1000,
                pageToken=page_token
            ).execute()
            
            items = results.get('files',[])
            
            for item in items:
                mime = item.get('mimeType', '')
                if mime == 'application/vnd.google-apps.folder':
                    process_drive_audio_folder(item['id'], item['name'], folder_id, batch_manager, collection_ref)
                else: 
                    audio_ref = collection_ref.document(item['id'])
                    batch_manager.set(audio_ref, {
                        "id": item['id'],
                        "name": item['name'],
                        "type": "audio",
                        "parentId": folder_id
                    })
            
            page_token = results.get('nextPageToken')
            if not page_token:
                break 

        except Exception as e:
            print(f"     [!] Error reading folder {folder_name}: {e}")
            break

def sync_audio_library():
    print("📡 Step 4: Syncing Audio Library (Naats, Durood, Speeches) into Database...")
    if not drive_service:
        print("❌ STOPPING STEP 4: Google Drive API Key is missing for Audio sync!")
        return

    drive_roots =[
        {"name": "QASIDA BURDA & Ghousia SHAREEF", "id": "1RTmCLKb-6dzfz6HPseWLlkofp6_NGIUI"},
        {"name": "Naat Shareef", "id": "1HgtPfakatBSExhM2b2bdGeXcWPR8Uyaf"},
        {"name": "Mix Kalaam", "id": "11Ax5od9AXUULORx5vBr4T_mr93CqpBWa"},
        {"name": "Mankabat Shareef", "id": "10iAvX5oJXgrIT2xetBVhuLDmPJBr4crj"},
        {"name": "HAMD SHAREEF", "id": "1c71OQx6tl-oXTkzbBHS5Q8sqfz6IK_N7"},
        {"name": "EID -e- MILAD-UN-NABI KALAM", "id": "1ylS_aR-CGNo5ucAEBFM286co0NuH_hN7"},
        {"name": "DUROOD -o- SALAAM", "id": "1I9LYCOPA2S4LD7QQAQgtCH1iUxeJU8_L"},
        {"name": "BEST TAKREERS Or Speeches", "id": "1W83mWNmjnFHaDrP__pLS3TOqODxRKYkk"}
    ]

    drive_collection_ref = db.collection("kids_zone").document("nasheeds").collection("drive_items")

    print("[PHASE 0] Wiping existing Audio data...")
    clear_collection_batch(drive_collection_ref)

    print(f"   [PHASE 1] Fetching & Uploading Google Drive Audios...")
    drive_batch = BatchManager(db)
    
    for root in drive_roots:
        process_drive_audio_folder(root['id'], root['name'], "root", drive_batch, drive_collection_ref)
    
    drive_batch.commit()
    print("✅ Audio Library Synced perfectly!")


if __name__ == "__main__":
    sync_homepage()
    sync_unified_duas()
    sync_drive_modules()
    sync_audio_library()
    print("\n🚀 DONE! Database fully updated to match the new UI.")