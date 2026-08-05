---
title: "Contoso *** AI Solution - Technical Backlog"
description: "Overview of the six technical backlog items for the Contoso *** AI logistics email automation solution, with detailed documentation added per item over time."
author: Vincent Rouet
ms.date: 2026-07-29
ms.topic: overview
keywords:
  - supply chain
  - email automation
  - scenario classification
  - Contoso
  - "*** AI"
estimated_reading_time: 8
---

## Overview

This documentation tracks the improvement work on the **Contoso \*\*\* AI** logistics email automation solution. Inbound logistics emails are redirected from ~60-67 specialist mailboxes into the application, where an AI classification agent (Semantic Kernel + Azure OpenAI) identifies the scenario, extracts entities, calls Oracle Transportation Management (OTM) and SAP, selects and fills a response template, and returns it to a specialist for review. Emails it cannot handle are routed back to the specialist mailbox.

The backlog is a set of **six items** that ZC carved out of a larger turnaround plan - specifically the asks where they need Microsoft's support. It was compiled from two Microsoft - Contoso / ZC discovery sessions:

- **23 July 2026** - issue walkthrough.
- **24 July 2026** - architecture and UI walkthrough.

> [!IMPORTANT]
> Both sessions focused on **understanding** the issues rather than solving them. The "potential solutions" noted per item are ideas that surfaced in conversation - **not agreed approaches or commitments**.

Each item gets its own page (or set of pages) as it is documented. Detailed pages are linked below as they are produced.

## The six items

| # | Item | Support requested | Documentation |
|---|------|-------------------|---------------|
| 1 | Handling non-automated email | Feasibility | [Item 1 detail](issue-1-non-automated-email.md) |
| 2 | Centralized Outlook re-direction rules | Feasibility | [Item 2 detail](issue-2-redirection-rules.md) |
| 3 | CR: undelivered email tracking | Technical feasibility review | [Item 3 detail](issue-3-undelivered-email-tracking.md) |
| 4 | Response correctness & scenario classification | Architecture / methodology review | [Item 4 overview](issue-4-kpis/Issue4main.md) |
| 5 | Self-learning capabilities | Architecture / methodology review | Detail to follow |
| 6 | Evals | Architecture / methodology review | Detail to follow |

## Item summaries

### Item 1 - Handling non-automated email

When \*\*\* AI cannot automate an email it returns it to the specialist as a **forward** rather than the original message, so the "From" becomes \*\*\* AI and the original sender is lost. Every return looks identical, forcing specialists to dig through the thread to find and copy the requester's address. Combined with working two inboxes (Outlook plus the web app), mailboxes become unmanageable and the old carrier/warehouse folder segregation breaks down. Volume is tied to the classification problem (see Item 4): emails with a confidence score below 75%, not-yet-live scenarios, and unmatched business groups all get forwarded back. **ZC's higher-priority email item.**

*Ideas discussed:* convert the forward into a **redirect** to preserve the original sender; make redirection **dynamic** (back to the originating specialist); a Microsoft Graph "reply-to" workaround ZC already explored; replacing mail rules with Power Automate / Logic Apps, or shifting away from email toward tickets or Teams notifications.

Full detail: **[Item 1 - Handling non-automated email](issue-1-non-automated-email.md)**.

### Item 2 - Centralized Outlook re-direction rules

Each of the ~60-67 specialist mailboxes carries redirection rules that forward mail to the \*\*\* AI backend mailbox. High BPO attrition means rules must be set up for every joiner, identical rules drift across mailboxes, and any change is applied manually everywhere. The core business risk is **email leakage** - when a rule is missing, outdated, reordered, or disabled, mail never reaches \*\*\* AI and there is no way to confirm coverage.

*Ideas discussed:* a rule-governance / master-data layer that checks each mailbox against controlled mapping data; Power Automate / Logic Apps instead of Outlook rules. **Key dependency:** whether the solution has a Microsoft Graph identity with sufficient permission to read/write individual mailboxes - flagged as doubtful and potentially blocking pending a SecOps / data-protection decision. This layer sits **upstream** of the current architecture, which starts at the \*\*\* AI mailbox.

Full detail: **[Item 2 - Centralized Outlook re-direction rules](issue-2-redirection-rules.md)**.

### Item 3 - CR: undelivered email tracking

The bot sends outbound emails when it needs more information from a requester, TSP, or warehouse. Target addresses come from the central OTM database and are sometimes invalid or retired, so emails bounce. The undelivered notifications are **generic and cannot be tied back** to the original request or thread, so failures cannot be acted on. Recipients are dynamic and predominantly B2B (many on non-Contoso domains), a constant data challenge. Previously raised with Microsoft support without resolution.

*Ideas discussed:* a self-managed technical acknowledgement (detect a missing expected response); validate the recipient address via Graph before sending and route invalids to a **dead-letter queue** with a defined business process; review the earlier support-ticket trace. Owner: ZC's web-app team (Shalini / Rohit).

