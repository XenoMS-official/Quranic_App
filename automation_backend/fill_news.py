import os
import firebase_admin
from firebase_admin import credentials, firestore
import requests
import sys
import hashlib
from datetime import datetime
import googleapiclient.discovery
from googleapiclient.errors import HttpError

# ==========================================
# 0. HARDCODED API KEYS
# ==========================================
YOUTUBE_API_KEYS = [
    "AIzaSyCPD67w9DxhhyiPuu4zoDy0_Gf3Yj0a67M",
    "AIzaSyA5AixRjTXy45abUTwuOzwGO18kzLZKHmo"
]
YOUTUBE_API_KEYS = [k for k in YOUTUBE_API_KEYS if k and k.strip() != ""]

current_yt_key_index = 0

def get_youtube_service():
    """Builds the YouTube service using the current key index."""
    if not YOUTUBE_API_KEYS:
        return None
    return googleapiclient.discovery.build("youtube", "v3", developerKey=YOUTUBE_API_KEYS[current_yt_key_index])

def rotate_youtube_key():
    """Switches to the next available key. Returns True if successful."""
    global current_yt_key_index
    if current_yt_key_index < len(YOUTUBE_API_KEYS) - 1:
        current_yt_key_index += 1
        print(f"🔄 YouTube Limit reached! Switched to API Key {current_yt_key_index + 1}")
        return True
    print("❌ All YouTube API keys exhausted.")
    return False

# ==========================================
# 1. SETUP FIREBASE
# ==========================================
if not firebase_admin._apps:
    try:
        cred = credentials.Certificate("serviceAccountKey.json")
        firebase_admin.initialize_app(cred)
    except Exception as e:
        print(f"Firebase Init Error: {e}")
        sys.exit(1)
db = firestore.client()

KEYS = {
    "NEWS_API": "d2db2c5ef30048108ce1a78abaf89ba5",
    "GNEWS": "c35bea552bd6baf2aea5e52878f81aac",
    "GUARDIAN": "40ab5a76-9752-4227-8ff5-ee8b437d40e0"
}

ARTICLE_LIMIT = 30

CATEGORIES = {
    "Global News": {"news_cat": "general", "q": "world news"},
    "Islamic World": {"news_cat": "general", "q": "Islamic world OR Muslim world"},
    "Palestine Updates": {"news_cat": "general", "q": "Palestine OR Gaza"},
    "Tech": {"news_cat": "technology", "q": "technology"},
    "Business": {"news_cat": "business", "q": "business"},
    "Sports": {"news_cat": "sports", "q": "sports"},
    "Health": {"news_cat": "health", "q": "health"},
    "Science": {"news_cat": "science", "q": "science"},
    "Education": {"news_cat": "general", "q": "education"},
    "Food": {"news_cat": "general", "q": "food OR cooking"},
    "Travel": {"news_cat": "general", "q": "travel OR tourism"},
}

SPORTS_CHANNELS = {
    "Fighting & Combat": [
        {"name": "UFC - Ultimate Fighting Championship", "id": "UCvgfXK4nTYKudb0rFR6noLA"},
        {"name": "ONE Championship", "id": "UCiormkBf3jm6mfb7k0yPbKA"}
    ],
    "Team & Individual": [
        {"name": "Dude Perfect", "id": "UCRijo3ddMTht_IHyNSNXpNQ"},
        {"name": "Red Bull", "id": "UCblfuW_4rakIf2h6aqANefA"},
        {"name": "Sky Sports", "id": "UCNAf1k0yIjyGu3k9BwAg3lg"},
        {"name": "UR Cristiano", "id": "UCtxD0x6AuNNqdXO9Wp5GHew"}
    ],
    "Swimming": [
        {"name": "Olympics", "id": "UCTl3QQTvqHFjurroKxexy2Q"},
        {"name": "Global Swimming Network", "id": "UCki3xw9o42vVpvwa3wlmw8g"}
    ],
    "Cricket": [
        {"name": "Sony Sports", "id": "UC_WKb6N9iTGc77hxwXLDrbA"},
        {"name": "Ten Sports", "id": "UCuUf2bNcm72w7JVZLLLZ4Ww"}
    ]
}

