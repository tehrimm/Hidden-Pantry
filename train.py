import json
import pandas as pd
import numpy as np
from pathlib import Path
from sklearn.feature_extraction.text import TfidfVectorizer
import joblib
from scipy import sparse

# =========================
# PATHS
# =========================
BASE_DIR = Path(__file__).resolve().parent
DATA_PATH = BASE_DIR / "food_dataset_fast.json"
OUT_DIR = BASE_DIR / "trained_model"
OUT_DIR.mkdir(exist_ok=True)

def train():
    print(f"[INFO] Loading data from {DATA_PATH}...")
    with open(DATA_PATH, 'r', encoding='utf-8') as f:
        data = json.load(f)

    df = pd.DataFrame(data)
    print(f"[INFO] Loaded {len(df)} recipes.")

    # =========================
    # PREPARE TEXT FOR TF-IDF
    # =========================
    print("[INFO] Preparing text for training...")
    def build_ml_text(row):
        name = str(row.get('recipe_name', '')).lower()
        tags = " ".join([str(t).lower() for t in row.get('tags', [])])
        ingredients = " ".join([str(i).lower() for i in row.get('ingredients', [])])
        description = str(row.get('recipe_description', '')).lower()
        return f"{name} {tags} {ingredients} {description}".strip()

    df['ml_text'] = df.apply(build_ml_text, axis=1)

    # =========================
    # TRAIN TF-IDF
    # =========================
    print("[INFO] Training TF-IDF vectorizer...")
    vectorizer = TfidfVectorizer(
        max_features=20000, 
        ngram_range=(1, 2), 
        stop_words='english'
    )
    X = vectorizer.fit_transform(df['ml_text'])

    # =========================
    # SAVE ARTIFACTS
    # =========================
    print("[INFO] Saving artifacts...")
    # Save vectorizer
    joblib.dump(vectorizer, OUT_DIR / "vectorizer.joblib")
    # Save TF-IDF matrix
    sparse.save_npz(OUT_DIR / "tfidf_matrix.npz", X)
    # Save processed index using joblib (handles mixed types better than parquet)
    joblib.dump(df, OUT_DIR / "recipe_index.joblib")

    print(f"🎉 Training complete! Artifacts saved in {OUT_DIR}")

if __name__ == "__main__":
    train()
