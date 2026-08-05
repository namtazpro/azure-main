---
title: Issue 4.b - Response Correctness
description: Detailed analysis of the response correctness KPI for the Contoso LET AI solution, including the three automation buckets, the KPI formula and its distortions, and proposed agent-based improvements.
author: Microsoft
ms.date: 2026-07-29
ms.topic: concept
keywords:
  - response correctness
  - automation rate
  - templates
  - LLM as judge
  - foundry
  - cosmos db
estimated_reading_time: 11
---

## Issue 4.b - Response correctness

Response correctness is the second of the two primary KPIs in [Item 4](Issue4main.md). It is used as a **proxy for how much automation** the solution delivers: how often the bot's selected-and-filled response template is accepted by the specialist without edits.

> Source: walkthrough call on 29 July 2026 ("Walk through 4b") with delivery, development, and architecture representatives.

## Responses are selected, not generated

An important distinction: the LLM does **not** generate responses. Response correctness is driven by two business-owned inputs:

- **Templates** - authored by the business, which set the language and tone. Each scenario has its own small set of templates (for example a billing scenario might have 3, a cancellation scenario 2). Templates contain **placeholders / variables** (like a mail-merge name field).
- **Variables** - the placeholder values, retrieved from the **OTM** (Oracle Transportation Management) database.

The LLM's only job is to **select** the best-fitting template for a given email and pair it with the right variables. Describing this as "the LLM generating a response" would be misleading.

## The three automation buckets

Every email that reaches the response stage (after scenario classification) falls into one of three buckets:

| Bucket | Name | What happens | Human in loop |
|--------|------|--------------|---------------|
| A | Strictly closed by bot | Bot selects a template and formulates the response; the specialist clicks **submit** with no edit | Read + approve |
| B | Closed by bot with specialist edit (partial automation) | Bot selects a template; the specialist edits it (adds phrases, or overwrites it entirely) before sending | Read + write + approve |
| C | Closed by specialist (no automation) | Bot cannot map a template, or a process-design branch hands off; the specialist starts from a **blank slate** | Full manual |

Notes from the walkthrough:

- In bucket B the specialist edits a free text box; they **cannot select a different template**, only edit the text. Saving an edit requires choosing a **reason** from a drop-down (with a custom "other" free-text option). The before-edit and after-edit versions and the reason are all stored.
- Bucket C has two sub-cases: the incoming mail maps to no template, or by process design that branch always hands off to a specialist. Handing off is considered **correct** behaviour, not a bot failure.

## The KPI and its ceiling

Response correctness (also called "no touch") counts the fully-automated and the by-design-manual buckets as successes:

$$\text{Response correctness} = \frac{A + C}{A + B + C}$$

In the worked example (30 emails split 10/10/10) this gives $(10 + 10) / 30 = 66.7\%$.

- The aligned **target is 90%**, but analysis shows roughly **30% of the current workflow is by design handled by the specialist** (bucket C). So the realistic ceiling is closer to **70%**, and the 90% target needs to be **realigned with the business**.
- The only genuine improvement lever is **bucket B** - reducing the specialist edits on templates the bot did select.

## Why the KPI is distorted

- **Non-meaningful edits inflate bucket B.** Specialists sometimes overwrite a complete, correct bot response (for example one that already contained the collected shipment ID, date, and time) with a terse "changed." or "yes". Because an edit occurred, it counts in bucket B and is **discounted** from the numerator - so the KPI is **under-reported**. Trivial edits (adding/removing a space or dot) are already filtered out technically.
- **Language handling.** The bot produces English; specialists sometimes respond in a non-English language (for example Polish). This blurs the bucket definition (should the comparison be English-to-English only?) and can lose otherwise-automated cases.
- **The metric conflates many causes.** A "wrong" response can stem from incorrect entity extraction, an incorrect scenario classification (wrong path, wrong template), the on-ground situation changing between generation and review, or the specialist simply choosing to work manually. The metric cannot distinguish these, so it does not measure any one thing accurately - a redesign of how automation is tracked may be needed. The current KPIs were set on the Contoso side between the delivery lead and the business.

## What is tracked today

For each request the system captures the original message, the bot-selected template and formulated response, whether the specialist edited it, the final response sent, and the edit **reason** (drop-down plus custom). Before/after versions are stored in **Cosmos DB** as JSON (not vectorized). Unlike scenario classification, there is **no secondary SME review** of response correctness, so there is no ground-truth signal on whether an edit was justified.

## Proposed actions

Ideas raised during the call (not commitments):

1. **Capture more evidence / telemetry.** Instrument every step so the team can show the business *why* the bot behaved as it did and *where* the human in the loop changed it. Transparency builds trust and lets the team respond to the customer quickly instead of running multi-day manual analyses.
2. **Make the KPI nuanced, not binary.** Move away from pass/fail toward a graded measure (degree of automation, size/type of edit) so a near-perfect response is not scored identically to a full rewrite.
3. **LLM-as-judge agent (in-flight).** When the specialist clicks edit / save, an agent analyses exactly what changed - does the stated reason match the actual change; is it a grammar, format, or full-rewrite change - and logs a correctness assessment.
4. **Nightly batch agent.** An overarching agent crawls the day's volume (~1000-2000 emails), finds patterns (for example "reason does not match change"), and can reference supporting assets (playbooks, manuals, PDFs) for richer analysis. Learnings feed prompt/skill/instruction updates.
5. **RPA "fly on the wall" alternative.** Because specialists may not reliably provide validation, a bot could silently observe the handful of specialists and capture the edit trace to build a dataset - subject to change-management (users must not feel monitored and stop using the app). Some reasons (a phone call to get information) cannot be captured this way.
6. **Trigger via Logic Apps + Foundry.** A scheduled Logic Apps agent loop can call a Foundry-hosted agent so telemetry flows into Foundry and Application Insights automatically.
7. **Vectorize the data.** The Cosmos JSON is not vectorized; for efficient analysis, move it to Azure AI Search or use Cosmos vector features, then add a chat-over-data assistant so the business can ask questions ("why is WIMT low?", "why better at certain times?").
8. **Revise templates and educate users** to reduce avoidable bucket-B edits; decide how to handle non-English responses and whether to separate salutation/signature from the body.

## Dependencies and next steps

- Building any judge/eval agent needs a **validation layer / ground truth**, which response correctness currently lacks - see [self-learning (Item 5)](../TechnicalBacklogJuly2026.md#item-5---self-learning-capabilities) and the [evaluation strategy](../foundry-evaluations.md).
- Agreed direction: take a **small sample** and pilot both the in-flight judge agent and the nightly batch agent to test the hypothesis before widening scope.
- The architecture advisor will research vectorization options for the Cosmos data.

## Related guidance

- [4.a - Scenario classification](4a-scenario-classification.md) - the upstream KPI; a wrong scenario yields a wrong template here.
- [Foundry Evaluations](../foundry-evaluations.md) and [building the evaluation dataset](dataset-guidance.md).
