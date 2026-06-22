# Microsoft Foundry risk register - SE working notes

Source workbook: `MS_foundry-per-scenario-risk-register-v2.xlsx`

Purpose: working document for a Microsoft Solution Engineer to review each risk, add recommendations, capture pros/cons, and record decisions or follow-up actions in a GitHub repo.

## How to use this document

For each risk, complete the editable SE sections:

- **SE recommendation**: proposed Microsoft position or mitigation pattern.
- **Pros**: benefits of the recommendation.
- **Cons / trade-offs**: constraints, costs, residual risks, or customer decisions required.
- **Decision made**: agreed customer/Microsoft decision, including owner and date if known.
- **Next actions**: follow-up actions, owners, and target dates.

## Risk summary

| Risk ID | Category | Scenario(s) | Impact | Likelihood |
|---|---|---|---|---|
| R1 | Identity & Access | S1–S3 | High | High |
| R2 | Identity & Access | S2–S3 | High | Medium |
| R3 | Identity & Access | S4 | High | Medium |
| R4 | Identity & Access | S1–S3 (adoption dependency in S3) | High | High |
| R5 | Network & Data Exfiltration | S1–S3 (critical in S2+) | Very High | High |
| R6 | Network & Data Exfiltration | S2–S3 | High | High |
| R7 | Network & Data Exfiltration | S1–S3 | Medium | Medium |
| R8 | Platform & SDLC Governance | S2–S3 | High | High |
| R9 | Platform & SDLC Governance | S2–S3 | High | Medium |
| R10 | Platform & SDLC Governance | S2–S3 | Medium | High |
| R11 | Supply Chain & Runtime | S2–S3 | Very High | High |
| R12 | Supply Chain & Runtime | S2–S3 | High | Medium |
| R13 | Supply Chain & Runtime | S3 | Very High | High |
| R14 | Infrastructure & Observability Risks | S3 | High | High |
| R15 | Infrastructure & Observability Risks | S3 | High | Medium |
| R16 | Infrastructure & Observability Risks | S3 | Medium | High |
| R17 | Environment & Data Risks | S1–S3 | Medium | Medium |
| R18 | Environment & Data Risks | S1–S3 | Medium | Medium |
| R19 | Cross-cutting / Strategic Risks | S2–S3 | Medium | High |
| R20 | Cross-cutting / Strategic Risks | S2–S4 | Medium | Medium |
| R21 | Network & Data Exfiltration | S2–S4 | Very High | High |
| R22 | Platform & SDLC Governance | S3 | High | Medium |
| R23 | Identity & Access | S2–S3 | High | Medium |
| R24 | Network & Data Exfiltration | S1–S3 | High | Medium |
| R25 | Platform & SDLC Governance | S2–S4 | High | Medium |
| R26 | Identity & Access | S1–S4 | Medium | Medium |
| R27 | Environment & Data Risks | S1–S4 | High | Medium |

## Detailed risks

### R1 - Identity & Access

| Field | Value |
|---|---|
| Scenario(s) | S1–S3 |
| Impact | High |
| Likelihood | High |

**Risk description**

Foundry's default API keys are shared, so we can't tell which person or system made any given request. That breaks audit trails and fails the 'unique user' rule our certifications require – and a shared key, once leaked, opens the whole resource.

**Key controls / drivers from source**

API keys violate ISMS-ACCESS-2, CE+ A7.2, ISO A.5.35

**Mitigation from source**

Enforce Entra auth, disable local auth

**Additional source notes**

- **Column 9**: Disable Keys for Foundry Models. Use User RBAC

#### SE recommendation

Disable local/API key authentication for Foundry model consumption and require Entra ID authentication with role-based access control. Foundry models should only be consumed by an authenticated user or workload identity with explicitly assigned RBAC permissions.

#### Pros

- Provides per-user or per-workload traceability for audit evidence.
- Removes the shared-secret exposure path if an API key is leaked.
- Aligns with the source mitigation to enforce Entra auth and disable local auth.

#### Cons / trade-offs

- Requires all consuming applications, agents, and pipelines to use managed identity, workload identity, or user authentication rather than static keys.
- Existing integrations using keys must be remediated before local auth is disabled.

#### Decision made

