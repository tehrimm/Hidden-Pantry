import pandas as pd
import numpy as np
from pathlib import Path
from typing import List, Optional
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
import joblib
from scipy import sparse
from sklearn.metrics.pairwise import cosine_similarity

# =========================
# PATHS
# =========================
BASE_DIR = Path(__file__).resolve().parent
MODEL_DIR = BASE_DIR / "trained_model"

# =========================
# APP SETUP
# =========================
app = FastAPI(title="Hidden Pantry API (New)")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=False,
    allow_methods=["*"],
    allow_headers=["*"],
)

# =========================
# LOAD MODELS
# =========================
print("[INFO] Loading backend artifacts...")
try:
    vectorizer = joblib.load(MODEL_DIR / "vectorizer.joblib")
    tfidf_matrix = sparse.load_npz(MODEL_DIR / "tfidf_matrix.npz")
    recipe_index = joblib.load(MODEL_DIR / "recipe_index.joblib")
    
    # Ensure ID is string for lookup
    recipe_index['recipe_id'] = recipe_index['recipe_id'].astype(str)
    recipe_index['author_id'] = recipe_index['author_id'].astype(str)
    
    print(f"[INFO] Loaded {len(recipe_index)} recipes.")
    
    # Pre-calculate author statistics for fast lookup
    print("[INFO] Calculating author statistics...")
    author_counts = recipe_index['author_id'].value_counts().to_dict()
    print(f"[INFO] Tracked {len(author_counts)} unique authors.")
except Exception as e:
    print(f"[ERROR] Failed to load artifacts: {e}")
    print("[HINT] Run 'python train.py' first.")

# =========================
# MODELS
# =========================
class RecommendRequest(BaseModel):
    query: str
    top_k: int = 20

class FeedRequest(BaseModel):
    author_ids: List[str]
    limit: int = 20

# =========================
# HELPERS
# =========================
    