Full detail: **[Item 3 - CR: undelivered email tracking](issue-3-undelivered-email-tracking.md)**.

### Item 4 - Response correctness & scenario classification

The solution's two core KPIs. **Response correctness** target is 90% but currently ~53%; **scenario-classification** accuracy is ~85% against a 90% target. On the classifiable subset accuracy is strong, but roughly **57% of volume falls out as "unknown"** and only ~16-17% is actually automated - so even perfect accuracy caps delivered impact at ~16%. Response correctness is driven by specialist edits to the selected/filled template, and when a specialist edits, ZC often cannot tell where it failed. Additional pain points: overly terse "acknowledgement" edits, and language handling (English-only generation with manual Polish translation; non-scope salutations/signatures causing whole emails to be dropped).

This item has two sub-issues, documented in the **[Item 4 overview](issue-4-kpis/Issue4main.md)**:

- **[4.a - Scenario classification](issue-4-kpis/4a-scenario-classification.md)** - accuracy of the classification module and how to widen catchment. *(Documented)*
- **[4.b - Response correctness](issue-4-kpis/4b-response-correctness.md)** - how correctly the response template is selected and filled. *(Documented)*

Supporting guidance already produced: [Foundry Evaluations](foundry-evaluations.md) and [building the evaluation dataset](issue-4-kpis/dataset-guidance.md). Microsoft documentation: [Inspection of telemetry data with Application Insights](https://learn.microsoft.com/en-us/semantic-kernel/concepts/enterprise-readiness/observability/telemetry-with-app-insights?tabs=Powershell&pivots=programming-language-csharp) and [Index and Query Vector Data in .NET](https://learn.microsoft.com/en-us/azure/cosmos-db/how-to-dotnet-vector-index-query).

### Item 5 - Self-learning capabilities

There is no built-in feedback loop; improvement today is manual labelling with the business - slow and effort-heavy. The only "ground truth" is small and biased (reclassified requests reviewed by a single business SME), and where the bot is wrong the true label is unknown, so it is **not a golden dataset**. Unknowns are never tracked once forwarded to specialists, so no signal returns that "this should not have been unknown."

*Ideas discussed:* treat self-learning as a **multi-phase discipline** (collect data, evaluate, then improve prompts / split agents / use skills, then roll to production) rather than an out-of-the-box feature; a labelled dataset (~100-150 emails) as the foundation with Foundry evaluations on it; a prompt optimizer as the learning loop; exploring agent-with-instructions vs. an agent-loop-with-skills approach.

### Item 6 - Evals

Current evaluations focus on precision and response correctness, giving limited visibility into root causes and leakage points. The plan is to **pivot from precision to recall**, which needs a good volume of manually tagged emails - a stratified sample balanced across scenarios, languages, edge cases, and confidence scores, labelled by the business. There is also an **observability gap**: status/sub-status and agent input/output are stored in Cosmos DB via custom logging, but there is no Application Insights / Azure Monitor telemetry, and the unknown-bucket analysis happens off-platform in Excel.

*Ideas discussed:* instrument every call now (App Insights / Azure Monitor / Log Analytics, configurable via Foundry) capturing agent input and output - the foundation for both evals and self-learning; run Foundry evaluations on a dataset at every change/publish; pivot to recall using the stratified, business-labelled sample.

Microsoft reference: [Observability and evaluations in Microsoft Foundry](https://learn.microsoft.com/en-us/azure/foundry/concepts/observability).

## Cross-cutting theme

The common dependency across **Items 4-6** is a **labelled ground-truth dataset plus call-level tracking**. Without it, evaluations cannot be trusted and self-learning cannot be built. Items 1 and 2 share a dependency on the **SecOps / Microsoft Graph permissions** position for individual mailboxes.

Agreed direction from the sessions: split into small, focused workstreams with named owners on each side (for example email items with Mark, evals with Vincent); Contoso / ZC to confirm the Graph permissions policy; ZC to share the Microsoft support-ticket trace (Item 3) and the Graph "reply-to" thread (Item 1).

## Glossary

| Term | Meaning |
|------|---------|
| \*\*\* AI | The Contoso logistics email automation solution documented here |
| OTM | Oracle Transportation Management - system of record for shipment/order details, and source of outbound recipient addresses |
| SAP BTP | SAP Business Technology Platform - here it acts as the API gateway; SAP is also called to check warehouse stock |
| TSP | Transport Service Provider |
| BPO | Business Process Outsourcing - the operating model behind the specialist teams (high attrition) |
| SME | Subject Matter Expert - verifies the correctness of bot and specialist classifications |
| Specialist | Business user who reviews, continues, or reclassifies an email in the web UI |
| Confidence score | Classifier score; emails below 75% are routed to the specialist mailbox |
| Cosmos DB | Store for conversation history and status logging (Microsoft Graph message and conversation IDs) |
| Scenario | One of 12 defined logistics email categories; a 13th "unknown" category catches everything else |