- **Decision**: Disable keys for Foundry models and use Entra ID/RBAC-based access only.
- **Owner**: Vincent Rouet / Microsoft SE team
- **Date**: 18 June 2026, 05:01 PM GMT+1
- **Status**: Decided
- **Why**: The transcript confirms the decision was clear because shared Foundry API keys break unique-user auditability and create a broad exposure path if leaked. Enforcing authenticated identities provides auditable, role-scoped access.

#### Next actions

- [ ] Confirm Foundry local authentication can be disabled across all relevant environments and identify any key-based consumers that need migration.

---

### R2 - Identity & Access

| Field | Value |
|---|---|
| Scenario(s) | S2–S3 |
| Impact | High |
| Likelihood | Medium |

**Risk description**

An AI agent decides for itself at run-time which tools and data to use, so its account can reach far more than an ordinary application would. If the agent is manipulated, the potential damage spans everything that identity can touch – a much bigger breach radius than usual.

**Key controls / drivers from source**

“Lethal trifecta” (data + tools + egress); ISMS-ACCESS-2, CE+ A7.2, ISO A.5.17, SOC 2 CC6.1.8

**Mitigation from source**

Tighten identity scoping beyond standard least-privilege

**Additional source notes**

- **Column 9**: An agent will only access internal data via tools that has been coded. So is the risk for the developer to add tools they are not supposed to? How is this different than traditional apps?

#### SE recommendation

Do not create a separate Foundry-specific risk action for this item. Treat agent tool and data access as an application SDLC control: only approved tools should be deployed, tool endpoints should be checked during CI/CD, and runtime tool access should be limited to registered MCP tools exposed through API Management and authorized through user authentication.

#### Pros

- Reuses the same control model already applied to traditional application development.
- Keeps the compliance focus on code review, CI/CD validation, approved tool registration, and authenticated access.
- Provides a practical control point by checking that tool URLs are approved MCP tools registered in API Management.

#### Cons / trade-offs

- Depends on CI/CD controls and review gates being consistently implemented.
- Residual risk remains if developers add unapproved tools and those changes bypass review or deployment checks.

#### Decision made

- **Decision**: No additional bespoke action is required for R2 beyond standard SDLC controls, CI/CD checks, approved MCP tool registration in API Management, and user-authorized access.
- **Owner**: Vincent Rouet / Microsoft SE team
- **Date**: 18 June 2026, 05:01 PM GMT+1
- **Status**: Decided
- **Why**: The transcript states that an agent can only access internal data through tools that have been coded, so this is equivalent to controlling backend data access in a traditional application. The agreed control is to validate during deployment that only approved MCP tools registered in API Management are used and that access is authorized by the user.

#### Next actions

- [ ] Define the CI/CD validation rule that checks tool endpoints against the approved MCP tool list in API Management.

---

### R3 - Identity & Access

| Field | Value |
|---|---|
| Scenario(s) | S4 |
| Impact | High |
| Likelihood | Medium |

**Risk description**

If an agent runs 'as the signed-in user', it inherits that person's access across every project they belong to. That could let one customer's or project's data surface in another, breaking the separation we promise clients. The risk only appears if we adopt that pattern (most likely in the Teams-published scenario).

**Key controls / drivers from source**

User identity not bounded to project

**Mitigation from source**

Avoid OBO / enforce workload identity boundary

**Additional source notes**

- **Column 9**: Yes, this one has to be design.  The data access is governed in Foundry

#### SE recommendation

> _Add recommended Microsoft position, reference architecture pattern, or mitigation approach._

#### Pros

- _Add benefit._

#### Cons / trade-offs

- _Add trade-off, residual risk, cost, or dependency._

#### Decision made

- **Decision**: _TBD_
- **Owner**: _TBD_
- **Date**: _TBD_
- **Status**: _Open_

#### Next actions

- [ ] _Add next action, owner, and due date._

---

### R4 - Identity & Access

| Field | Value |
|---|---|
| Scenario(s) | S1–S3 (adoption dependency in S3) |
| Impact | High |
| Likelihood | High |

**Risk description**

We govern developer access through two systems (GitHub teams for Platform and Entra groups for Foundry) that aren't kept in sync. People who change roles or leave can keep access they shouldn't, and we can't confidently evidence access reviews if audited.

**Key controls / drivers from source**

Multiple access control planes not reconciled; ISO A.5.18

**Mitigation from source**

Align Entra groups with developer access model

