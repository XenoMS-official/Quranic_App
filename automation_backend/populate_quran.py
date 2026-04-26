import os
import firebase_admin
from firebase_admin import credentials, firestore
import requests
from requests.adapters import HTTPAdapter
from urllib3.util.retry import Retry
import time

# --- HARDCODED API KEYS & FOLDER IDs ---
GOOGLE_DRIVE_API_KEY = "AIzaSyCPD67w9DxhhyiPuu4zoDy0_Gf3Yj0a67M"
ROOT_FOLDER_ID = "19nEEAnfdFj6W3uQG2YhjgmOfapKSfgsb"

# --- SETUP FIREBASE ---
if not firebase_admin._apps:
    cred = credentials.Certificate('serviceAccountKey.json')
    firebase_admin.initialize_app(cred)
db = firestore.client()

# --- SETUP REQUESTS SESSION WITH RETRY ---
session = requests.Session()
retry_strategy = Retry(
    total=5, 
    status_forcelist=[429, 500, 502, 503, 504], 
    allowed_methods=["HEAD", "GET", "OPTIONS"],
    backoff_factor=1 
)
adapter = HTTPAdapter(max_retries=retry_strategy)
session.mount("https://", adapter)
session.mount("http://", adapter)

QARI_MAPPING = {
    "ar.abdulbasitmurattal": "assets/images/AbdulBasit.png",
    "ar.abdullahbasfar": "assets/images/abdullah-basfar.jpg",
    "ar.abdulsamad": "assets/images/AbdulSamad.jpg",
    "ar.shaatree": "assets/images/AbuBakarAshShatray.jpg",
    "ar.ahmedajamy": "assets/images/AhmedIbneAliALJamay.jpg",
    "ar.alafasy": "assets/images/Alfasay.jpg",
    "ar.aymansowaid": "assets/images/AymanSowaid.jpg",
    "ar.hanirifai": "assets/images/HaniRifai.jpg",
    "ar.hudhaify": "assets/images/Hudhaify.jpg",
    "ar.husary": "assets/images/Husary.jpg",
    "ar.husarymujawwad": "assets/images/HusaryMujawad.jpg",
    "ar.ibrahimakhdar": "assets/images/ibrahimAkhdar.jpg",
    "ar.mahermuaiqly": "assets/images/mahirAlMuaiqly.jpg",
    "ar.minshawi": "assets/images/minshwai.jpg",
    "ar.minshawimujawwad": "assets/images/minshwaymujjawad.jpg",
    "ar.muhammadayyoub": "assets/images/MuhammadAyyoub.jpg",
    "ar.muhammadjibreel": "assets/images/MuhammadJibreel.jpg",
    "ar.parhizgar": "assets/images/Parhizgar.jpg",
    "ar.saoodshuraym": "assets/images/Saud Bin Ibrahim Al shuraim.jpg",
    "ar.abdurrahmaansudais": "assets/images/Sudais.jpg"
}

def sync_reciters():
    print("🎙️ PHASE 1: Syncing 80+ Qaris (Reciters)...")
    url = "https://api.alquran.cloud/v1/edition?format=audio&language=ar"
    try:
        response = session.get(url, timeout=15)
        all_reciters = response.json()['data']
        for qari in all_reciters:
            qari_id = qari['identifier']
            qari_data = {
                'identifier': qari_id,
                'name': qari['name'],
                'english_name': qari['englishName'],
                'format': qari['format'],
                'type': qari['type'],
                'image_url': f"https://ui-avatars.com/api/?name={qari['englishName'].replace(' ', '+')}&background=random",
                'local_image': QARI_MAPPING.get(qari_id, "") 
            }
            db.collection('quran_reciters').document(qari_id).set(qari_data)
        print("✅ Qaris sync complete.")
    except Exception as e:
        print(f"❌ Error syncing Qaris: {e}")

