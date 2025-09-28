import requests
from fastapi import FastAPI
from pydantic import BaseModel

app = FastAPI()

# Список доменов для рассылки
DOMAINS = [
    "https://loom-ai.ru.com",
    "https://stage.loom-ai.ru.com",
    "https://dev1.loom-ai.ru.com",
    "https://dev2.loom-ai.ru.com",
    "https://dev3.loom-ai.ru.com",
]

ENDPOINT = "/api/content/video-cut/vizard/create"


class Video(BaseModel):
    viralScore: str
    relatedTopic: str
    transcript: str
    videoUrl: str
    clipEditorUrl: str
    videoMsDuration: int
    videoId: int
    title: str
    viralReason: str


class CreateVizardVideoCutsBody(BaseModel):
    code: int
    videos: list[Video]
    projectId: int
    creditsUsed: int


@app.post("/vizard-router")
def create_vizard_video(body: CreateVizardVideoCutsBody):
    data = body.model_dump()

    for domain in DOMAINS:
        url = f"{domain}{ENDPOINT}"
        try:
            response = requests.post(url, json=data, timeout=30)
        except Exception as e:
            pass


if __name__ == "__main__":
    import uvicorn

    uvicorn.run(app, host="0.0.0.0", port=8645)