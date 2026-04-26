import os
import requests
import firebase_admin
from firebase_admin import credentials, firestore
import sys
import re
from datetime import datetime

# --- HARDCODED YOUTUBE KEYS ---
YOUTUBE_API_KEYS = [
    "AIzaSyCPD67w9DxhhyiPuu4zoDy0_Gf3Yj0a67M",
    "AIzaSyA5AixRjTXy45abUTwuOzwGO18kzLZKHmo"
]
YOUTUBE_API_KEYS = [k for k in YOUTUBE_API_KEYS if k]

if not YOUTUBE_API_KEYS:
    print("❌ ERROR: No YouTube API keys found in environment variables.")
    sys.exit(1)

current_key_index = 0

def get_key():
    global current_key_index
    if current_key_index < len(YOUTUBE_API_KEYS):
        return YOUTUBE_API_KEYS[current_key_index]
    else:
        print("❌ CRITICAL: Attempted to access key out of range.")
        return None

def rotate_key():
    global current_key_index
    if current_key_index < len(YOUTUBE_API_KEYS) - 1:
        current_key_index += 1
        print(f"🔄 Limit reached! Switched to API Key {current_key_index + 1}")
        return True
    else:
        print("❌ All API keys exhausted. Cannot rotate further.")
        return False

# --- SETUP FIREBASE ---
if not firebase_admin._apps:
    try:
        cred = credentials.Certificate("serviceAccountKey.json")
        firebase_admin.initialize_app(cred)
    except Exception as e:
        print(f"Firebase Init Error: {e}")
        sys.exit(1)
db = firestore.client()

# --- 1. INDIVIDUAL LIVE STREAMS & VIDEOS ---
INDIVIDUAL_VIDEOS = [
    {"id": "6y-xI8UjGno", "theme": "Dawate Islami Live"},
    {"id": "A9AdcR7i_Kc", "theme": "Dawate Islami Live"},
    {"id": "eqYNCEUdaxE", "theme": "Makkah & Madina Live"},
    {"id": "rHWSRMcGGBQ", "theme": "Quran Tv By Language"},
    {"id": "_5IGtBdAFXM", "theme": "Quran Tv By Language"},
    {"id": "OeGVfM8hacs", "theme": "Islamic TV Channels"},
    {"id": "dXxh8tmUimc", "theme": "Islamic TV Channels"},
    {"id": "FKnSnkzc8yc", "theme": "Islamic TV Channels"},
    {"id": "XMO-n692Hj8", "theme": "Islamic TV Channels"},
    {"id": "LkrHJy8J8Cc", "theme": "Islamic Streams"},
    {"id": "7-Qf3g-0xEI", "theme": "Islamic Streams"},
    {"id": "TpT8b8JFZ6E", "theme": "Islamic Streams"},
    {"id": "Z5zh5QCsjYY", "theme": "Islamic Streams"},
    {"id": "dtzRy8ZisBE", "theme": "Islamic Streams"},
    {"id": "9zK54w4n5B0", "theme": "Islamic Streams"},
    {"id": "euAVU9aWuJk", "theme": "Islamic Streams"},
    {"id": "pDrOCDI3NZo", "theme": "Islamic Streams"},
    {"id": "a_PJIoQ2C4k", "theme": "Islamic Streams"},
    {"id": "A9Ky_iOfj3s", "theme": "Islamic Streams"},
    {"id": "ARC8BNPANaI", "theme": "Islamic Streams"},
    {"id": "hbTncC3wV3k", "theme": "Islamic Streams"},
    {"id": "3bsskekN0j8", "theme": "Islamic Streams"},
]

