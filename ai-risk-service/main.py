from __future__ import annotations

from pathlib import Path

import joblib
from pydantic import BaseModel
from fastapi import FastAPI, HTTPException


app = FastAPI(title="PatiMap AI Risk Service")
MODEL_PATH = Path(__file__).with_name("risk_model.pkl")


class RiskRequest(BaseModel):
    description: str | None = None


def _risk_score_for_level(risk_level: str) -> int:
    return {
        "Düşük Risk": 25,
        "Orta Risk": 55,
        "Yüksek Risk": 85,
    }.get(risk_level, 0)


def _load_model():
    if not MODEL_PATH.exists():
        raise HTTPException(
            status_code=503,
            detail="Model dosyasi bulunamadi. Once train_model.py calistirin.",
        )
    return joblib.load(MODEL_PATH)


@app.get("/")
def root() -> dict[str, str]:
    return {"message": "PatiMap AI Risk Service çalışıyor"}


@app.post("/predict-risk")
def predict_risk(payload: RiskRequest) -> dict[str, int | str]:
    description = (payload.description or "").strip()
    if not description:
        return {"risk_level": "Belirlenmedi", "score": 0}
    model = _load_model()
    prediction = model.predict([description])[0]
    risk_level = str(prediction)
    score = _risk_score_for_level(risk_level)
    return {"risk_level": risk_level, "score": score}
