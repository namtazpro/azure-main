---
title: Issue 4 - Two Primary KPIs
description: Overview of Track 4 covering the scenario classification and response correctness KPIs for the supply chain email automation solution.
author: Vincent Rouet
ms.date: 2026-07-29
ms.topic: concept
keywords:
  - kpi
  - scenario classification
  - response correctness
  - automation rate
estimated_reading_time: 4
---

## Issue 4 - Two primary KPIs

Track 4 is about **optimising the two KPIs of primary significance** for the solution. Two additional KPIs are also tracked, but these two are the focus:

| Sub-issue | KPI | What it measures | Status |
|-----------|-----|------------------|--------|
| 4.a | Scenario classification | Accuracy of the classification module - how correctly inbound emails are mapped to a scenario | [Documented](4a-scenario-classification.md) |
| 4.b | Response correctness | Proxy for the automation rate - how correctly the response template is filled from the extracted details and presented to the specialist | [Documented](4b-response-correctness.md) |

The **North Star is maximum automation**: reduce both incorrect initial classifications and specialist reclassifications so that more emails flow straight through without manual intervention.

## Sub-issues

- **[4.a - Scenario classification](4a-scenario-classification.md)** - the accuracy of the classification module, currently blocked by poor recall on the "unknown" category and overlapping scenarios.
- **[4.b - Response correctness](4b-response-correctness.md)** - measures how well the pipeline selects and fills the response template presented to the specialist. Detailed in the 29 July 2026 ("Walk through 4b") follow-up session.

## Evaluation and data

Improving these KPIs requires measuring changes objectively:

- [Evaluation strategy with Foundry Evaluations](evaluation-strategy-foundry.md) - code-first evaluation woven into the agent development lifecycle.
- [Building the evaluation dataset](dataset-guidance.md) - how to build the golden / ground-truth dataset the evaluation depends on.

## Related context

Both KPIs depend on the same upstream pipeline: pre-processing, classification, parallel entity extraction, OTM and SAP calls, and the business logic (happy path) defined per scenario. See [4.a - Scenario classification](4a-scenario-classification.md) for the detailed pipeline and issue analysis.