**Additional source notes**

- **Column 9**: Please clarify, how is it different than for a web app. A developer would use their Entra ID to work with Foundry, not their GitHub account. GitHub account is used to push code to repos (and use GHCP if available). Code is pushed to Azure via Pipeline running on service accounts

#### SE recommendation

> _Add recommended Microsoft position, reference architecture pattern, or mitigation approach._

#### Pros

- _Add benefit._

#### Cons / trade-offs

- _Add trade-off, residual risk, cost, or dependency._

#### Decision made

- **Decision**: _TBD_
- **Owner**: _TBD_
- **Date**: _TBD_
- **Status**: _Open_

#### Next actions

- [ ] _Add next action, owner, and due date._

---

### R5 - Network & Data Exfiltration

| Field | Value |
|---|---|
| Scenario(s) | S1–S3 (critical in S2+) |
| Impact | Very High |
| Likelihood | High |

**Risk description**

Agents can reach out to the internet on their own. If one is tricked by a malicious document or prompt, it could quietly send sensitive or customer data to an attacker – and there's no reliable way to catch this after the fact. Blocking outbound traffic by default is the only dependable defence.

**Key controls / drivers from source**

Agents dynamically call external endpoints; ISMS-MALWARE-7, ISO A.8.23, A.8.12, A.8.20, A.8.22

**Mitigation from source**

One Foundry instance per project. Enforce deny-by-default egress + application-specific allowlist

#### SE recommendation

> _Add recommended Microsoft position, reference architecture pattern, or mitigation approach._

#### Pros

- _Add benefit._

#### Cons / trade-offs

- _Add trade-off, residual risk, cost, or dependency._

#### Decision made

- **Decision**: _TBD_
- **Owner**: _TBD_
- **Date**: _TBD_
- **Status**: _Open_

#### Next actions

- [ ] _Add next action, owner, and due date._

---

### R6 - Network & Data Exfiltration

| Field | Value |
|---|---|
| Scenario(s) | S2–S3 |
| Impact | High |
| Likelihood | High |

**Risk description**

When Foundry runs the agent, that runtime sits outside of secure network controls. Securing it forces a choice between two network models that are mutually exclusive – and one of them permanently rules out the Hosted-Agent and Teams scenarios.

**Key controls / drivers from source**

Runtime outside existing network security model

**Mitigation from source**

Choose a network model at platform-pattern level (not per workload): Path 2.a (managedNetwork) is default-preferred; Path 2.b (subnet) only for small portfolios where foreclosing S3/S4 is acceptable. See R21.

#### SE recommendation

> _Add recommended Microsoft position, reference architecture pattern, or mitigation approach._

#### Pros

- _Add benefit._

#### Cons / trade-offs

- _Add trade-off, residual risk, cost, or dependency._

#### Decision made

- **Decision**: _TBD_
- **Owner**: _TBD_
- **Date**: _TBD_
- **Status**: _Open_

#### Next actions

- [ ] _Add next action, owner, and due date._

---

### R7 - Network & Data Exfiltration

| Field | Value |
|---|---|
| Scenario(s) | S1–S3 |
| Impact | Medium |
| Likelihood | Medium |

**Risk description**

If a production Foundry instance isn't locked to our private network, its stored files and conversation history are reachable from the public internet with only an API key. (Development instances are deliberately internet-facing under an agreed, contained exception.)

**Key controls / drivers from source**

Public endpoints + API access

**Mitigation from source**

Private endpoints (prod), controlled dev-tier isolation

#### SE recommendation

> _Add recommended Microsoft position, reference architecture pattern, or mitigation approach._

#### Pros

- _Add benefit._

#### Cons / trade-offs

- _Add trade-off, residual risk, cost, or dependency._

#### Decision made

- **Decision**: _TBD_
- **Owner**: _TBD_
- **Date**: _TBD_
- **Status**: _Open_

#### Next actions

- [ ] _Add next action, owner, and due date._

---

### R8 - Platform & SDLC Governance

| Field | Value |
|---|---|
| Scenario(s) | S2–S3 |
| Impact | High |
| Likelihood | High |

**Risk description**

Foundry agents are configuration data, so by default they sit outside our normal 'what's in Git is what's in production' control. Without that, we lose a trustworthy record of what's running and how it changed, and can't effectively apply IT Change Management – undermining change audits and our ability to recover.

