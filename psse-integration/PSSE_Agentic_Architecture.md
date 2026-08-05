# PSSE Integration Architecture: Copilot Studio + Foundry

**Document Date**: August 5, 2026  
**Status**: Recommended Architecture  
**Scope**: Project Server Subscription Edition (PSSE) integration with Microsoft agentic solutions

---

## Executive Summary

Rather than choosing between **Copilot Studio** or **Foundry**, this document recommends a **hybrid, layered architecture** combining both tools strategically:

- **Copilot Studio**: Orchestration, conversation, and UX layer for real-time interactions
- **Foundry**: Deep AI reasoning, knowledge synthesis, and complex analytics
- **PSSE REST API**: Core integration point, secured via Azure API Management (APIM)

This approach balances rapid deployment for quick wins with enterprise-grade AI capabilities.

---

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────┐
│  User Interfaces (Teams, Web, Mobile)                      │
└────────────────────────────┬────────────────────────────────┘
                             │
┌────────────────────────────▼────────────────────────────────┐
│        COPILOT STUDIO (Orchestration & UX Layer)           │
│  • Project team assistant (conversation, context)          │
│  • Route tasks via custom connectors to PSSE REST APIs     │
│  • Delegate complex reasoning to Foundry agents            │
│  • Manage multi-turn workflows & approval flows            │
└────────────────────────────┬────────────────────────────────┘
                             │
        ┌────────────────────┼────────────────────┐
        │                    │                    │
        ▼                    ▼                    ▼
   ┌─────────┐      ┌──────────────┐      ┌──────────────┐
   │ PSSE    │      │  FOUNDRY     │      │  FOUNDRY IQ  │
   │REST API │      │   AGENTS     │      │(Knowledge)   │
   │via APIM │      │              │      │              │
   └─────────┘      │ • Scheduling │      │• Project     │
                    │ • Resource   │      │  artifacts   │
   (Direct CRUD)    │   Planning   │      │• Historical  │
                    │ • Analytics  │      │  data        │
                    └──────────────┘      └──────────────┘
                             │
        ┌────────────────────┼────────────────────┐
        │                    │                    │
        ▼                    ▼                    ▼
   ┌─────────────────────────────────────────────────────────┐
   │        PSSE (Project Server Subscription Edition)       │
   │                                                          │
   │  • Projects, Resources, Tasks, Assignments, Timesheets │
   │  • Event System, Workflows, Reporting Database        │
   └─────────────────────────────────────────────────────────┘
```

---

## Layer 1: Copilot Studio (Foreground)

### Responsibility
Conversation, orchestration, surface-level logic, and user experience

### Best For
- Real-time Q&A ("What are my tasks?", "Who's on my team?")
- Quick updates via PSSE REST API (simple CRUD operations)
- Multi-step approval workflows (Teams integration)
- Connecting to external systems (Finance, HR, SharePoint)

### Integration Pattern

```
Custom Connector (in Copilot Studio)
  ↓
APIM Policy (OAuth validation, throttling, audit)
  ↓
PSSE REST API
  ↓
Project Application Service (SharePoint-backed)
```

### Key Endpoints
- `/_api/ProjectServer/Projects`
- `/_api/ProjectServer/EnterpriseResources`
- `/_api/ProjectServer/CustomFields`
- `/_api/ProjectServer/Projects('{projectId}')/Tasks`
- `/_api/ProjectServer/EnterpriseResources('{resourceId}')/Assignments`

### Authentication
- OAuth 2.0 via Microsoft Entra ID (Azure AD)
- Use managed identity (service principal), not user credentials
- Enforce conditional access policies (MFA, IP restrictions)

### Connector Configuration
- Authenticate with managed identity
- Implement retry logic & error handling
- Cache GET responses where safe (project metadata, resource lists)
- Validate input to prevent SSRF and prompt injection attacks

---

## Layer 2: Foundry (Background)

### Responsibility
Advanced reasoning, knowledge synthesis, multi-source analytics, and agentic retrieval

### Best For
- Agentic retrieval across PSSE historical data + project artifacts
- Complex resource scheduling & capacity planning (multi-constraint reasoning)
- Predictive analytics (timeline risk, resource churn)
- Document analysis & project insights (unstructured data)
- Portfolio-level insights and trend analysis

### Integration Pattern

**Data Ingestion**:
```
PSSE REST API
  ↓
