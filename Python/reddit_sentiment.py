import requests
import pandas as pd
from textblob import TextBlob
import time
import os

# --- Colors to search ---
colors = [
    "black", "blue", "brown", "grey", "green", "orange", "pink", "purple", "red", "white", "yellow"
]

def get_reddit_posts(color, subreddit="aloyoga", limit=100):
    print(f"Pulling posts mentioning: {color}")
    
    url = "https://api.pullpush.io/reddit/search/submission"
    params = {
        "q"         : color,
        "subreddit" : subreddit,
        "size"      : limit,
        "fields"    : "title,score,num_comments,created_utc,upvote_ratio"
    }
    
    try:
        response = requests.get(url, params=params, timeout=10)
        data = response.json()
        posts = data.get("data", [])
        
        results = []
        for post in posts:
            sentiment = TextBlob(post.get("title", "")).sentiment
            results.append({
                "color"        : color,
                "title"        : post.get("title", ""),
                "score"        : post.get("score", 0),
                "num_comments" : post.get("num_comments", 0),
                "created_date" : pd.to_datetime(post.get("created_utc"), unit="s"),
                "polarity"     : round(sentiment.polarity, 3),
                "subjectivity" : round(sentiment.subjectivity, 3),
                "sentiment"    : "positive" if sentiment.polarity > 0.05
                                 else "negative" if sentiment.polarity < -0.05
                                 else "neutral"
            })
        
        time.sleep(1)
        return results
    
    except Exception as e:
        print(f"  Error on {color}: {e}")
        return []

# ── Pull all colors ───
all_results = []
for color in colors:
    results = get_reddit_posts(color)
    all_results.extend(results)
    print(f"  → {len(results)} posts pulled")

# ── Convert and summarize ───
df = pd.DataFrame(all_results)

print(f"\n Total rows: {len(df)}")
print("\n--- Sentiment by color ---")
print(
    df.groupby("color")["polarity"]
    .agg(["mean", "count"])
    .round(3)
    .sort_values("mean", ascending=False)
    .to_string()
)

# ── Save ──
os.makedirs("data/processed", exist_ok=True)
df.to_csv("data/processed/reddit_sentiment.csv", index=False)
print("\n✅ Saved reddit_sentiment.csv")