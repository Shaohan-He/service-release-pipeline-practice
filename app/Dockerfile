FROM python:3.12-slim

ARG APP_VERSION=v1.0.0
ARG GIT_SHA=unknown
ARG IMAGE_TAG=unknown
ARG APP_ENV=dev
ARG BUILD_TIME=unknown

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    APP_VERSION=${APP_VERSION} \
    GIT_SHA=${GIT_SHA} \
    IMAGE_TAG=${IMAGE_TAG} \
    APP_ENV=${APP_ENV} \
    BUILD_TIME=${BUILD_TIME}

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt \
    && adduser --disabled-password --gecos "" appuser

COPY main.py .

USER appuser
EXPOSE 8000

CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]
