---
title: Issue 4.a - Scenario Classification
description: Detailed analysis of the scenario classification KPI for the Unilever supply chain email automation solution, including the pipeline, root causes of poor accuracy, and proposed actions.
author: Vincent Rouet
ms.date: 2026-07-29
ms.topic: concept
keywords:
  - scenario classification
  - recall
  - precision
  - golden dataset
  - microsoft foundry
  - evaluation
estimated_reading_time: 10
---

## Issue 4.a - Scenario classification

Scenario classification is the first of the two primary KPIs in [Track 4](README.md). It measures the **accuracy of the classification module**: out of the emails going through the classifier, how accurately the correct scenario is identified.

> Source: walkthrough call on 28 July 2026. Participants: Vincent Rouet, Amogh Singhal, Rohit Gavval, Sourav Dutta (developer), Anjali Iyer, Sameer Kulkarni.

## How classification works today

1. **Ingestion** - a logistics email is redirected from a specialist mailbox into the application. The message is tracked using the Microsoft Graph **message ID** and **conversation ID**.
2. **Pre-processing** - a pre-processing layer cleans the email body and subject (for example, removing signatures) before classification.
3. **Classification** - the cleaned **subject, body, timestamp, and sender** are sent to the classification agent (Semantic Kernel + Azure OpenAI). The prompt defines **12 scenarios** plus a **13th "unknown" category** for anything that does not match.
4. **Entity extraction (parallel)** - entities such as the shipment number are extracted so an **OTM** call can fetch additional shipment details. **SAP BTP** acts as the API gateway; SAP is also called in some scenarios to check warehouse stock.
5. **Routing**:
   - **Scenarios with business logic** (9 currently live in production, out of the 12 defined) follow their defined happy path and are automated.
   - **Scenarios without business logic** (currently scenarios 10-12) are classified but **not automated**, and are forwarded back to the specialist's mailbox.
   - **Unknown (13th category)** is forwarded to the specialist for manual handling.
6. **Follow-up handling** - only a fresh email (no parent ID) is classified. A follow-up on the same thread inherits the parent's scenario and is **not re-classified**. Conversation history is stored in **Cosmos DB**.

### Manual intervention and reclassification

The specialist reviews the bot's classification in the web UI and can either **continue as-is** or **reclassify** using a drop-down of all 13 categories (12 scenarios + unknown). For audit purposes, when a reclassification happens the original bot value is retained in a `bot scenario` column while the `scenario` column is updated to the specialist's choice; a `correct by bot (yes/no)` flag is also recorded by an SME.

## The problem

The classifier does well on the **core operational (automated) scenarios** - **precision is good** - but the overall scenario-level accuracy is dragged down:

- **Recall is not yet estimated** (data is still being gathered), and recall on the **"unknown" category is very poor**. Because there is no clear boundary or definition around "unknown", it is becoming a **blocker** to moving forward.
- **Overlapping scenarios** - for example "loading reference" vs "unloading reference" - are hard to tell apart from the email wording.
- **Low-quality, poorly formed emails** make interpretation difficult (data unsuitability).
- The **prompt is keyword / phrase driven**, mirroring how specialists classify today. It works, but it is not the ideal way to write the prompt; it relies on wordings and phrases rather than meaning.
- **Specialists themselves sometimes cannot classify** an email and select "unknown", and the quality of specialist reclassification is on a **downtrend**. This makes it hard for the platform to learn from that data.
- **No look-back / memory** - the agent sees only the single email (subject, body, timestamp, sender). A message like "where is my truck?" with no other context is likely to fall into "unknown" because the agent has no access to earlier emails that carried the shipment or consignment number.

## Proposed actions

Actions raised during the call, roughly in priority order:

1. **Give the agent more context (memory / history).** Let the agent look back at previous emails from the same conversation or sender - for example via an MCP endpoint that queries the email history in Cosmos DB - so it can enrich a sparse email ("where is my truck?") with earlier context. Optionally, compare an incoming email against a curated set of exemplar emails with known scenarios (few-shot / similarity) to raise confidence. *This was called out as item number one.*
2. **Build a golden / ground-truth dataset.** A benchmark of correctly-classified emails per scenario, provided by Unilever / the SME.
   - Available data: ~682 emails flagged incorrect by the SME (correct labels unknown) plus ~1000 emails known to be correct.
   - Preferred approach: take a **random sample from the bot-automated emails**, have the SME provide the correct classification, targeting ~1000-1200 emails for good scenario representation, **refreshed periodically**.
   - This dataset is required both to measure prompt improvements and for the evaluation track.
3. **Automated evaluation / regression testing.** Testing today is manual (SIT then UAT against business-provided test cases), with no automated regression.
   - Risk: a prompt change can silently regress previously-working classifications; model retirement (for example GPT-4o to a GPT-5.x model) will require re-validation.
   - Use **Microsoft Foundry** evaluations, driven from the **Foundry SDK / Python** (not only the UI), running against the golden dataset. Register a Foundry project, then reference it from code.
   - Feed **telemetry and observability** (Application Insights / logs, and potentially Microsoft Fabric for querying) so runs can be executed and monitored - potentially daily.
4. **Self-learning loop.** A nightly agent reviews the last 24 hours of reclassifications, gathers why each was reclassified, and suggests prompt improvements. This depends on reliable specialist labels (see governance below).
5. **Governance and change management.** Reconsider whether specialists should be able to freely select "unknown"; capture the specialist's reasoning ("specialist brain") for edge cases; invest in user education and consider a dedicated specialist / SME team so feedback quality is high without overloading operational staff.

## KPIs and metrics

| Metric | Current state |
|--------|---------------|
| Precision (automated scenarios) | Good |
| Recall | Not yet estimated; poor for "unknown" |
| Reclassification rate | Tracked via bot vs specialist scenario; specialist quality on a downtrend |

## Stakeholders

| Role | People |
|------|--------|
| Delivery team | Amogh Singhal, Rohit Gavval, Sourav Dutta (writes the Semantic Kernel / Python bot), Sameer Kulkarni |
| Product | Sourav (works with business to obtain the dataset), reporting into Anis' team |
| Business (Unilever) | Azita, Manu |
| Genpact | Anis |
| SME / verification | Single SME verifying reclassifications; Ana Carolina (Brazil) as lead for verifying reclassified scenarios |
| Advisor / architecture | Vincent Rouet |

## Related guidance

- [Evaluation strategy with Foundry Evaluations](evaluation-strategy-foundry.md) - code-first evaluation as part of the agent development lifecycle.
- [Building the evaluation dataset](dataset-guidance.md) - how to build the golden / ground-truth dataset this strategy depends on.

## Next steps

- Agree the golden dataset scope and cadence with Unilever / the SME - see [dataset guidance](dataset-guidance.md).
- Stand up automated evaluation on Microsoft Foundry against that dataset - see [evaluation strategy](evaluation-strategy-foundry.md).
- Prototype giving the agent access to email history for added context.
- Continue with sub-issue [4.b - response correctness](4b-response-correctness.md).
