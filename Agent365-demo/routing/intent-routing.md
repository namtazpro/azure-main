---
title: Intent and Skill Routing Design
description: Routing model for the Construction Compliance Intelligence Agent using Microsoft Agent Framework and Agent365 SDK
author: Azure Main Team
ms.date: 2026-06-08
ms.topic: reference
keywords:
  - intent routing
  - skills
  - construction compliance
estimated_reading_time: 7
---

## Routing objective

Route each user request to a deterministic skill sequence that produces a source-backed and jurisdiction-aware compliance response.

## Intent catalog

### Intent 1: identify_constraints

* Trigger phrases: "what constraints apply", "applicable code requirements", "design rules for".
* Required inputs: country, buildingType, occupancyClass, designStage.
* Skill order:
  1. jurisdictionResolver
  2. regulationRetrieval
  3. constraintEngine
  4. citationAudit

### Intent 2: compare_jurisdictions

* Trigger phrases: "compare regulations", "difference between country A and B".
* Required inputs: two jurisdictions plus same building context.
* Skill order:
  1. jurisdictionResolver for jurisdiction A
  2. jurisdictionResolver for jurisdiction B
  3. regulationRetrieval for each
  4. constraintEngine
  5. citationAudit

### Intent 3: prepermit_risk_check

* Trigger phrases: "check design", "pre-permit review", "red flags".
* Required inputs: design parameter set and jurisdiction.
* Skill order:
  1. jurisdictionResolver
  2. regulationRetrieval
  3. constraintEngine
  4. designChecker
  5. citationAudit

### Intent 4: explain_clause

* Trigger phrases: "explain this clause", "interpret section".
* Required inputs: clause reference or legal text plus jurisdiction context.
* Skill order:
  1. regulationRetrieval
  2. citationAudit

## Unknown and fallback handling

* If jurisdiction is unsupported, return coverageStatus as unsupported and request nearest supported alternative.
* If required inputs are missing, return clarificationRequests with exact fields needed.
* If citation confidence is below threshold, return unknown instead of inferred legal advice.

## Output structure guideline

* applicableRegulations: list of authority, code name, edition, amendment date.
* constraints: grouped by category.
* riskFindings: each finding includes severity, rationale, and impacted design parameter.
* citations: clause-level references and source links.
* coverageStatus: supported, partial, unsupported.

## Minimal orchestrator pseudocode

```text
resolveIntent(request)
validateRequiredFields(intent, request)
if missingFields then return clarification

context <- resolveJurisdiction(request)
if context.unsupported then return unsupportedCoverage

sources <- retrieveRegulations(context, request)
constraints <- extractConstraints(sources, request)

if intent == prepermit_risk_check then
  findings <- evaluateDesign(constraints, request.designParameters)

response <- composeResponse(constraints, findings, sources)
return citationAudit(response)
```

## Quality gates before returning

* Every constraint has at least one citation.
* Every citation includes code version metadata.
* Every high-severity finding contains explicit design impact language.
* Response includes advisory-only compliance disclaimer.
