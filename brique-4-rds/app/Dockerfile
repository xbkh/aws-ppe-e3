FROM python:3.12-slim

ENV PYTHONDONTWRITEBYTECODE=1 PYTHONUNBUFFERED=1 PORT=8080
WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY app.py db.py ./
COPY templates ./templates

# Exécution sans les droits administrateur
RUN useradd --system --no-create-home appli
USER appli

EXPOSE 8080
CMD ["sh", "-c", "exec gunicorn --bind 0.0.0.0:${PORT} --workers 2 app:app"]
