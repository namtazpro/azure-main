"""Provision the Search index, knowledge source, and Foundry IQ knowledge base."""

from __future__ import annotations

import json
import os
import re
import shutil
import subprocess
import sys
from pathlib import Path
from typing import Any

SEARCH_SCOPE = "https://search.azure.com/.default"
API_VERSION = "2026-08-01-preview"
SEMANTIC_CONFIG_NAME = "travel-policy-semantic"
DEFAULT_DATA_PATH = Path(__file__).resolve().parents[2] / "knowledge" / "travel-policies.json"


def _require(name: str) -> str:
    value = os.environ.get(name, "").strip()
    if not value:
        raise RuntimeError(f"Required environment variable '{name}' is not set.")
    return value


def load_documents(path: Path) -> list[dict[str, str]]:
    with path.open(encoding="utf-8") as handle:
        source: Any = json.load(handle)
    if not isinstance(source, list) or not source:
        raise ValueError(f"{path} must contain a non-empty JSON array.")

    documents: list[dict[str, str]] = []
    for item in source:
        if not isinstance(item, dict):
            raise ValueError("Every policy entry must be a JSON object.")
        required = ("id", "section", "category", "content")
        missing = [field for field in required if not str(item.get(field, "")).strip()]
        if missing:
            raise ValueError(f"Policy entry is missing fields: {', '.join(missing)}")
        documents.append(
            {
                "id": re.sub(r"[^A-Za-z0-9_\-=]", "-", str(item["id"])),
                "title": str(item["section"]),
                "section": str(item["section"]),
                "category": str(item["category"]),
                "content": str(item["content"]),
            }
        )
    return documents


class SearchClient:
    def __init__(self, endpoint: str, token: str) -> None:
        import requests

        self._requests = requests
        self._endpoint = endpoint.rstrip("/")
        self._headers = {
            "Authorization": f"Bearer {token}",
            "Content-Type": "application/json",
        }

    def put(self, path: str, body: dict[str, Any]) -> None:
        response = self._requests.put(
            f"{self._endpoint}/{path}?api-version={API_VERSION}",
            headers=self._headers,
            json=body,
            timeout=120,
        )
        if response.status_code not in (200, 201, 204):
            raise RuntimeError(
                f"PUT {path} failed ({response.status_code}): {response.text}"
            )

    def post(self, path: str, body: dict[str, Any]) -> dict[str, Any]:
        response = self._requests.post(
            f"{self._endpoint}/{path}?api-version={API_VERSION}",
            headers=self._headers,
            json=body,
            timeout=120,
        )
        if response.status_code not in (200, 201):
            raise RuntimeError(
                f"POST {path} failed ({response.status_code}): {response.text}"
            )
        return response.json() if response.content else {}


def create_index(client: SearchClient, index_name: str) -> None:
    body = {
        "name": index_name,
        "fields": [
            {"name": "id", "type": "Edm.String", "key": True, "filterable": True},
            {
                "name": "title",
                "type": "Edm.String",
                "searchable": True,
                "retrievable": True,
            },
            {
                "name": "section",
                "type": "Edm.String",
                "searchable": True,
                "filterable": True,
                "retrievable": True,
            },
            {
                "name": "category",
                "type": "Edm.String",
                "searchable": True,
                "filterable": True,
                "facetable": True,
                "retrievable": True,
            },
            {
                "name": "content",
                "type": "Edm.String",
                "searchable": True,
                "retrievable": True,
            },
        ],
        "semantic": {
            "configurations": [
                {
                    "name": SEMANTIC_CONFIG_NAME,
                    "prioritizedFields": {
                        "titleField": {"fieldName": "title"},
                        "prioritizedContentFields": [{"fieldName": "content"}],
                        "prioritizedKeywordsFields": [
                            {"fieldName": "category"},
                            {"fieldName": "section"},
                        ],
                    },
                }
            ]
        },
    }
    client.put(f"indexes/{index_name}", body)


