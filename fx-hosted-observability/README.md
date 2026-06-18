# Foundry Agents — Prompt vs Hosted

Two minimal, runnable examples side-by-side, showing the technical difference between
the two ways to build an agent on Microsoft Foundry Agent Service.

| | [prompt-agent/](prompt-agent/) | [hosted-agent/](hosted-agent/) |
|---|---|---|
| What you ship | A `PromptAgentDefinition` (model + instructions) | A container image with your own HTTP server (`main.py`) |
| Who runs the loop | Foundry's shared runtime | Your code, in a per-session sandbox |
| Languages | Any (calls REST/SDK) | Python or C# (in the container) |
| Endpoint | `{project}/openai/v1/responses` (shared) | `{project}/agents/{name}/endpoint/...` (dedicated) |
| Sample tool here | None (pure prompt) | Local Python `get_weather` tool |
| Run locally | `python create_and_chat.py` | `python main.py` then `curl localhost:8088/responses` |
| Deploy | `python create_and_chat.py` (single SDK call) | `azd up` (builds container, registers version) |

## Prerequisites for both

1. A Foundry project with a deployed model (e.g. `gpt-5-mini` or `gpt-4.1-mini`).
2. `az login` with access to the project.
3. Set `FOUNDRY_PROJECT_ENDPOINT` and `AZURE_AI_MODEL_DEPLOYMENT_NAME` in your shell or in a `.env`.

```powershell
$env:FOUNDRY_PROJECT_ENDPOINT = "https://<resource>.services.ai.azure.com/api/projects/<project>"
$env:AZURE_AI_MODEL_DEPLOYMENT_NAME = "gpt-5-mini"
```

See each sub-folder's README for the specifics.
