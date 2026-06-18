# Hosted agent example

A **hosted agent** is your own code, packaged in a container, that Foundry deploys into
per-session VM-isolated sandboxes. You write the agent loop yourself (here using the
Microsoft Agent Framework with the Responses host server) and Foundry handles routing,
sessions, identity, observability, and scaling.

## Files

- [main.py](main.py) — Agent Framework agent with a local Python tool, exposed over the
  Responses protocol on `:8088`.
- [agent.yaml](agent.yaml) — Declares this is a `hosted` agent and which protocol the
  container speaks.
- [requirements.txt](requirements.txt) — Agent Framework + Foundry hosting library.
- [Dockerfile](Dockerfile) — Container image Foundry will run.

## Run locally (no deploy)

```powershell
python -m venv .venv
.\.venv\Scripts\Activate.ps1
pip install -r requirements.txt

az login
$env:FOUNDRY_PROJECT_ENDPOINT = "https://<resource>.services.ai.azure.com/api/projects/<project>"
$env:AZURE_AI_MODEL_DEPLOYMENT_NAME = "gpt-5-mini"

python main.py
```

In another terminal:

```powershell
curl -sS -H "Content-Type: application/json" -X POST http://localhost:8088/responses `
  -d '{"input": "What is the weather in Paris?", "stream": false}'
```

The agent will call the local `get_weather` tool and return a one-line answer.

## Deploy to Foundry

From this folder, use `azd` (install with `azd ext install microsoft.foundry`):

```powershell
azd init           # only if not already an azd project
azd up             # provisions resources and deploys the container
azd ai agent invoke "What is the weather in Tokyo?"
```

## What to notice

- `main.py` runs *your* HTTP server (`ResponsesHostServer`) inside the container — Foundry
  routes traffic to it; you own the process.
- `agent.yaml` says `kind: hosted` and lists `responses` as the protocol — that is what
  switches Foundry from "declarative agent" mode to "run my image" mode.
- The agent has a real Python function (`get_weather`) decorated with `@tool` — that is
  code you couldn't ship inside a prompt agent's definition.
- After deploy, the agent has its own dedicated Microsoft Entra ID and a dedicated
  endpoint, separate from the project-level Responses endpoint used by prompt agents.
