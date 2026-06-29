# PatiMap AI Risk Service

Bu klasör, PatiMap için Python tabanlı risk analiz servisini barındırır.

## Mevcut durum

- FastAPI tabanlı risk servisi çalışır durumdadır.
- `GET /` endpoint'i servis durum mesajı döner.
- `POST /predict-risk` endpoint'i `risk_model.pkl` modeli ile tahmin yapar.

## Kurulum

```bash
pip install -r requirements.txt
```

## Çalıştırma

```bash
uvicorn main:app --reload
```

## Modeli eğitme

```bash
python train_model.py
```

Bu komut, örnek eğitim verileriyle modeli eğitip `risk_model.pkl` dosyasını oluşturur.

## Tahmin endpoint'i

`POST /predict-risk` gövdesi:

```json
{
  "description": "Kedi kanıyor ve hareket etmiyor."
}
```

Örnek dönüş:

```json
{
  "risk_level": "Yüksek Risk",
  "score": 85
}
```