# --- 2. CHANNEL DATABASE ---
CHANNELS = [
    {"id": "UCzH1EwXwDkIf5b7tLvepLwA", "theme": "Mufti Menk"},
    {"id": "UC3vHW2h22WE-pNi5WJtRIjg", "theme": "Merciful Servant"},
    {"id": "UCLH52eKqlMTtTowsMDcQA-A", "theme": "Yaqeen Institute"},
    {"id": "UCct5L-DaVYK8UtmqGU8gJtw", "theme": "Pakistan & India Scholars"},
    {"id": "UCGpZzdvM0olSiiLpjbLVQjA", "theme": "Pakistan & India Scholars"},
    {"id": "UCBj6SU_o5wZQJbZJZSkVzOw", "theme": "Pakistan & India Scholars"},
    {"id": "UCThbMTLFbeDGrZlb9DnTKDg", "theme": "Pakistan & India Scholars"},
    {"id": "UChE-B08gBYDdokkpDS8ib-g", "theme": "Pakistan & India Scholars"},
    {"id": "UC3YmP7nqf514I1zh1eVbzrA", "theme": "Pakistan & India Scholars"},
    {"id": "UC1isGGyqPXxGb3i_Tr6agHg", "theme": "Pakistan & India Scholars"},
    {"id": "UC3TenRnIEWa-P-JliJv3yTQ", "theme": "Pakistan & India Scholars"},
    {"id": "UCpw3zriDRFelSFzlAo2OGTA", "theme": "Pakistan & India Scholars"},
    {"id": "UCIQQovwY3Gws0ZFc1jzINqQ", "theme": "Pakistan & India Scholars"},
    {"id": "UCo9HPMSoI3aDsDMn_HVzvtg", "theme": "Pakistan & India Scholars"},
    {"id": "UCWsdcrre0WbCWML_PnuzoAg", "theme": "Saudi & Arabic Scholars"},
    {"id": "UC37tvO47bp_cKH1f4_VQCOA", "theme": "Saudi & Arabic Scholars"},
    {"id": "UCEtzpou7x4iq1r8PxSAcZxQ", "theme": "Saudi & Arabic Scholars"},
    {"id": "UCutq_y0TcJFO3QNc70CKEiw", "theme": "Saudi & Arabic Scholars"},
    {"id": "UC9AGtdHF1KIrx_ql9INA8cg", "theme": "Saudi & Arabic Scholars"},
    {"id": "UCutq_y0TcJFO3QNc70CKEiw", "theme": "Saudi & Arabic Scholars"},
    {"id": "UCNB_OaI4524fASt8h0IL8dw", "theme": "English Speakers"},
    {"id": "UCRtiU-lpcBSi-ipFKyfIkug", "theme": "English Speakers"},
    {"id": "UC88lF82aS_VW3oJe7GV5zsA", "theme": "English Speakers"},
    {"id": "UClUa7-iHJNKEM2e_zWYSPQg", "theme": "English Speakers"},
    {"id": "UC6ApDIST7zf1jyo9V2GXyag", "theme": "English Speakers"},
    {"id": "UC34dxKHa9n9ggxz4m7bztfA", "theme": "English Speakers"},
    {"id": "UCk1-R7Mmzd7iikof378dcuA", "theme": "English Speakers"},
    {"id": "UCFnsCaT_2VKBg_SoGjhO1nA", "theme": "Female Scholars"},
    {"id": "UCjr67rJYy3mtZgF-hx6lQhA", "theme": "Female Scholars"},
    {"id": "UCx1Zr8zUKUHUtHEVq09b5vg", "theme": "Female Scholars"},
    {"id": "UCDbcE4qLJBwU2ECK4jlhK6A", "theme": "Female Scholars"},
    {"id": "UCqiS2mW5lOBKIsFzHzpUbWA", "theme": "Female Scholars"},
    {"id": "UCfiM9_Me5QJBEr0PItkbXgw", "theme": "Historical Series & Dramas"},
    {"id": "UCMfwlaPLGMn44BKvHv15yzA", "theme": "Historical Series & Dramas"},
    {"id": "UCc_ExYKEewFxSprpNUzxXiw", "theme": "Historical Series & Dramas"},
    {"id": "UCButGmXFqWNU-UxK7umP6yQ", "theme": "Historical Series & Dramas"},
    {"id": "UCQvQjw1-fCboX5e_EjjGRUw", "theme": "Historical Series & Dramas"},
    {"id": "UC4BVyaekE3PFY8m7H4rXkOw", "theme": "Historical Series & Dramas"},
    {"id": "UCWJPKXhkcMGXafdtqGx1mEw", "theme": "Podcasts"},
    {"id": "UCsy3iXZmEZ66-D7QeLPzeKw", "theme": "Podcasts"},
    {"id": "UCyP9IZwHkcKUmwrYEUzKAfA", "theme": "Podcasts"},
    {"id": "UCQHRLH8RQIrdGWMhf5heWiA", "theme": "Documentaries"},
    {"id": "UCNdUFOtzSx3FS71pHkQLxhQ", "theme": "Documentaries"},
    {"id": "UCn4JmUrO4WMNu3W94ZbE03g", "theme": "Documentaries"},
    {"id": "UC5vCwookDYaSy6ACyKaAjNA", "theme": "Documentaries"},
]

