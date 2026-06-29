from __future__ import annotations

import joblib
from sklearn.feature_extraction.text import TfidfVectorizer
from sklearn.linear_model import LogisticRegression
from sklearn.pipeline import Pipeline


TRAIN_SAMPLES = [
    ("Kedi kaniyor ve hareket etmiyor.", "Yüksek Risk"),
    ("Kopege araba carpmis, yerde yatiyor.", "Yüksek Risk"),
    ("Hayvan nefes almakta zorlaniyor.", "Yüksek Risk"),
    ("Kedinin ayagi kirilmis olabilir.", "Yüksek Risk"),
    ("Kopek baygin gorunuyor.", "Yüksek Risk"),
    ("Kedi cok halsiz ve yemek yemiyor.", "Orta Risk"),
    ("Kopek bir suredir su icmemis.", "Orta Risk"),
    ("Hayvan zayif ve bitkin gorunuyor.", "Orta Risk"),
    ("Kedi kaybolmus, sahibi araniyor.", "Orta Risk"),
    ("Hayvan ac ve sokakta bekliyor.", "Orta Risk"),
    ("Kedi bahcede dolasiyor.", "Düşük Risk"),
    ("Kopek mama ariyor.", "Düşük Risk"),
    ("Sokakta saglikli gorunen bir kedi var.", "Düşük Risk"),
    ("Hayvan sakin ve yarasi gorunmuyor.", "Düşük Risk"),
    ("Kedi apartman onunde bekliyor.", "Düşük Risk"),
]


def build_pipeline() -> Pipeline:
    return Pipeline(
        steps=[
            ("tfidf", TfidfVectorizer(lowercase=True, ngram_range=(1, 2))),
            ("clf", LogisticRegression(max_iter=1000)),
        ]
    )


def train_and_save_model(output_path: str = "risk_model.pkl") -> None:
    texts = [item[0] for item in TRAIN_SAMPLES]
    labels = [item[1] for item in TRAIN_SAMPLES]

    model = build_pipeline()
    model.fit(texts, labels)
    joblib.dump(model, output_path)
    print(f"Model kaydedildi: {output_path}")


if __name__ == "__main__":
    train_and_save_model()