**Key controls / drivers from source**

Foundry agents are “data-plane JSON”, not IaC; ISO A.5.9, ISMS-ASSET-1, SOC 2 CC8.1.12, ISO A.8.9, ISO A.5.33

**Mitigation from source**

Build reconciliation loop (Git as source of truth) AND enforce policy denying agents/* writes except from the reconciliation identity (closes portal/SDK/laptop bypass).

#### SE recommendation

> _Add recommended Microsoft position, reference architecture pattern, or mitigation approach._

#### Pros

- _Add benefit._

#### Cons / trade-offs

- _Add trade-off, residual risk, cost, or dependency._

#### Decision made

- **Decision**: _TBD_
- **Owner**: _TBD_
- **Date**: _TBD_
- **Status**: _Open_

#### Next actions

- [ ] _Add next action, owner, and due date._

---

### R9 - Platform & SDLC Governance

| Field | Value |
|---|---|
| Scenario(s) | S2–S3 |
| Impact | High |
| Likelihood | Medium |

**Risk description**

Anyone with access could change a production agent directly through the Foundry portal, with no review or approval – bypassing the change-management hygiene that responsible AI and certifications depend on.

**Key controls / drivers from source**

ISMS-DEVOPS-1, ISMS-OPS-7, SOC 2 CC8.1.2/CC8.1.8, ISO A.8.32

**Mitigation from source**

Enforce policy: changes only via GitOps/ServiceNow (see R8).

#### SE recommendation

> _Add recommended Microsoft position, reference architecture pattern, or mitigation approach._

#### Pros

- _Add benefit._

#### Cons / trade-offs

- _Add trade-off, residual risk, cost, or dependency._

#### Decision made

- **Decision**: _TBD_
- **Owner**: _TBD_
- **Date**: _TBD_
- **Status**: _Open_

#### Next actions

- [ ] _Add next action, owner, and due date._

---

### R10 - Platform & SDLC Governance

| Field | Value |
|---|---|
| Scenario(s) | S2–S3 |
| Impact | Medium |
| Likelihood | High |

**Risk description**

Agents don't automatically appear in our asset register (CMDB), so one can run with no recorded owner and no oversight. That fails the basic 'know and own your assets' requirement and makes agents easy to lose track of.

**Key controls / drivers from source**

Agents not registered as assets by default; ISO A.5.9, ISMS-ASSET-1

**Mitigation from source**

Treat agents as first-class application assets (CMDB)

#### SE recommendation

> _Add recommended Microsoft position, reference architecture pattern, or mitigation approach._

#### Pros

- _Add benefit._

#### Cons / trade-offs

- _Add trade-off, residual risk, cost, or dependency._

#### Decision made

- **Decision**: _TBD_
- **Owner**: _TBD_
- **Date**: _TBD_
- **Status**: _Open_

#### Next actions

- [ ] _Add next action, owner, and due date._

---

### R11 - Supply Chain & Runtime

| Field | Value |
|---|---|
| Scenario(s) | S2–S3 |
| Impact | Very High |
| Likelihood | High |

**Risk description**

The code-interpreter tool lets an agent install arbitrary software while it runs, so we can never be sure exactly what code is executing. That breaks software-approval and supply-chain controls. Tools like this should stay switched off until leadership and Group Security explicitly accept the risk.

**Key controls / drivers from source**

Dynamic package install breaks approval model

**Mitigation from source**

Tool allowlist. code_interpreter: leadership + Group Security risk-acceptance before enabling. shell/apply_patch: default-exclude pending capability verification. (CE+ A6.5 scopes to OS/image patching, not libraries; CE+ A8.1 allowlisting governs.)

#### SE recommendation

> _Add recommended Microsoft position, reference architecture pattern, or mitigation approach._

#### Pros

- _Add benefit._

#### Cons / trade-offs

- _Add trade-off, residual risk, cost, or dependency._

#### Decision made

- **Decision**: _TBD_
- **Owner**: _TBD_
- **Date**: _TBD_
- **Status**: _Open_

#### Next actions

- [ ] _Add next action, owner, and due date._

---

### R12 - Supply Chain & Runtime

| Field | Value |
|---|---|
| Scenario(s) | S2–S3 |
| Impact | High |
| Likelihood | Medium |

**Risk description**

The 'shell' and 'apply_patch' tools may let an agent run arbitrary commands or programs. If they do, our certification rules forbid them outright with no exception available – so they should stay switched off until proven safe.

**Key controls / drivers from source**

CE+ A8.1 allowlisting

**Mitigation from source**

Default exclude tools until verified

#### SE recommendation

> _Add recommended Microsoft position, reference architecture pattern, or mitigation approach._

#### Pros

- _Add benefit._

#### Cons / trade-offs

- _Add trade-off, residual risk, cost, or dependency._

#### Decision made

- **Decision**: _TBD_
- **Owner**: _TBD_
- **Date**: _TBD_
- **Status**: _Open_

#### Next actions

- [ ] _Add next action, owner, and due date._

---

### R13 - Supply Chain & Runtime

| Field | Value |
|---|---|
| Scenario(s) | S3 |
| Impact | Very High |
| Likelihood | High |

**Risk description**

A hosted agent keeps running its original image and won't pick up security patches automatically, leaving it on known-vulnerable code. That breaks the 14-day patching rule – a hard certification failure. We can't adopt this scenario until we build an automatic patch-and-redeploy mechanism.

**Key controls / drivers from source**

Image pinned to digest, not updated automatically; CE+ A6.5, ISMS-MALWARE-3

**Mitigation from source**

Build patch-triggered redeployment controller

#### SE recommendation

> _Add recommended Microsoft position, reference architecture pattern, or mitigation approach._

#### Pros

- _Add benefit._

#### Cons / trade-offs

- _Add trade-off, residual risk, cost, or dependency._

#### Decision made

- **Decision**: _TBD_
- **Owner**: _TBD_
- **Date**: _TBD_
- **Status**: _Open_

#### Next actions

- [ ] _Add next action, owner, and due date._

---

### R14 - Infrastructure & Observability Risks

| Field | Value |
|---|---|
| Scenario(s) | S3 |
| Impact | High |
| Likelihood | High |

**Risk description**

The hosted runtime lives on Microsoft-owned infrastructure we can't see into, so our usual monitoring and scanning don't reach it. We'd depend more on Microsoft and be less able to spot or investigate problems ourselves.

**Key controls / drivers from source**

No access to host-level telemetry

**Mitigation from source**

Accept vendor boundary at host level; build app-layer observability (App Insights); define a custom observer role; resolve GitHub-Entra reconciliation; SecOps runbook for Logstream-based log retrieval.

#### SE recommendation

> _Add recommended Microsoft position, reference architecture pattern, or mitigation approach._

#### Pros

- _Add benefit._

#### Cons / trade-offs

- _Add trade-off, residual risk, cost, or dependency._

#### Decision made

- **Decision**: _TBD_
- **Owner**: _TBD_
- **Date**: _TBD_
- **Status**: _Open_

#### Next actions

- [ ] _Add next action, owner, and due date._

---

### R15 - Infrastructure & Observability Risks

| Field | Value |
|---|---|
| Scenario(s) | S3 |
| Impact | High |
| Likelihood | Medium |

**Risk description**

Vulnerability management is a continuous process, but our scanner (Tenable) can't reach the agent running on Microsoft-managed compute. We can only scan images in the registry, with no way to confirm which are actually live – so findings become noise (issues on images that aren't deployed) or inertia (real issues missed). These systems then fall out of vulnerability governance, unpatched and unevidenced, until an incident or a Cyber Essentials audit failure.

**Key controls / drivers from source**

Tenable can't reach the managed runtime to confirm what's deployed; ISO A.8.8, ISMS-MALWARE-5. Counterpart to R13 (patch delivery).

**Mitigation from source**

Extend vulnerability governance to Foundry: scope scanning to the digests actually deployed (known from R13's controller)

#### SE recommendation

> _Add recommended Microsoft position, reference architecture pattern, or mitigation approach._

#### Pros

- _Add benefit._

#### Cons / trade-offs

- _Add trade-off, residual risk, cost, or dependency._

#### Decision made

- **Decision**: _TBD_
- **Owner**: _TBD_
- **Date**: _TBD_
- **Status**: _Open_

#### Next actions

- [ ] _Add next action, owner, and due date._

---

### R16 - Infrastructure & Observability Risks

| Field | Value |
|---|---|
| Scenario(s) | S3 |
| Impact | Medium |
| Likelihood | High |

**Risk description**

When using managed compute, we get only limited, hard-to-keep logs from the layer Microsoft manages, which would make investigating an incident harder.

**Key controls / drivers from source**

No persistent logging surface; ISO A.8.15, A.8.16, SOC 2 CC7.2

**Mitigation from source**

Build logging bridge or accept gap

#### SE recommendation

> _Add recommended Microsoft position, reference architecture pattern, or mitigation approach._

#### Pros

- _Add benefit._

#### Cons / trade-offs

- _Add trade-off, residual risk, cost, or dependency._

#### Decision made

- **Decision**: _TBD_
- **Owner**: _TBD_
- **Date**: _TBD_
- **Status**: _Open_

#### Next actions

- [ ] _Add next action, owner, and due date._

---

### R17 - Environment & Data Risks

| Field | Value |
|---|---|
| Scenario(s) | S1–S3 |
| Impact | Medium |
| Likelihood | Medium |

**Risk description**

Development Foundry instances can quietly build up real data, secrets, and access over time and become 'shadow' AI systems we're running without realising. Regular purging, no production credentials, and a data policy keep this contained.

**Key controls / drivers from source**

Foundry dev instances persistent & accessible

**Mitigation from source**

Data policy + regular purge + no production creds

#### SE recommendation

> _Add recommended Microsoft position, reference architecture pattern, or mitigation approach._

#### Pros

- _Add benefit._

#### Cons / trade-offs

- _Add trade-off, residual risk, cost, or dependency._

#### Decision made

- **Decision**: _TBD_
- **Owner**: _TBD_
- **Date**: _TBD_
- **Status**: _Open_

#### Next actions

- [ ] _Add next action, owner, and due date._

---

### R18 - Environment & Data Risks

| Field | Value |
|---|---|
| Scenario(s) | S1–S3 |
| Impact | Medium |
| Likelihood | Medium |

**Risk description**

If our test environment doesn't mirror production's security controls, testing gives false confidence and problems only surface once live. We need both a production-like cloud tier and the lightweight local tier.

**Key controls / drivers from source**

Public vs private network mismatch

**Mitigation from source**

Dual-tier dev/test model (cloud + local)

#### SE recommendation

> _Add recommended Microsoft position, reference architecture pattern, or mitigation approach._

#### Pros

- _Add benefit._

#### Cons / trade-offs

- _Add trade-off, residual risk, cost, or dependency._

#### Decision made

- **Decision**: _TBD_
- **Owner**: _TBD_
- **Date**: _TBD_
- **Status**: _Open_

#### Next actions

- [ ] _Add next action, owner, and due date._

---

### R19 - Cross-cutting / Strategic Risks

| Field | Value |
|---|---|
| Scenario(s) | S2–S3 |
| Impact | Medium |
| Likelihood | High |

**Risk description**

Each step beyond the basic scenario adds its own governance work. If teams adopt Foundry in an uncoordinated way, that cost multiplies and delivery slows. Agreeing standard patterns early keeps it manageable.

**Key controls / drivers from source**

Each deviation creates new governance surface

**Mitigation from source**

Standardise patterns early

#### SE recommendation

> _Add recommended Microsoft position, reference architecture pattern, or mitigation approach._

#### Pros

- _Add benefit._

#### Cons / trade-offs

- _Add trade-off, residual risk, cost, or dependency._

#### Decision made

- **Decision**: _TBD_
- **Owner**: _TBD_
- **Date**: _TBD_
- **Status**: _Open_

#### Next actions

- [ ] _Add next action, owner, and due date._

---

### R20 - Cross-cutting / Strategic Risks

| Field | Value |
|---|---|
| Scenario(s) | S2–S4 |
| Impact | Medium |
| Likelihood | Medium |

**Risk description**

It's tempting to treat Microsoft Agent 365 as our safeguard, since all Foundry agents now auto-appear in its registry. Yet the registry is only an inventory: its controls (Purview, Defender) act only on activity we explicitly instrument, and only on Microsoft-mediated surfaces – they're blind to an agent's calls to our core engineering systems (Autodesk, Bentley, ESRI) and any API-key or third-party connections. Most of what it offers is detect-after-the-fact, with only narrow preventive cover. Treating registry presence as coverage gives false assurance.

**Key controls / drivers from source**

Detection-not-prevention; coverage limited to instrumented, Microsoft-mediated surfaces; excludes third-party engineering systems; full stack needs Entra P1/P2 + Purview + Defender licences

**Mitigation from source**

Keep preventative controls on the platform; treat Agent 365 as a backstop, not the primary safeguard. Don't equate registry listing with governance; where used, require SDK instrumentation and the supporting licences.

#### SE recommendation

> _Add recommended Microsoft position, reference architecture pattern, or mitigation approach._

#### Pros

- _Add benefit._

#### Cons / trade-offs

- _Add trade-off, residual risk, cost, or dependency._

#### Decision made

- **Decision**: _TBD_
- **Owner**: _TBD_
- **Date**: _TBD_
- **Status**: _Open_

#### Next actions

- [ ] _Add next action, owner, and due date._

---

### R21 - Network & Data Exfiltration

| Field | Value |
|---|---|
| Scenario(s) | S2–S4 |
| Impact | Very High |
| Likelihood | High |

**Risk description**

The network model for Foundry is a one-time choice that can't be changed later without costly and disruptive rebuilds, and one option rules out the Hosted-Agent and Teams scenarios. Choosing wrongly means either costly rework or losing future options, so it must be decided deliberately and up front for the platform as a whole.

**Key controls / drivers from source**

Capability host commits account (no incremental update path); Path 2.b excludes hosted agents

**Mitigation from source**

Decide the network model at platform-pattern level upfront; treat as an architectural commitment

#### SE recommendation

> _Add recommended Microsoft position, reference architecture pattern, or mitigation approach._

#### Pros

- _Add benefit._

#### Cons / trade-offs

- _Add trade-off, residual risk, cost, or dependency._

#### Decision made

- **Decision**: _TBD_
- **Owner**: _TBD_
- **Date**: _TBD_
- **Status**: _Open_

#### Next actions

- [ ] _Add next action, owner, and due date._

---

### R22 - Platform & SDLC Governance

| Field | Value |
|---|---|
| Scenario(s) | S3 |
| Impact | High |
| Likelihood | Medium |

**Risk description**

For hosted agents, our safeguard that 'only approved, scanned images run in production' only holds if the automated pipeline is the single way to deploy. If anyone can register an agent directly, they could push unreviewed code straight to production – or publish it to tenant-wide Teams/M365 surfaces without Scenario 4 governance – bypassing every check and breaking compartmentalisation.

**Key controls / drivers from source**

Microsoft-managed runtime; no host-level admission controller can be installed

**Mitigation from source**

Azure Policy / tightly-scoped IAM restricting agents/* writes to the reconciliation identity (sole-deployment-pathway guarantee); deny publishing operations on instances not classified as published.

#### SE recommendation

> _Add recommended Microsoft position, reference architecture pattern, or mitigation approach._

#### Pros

- _Add benefit._

#### Cons / trade-offs

- _Add trade-off, residual risk, cost, or dependency._

#### Decision made

- **Decision**: _TBD_
- **Owner**: _TBD_
- **Date**: _TBD_
- **Status**: _Open_

#### Next actions

- [ ] _Add next action, owner, and due date._

---

### R23 - Identity & Access

| Field | Value |
|---|---|
| Scenario(s) | S2–S3 |
| Impact | High |
| Likelihood | Medium |

**Risk description**

To connect to other systems, Foundry can store a long-lived, password-style token that never expires, can't use our safer sign-in, and sits outside our normal secret-handling – raising the chance of a leaked credential. Prefer connections that use managed sign-in, and route anything needing the insecure method through the pro-code platform path.

**Key controls / drivers from source**

No managed-identity path for MCP; connector secrets outside the platform secret surface

**Mitigation from source**

Prefer AAD/managed-identity connectors; disable secret-bearing connectors by default; route secure-MCP workloads via S1 pro-code; pursue Secure Data Pathway brokering.

#### SE recommendation

> _Add recommended Microsoft position, reference architecture pattern, or mitigation approach._

#### Pros

- _Add benefit._

#### Cons / trade-offs

- _Add trade-off, residual risk, cost, or dependency._

#### Decision made

- **Decision**: _TBD_
- **Owner**: _TBD_
- **Date**: _TBD_
- **Status**: _Open_

#### Next actions

- [ ] _Add next action, owner, and due date._

---

### R24 - Network & Data Exfiltration

| Field | Value |
|---|---|
| Scenario(s) | S1–S3 |
| Impact | High |
| Likelihood | Medium |

**Risk description**

A booby-trapped document could trick an agent into smuggling data out through the user's own browser – for example hidden inside an image link – slipping past normal input checks and outbound blocking. A browser content-security policy on any screen that shows agent output closes this.

**Key controls / drivers from source**

Client-side rendering exfil channel; ISO A.8.26, ISO A.8.28

**Mitigation from source**

Enforce Content Security Policy in Platform frontends restricting external resources the browser may load on any frontend rendering agent output.

#### SE recommendation

> _Add recommended Microsoft position, reference architecture pattern, or mitigation approach._

#### Pros

- _Add benefit._

#### Cons / trade-offs

- _Add trade-off, residual risk, cost, or dependency._

#### Decision made

- **Decision**: _TBD_
- **Owner**: _TBD_
- **Date**: _TBD_
- **Status**: _Open_

#### Next actions

- [ ] _Add next action, owner, and due date._

---

### R25 - Platform & SDLC Governance

| Field | Value |
|---|---|
| Scenario(s) | S2–S4 |
| Impact | High |
| Likelihood | Medium |

**Risk description**

Inside Foundry, someone with the right access can permanently delete an agent's change history, destroying the audit trail we'd rely on to investigate an incident or prove compliance. Keeping the authoritative record in Git (which is the standard record that we already protect) is the safe position.

**Key controls / drivers from source**

ISO A.5.33 (records protected from destruction/falsification)

**Mitigation from source**

Git as the authoritative agent-definition record; Azure Policy restricting agents/* writes; do not rely on the in-Foundry version list for audit.

#### SE recommendation

> _Add recommended Microsoft position, reference architecture pattern, or mitigation approach._

#### Pros

- _Add benefit._

#### Cons / trade-offs

- _Add trade-off, residual risk, cost, or dependency._

#### Decision made

- **Decision**: _TBD_
- **Owner**: _TBD_
- **Date**: _TBD_
- **Status**: _Open_

#### Next actions

- [ ] _Add next action, owner, and due date._

---

### R26 - Identity & Access

| Field | Value |
|---|---|
| Scenario(s) | S1–S4 |
| Impact | Medium |
| Likelihood | Medium |

**Risk description**

On a shared Foundry instance, files can accumulate in a store that routine access reviews don't surface – so sensitive data lingers unnoticed (unintended retention) and can be reachable across project or customer boundaries (leakage to the wrong customer). Giving each project its own Foundry instance removes both.

**Key controls / drivers from source**

ISMS-ACCESS-6, CE+ A7.4 (access scoped to role)

**Mitigation from source**

One Foundry instance per project.

#### SE recommendation

> _Add recommended Microsoft position, reference architecture pattern, or mitigation approach._

#### Pros

- _Add benefit._

#### Cons / trade-offs

- _Add trade-off, residual risk, cost, or dependency._

#### Decision made

- **Decision**: _TBD_
- **Owner**: _TBD_
- **Date**: _TBD_
- **Status**: _Open_

#### Next actions

- [ ] _Add next action, owner, and due date._

---

### R27 - Environment & Data Risks

| Field | Value |
|---|---|
| Scenario(s) | S1–S4 |
| Impact | High |
| Likelihood | Medium |

**Risk description**

Everything users type, upload, and get back is stored by Foundry with no sensitivity labelling, retention limit, or deletion process. Sensitive or personal data could pile up unmanaged, breaching our data-handling and privacy obligations. This needs its own classification, retention and disposal controls.

**Key controls / drivers from source**

Nothing labels conversation data by sensitivity; ISO A.5.12, retention/disposal obligations

**Mitigation from source**

Define classification, retention, access and disposal controls for Foundry conversation state.

#### SE recommendation

> _Add recommended Microsoft position, reference architecture pattern, or mitigation approach._

#### Pros

- _Add benefit._

#### Cons / trade-offs

- _Add trade-off, residual risk, cost, or dependency._

#### Decision made

- **Decision**: _TBD_
- **Owner**: _TBD_
- **Date**: _TBD_
- **Status**: _Open_

#### Next actions

- [ ] _Add next action, owner, and due date._

---