Power Automate Flow / Custom Python Pipeline
  ↓
Daily/Weekly Sync
  ↓
SharePoint / Blob Storage / OneLake
  ↓
Foundry IQ Knowledge Base
```

**Agentic Retrieval**:
```
Foundry Agent (reasoning)
  ↓
Foundry IQ (semantic search, retrieval)
  ↓
PSSE Data + Project Documents
  ↓
Synthesized Response with Citations
```

### Foundry IQ Knowledge Base
- Index PSSE data (projects, resources, assignments, timesheets)
- Index project documentation (Word, PDF artifacts from SharePoint)
- Enable granular access control (respect PSSE resource-level permissions)
- Auto-chunk documents, generate embeddings, manage indexes
- Sync ACLs (access control lists) from PSSE permissions

### Foundry Agents
- **Resource Planner Agent**: Optimize resource allocation across projects
- **Project Analyst Agent**: Trend analysis, risk identification, historical insights
- **Forecasting Agent**: Capacity planning, timeline risk assessment

### Data Sync Strategy
- **Frequency**: Daily or weekly depending on change velocity
- **Scope**: Export projects, assignments, timesheets, custom field history, task status
- **Method**: PSSE REST API + Power Automate or Python/Node.js scheduled job
- **Permission Enforcement**: Respect PSSE resource-level permissions in retrieval

---

## Layer 3: PSSE REST API (Integration Point)

### PSSE Architecture Context
Per Microsoft Learn documentation, PSSE includes:
- **Project Application Service**: Tied to SharePoint site collections
- **Front-end Clients**: Project Web App (PWA), Project Professional, third-party integrations
- **Programmatic Interfaces**:
  - REST API (modern, HTTP/JSON)
  - CSOM (Client-Side Object Model)
  - WCF/PSI (legacy, on-premises)
- **Event Receivers**: Both local (full-trust) and remote
- **Database Layer**: SharePoint content database (no separate PSSE database)

### Authentication & Security
- **OAuth 2.0**: Delegated token-based auth via Entra ID
- **Service Principal**: For app-to-app integrations (agents, sync jobs)
- **Azure API Management (APIM)**:
  - Acts as security proxy
  - Enforces authentication, throttling, audit logging
  - Enables Zero Trust network policies (IP whitelisting, conditional access)
  - Validates payloads to prevent injection attacks

### Rate Limiting & Throttling
- PSSE REST API has built-in throttling (~2,000 requests/minute per tenant)
- APIM policies should enforce lower per-client limits
- Implement exponential backoff in Copilot Studio & Foundry agents

### Error Handling
- PSSE returns standard HTTP status codes (200, 201, 400, 401, 403, 404, 429, 500)
- Parse error responses for actionable messages (avoid leaking stack traces to agents)
- Implement retry logic with circuit breaker pattern for resilience

---

## Implementation Phases

### Phase 1: Quick Win (Weeks 1-2)
**Goal**: Demonstrate value with Copilot Studio + direct REST API integration

**Components**:
- Set up PSSE custom connector in Copilot Studio
- Deploy Azure API Management (APIM) to secure the connection
- Create initial copilot agent: "Project Assistant" (lookup tasks, resources, project status)
- Teams channel integration

**Deliverables**:
- Working Copilot Studio agent in Teams
- APIM audit trail of all PSSE API calls
- Basic Q&A capabilities (task lookup, resource search)

### Phase 2: Data Layer (Weeks 3-4)
**Goal**: Set up Foundry IQ knowledge base for agentic retrieval

**Components**:
- Design PSSE data sync pipeline (Power Automate or Python)
- Export projects, assignments, timesheets, historical data
- Ingest into Foundry IQ knowledge base
- Configure permission boundaries (respect PSSE ACLs)

**Deliverables**:
- Foundry IQ knowledge base (indexed, queryable)
- Automated sync job (daily/weekly)
- Knowledge base documentation & governance policies

### Phase 3: Intelligence (Weeks 5-6)
**Goal**: Deploy specialized Foundry agents with agentic retrieval

**Components**:
- Build Resource Planner agent (Foundry)
- Build Project Analyst agent (Foundry)
- Integrate agents with Copilot Studio (delegation pattern)
- Add reasoning capabilities (multi-step, multi-source synthesis)

**Deliverables**:
- Foundry agents deployed and callable from Copilot Studio
- Complex queries answerable (e.g., "Forecast Q4 capacity given hiring plans")
- Agent performance metrics & latency baselines

### Phase 4: Governance (Week 7+)
**Goal**: Implement multi-agent orchestration, audit, and compliance

**Components**:
- Data Loss Prevention (DLP) policies in Power Platform
- Purview DSPM integration (data governance)
- Audit logging & compliance reporting
- Multi-agent orchestration patterns (chaining agents)
- Cost optimization (caching, batching, smart filtering)

**Deliverables**:
- Compliance-ready audit trail
- DLP policy enforcement
- Agent chaining patterns documented
- Cost analytics dashboard

---

## When to Use Which Component

| Scenario | Solution | Rationale |
|----------|----------|-----------|
| "What are my tasks?" (lookup) | Copilot Studio + REST connector | Low latency, simple retrieval |
| "Show me the top 3 resource risks" (multi-source synthesis) | Foundry agent + Foundry IQ | Requires reasoning across historical data |
| "Approve time entries for John's team" (workflow) | Copilot Studio + APIM + REST API | Needs user interaction, approval flow |
| "Forecast Q4 capacity given hiring plans" (complex reasoning) | Foundry agent (calls PSSE API for actuals) | Multi-constraint optimization, synthesis |
| "Summarize project risks across portfolio" (knowledge synthesis) | Foundry IQ + Foundry agent | Unstructured + structured data analysis |
| "Generate weekly status report" (document generation) | Copilot Studio + Foundry agent | Combines orchestration + reasoning |

---

## Security & Governance

### Authentication & Authorization
- All access flows through **Microsoft Entra ID** (managed identity or delegated user auth)
- Copilot Studio uses **service principal** (managed identity) for PSSE API calls
- End-user permissions enforced at:
  - PSSE resource level (projects, resources, assignments)
  - Foundry IQ ACL level (knowledge base access)
  - Copilot Studio agent channel level (Teams integration)

### Data Loss Prevention (DLP)
- Restrict Copilot Studio to approved connectors only (APIM endpoint, not raw HTTP)
- Block unapproved connector combinations (prevent data exfiltration)
- Audit all agent invocations and data access patterns

### Compliance & Audit
- **APIM Logging**: All REST API calls logged with caller, timestamp, payload size, response status
- **Application Insights**: Foundry agent calls, retrieval latency, token usage
- **Purview DSPM**: Data lineage, sensitivity labels, access governance
- **Compliance Reports**: Monthly audit reports for SOC 2 / ISO 27001 requirements

### Network Security
- PSSE must be accessible from APIM (firewall rules)
- Conditional access policies for Entra ID authentication
- IP whitelisting at APIM level (restrict to known VNets)
- TLS 1.2+ for all external connections

### Secret Management
- **Never hard-code credentials** in agent topics or Power Automate flows
- Use **Azure Key Vault** for storing API keys, connection strings
- Rotate credentials per your organization's policy (quarterly recommended)
- Audit Key Vault access logs

---

## Comparison: Pure Copilot Studio vs. Pure Foundry

### Why Not Pure Copilot Studio?
❌ Limited reasoning capabilities  
❌ No multi-source synthesis (knowledge bases)  
❌ Simple orchestration only, not suitable for complex analytics  
❌ Difficult to implement sophisticated scheduling or forecasting  

### Why Not Pure Foundry?
❌ Overkill for simple lookups ("What's my task?")  
❌ No out-of-the-box Teams integration  
❌ Steeper learning curve for business users  
❌ Higher latency for real-time conversations  

### Hybrid Advantage ✅
✅ **Copilot Studio** handles UX, conversation, quick tasks  
✅ **Foundry** handles reasoning, synthesis, analytics  
✅ **APIM** secures and audits all interactions  
✅ **PSSE REST API** provides single, well-defined integration point  

---

## Cost Considerations

### Copilot Studio
- Per-user, per-month licensing
- Custom connectors included (no additional cost per connector)
- APIM gateway deployment (pay-as-you-go: ~$0.50/1M API calls)

### Foundry
- Foundry IQ knowledge base (storage + indexing)
- Foundry Agent Service (inference, reasoning tokens)
- Azure AI Search (if using PSSE data indexing)

### PSSE
- Project Server Subscription Edition license (per-user)
- SharePoint infrastructure (existing, typically)

### Optimization Tips
1. **Cache frequently accessed data** (project lists, resource profiles) in Copilot Studio
2. **Batch Foundry IQ queries** (combine multiple user questions into single retrieval)
3. **Limit sync frequency** for PSSE data (daily is typically sufficient)
4. **Use APIM throttling policies** to prevent runaway usage
5. **Monitor token usage** in Foundry agents (add cost controls)

---

## Getting Started Checklist

### Pre-Requisites
- [ ] PSSE environment live (Project Web App accessible)
- [ ] Azure subscription with APIM provisioned
- [ ] Copilot Studio environment provisioned (Power Platform tenant)
- [ ] Foundry resource available (in same Entra ID tenant)
- [ ] Entra ID app registration for service principal (auth)

### Phase 1 Setup
- [ ] PSSE custom connector created in Copilot Studio
- [ ] APIM policy configured (OAuth, throttling, audit)
- [ ] Initial copilot agent topics authored ("Get My Tasks", "Find Resource")
- [ ] Test end-to-end flow (Teams → Copilot Studio → APIM → PSSE)
- [ ] Verify audit logging in Application Insights

### Phase 2 Setup
- [ ] PSSE data sync pipeline designed (Power Automate or Python)
- [ ] Test export: 100 sample projects + assignments
- [ ] Ingest into Foundry IQ (test indexing, search)
- [ ] Validate permission boundaries
- [ ] Document data sync schedule (daily vs. weekly)

### Phase 3+ Setup
- [ ] Foundry agents authored (Resource Planner, Analyst)
- [ ] Test agent delegation from Copilot Studio
- [ ] Verify latency & accuracy
- [ ] Document agent capabilities & limitations

---

## References & Resources

### Microsoft PSSE Documentation
- [Project Server Subscription Edition Architecture](https://learn.microsoft.com/en-us/project/project-server-subscription-edition-architecture)
- [PSSE REST API Endpoints](https://github.com/akordowski/Project-Server-Resources)
- [Project Server Event Receivers](https://learn.microsoft.com/en-us/project/project-server-event-receivers)

### Copilot Studio & Foundry Integration
- [Copilot Studio Implementation Guide (2024)](https://aka.ms/CopilotStudioImplementationGuide)
- [Copilot Studio Security Best Practices](https://learn.microsoft.com/en-us/power-platform/copilot/security)
- [Foundry IQ in Copilot Studio](https://techcommunity.microsoft.com/blog/azure-ai-foundry-blog/foundry-iq-is-now-in-copilot-studio)
- [Multi-Agent Orchestration in Copilot Studio](https://github.com/Azure/Copilot-Studio-and-Azure)

### Azure API Management
- [APIM Policies & Security](https://learn.microsoft.com/en-us/azure/api-management/api-management-policies)
- [OAuth 2.0 in APIM](https://learn.microsoft.com/en-us/azure/api-management/authenticate-oauth-2)

### Foundry Agentic Retrieval
- [Foundry: Build Knowledge-Grounded AI Agents](https://learn.microsoft.com/en-us/azure/foundry)
- [Agentic Retrieval Pipeline with Azure AI Search](https://github.com/Azure-Samples/azure-search-python-samples)

---

## Appendix: Example PSSE API Calls

### Get All Projects
```http
GET /_api/ProjectServer/Projects HTTP/1.1
Host: https://<tenant>.sharepoint.com
Authorization: Bearer <access_token>
```

### Get Tasks for a Project
```http
GET /_api/ProjectServer/Projects('{projectId}')/Tasks HTTP/1.1
Host: https://<tenant>.sharepoint.com
Authorization: Bearer <access_token>
```

### Get Enterprise Resources
```http
GET /_api/ProjectServer/EnterpriseResources HTTP/1.1
Host: https://<tenant>.sharepoint.com
Authorization: Bearer <access_token>
```

### Create a Task
```http
POST /_api/ProjectServer/Projects('{projectId}')/Tasks HTTP/1.1
Host: https://<tenant>.sharepoint.com
Authorization: Bearer <access_token>
Content-Type: application/json

{
  "Name": "New Task",
  "DurationTimeSpan": "PT8H",
  "StartDate": "2026-08-06T09:00:00Z"
}
```

---

**Document Version**: 1.0  
**Last Updated**: August 5, 2026  
**Next Review**: September 5, 2026  