def parse_ingredient(ingredient_str):
    """Parse ingredient string or dict into clean components."""
    import re
    
    # Case A: Input is already a dictionary
    if isinstance(ingredient_str, dict) or (hasattr(ingredient_str, 'get') and not isinstance(ingredient_str, str)):
        raw_name = str(ingredient_str.get("name") or ingredient_str.get("ingredient") or "")
        if '{name:' in raw_name.replace(" ", ""):
            return parse_ingredient(raw_name)
        
        raw_qty_val = ingredient_str.get("quantity") or ingredient_str.get("quantiy")
        # Keep existing displayQuantity if it exists
        display_qty = ingredient_str.get("displayQuantity")
        if display_qty is None:
            raw_qty_str = str(raw_qty_val).strip() if raw_qty_val is not None else ""
            display_qty = raw_qty_str if any(c in raw_qty_str for c in '/-') else None

        def _to_float(v):
            if v is None: return 0.0
            if isinstance(v, (int, float)): return float(v)
            s_val = str(v).strip().lower()
            if not s_val: return 0.0
            try:
                if '/' in s_val:
                    parts = s_val.split()
                    total = 0.0
                    for p in parts:
                        if '/' in p:
                            n, d = p.split('/')
                            total += float(n)/float(d)
                        else: total += float(p)
                    return total
                return float(s_val)
            except: return 0.0

        return {
            "name": raw_name,
            "quantity": _to_float(raw_qty_val),
            "unit": str(ingredient_str.get("unit") or ""),
            "displayQuantity": display_qty
        }
    
    # Case B: Input is a string
    s = str(ingredient_str).strip()
    if not s:
        return {"name": "", "quantity": 0.0, "unit": "", "displayQuantity": None}

    original_s = s
    qty_str = ""
    unit_str = ""
    display_qty = None

    # 1. Handle special prefixes (to taste, as needed, handful)
    # Using \s+ to be flexible with spaces
    special_prefixes = [
        r'^to\s+taste\b', 
        r'^as\s+needed\b', 
        r'^optional\b',
        r'^taste\b',
        r'^handful\b',
        r'^a\s+handful\b'
    ]
    for pref in special_prefixes:
        match = re.match(pref, s, re.I)
        if match:
            display_qty = match.group(0).lower()
            s = s[match.end():].strip()
            # Remove leading "of " or ","
            s = re.sub(r'^of\s+|^,\s*', '', s, flags=re.I)
            break
            
    # Also handle suffix "to taste" (e.g. "salt to taste")
    if not display_qty:
        suffix_match = re.search(r'\s+to\s+taste\s*$', s, re.I)
        if suffix_match:
            display_qty = "to taste"
            s = s[:suffix_match.start()].strip()
            # Remove trailing comma
            s = s.rstrip(',')

    # 2. Extract Quantity (Range first, then single)
    if not display_qty:
        # Check for range: "4 to 8" or "4-8"
        # Note: we use non-greedy and word boundaries to be safe
        range_match = re.match(r'^([\d\s\./¼½¾⅓⅔⅛⅜⅝⅞-]+)\s+(?:to|-)\s+([\d\s\./¼½¾⅓⅔⅛⅜⅝⅞-]+)', s, re.I)
        if range_match:
            qty_str = f"{range_match.group(1).strip()} to {range_match.group(2).strip()}"
            s = s[range_match.end():].strip()
        else:
            # Single quantity
            qty_match = re.match(r'^([\d\./¼½¾⅓⅔⅛⅜⅝⅞-]+(?:\s+[\d\./¼½¾⅓⅔⅛⅜⅝⅞-]+)?)', s, re.I)
            if qty_match:
                qty_str = qty_match.group(1).strip()
                s = s[qty_match.end():].strip()

    # 3. Extract Unit
    units = [
        'tablespoons', 'tablespoon', 'tbsp', 'tbs', 
        'teaspoons', 'teaspoon', 'tsp', 'ts',
        'cups', 'cup', 'c', 'ounces', 'ounce', 'oz',
        'pounds', 'pound', 'lbs', 'lb', 'grams', 'gram', 'g',
        'kilograms', 'kilogram', 'kg', 'milliliters', 'milliliter', 'ml',
        'liters', 'liter', 'l', 'cloves', 'clove', 'can', 'pkg', 'slices', 'slice',
        'pinch', 'dash', 'sticks', 'stick'
    ]
    units.sort(key=len, reverse=True)
    unit_regex = r'^(' + '|'.join(units) + r')\b'
    
    unit_match = re.match(unit_regex, s, re.I)
    if unit_match:
        unit_str = unit_match.group(1).lower()
        s = s[unit_match.end():].strip()
    
    # 4. Final cleanup
    name = re.sub(r'^of\s+|^,\s*|^-\s*', '', s, flags=re.I).strip()
    if not name: name = original_s

    # 5. Numeric quantity conversion
    def _parse_qty(q):
        q = q.strip().lower()
        if not q: return 0.0
        for delim in [' to ', '-', '–']:
            if delim in q:
                parts = q.split(delim)
                try:
                    v1 = _parse_qty(parts[0])
                    v2 = _parse_qty(parts[1])
                    return (v1 + v2) / 2.0
                except: pass
        try:
            if '/' in q:
                parts = q.split()
                total = 0.0
                for p in parts:
                    if '/' in p:
                        n, d = p.split('/')
                        total += float(n)/float(d)
                    else: total += float(p)
                return total
            return float(q)
        except: return 0.0

    result = {
        "name": name,
        "quantity": _parse_qty(qty_str),
        "unit": unit_str,
        "displayQuantity": display_qty if display_qty else (qty_str if qty_str else None)
    }
    
    # Debug log (optional, remove for production)
    # print(f"[DEBUG] '{original_s}' -> {result}")
    
    return result