def sync_surahs():
    print("\n📖 PHASE 2: Syncing 114 Surahs (Uthmani, Indo-Pak, Translations, WBW & Tajweed)...")
    editions = "quran-uthmani,quran-indo-pak,en.ahmedali,ur.maududi,ar.alafasy"
    
    for surah_num in range(1, 115):
        success = False
        attempts = 0
        
        while not success and attempts < 5:
            try:
                print(f"📦 Processing Surah {surah_num}/114...")
                url = f"https://api.alquran.cloud/v1/surah/{surah_num}/editions/{editions}"
                response = session.get(url, timeout=30).json()['data'] 
                
                arabic_uthmani_data = response[0]
                arabic_indopak_data = response[1]
                english_data = response[2]
                urdu_data = response[3]
                audio_data = response[4]

                quran_com_url = f"https://api.quran.com/api/v4/verses/by_chapter/{surah_num}?words=true&word_fields=text_uthmani,translation,tajweed&per_page=300"
                qc_response = session.get(quran_com_url, timeout=30).json()
                qc_verses = qc_response.get('verses',[])
                qc_dict = {v['verse_key']: v['words'] for v in qc_verses}

                ayahs_list = []
                for i in range(len(arabic_uthmani_data['ayahs'])):
                    verse_number = arabic_uthmani_data['ayahs'][i]['numberInSurah']
                    verse_key = f"{surah_num}:{verse_number}"
                    
                    raw_words = qc_dict.get(verse_key, [])
                    formatted_words =[]
                    for w in raw_words:
                        formatted_words.append({
                            'arabic': w.get('text_uthmani', ''),
                            'english': w.get('translation', {}).get('text', ''),
                            'tajweed': w.get('tajweed', '')
                        })

                    ayah_entry = {
                        'number': verse_number,
                        'text_uthmani': arabic_uthmani_data['ayahs'][i]['text'],
                        'text_indopak': arabic_indopak_data['ayahs'][i]['text'],
                        'text_english': english_data['ayahs'][i]['text'],
                        'text_urdu': urdu_data['ayahs'][i]['text'],
                        'audio_url': audio_data['ayahs'][i]['audio'],
                        'words': formatted_words
                    }
                    ayahs_list.append(ayah_entry)

                surah_doc = {
                    'surah_number': surah_num,
                    'name_arabic': arabic_uthmani_data['name'],
                    'name_english': arabic_uthmani_data['englishName'],
                    'english_meaning': arabic_uthmani_data['englishNameTranslation'],
                    'revelation_type': arabic_uthmani_data['revelationType'],
                    'total_ayahs': len(ayahs_list),
                    'ayahs': ayahs_list 
                }

                sequential_id = str(surah_num).zfill(3)
                db.collection('quran_surahs').document(sequential_id).set(surah_doc)
                
                success = True 
                time.sleep(0.5) 

            except Exception as e:
                attempts += 1
                print(f"   ⚠️ Network error on Surah {surah_num} (Attempt {attempts}/5): {e}")
                time.sleep(2 * attempts) 
                
        if not success:
            print(f"❌ Failed Surah {surah_num} completely after 5 attempts. Skipping.")
            
    print("✅ Surah sync complete.")

def clear_old_resources():
    print("🧹 Cleaning up old Ghost files from the database...")
    try:
        docs = db.collection('quran_resources').stream()
        count = 0
        for doc in docs:
            doc.reference.delete()
            count += 1
        print(f"✅ Successfully deleted {count} old entries.")
    except Exception as e:
        print(f"⚠️ Error cleaning collection: {e}")

def sync_drive_resources(folder_id, api_key, current_path=""):
    if not api_key: return
    print(f"📂 Scanning Folder: {current_path or 'Root Folder'}")
    
    url = "https://www.googleapis.com/drive/v3/files"
    query = f"'{folder_id}' in parents and trashed = false"
    params = {
        'q': query,
        'key': api_key,
        'fields': "files(id, name, mimeType)",
        'pageSize': 1000,
        'orderBy': 'name'
    }
    
    attempts = 0
    while attempts < 3:
        try:
            response = session.get(url, params=params, timeout=20).json()
            if 'error' in response:
                print(f"❌ Google API Error: {response['error']['message']}")
                return

            files = response.get('files',[])
            
            for f in files:
                mime_type = f.get('mimeType', '')
                file_id = f.get('id', '')
                file_name = f.get('name', '')
                
                if mime_type == 'application/vnd.google-apps.folder':
                    db.collection('quran_resources').document(file_id).set({
                        'title': file_name,
                        'type': 'folder',
                        'folder_path': current_path,
                        'drive_url': ''
                    })
                    sync_drive_resources(file_id, api_key, current_path + file_name + "/")
                
                # ONLY syncing Audio and PDF files. Any other type is ignored.
                elif mime_type.startswith('audio/') or mime_type == 'application/pdf':
                    res_type = 'audio' if mime_type.startswith('audio/') else 'pdf'
                    
                    # Direct download URL with acknowledgeAbuse=true to bypass Google Drive limits on large files
                    direct_url = f"https://www.googleapis.com/drive/v3/files/{file_id}?alt=media&key={api_key}&acknowledgeAbuse=true"
                    res_data = {
                        'title': file_name.replace('.mp3', '').replace('.pdf', '').replace('.m4a', ''),
                        'type': res_type,
                        'drive_url': direct_url,
                        'folder_path': current_path,
                        'mime_type': mime_type
                    }
                    
                    db.collection('quran_resources').document(file_id).set(res_data)
                    print(f"   ✅ Saved[{res_type.upper()}]: {file_name}")
            
            break 
                    
        except Exception as e:
            attempts += 1
            print(f"   ⚠️ Error scanning drive folder {current_path} (Attempt {attempts}/3): {e}")
            time.sleep(2)

if __name__ == "__main__":
    start_time = time.time()
    
    sync_reciters()
    sync_surahs()
    
    print("\n📁 PHASE 3: Dynamically Syncing Google Drive Resources...")
    if not GOOGLE_DRIVE_API_KEY:
        print("⚠️ ERROR: Google Drive API Key is missing!")
    else:
        clear_old_resources() # Wipes ghost files before adding fresh ones
        sync_drive_resources(ROOT_FOLDER_ID, GOOGLE_DRIVE_API_KEY)
        
    end_time = time.time()
    duration = round((end_time - start_time) / 60, 2)
    print(f"\n🚀 ALL DATA SYNCED! Total time: {duration} minutes.")