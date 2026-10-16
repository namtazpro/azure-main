from __future__ import annotations

import os
import time
from collections import defaultdict, deque
from pathlib import Path

from agent_framework import Agent
from agent_framework.foundry import FoundryChatClient
from agent_framework_foundry_hosting import FoundryToolbox
from azure.identity import DefaultAzureCredential
from azure.monitor.opentelemetry import configure_azure_monitor
from fastapi import FastAPI, HTTPException, Request
from fastapi.responses import FileResponse
from fastapi.staticfiles import StaticFiles
from pydantic import BaseModel, Field

STATIC_DIR = Path(__file__).with_name("static")
REQUEST_LIMIT = 20
REQUEST_WINDOW_SECONDS = 60
_requests: dict[str, deque[float]] = defaultdict(deque)

if os.environ.get("APPLICATIONINSIGHTS_CONNECTION_STRING"):
    configure_azure_monitor()

app = FastAPI(title="Foundry IQ Travel Policy Demo", docs_url=None, redoc_url=None)
app.mount("/static", StaticFiles(directory=STATIC_DIR), name="static")

INSTRUCTIONS = """You are the Corporate Travel Policy Assistant.

Use the travel-policy knowledge-base tool for every answer. Give exact policy
amounts, deadlines, preferred vendors, required approvals, and exceptions.
Start with a direct answer, then add a short "Policy details" section. Include
citations returned by the knowledge base. If the corpus does not contain the
answer, say that you could not find it in the standing policy. This web
experience does not have Work IQ Mail, so do not claim to have searched email.
"""


class ChatRequest(BaseModel):
    message: str = Field(min_length=2, max_length=1500)


class ChatResponse(BaseModel):
    answer: str
    user: str | None = None


def _enforce_rate_limit(request: Request) -> None:
    forwarded = request.headers.get("x-forwarded-for", "")
    client = forwarded.split(",", 1)[0].strip() or (
        request.client.host if request.client else "unknown"
    )
    now = time.monotonic()
    bucket = _requests[client]
    while bucket and now - bucket[0] > REQUEST_WINDOW_SECONDS:
        bucket.popleft()
    if len(bucket) >= REQUEST_LIMIT:
        raise HTTPException(status_code=429, detail="Too many requests. Try again shortly.")
    bucket.append(now)


@app.get("/")
async def index() -> FileResponse:
    return FileResponse(STATIC_DIR / "index.html")


@app.get("/health")
async def health() -> dict[str, str]:
    return {"status": "healthy"}


@app.post("/api/chat", response_model=ChatResponse)
async def chat(payload: ChatRequest, request: Request) -> ChatResponse:
    _enforce_rate_limit(request)
    project_endpoint = os.environ.get("FOUNDRY_PROJECT_ENDPOINT")
    model = os.environ.get("AZURE_AI_MODEL_DEPLOYMENT_NAME")
    toolbox_endpoint = os.environ.get("TOOLBOX_ENDPOINT")
    if not project_endpoint or not model or not toolbox_endpoint:
        raise HTTPException(status_code=503, detail="Foundry IQ is not configured.")

    credential = DefaultAzureCredential()
    toolbox = FoundryToolbox(credential, name="travel_policy")
    client = FoundryChatClient(
        project_endpoint=project_endpoint,
        model=model,
        credential=credential,
    )
    async with Agent(
        client=client,
        name="TravelPolicyWebAgent",
        instructions=INSTRUCTIONS,
        tools=toolbox,
        default_options={"store": False, "max_output_tokens": 1200},
    ) as agent:
        result = await agent.run(payload.message)

    return ChatResponse(
        answer=result.text,
        user=request.headers.get("x-ms-client-principal-name"),
    )