def map_recipe_to_flutter(row):
    """Maps the scraped JSON fields to the Flutter Recipe model names."""
    def parse_iso_time(iso_str):
        import re
        if not isinstance(iso_str, str): return 0
        h = re.search(r'(\d+)H', iso_str)
        m = re.search(r'(\d+)M', iso_str)
        total = 0
        if h: total += int(h.group(1)) * 60
        if m: total += int(m.group(1))
        return total

    return {
        "id": str(row.get("recipe_id")),
        "name": row.get("recipe_name"),
        "description": row.get("recipe_description"),
        "category": row.get("recipe_category"),
        "allergens": row.get("allergens", []),
        "serving_size": row.get("serving_size"),
        "prep_minutes": parse_iso_time(row.get("prep_time")),
        "cook_minutes": parse_iso_time(row.get("cook_time")),
        "minutes": parse_iso_time(row.get("total_time")),
        "avg_rating": float(row.get("recipe_average_rating") or 0.0),
        "review_count": int(row.get("review_count") or 0),
        "imageUrl": row.get("recipe_image"),
        "author_name": row.get("author_name"),
        "author_id": str(row.get("author_id")),
        "base_servings": 1, 
        "total_ingredients": int(row.get("total_ingredients") or 0),
        "total_steps": int(row.get("total_steps") or 0),
        "ingredients": [
            parse_ingredient(ing) for ing in row.get("ingredients", [])
        ],
        "directions": row.get("steps", []),
        "tags": row.get("tags", []),
        "nutrition": {
            "Calories": f"{row.get('calories', 0)} kcal",
            "Fat": f"{row.get('fat_content', 0)} g",
            "Saturated Fat": f"{row.get('saturated_fat_content', 0)} g",
            "Cholesterol": f"{row.get('cholesterol', 0)} mg",
            "Sodium": f"{row.get('sodium_content', 0)} mg",
            "Carbohydrates": f"{row.get('carbohydrates', 0)} g",
            "Fiber": f"{row.get('fiber_content', 0)} g",
            "Sugar": f"{row.get('sugar_content', 0)} g",
            "Protein": f"{row.get('protein_content', 0)} g",
        }
    }


# =========================
# ROUTES
# =========================
@app.get("/health")
def health():
    return {"status": "ok", "recipes_count": len(recipe_index)}

@app.post("/recommend")
def recommend(req: RecommendRequest):
    q = (req.query or "").strip().lower()
    if not q:
        raise HTTPException(status_code=400, detail="Query empty")

    # Transform query
    q_vec = vectorizer.transform([q])
    
    # Compute similarity
    sims = cosine_similarity(q_vec, tfidf_matrix).flatten()
    
    # Get top K
    top_indices = np.argsort(-sims)[:req.top_k]
    
    results = []
    for idx in top_indices:
        row = recipe_index.iloc[int(idx)].to_dict()
        results.append(map_recipe_to_flutter(row))
        
    return {"results": results}

@app.get("/recipes/{recipe_id}")
def get_recipe(recipe_id: str):
    mask = recipe_index['recipe_id'] == str(recipe_id)
    if not mask.any():
        raise HTTPException(status_code=404, detail="Recipe not found")
    
    row = recipe_index[mask].iloc[0].to_dict()
    return map_recipe_to_flutter(row)

# For Flutter's tags screen
@app.get("/tags")
def get_tags(limit: int = 15):
    all_tags = []
    for tags in recipe_index['tags']:
        all_tags.extend(tags)
    
    counts = pd.Series(all_tags).value_counts().head(limit)
    return {"tags": counts.index.tolist()}

@app.get("/authors/{author_id}/stats")
def get_author_stats(author_id: str):
    mask = recipe_index['author_id'] == str(author_id)
    count = int(mask.sum())
    
    if count == 0:
        return {
            "author_id": author_id,
            "recipe_count": 0,
            "followers": 0,
            "following": 0,
            "avg_rating": 0.0
        }
    
    # Calculate average rating from all their recipes
    avg_rating = float(recipe_index[mask]['recipe_average_rating'].mean())
    if np.isnan(avg_rating):
        avg_rating = 0.0

    return {
        "author_id": author_id,
        "recipe_count": count,
        "followers": 0, # Managed in real-time by mobile app
        "following": 0, # Managed in real-time by mobile app
        "avg_rating": round(avg_rating, 1)
    }

@app.get("/authors/{author_id}/recipe_count")
def get_author_recipe_count(author_id: str):
    # Keep for backward compatibility
    res = get_author_stats(author_id)
    return {"count": res["recipe_count"]}

@app.get("/authors/{author_id}/recipes")
def get_author_recipes(author_id: str, limit: int = 10):
    mask = recipe_index['author_id'] == str(author_id)
    if not mask.any():
        return {"results": []}
    
    rows = recipe_index[mask].head(limit).to_dict('records')
    return {"results": [map_recipe_to_flutter(row) for row in rows]}

@app.post("/recipes/feed")
def get_following_feed(req: FeedRequest):
    if not req.author_ids:
        return {"results": []}
    
    # Filter by any of the author IDs
    mask = recipe_index['author_id'].isin([str(aid) for aid in req.author_ids])
    
    # Sort by recent (if we had a date field, but let's just take head for now)
    # The dataset might have a proxy for recency in its ordering
    rows = recipe_index[mask].head(req.limit).to_dict('records')
    return {"results": [map_recipe_to_flutter(row) for row in rows]}

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
