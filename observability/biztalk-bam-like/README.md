# Agentic BAM — Business Activity Monitoring for Multi-Agent Orchestrations

## Overview

Agentic BAM brings BizTalk BAM principles to AI agent orchestrations. It enables
business users to track the lifecycle of business objects (sales orders, claims,
onboarding cases) as they flow through multiple agents — without the agents
themselves being aware of the monitoring.

## Core Principles (inherited from BizTalk BAM)

1. **Business-user-driven definitions** — Activities, milestones, and data items
   are defined by business stakeholders, not developers.
2. **Separation from execution** — Agents have zero awareness of BAM. Tracking
   is configured via profiles that bind agent lifecycle events to milestones.
3. **Correlation across boundaries** — A composite correlation token links all
   milestones for a business object, even across different agent orchestrations.
4. **Views for different stakeholders** — Finance sees different data than ops.
5. **Active/Completed partitioning** — Active instances are queryable in real-time;
   completed instances are archived for historical analysis.

## Architecture

```
┌──────────────────────────────────────────────────────────────┐
│                    Agent Orchestrations                        │
│  (Microsoft Agent Framework + Azure AI Foundry Agents)        │
│                                                               │
│  ┌─────────┐  ┌──────────┐  ┌─────────┐  ┌──────────────┐   │
│  │ Intake  │→ │Validation│→ │ Credit  │→ │  Approval    │   │
│  │ Agent   │  │  Agent   │  │  Agent  │  │    Agent     │   │
│  └────┬────┘  └────┬─────┘  └────┬────┘  └──────┬───────┘   │
│       │             │             │              │            │
└───────┼─────────────┼─────────────┼──────────────┼────────────┘
        │             │             │              │
        ▼             ▼             ▼              ▼
┌──────────────────────────────────────────────────────────────┐
│              BAM Interceptor Middleware                        │
│  (reads tracking profiles, writes milestones)                 │
└──────────────────────────────────────────────────────────────┘
        │
        ▼
┌──────────────────────────────────────────────────────────────┐
│              BAM Activity Store (SQL / Kusto)                  │
│  ┌─────────────────────┐  ┌───────────────────────────┐      │
│  │  Active Instances    │  │  Completed Instances       │      │
│  │  (real-time queries) │  │  (historical/aggregation)  │      │
│  └─────────────────────┘  └───────────────────────────────┘   │
└──────────────────────────────────────────────────────────────┘
        │
        ▼
┌──────────────────────────────────────────────────────────────┐
│              BAM Portal / Dashboards                           │
│  Views • Aggregations • Alerts • Drill-down                   │
└──────────────────────────────────────────────────────────────┘
```

## Correlation Token Format

```
{Division}-{ObjectType}-{ObjectID}-{Timestamp}
```

Example: `EMEA-SO-4821-20260714T140103Z`

See `schema/correlation-token.md` for full specification.

## Quick Start

1. Define your activity: `definitions/sales-order.activity.yaml`
2. Create a tracking profile: `tracking-profiles/sales-order.profile.yaml`
3. Deploy infrastructure: `infrastructure/deploy.bicep`
4. Register the interceptor in your agent host
5. Business users consume via the portal

## Project Structure

```
agentic-bam/
├── schema/                    # JSON schemas and specifications
├── definitions/               # Activity definitions (YAML)
├── tracking-profiles/         # Tracking profiles binding agents → milestones
├── infrastructure/            # Bicep/Terraform for backing store + portal
├── runtime/                   # Interceptor middleware (C#)
└── portal/                    # Dashboard queries and views
```
