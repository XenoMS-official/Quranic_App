import os
import firebase_admin
from firebase_admin import credentials, firestore
from googleapiclient.discovery import build
from googleapiclient.errors import HttpError 
import sys
from datetime import datetime

# ==========================================
# 0. ON/OFF SWITCHES
# ==========================================
SYNC_YOUTUBE = True  

# ==========================================
# 1. SETUP FIREBASE
# ==========================================
try:
    cred = credentials.Certificate("serviceAccountKey.json")
    firebase_admin.initialize_app(cred)
    db = firestore.client()
except Exception as e:
    print(f"Firebase Initialization Error: {e}")
    sys.exit(1)

# ==========================================
# 2. SETUP APIs with Rotation Logic
# ==========================================
YOUTUBE_API_KEYS = [
    "AIzaSyCPD67w9DxhhyiPuu4zoDy0_Gf3Yj0a67M",
    "AIzaSyA5AixRjTXy45abUTwuOzwGO18kzLZKHmo"
]
YOUTUBE_API_KEYS = [k for k in YOUTUBE_API_KEYS if k]

if not YOUTUBE_API_KEYS:
    print("❌ ERROR: No YouTube API keys found.")
    sys.exit(1)

current_yt_key_index = 0

def build_youtube_service():
    global current_yt_key_index
    if current_yt_key_index < len(YOUTUBE_API_KEYS):
        return build('youtube', 'v3', developerKey=YOUTUBE_API_KEYS[current_yt_key_index])
    return None

if SYNC_YOUTUBE:
    youtube = build_youtube_service()

# ==========================================
# 3. BATCH MANAGER
# ==========================================
class BatchManager:
    def __init__(self, db):
        self.db = db
        self.batch = db.batch()
        self.count = 0

    def set(self, doc_ref, data, merge=True):
        self.batch.set(doc_ref, data, merge=merge)
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

# ==========================================
# 4. YOUTUBE LOGIC (Optimized for Quota)
# ==========================================
def get_recent_videos(channel_id, max_results=20):
    global youtube, current_yt_key_index
    if not youtube: return []

    try:

        uploads_playlist_id = "UU" + channel_id[2:] if channel_id.startswith("UC") else channel_id

        request = youtube.playlistItems().list(
            part="snippet",
            playlistId=uploads_playlist_id,
            maxResults=max_results
        )
        response = request.execute()
        
        videos = []
        sync_time = datetime.now() 
        for item in response.get('items', []):
            snippet = item['snippet']
            title = snippet['title']
            
            # Extract videoId from resourceId
            v_id = snippet.get('resourceId', {}).get('videoId')
            if not v_id: continue

            videos.append({
                "videoId": v_id,
                "title": title,
                "thumbnail": snippet['thumbnails'].get('high', {}).get('url', ''),
                "publishedAt": snippet['publishedAt'],
                "syncedAt": sync_time,
                "channelId": channel_id,
                "isShort": "#shorts" in title.lower() or "short" in title.lower()
            })
        return videos
        
    except HttpError as e:
        if e.resp.status in [403, 429]:
            # FIXED: Added boundary check for index
            if current_yt_key_index < len(YOUTUBE_API_KEYS) - 1:
                print(f"    ⚠️ Quota exceeded for Key {current_yt_key_index + 1}. Rotating...")
                current_yt_key_index += 1
                youtube = build_youtube_service()
                return get_recent_videos(channel_id, max_results) # Retry
            else:
                print(f"    ❌ All API keys exhausted.")
                return []
        else:
            print(f"    ⚠️ HTTP Error: {e.resp.status}")
            return []
    except Exception as e:
        print(f"    ⚠️ General Error: {e}")
        return []

# ==========================================
# 5. MAIN SYNC ROUTINE
# ==========================================
def sync_kids_zone():
    print("🚀 Starting Kids Zone Incremental Sync...")

    if SYNC_YOUTUBE:
        yt_data = {
            "animated_stories": [
                {"name": "Stories of the Prophets", "id": "UCvWyP-vFhlS1-XENpD6w68A", "handle": "@StoriesoftheProphets"},
                {"name": "IQRA CARTOON", "id": "UCSL4Dn-FQlvHZiSKipQZMqw", "handle": "@IqraCartoon"},
                {"name": "Noor Kids", "id": "UC1l6sC1nwdBIA06FTcnVKbg", "handle": "@NoorKids"},
                {"name": "Muslim Kids Magical Moral Stories", "id": "UCDCSi8bvaXpRSgFmE35Xskg", "handle": "@MuslimKidsMagicalMoralStories"}
            ],
            "cartoons": [
                {"name": "Omar & Hana", "id": "UC178EmfQAV3OT-UpuO6WUMg", "handle": "@OmarAndHana"},
                {"name": "Cocomelon", "id": "UCbCmjCuTUZos6Inko4u57UQ", "handle": "Cocomelon"},
                {"name": "One4kids", "id": "UC5vfWTTPnKdFp-8s0KbqJhw", "handle": "@ZakyOne4kids"},
                {"name": "MUSLIM REMINDER KIDS", "id": "UCUUQonfh_yNkI6h0O2a6nRA", "handle": "@MuslimReminderKids"}
            ]
        }

        print("\n[INFO] Preserving old data. Fetching newest updates...")

        for category, channels in yt_data.items():
            print(f"\n--- Category: {category.upper()} ---")
            category_ref = db.collection("kids_zone").document(category)
            category_ref.set({"title": category.replace("_", " ").title()}, merge=True)
            
            for channel in channels:
                print(f"Checking: {channel['name']}...")
                channel_ref = category_ref.collection("channels").document(channel['id'])
                channel_ref.set({
                    "name": channel['name'],
                    "handle": channel['handle'],
                    "channelId": channel['id']
                }, merge=True)

                vids = get_recent_videos(channel['id'], max_results=20)
                if not vids: continue

                yt_batch = BatchManager(db)
                video_collection = channel_ref.collection("videos")
                for v in vids:
                    doc_ref = video_collection.document(v['videoId'])
                    yt_batch.set(doc_ref, v) 
                yt_batch.commit()
                print(f"    ✅ Synced {len(vids)} items.")
                
    print("\n✅ [SUCCESS]: Kids Zone is updated. All old data remains safely in Firestore.")

if __name__ == "__main__":
    sync_kids_zone()