def upload_documents(
    client: SearchClient, index_name: str, documents: list[dict[str, str]]
) -> None:
    actions = [{"@search.action": "mergeOrUpload", **doc} for doc in documents]
    client.post(f"indexes/{index_name}/docs/index", {"value": actions})


def create_knowledge_source(client: SearchClient, ks_name: str, index_name: str) -> None:
    client.put(
        f"knowledgesources/{ks_name}",
        {
            "name": ks_name,
            "kind": "searchIndex",
            "description": "Corporate travel policies used by the Foundry IQ demo.",
            "searchIndexParameters": {
                "searchIndexName": index_name,
                "semanticConfigurationName": SEMANTIC_CONFIG_NAME,
                "sourceDataFields": [
                    {"name": "title"},
                    {"name": "section"},
                    {"name": "category"},
                    {"name": "content"},
                ],
                "searchFields": [
                    {"name": "title"},
                    {"name": "section"},
                    {"name": "category"},
                    {"name": "content"},
                ],
            },
        },
    )


def create_knowledge_base(client: SearchClient, kb_name: str, ks_name: str) -> None:
    deployment = _require("AZURE_AI_MODEL_DEPLOYMENT_NAME")
    client.put(
        f"knowledgebases/{kb_name}",
        {
            "name": kb_name,
            "description": (
                "Foundry IQ knowledge base for corporate travel policies, "
                "approval rules, preferred vendors, per diems, and exceptions."
            ),
            "knowledgeSources": [{"name": ks_name}],
            "outputMode": "answerSynthesis",
            "retrievalReasoningEffort": {"kind": "low"},
            "models": [
                {
                    "kind": "azureOpenAI",
                    "azureOpenAIParameters": {
                        "resourceUri": _require("AZURE_OPENAI_ENDPOINT").rstrip("/"),
                        "deploymentId": deployment,
                        "modelName": os.environ.get("AZURE_AI_MODEL_NAME", deployment),
                    },
                }
            ],
        },
    )


def _set_azd_env(name: str, value: str) -> bool:
    azd = shutil.which("azd")
    if not azd:
        return False
    try:
        subprocess.run([azd, "env", "set", name, value], check=True)
        return True
    except (OSError, subprocess.CalledProcessError):
        return False


def main() -> None:
    from azure.identity import DefaultAzureCredential
    from dotenv import load_dotenv

    load_dotenv()
    data_path = Path(os.environ.get("KNOWLEDGE_DATA_PATH", DEFAULT_DATA_PATH))
    documents = load_documents(data_path)
    endpoint = _require("AZURE_SEARCH_ENDPOINT")
    index_name = os.environ.get("AZURE_SEARCH_INDEX_NAME", "travel-policy-index")
    ks_name = os.environ.get("KNOWLEDGE_SOURCE_NAME", "travel-policy-source")
    kb_name = os.environ.get("KNOWLEDGE_BASE_NAME", "travel-policy-kb")

    print(f"Loading {len(documents)} policies from {data_path}.")
    token = DefaultAzureCredential().get_token(SEARCH_SCOPE).token
    client = SearchClient(endpoint, token)
    create_index(client, index_name)
    upload_documents(client, index_name, documents)
    create_knowledge_source(client, ks_name, index_name)
    create_knowledge_base(client, kb_name, ks_name)

    mcp_endpoint = (
        f"{endpoint.rstrip('/')}/knowledgebases/{kb_name}/mcp"
        f"?api-version={API_VERSION}"
    )
    print(f"Knowledge base '{kb_name}' is ready.")
    print(f"MCP endpoint: {mcp_endpoint}")
    if not _set_azd_env("KB_MCP_ENDPOINT", mcp_endpoint):
        print(f'Set KB_MCP_ENDPOINT manually to "{mcp_endpoint}".')


if __name__ == "__main__":
    try:
        main()
    except (OSError, RuntimeError, ValueError) as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        raise SystemExit(1) from exc