def upload_to_firestore(articles, ui_name, source_name):
    batch = db.batch()
    batch_count = 0
    total_uploaded = 0
    for art in articles:
        title = art.get("title") or art.get("webTitle")
        url = art.get("url") or art.get("webUrl")
        fields = art.get("fields", {})
        img = art.get("urlToImage") or art.get("image") or fields.get("thumbnail") or "https://picsum.photos/400/200"
        desc = art.get("description") or art.get("snippet") or fields.get("trailText") or ""
        
        pub_date_str = art.get("publishedAt") or art.get("webPublicationDate")
        try:
            pub_dt = datetime.fromisoformat(pub_date_str.replace('Z', '+00:00'))
        except Exception:
            pub_dt = firestore.SERVER_TIMESTAMP

        if not title or "[Removed]" in title or not url: continue

        url_hash = hashlib.md5(url.encode('utf-8')).hexdigest()
        
        doc_ref = db.collection("news").document(url_hash)
        batch.set(doc_ref, {
            "title": title,
            "description": desc,
            "thumbnailUrl": img,
            "category": ui_name, 
            "url": url,          
            "source": source_name,
            "publishedAt": pub_dt
        }, merge=True)
        
        batch_count += 1
        total_uploaded += 1
        if batch_count % 400 == 0:
            batch.commit()
            batch = db.batch()
            batch_count = 0
    
    if batch_count > 0:
        batch.commit()
    print(f"✅ Uploaded {total_uploaded} '{ui_name}' news via {source_name}.")

def fetch_and_upload():
    print("\n📰 Fetching News...")
    for ui_name, params in CATEGORIES.items():
        try:
            if ui_name in ["Global News", "Tech", "Business", "Sports", "Health", "Science"]:
                url = f"https://newsapi.org/v2/top-headlines?category={params['news_cat']}&language=en&pageSize={ARTICLE_LIMIT}&apiKey={KEYS['NEWS_API']}"
            else:
                url = f"https://newsapi.org/v2/everything?q={params['q']}&language=en&sortBy=publishedAt&pageSize={ARTICLE_LIMIT}&apiKey={KEYS['NEWS_API']}"
            res = requests.get(url).json()
            if res.get("status") == "ok" and res.get("articles"):
                upload_to_firestore(res["articles"][:ARTICLE_LIMIT], ui_name, "NewsAPI")
                continue 
        except Exception:
            pass

def fetch_youtube_sports():
    print("\n🥊 Fetching YouTube Sports Content...")
    youtube = get_youtube_service()
    if not youtube:
        print("❌ No YouTube API Keys configured.")
        return
        
    for category_name, channels in SPORTS_CHANNELS.items():
        for ch in channels:
            success = False
            while not success:
                try:
                    channel_id = ch["id"]
                    uploads_playlist_id = "UU" + channel_id[2:] if channel_id.startswith("UC") else channel_id
                    
                    res = youtube.playlistItems().list(
                        part="snippet",
                        playlistId=uploads_playlist_id,
                        maxResults=10
                    ).execute()
                    
                    videos_uploaded = 0
                    for item in res.get("items", []):
                        snippet = item["snippet"]
                        if 'thumbnails' not in snippet or 'high' not in snippet['thumbnails']:
                            continue
                            
                        video_id = snippet["resourceId"]["videoId"]
                        published_str = snippet["publishedAt"]
                        
                        try:
                            published_dt = datetime.fromisoformat(published_str.replace('Z', '+00:00'))
                        except Exception:
                            published_dt = firestore.SERVER_TIMESTAMP
                        
                        db.collection("video_hub").document(video_id).set({
                            "video_id": video_id,
                            "title": snippet["title"],
                            "description": snippet["description"],
                            "thumbnail": snippet["thumbnails"]["high"]["url"],
                            "channel_name": ch["name"],
                            "section": "video",
                            "type": "sports",
                            "theme": category_name,
                            "view_count": 1000,
                            "like_count": 100,
                            "published_at": published_str,
                            "timestamp": published_dt
                        }, merge=True)
                        videos_uploaded += 1
                    
                    print(f"    ✅ Downloaded {videos_uploaded} videos for {ch['name']}")
                    success = True 
                    
                except HttpError as e:
                    if e.resp.status in [403, 429]: 
                        if rotate_youtube_key():
                            youtube = get_youtube_service() 
                            continue 
                        else:
                            print("❌ Stop: No more keys to try.")
                            return
                    else:
                        print(f"    ⚠️ HTTP Error for {ch['name']}: {e}")
                        break 
                except Exception as e:
                    print(f"    ⚠️ Error fetching {ch['name']}: {e}")
                    break

if __name__ == "__main__":
    fetch_and_upload()
    fetch_youtube_sports()
    print("\n✅ DONE! News & Sports sync completed.")