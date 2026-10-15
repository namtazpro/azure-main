# Copilot Studio → MCP (AI Gateway) → REST API → Azure SQL demo

Demonstrates the end-to-end performance of a Copilot Studio agent calling MCP tools whose backend is an existing REST API over Azure SQL. The REST API is intentionally a plain OpenAPI-described service so it mirrors the live project, where the APIs cannot be changed and are exposed as MCP through the Azure AI Gateway.

```text
Copilot Studio agent ──MCP──▶ AI Gateway (ai.gateway.azure.com) ──HTTPS + x-functions-key──▶ Azure Functions API ──VNet / private endpoint──▶ Azure SQL (stored procedures)
        (manual)                       (manual)                                              (this repo)                                     (this repo)
```

## What is deployed (Sweden Central, resource group `rg-mcsmcpsql`)

| Resource | Purpose |
|---|---|
| Azure SQL server + database `itsmdb` (GP Gen5 2 vCores, provisioned) | ITSM data: 5,000 customers, 40 agents, 100,000 tickets, about 248k comments |
| Azure Functions app (.NET 9 isolated, Premium P0v3, always on) | REST API, one stored procedure per operation, OpenAPI at `/api/openapi/v3.json` |
| VNet, SQL private endpoint, storage private endpoints | Tenant policy forces SQL public access off, so the API reaches SQL privately |
| User-assigned managed identity | Function to SQL (`EXECUTE` on the API procedures only) and to storage |
| Application Insights + Log Analytics | Request, dependency (SQL) and error telemetry |

The Functions app stays publicly reachable (function key required) so the AI Gateway can call it.

## API operations (become MCP tools)

| operationId | Route | Stored procedure |
|---|---|---|
| `getTicket` | `GET /tickets/{ticketNumber}` | `usp_GetTicket` |
| `searchTickets` | `GET /tickets` | `usp_SearchTickets` |
| `getTicketComments` | `GET /tickets/{ticketNumber}/comments` | `usp_GetTicketComments` |
| `searchCustomers` | `GET /customers` | `usp_SearchCustomers` |
| `getCustomerTickets` | `GET /customers/{customerId}/tickets` | `usp_GetTicketsByCustomer` |
| `getAgentWorkload` | `GET /agents/workload` | `usp_GetAgentWorkload` |
| `getTicketSummary` | `GET /reports/summary` | `usp_GetTicketSummary` |
| `getSlaBreaches` | `GET /reports/sla-breaches` | `usp_GetSlaBreaches` |
| `createTicket` | `POST /tickets` | `usp_CreateTicket` |
| `updateTicketStatus` | `PATCH /tickets/{ticketNumber}/status` | `usp_UpdateTicketStatus` |

The exported spec is in [docs/openapi.json](docs/openapi.json). Regenerate it after API changes with `GET {API_BASE_URL}/api/openapi/v3.json`.

## Repository layout

```text
azure.yaml                azd project (Bicep + Functions deploy + DB postprovision hook)
infra/                    Bicep: monitoring, identity, network, SQL, API
database/                 01-schema.sql, 02-procs.sql, 03-seed.sql, deploy-db.ps1, run-sql.ps1
src/ItsmApi/              Azure Functions API
src/ItsmApi.Tests/        xUnit tests
perf/                     measure-api.ps1, k6-api.js, queries.kql
docs/                     runbook.md, openapi.json
```

## Deploy

Prerequisites: Azure CLI, azd, PowerShell 7, .NET 9 SDK, signed in as the Entra user that will be SQL admin.

```powershell
az login --tenant <tenant-id>
azd auth login --tenant-id <tenant-id>
azd env new <name> --subscription <subscription-id> --location swedencentral
azd env set SQL_ADMIN_LOGIN <user UPN>
azd env set AZURE_PRINCIPAL_ID <user object id>
azd up
```

`azd up` provisions the infrastructure, runs [database/deploy-db.ps1](database/deploy-db.ps1) (schema, procedures, seed, grants) and deploys the API.

Notes:

* The SQL server has no public access, so `deploy-db.ps1` runs the SQL scripts from a short-lived container instance injected into the VNet. Your Entra token is passed to it as a secure environment variable and the container is deleted afterwards.
* Choose a region that accepts new SQL servers for the subscription; UK South, West Europe and North Europe rejected them in this tenant, Sweden Central worked.
* Re-seed with `./database/deploy-db.ps1 -Reseed`.

## Test

```powershell
dotnet test src/ItsmApi.Tests
./perf/measure-api.ps1 -Iterations 50 -Concurrency 5   # live latency percentiles per operation
```

Run load from Azure (for example Azure Load Testing or a VM in the same region) for clean numbers; a home or office network adds latency and resolver noise.

See [docs/runbook.md](docs/runbook.md) for the AI Gateway and Copilot Studio configuration, demo script and how to measure each hop.
