# Runbook: AI Gateway and Copilot Studio configuration, demo and measurement

Values for the current deployment (from `azd env get-values`):

| Item | Value |
|---|---|
| API base URL | `https://func-ib5jb7jdzcyn6.azurewebsites.net` |
| OpenAPI URL | `https://func-ib5jb7jdzcyn6.azurewebsites.net/api/openapi/v3.json` (anonymous) |
| OpenAPI file | [openapi.json](openapi.json) |
| Auth header | `x-functions-key: <function key>` |
| Resource group | `rg-mcsmcpsql` (tenant `8317facd-c013-4d0c-9998-ff8d29c7f379`) |

Get the function key (treat it as a secret):

```powershell
az functionapp keys list -g rg-mcsmcpsql -n func-ib5jb7jdzcyn6 --query "functionKeys.default" -o tsv
```

## 1. Configure the MCP server in the AI Gateway (manual)

Confirmed working configuration (tested with `perf/test-mcp.ps1`):

| Item | Value |
|---|---|
| MCP endpoint | `https://astral-eclipse-9604.azure-api.net/default/toolservers/service-desk/mcp` |
| Client auth | gateway runtime access key in the `api-key` header (Keys page) |
| Backend source | OpenAPI file upload of [openapi.json](openapi.json) |
| Backend auth | API Key, header `x-functions-key`, value is the function key |
| Namespace | `itsm`, so tools are named `itsm_<operationId>`, for example `itsm_searchTickets` |

Smoke test: `$env:AIGW_API_KEY='<runtime key>'; ./perf/test-mcp.ps1 -Url <endpoint> -Tool itsm_getTicket -Arguments '{"ticketNumber":"INC-000123"}' -Repeat 5`. A tool result of "Tool invocation failed with status 401" means the backend API key header or value is wrong.

The portal UI is evolving; the intent of each step is what matters.

1. Open the AI Gateway (ai.gateway.azure.com) and create or select a gateway in the same region as the API (Sweden Central) to keep network time out of the comparison.
2. Add an MCP server and choose the option that creates tools from an OpenAPI definition (not "remote MCP endpoint").
3. Import the API by uploading [openapi.json](openapi.json) or by URL. The OpenAPI document declares the server URL, so no URL override should be needed.
4. Select operations to expose. For the demo start with the read operations: `searchTickets`, `getTicket`, `getTicketComments`, `searchCustomers`, `getCustomerTickets`, `getAgentWorkload`, `getTicketSummary`, `getSlaBreaches`. Add `createTicket` and `updateTicketStatus` only for a write-path scenario.
5. Backend authentication: API key sent in a header named `x-functions-key` with the function key value. Keep the key only in the gateway.
6. Note the MCP endpoint URL and how clients authenticate to the gateway (key or OAuth); you need both in Copilot Studio.
7. Test from the gateway's test tool or an MCP client (for example VS Code) before moving on: call `searchTickets` with `status=Open`, `priority=Critical`.

Tool names and descriptions come from the OpenAPI `operationId`, `summary` and `description` and from parameter descriptions. They are already written for an LLM; edit them in the API (and re-export) rather than in the gateway so both stay in sync.

## 2. Configure the agent in Copilot Studio (manual, new experience)

1. Create an agent and give it instructions such as:
   > You are an IT service desk assistant. Use the tools to look up tickets, customers, agents and SLA reports. Always use ticket numbers like INC-000123. Keep answers short and cite ticket numbers.
2. Add a tool, choose Model Context Protocol, and enter the gateway MCP endpoint and authentication from step 1.6.
3. Confirm all selected tools are listed and enabled. Keep the list focused; fewer tools means faster, more accurate tool selection.
4. Pick the orchestration model you want to benchmark and keep it fixed across runs.
5. Publish to the channel you will demo (Test pane, Teams, or web).

## 3. Demo script

| # | Prompt | Tool expected | What it shows |
|---|---|---|---|
| 1 | "Show ticket INC-000123" | `getTicket` | Point lookup |
| 2 | "List the 5 most recent open critical tickets" | `searchTickets` | Filtered search over 100k rows |
| 3 | "What is the conversation on INC-000123?" | `getTicketComments` | Child records |
| 4 | "Find customer Alice Anderson and her open tickets" | `searchCustomers` then `getCustomerTickets` | Multi-tool chain |
| 5 | "Which Service Desk agent has the most overdue tickets?" | `getAgentWorkload` | Aggregation |
| 6 | "Give me a ticket summary for the last 30 days" | `getTicketSummary` | Heavier report |
| 7 | "Which critical tickets breached SLA?" | `getSlaBreaches` | Sorted report |
| 8 | "Open a high priority ticket for customer 42: VPN down" | `createTicket` | Write path (optional) |

## 4. Measuring performance hop by hop

Total agent latency is the sum of model orchestration time, MCP transport and gateway time, API time and SQL time. Measure each so the demo can show where time goes.

| Hop | How |
|---|---|
| SQL | Application Insights `dependencies` where `type == "SQL"` ([perf/queries.kql](../perf/queries.kql), query 2) |
| API (server side) | Application Insights `requests` percentile per operation (query 1) |
| API (end to end from a client) | `./perf/measure-api.ps1` or `k6 run perf/k6-api.js`; run from Azure in the same region |
| Gateway | Gateway analytics or logs; compare gateway request duration with the API duration for the same call |
| Copilot Studio | Test pane activity map and the conversation transcript timing for each tool call; compare with the gateway and API numbers to isolate model time |

Recommended method:

1. Warm up first. Cold connections add about 5 seconds to the first SQL call after a restart.
2. Run each demo prompt at least 10 times and record median and p95 from the transcripts.
3. Run `measure-api.ps1` or k6 at the same time slice and compare: the gap between agent time and API time is orchestration plus gateway overhead.
4. For concurrency, use k6 with `-e VUS=20 -e DURATION=2m` and watch p95, failures and SQL time in Application Insights.

Baseline observed from a laptop in Europe (includes the home network round trip of about 150 ms): point lookups and searches around 200-300 ms median, `getTicketSummary` about 300 ms median after optimisation, `getSlaBreaches` about 650 ms median. Re-measure from Azure for the numbers you present.

## 5. Things that skew results

* Cold start: the plan is always on, but the first SQL call after a deployment or restart opens a new managed identity connection (about 5 s).
* SQL tier: the database is provisioned GP Gen5 2 vCores (no auto-pause). Scale with `azd env set SQL_SKU_NAME GP_Gen5_4` then `azd provision`.
* Distance: keep the gateway, API, SQL and the Copilot Studio environment geography aligned where possible.
* Tool count and description length affect model orchestration time more than backend time.
* Data skew: most open tickets are past their SLA by design, so "overdue" prompts return many rows (bounded by `top`).

## 6. Operations

* Re-seed data: `./database/deploy-db.ps1 -Reseed`
* Redeploy API only: `azd deploy`
* Tear everything down: `azd down --purge`
* The function key is a shared secret. Rotate it in the Functions app and update the gateway if it leaks.
