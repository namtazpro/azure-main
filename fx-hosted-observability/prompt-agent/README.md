# Prompt agent example

A **prompt agent** is a declarative agent: you register a definition (model + instructions
+ optional tools) with Foundry, and Foundry runs the agent loop on its shared inference
runtime. There is **no server, no container, no deploy step** beyond a single SDK call.

## Files

- [requirements.txt](requirements.txt) — `azure-ai-projects` and `azure-identity` only.
- [create_and_chat.py](create_and_chat.py) — creates (or updates) the agent and runs a two-turn chat.

## Run it

```powershell
python -m venv .venv
.\.venv\Scripts\Activate.ps1
pip install -r requirements.txt

az login
$env:FOUNDRY_PROJECT_ENDPOINT = "https://<resource>.services.ai.azure.com/api/projects/<project>"
$env:AZURE_AI_MODEL_DEPLOYMENT_NAME = "gpt-5-mini"

python create_and_chat.py
```

Expected output: the agent answers the question, then answers a follow-up using the same
conversation (so it remembers context).

## What to notice

- The whole "agent" is `PromptAgentDefinition(model=..., instructions=...)` — that is
  the artifact Foundry stores. No HTTP server in this folder.
- Invocation uses the standard OpenAI Responses client, with an `agent_reference` extra
  body telling Foundry which prompt agent to apply.
- Re-running `create_version` with the same name + different instructions produces a new
  immutable version of the agent.