# --- 3. ALL EXTRACTED CHANNELS ---
PDF_CHANNELS = [
    "UCZpQ8E962TlDCz_HsePVLbA", "UCiZL26ScfRZDdEAkkPJgJbA", "UCtKKyuORzErSd7TWfkunxsw", "UCXhg6jUrkGLiiwk7Zr13SuQ",
    "UC178EmfQAV3OT-UpuO6WUMg", "UC1XrhzT6FGdc9eAso7Kv3CQ", "UCHGAqdQBKTVON_FUCIYCh3Q", "UCLzcK1rRlVJu--nDIGE78Yw", 
    "UCD0WysHED1NfXUk3vedtRhQ", "UCHDFNoOk8WOXtHo8DIc8efQ", "UCMUUvDpphbVJELWzSlX_hVw", "UCggJmYhtxBk1naIbZN541pw",
    "UCNDpwS2nEiGiJAW3Oe-3zBg", "UCz4AXmFeSbi-0vPXI102Q5w", "UC4E8QX7OgwYDgyuuXTBMrcg", "UCBMHtZeFf0EJeYr7CXnO5xQ",
    "UChqQhJJV5SssDe8rB6R3GZA", "UCYcjqUjOpGDBAZzPsZDWsSA", "UCeCAQhKbU2ETNWxWxB94HgA", "UCULN4pFp-FlahCVfTNEE3BA", 
    "UCr-aPoKaFR0qxuKGmLTYy9g", "UCTwkuNzcL44wKOF7MxBZ4iw", "UClCMqb0Os1yqpoW4GK_awoA", "UC_qJhakG5LqYgVDxIhM0hew", 
    "UCxFqu5ogfORHnip6r9oC1eA", "UCDWfDagVqRfIMSWYvEMS5eQ", "UCunyXvfU2CbjtopaqUuxaVA", "UCkf6icud020fZ5wEZuxoe6A", 
    "UCvWyP-vFhlS1-XENpD6w68A", "UCN1m5L0RUDzXhofttWpjb3w", "UCKWs-9bZPIUkIErZar9dovw", "UCUUQonfh_yNkI6h0O2a6nRA", 
    "UCRMuR8lX3opVZDezphLSxVQ", "UCGy0bkgdFNad9t1W7wxTCQw", "UCPf8katHWsBVhIG7oz9GgDA", "UCCKSdoKEAkzxogEIK21xxkQ", 
    "UCOwXHjXP7wnTdQhr2UJSnqA", "UCny7HDfgTdiP6Q7IxMyLArA", "UCrhfT4dU6zouBzMJ8la5IKA", "UCh5Dxf7_-Npp4mPppFgQyRg", 
    "UCjzJflFF-9Xr_2P0oNj_Rdg", "UCncBMpODKI6wwLKOdFM9v_A", "UCl8a5j_l4hWWo41Nib0mWqQ", "UC-Dgw2fywna25r3P2xF8qIQ", 
    "UCPltU1gxcEJKGqtqmANKOvg", "UCgG2K5pObLX4mk7lmQWKY_Q", "UCeO_pSfiLy45HznBB0wNV8Q", "UCxelshLdx5Jx3qy7D2QlG-g", 
    "UCVaWfOQR3Q9O9nHfZxfyuyA", "UCE_BpRCcek2SuBaX0Ming7Q", "UCdqEwn5bGGbFE0u8UqdHmGQ", "UCnjmgyqTn5wKBtUH1tRmUuQ", 
    "UCIMSEsuDshsGybGjSb6oX-g", "UC-V496kekrz5-ihBeHvWCGA", "UC1Fbta1LbU30UuDM6rOlOyw", "UCgKgRKAy5z5XUq3lgEJBaMg", 
    "UCnxn7-L96mdYJL4GNLrXZHQ", "UCkAncwS4ANVQqMqli716KxQ", "UCWorhmC_iU4ObCGfckIPO6A", "UCTv_DCq-qQgALW0kJLFieqw", 
    "UCUgsdnf7uuSrcdO_Y1-ygWQ", "UC7y4bKCP4wzuZ19ENAgkWeA", "UC0o4-48gQsavA3-Lr8ksYqQ"
]

for pid in PDF_CHANNELS:
    CHANNELS.append({"id": pid, "theme": "Extracted Channels"})

def parse_duration(duration_str):
    match = re.match(r'PT(?:(\d+)H)?(?:(\d+)M)?(?:(\d+)S)?', duration_str)
    if not match: return 0
    h, m, s = match.groups()
    return (int(h) * 3600 if h else 0) + (int(m) * 60 if m else 0) + (int(s) if s else 0)

def fetch_with_retry(url, params):
    while True:
        key = get_key()
        if not key:
            return None
        
        params['key'] = key
        try:
            res = requests.get(url, params=params)
            if res.status_code == 403: 
                if not rotate_key():
                    print("❌ All API keys exhausted for this session.")
                    return None
                continue
            return res.json()
        except Exception as e:
            print(f"Request Error: {e}")
            return None

