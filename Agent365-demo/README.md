---
title: Construction Compliance Intelligence Agent Starter
description: Starter package for a Microsoft Agent Framework plus Agent365 SDK agent focused on building regulation constraints across countries
author: Azure Main Team
ms.date: 2026-06-08
ms.topic: how-to
keywords:
  - agent365
  - microsoft agent framework
  - construction compliance
  - building regulations
estimated_reading_time: 6
---

## Overview

This starter package defines a practical v1 agent for engineers and architects in the construction industry. The agent helps users identify applicable building regulations, extract actionable constraints, and flag early design risks before formal submission.

## Business outcome

* Reduce late-stage rework caused by jurisdiction mismatches.
* Improve pre-permit readiness with traceable citations.
* Standardize cross-country constraint checks at concept and schematic stages.

## What this package contains

* A registration manifest template for Agent365 in [agent365-manifest.template.json](agent365-manifest.template.json).
* An intent and skill routing design in [routing/intent-routing.md](routing/intent-routing.md).
* A validation prompt pack in [tests/acceptance-prompts.md](tests/acceptance-prompts.md).
* A runnable .NET sample runtime in [src/ConstructionCompliance.Agent/Program.cs](src/ConstructionCompliance.Agent/Program.cs).
* A sample request collection in [requests/sample-invoke.http](requests/sample-invoke.http).

## Suggested v1 scope

* Support pre-permit screening only.
* Start with a limited country set and clearly declare supported jurisdictions.
* Return structured findings with source references, confidence, and missing-data requests.
* Require explicit user confirmation for actions that create reports or export artifacts.

## Suggested implementation stack

* Agent orchestration: Microsoft Agent Framework.
* Registration and host integration: Agent365 SDK.
* Retrieval layer: versioned legal and standards corpus per jurisdiction.
* Constraint representation: normalized JSON with category, rule, threshold, unit, and citation.

## Safety and legal guardrails

* Never provide uncited legal claims.
* Always include regulation version and amendment date used for analysis.
* Surface unknown or unsupported coverage areas explicitly.
* Add advisory disclaimer that licensed local professionals perform final compliance sign-off.

## Next implementation step

Use [agent365-manifest.template.json](agent365-manifest.template.json) as the base, wire the intent router from [routing/intent-routing.md](routing/intent-routing.md), and run all prompts in [tests/acceptance-prompts.md](tests/acceptance-prompts.md) as your first acceptance gate.

## Run locally

1. Build the solution.

```bash
dotnet build Agent365-demo/ConstructionCompliance.sln
```

2. Run the API host.

```bash
dotnet run --project Agent365-demo/src/ConstructionCompliance.Agent/ConstructionCompliance.Agent.csproj --urls http://localhost:5099
```

3. Execute sample requests from [requests/sample-invoke.http](requests/sample-invoke.http).

## Current endpoint surface

* `GET /health`
* `GET /api/agent365/registration`
* `POST /api/agent/invoke`

## Important note about SDK integration

This scaffold demonstrates routing, contracts, and orchestration with mock skills. Replace mock skill classes in [src/ConstructionCompliance.Agent/Skills/MockSkills.cs](src/ConstructionCompliance.Agent/Skills/MockSkills.cs) with real Agent365 SDK skill bindings and your jurisdiction-specific regulation corpus before production use.
