import os
from typing import Any

from fastapi import FastAPI, HTTPException, Query


SERVICE_NAME = "release-demo-service"

app = FastAPI(
    title="Service Release Pipeline Practice",
    description="A minimal API used to demonstrate CI/CD release workflows.",
    version=os.getenv("APP_VERSION", "v1.0.0"),
)


def version_payload() -> dict[str, str]:
    return {
        "app": SERVICE_NAME,
        "version": os.getenv("APP_VERSION", "v1.0.0"),
        "git_sha": os.getenv("GIT_SHA", "unknown"),
        "image_tag": os.getenv("IMAGE_TAG", "unknown"),
        "environment": os.getenv("APP_ENV", "dev"),
        "build_time": os.getenv("BUILD_TIME", "unknown"),
    }


@app.get("/")
def root() -> dict[str, Any]:
    return {
        "service": SERVICE_NAME,
        "description": "CI/CD release pipeline demo service",
        "endpoints": ["/healthz", "/readyz", "/version", "/api/order"],
    }


@app.get("/healthz")
def healthz() -> dict[str, str]:
    return {"status": "ok"}


@app.get("/readyz")
def readyz() -> dict[str, bool]:
    return {"ready": True}


@app.get("/version")
def version() -> dict[str, str]:
    return version_payload()


@app.get("/api/order")
def get_order(fail: bool = Query(default=False)) -> dict[str, str]:
    if fail:
        raise HTTPException(status_code=500, detail="simulated order failure")

    return {
        "order_id": "demo-001",
        "status": "created",
        "service": SERVICE_NAME,
    }