def fetch_recent_items(channel_id, count=25): 
    if channel_id.startswith("UC"):
        playlist_id = "UU" + channel_id[2:]
    else:
        return []

    playlist_url = "https://www.googleapis.com/youtube/v3/playlistItems"
    playlist_params = {'playlistId': playlist_id, 'part': 'snippet', 'maxResults': count}
    
    playlist_data = fetch_with_retry(playlist_url, playlist_params)
    if not playlist_data or 'items' not in playlist_data or len(playlist_data['items']) == 0:
        return []

    video_ids = ",".join([item['snippet']['resourceId']['videoId'] for item in playlist_data['items']])
    vid_url = "https://www.googleapis.com/youtube/v3/videos"
    vid_params = {'id': video_ids, 'part': 'contentDetails,snippet,statistics'}
    
    vid_data = fetch_with_retry(vid_url, vid_params)
    return vid_data.get('items', []) if vid_data else []

def fetch_individual_video(video_id):
    url = "https://www.googleapis.com/youtube/v3/videos"
    params = {'id': video_id, 'part': 'snippet'}
    res = fetch_with_retry(url, params)
    if res and 'items' in res and len(res['items']) > 0:
        return res['items'][0]
    return None

def sync_master_hub():
    print(f"🚀 Starting Sync Architecture Build...")
    MAIN_COLLECTION = "video_hub"

    print("\n[PHASE 1] Fetching Live/Individual Videos...")
    for vid in INDIVIDUAL_VIDEOS:
        v_id = vid['id']
        theme = vid['theme']
        item = fetch_individual_video(v_id)
        if item:
            published_str = item['snippet']['publishedAt']
            try:
                published_dt = datetime.fromisoformat(published_str.replace('Z', '+00:00'))
            except Exception:
                published_dt = firestore.SERVER_TIMESTAMP

            video_obj = {
                "video_id": v_id,
                "title": item['snippet']['title'],
                "description": item['snippet']['description'],
                "thumbnail": item['snippet']['thumbnails'].get('high', {}).get('url', ''),
                "channel_name": item['snippet']['channelTitle'], 
                "theme": theme,
                "section": "live",
                "type": "live_or_individual",
                "published_at": published_str,
                "timestamp": published_dt
            }
            db.collection(MAIN_COLLECTION).document(v_id).set(video_obj, merge=True)
            print(f"✅ Saved Live Stream: {item['snippet']['title'][:30]}...")

    print(f"\n[PHASE 2] Fetching Channel Content ({len(CHANNELS)} channels)...")
    for ch in CHANNELS:
        theme = ch['theme']
        items = fetch_recent_items(ch['id'])
        if not items: continue

        batch = db.batch()
        for item in items:
            v_id = item['id']
            title = item['snippet']['title']
            description = item['snippet']['description']
            
            content_details = item.get('contentDetails', {})
            duration_str = content_details.get('duration', 'PT0S') 
            duration_sec = parse_duration(duration_str)
            
            stats = item.get('statistics', {})
            view_count = int(stats.get('viewCount', 0))
            like_count = int(stats.get('likeCount', 0))
            comment_count = int(stats.get('commentCount', 0))
            
            is_live_broadcast = item.get('snippet', {}).get('liveBroadcastContent') in ['live', 'upcoming']
            
            if is_live_broadcast:
                section = "live"
            elif duration_sec <= 60 or "#shorts" in title.lower() or "short" in title.lower():
                section = "short"
            elif duration_sec >= 1800: 
                section = "podcast"
            else:
                section = "video"
            
            published_str = item['snippet']['publishedAt']
            try:
                published_dt = datetime.fromisoformat(published_str.replace('Z', '+00:00'))
            except Exception:
                published_dt = firestore.SERVER_TIMESTAMP

            video_obj = {
                "video_id": v_id,
                "title": title,
                "description": description,
                "thumbnail": item['snippet']['thumbnails'].get('high', {}).get('url', ''),
                "section": section,
                "channel_name": item['snippet']['channelTitle'],
                "theme": theme,
                "published_at": published_str,
                "view_count": view_count,
                "like_count": like_count,
                "comment_count": comment_count,
                "timestamp": published_dt 
            }
            
            doc_ref = db.collection(MAIN_COLLECTION).document(v_id)
            batch.set(doc_ref, video_obj, merge=True)
        
        batch.commit()
        print(f"✅ Synced {len(items)} items for {theme} Collection.")

if __name__ == "__main__":
    sync_master_hub()
    print("\n🔥 DONE! Database is completely updated with newly fetched videos while securely saving old videos.")