---
title: Issue 5 - Self-Learning Capabilities
description: Architecture and methodology guidance for adding feedback-driven improvement to the Contoso AI logistics email automation solution.
author: Vincent Rouet
ms.date: 2026-09-29
ms.topic: concept
keywords:
  - self-learning
  - feedback loop
  - ground-truth dataset
  - prompt optimization
estimated_reading_time: 1
---

## Issue 5 - Self-learning capabilities

# ***\-AI: Governed Self\-Improving Agent Architecture

## Objective

Enable ***\-AI to improve continuously from specialist feedback, classifications and production outcomes without allowing the model or operational agents to modify production behaviour autonomously.

The goal is not to create a self\-learning model.

The goal is to create a **governed, self\-improving agent system**.

---

## Core Design Principle

**Foundry IQ = Authoritative knowledge**

**Foundry Memory = Working beliefs and candidate knowledge**

**Foundry Evaluations = Evidence**

**Learner Agent = Evidence analyst and memory curator**

**Classifier Agent = Consumer of approved knowledge and relevant memories**

---

## Learner Agent

The approach proposes an offline Learner Agent that:

- Runs outside the live email\-processing path
- Analyses specialist feedback and operational outcomes
- Identifies patterns in unsuccessful or unknown classifications
- Proposes improvements to the system
- Helps reduce the number of emails classified as Unknown

The learner Agent uses **Foundry Memory as an intermediate learning layer**.

Rather than writing every newly discovered pattern directly into Foundry IQ, the Learner Agent first records it as a candidate memory. Evidence can then accumulate until the pattern is validated, promoted or rejected.

---

# The Three Knowledge Layers

## 1\. Foundry IQ: Organisational Knowledge

Foundry IQ remains the authoritative source used to ground ***\-AI.

It contains stable and approved information such as:

- Classification taxonomy
- Business rules
- Transport and logistics procedures
- OTM processes
- TSP policies
- Approved classification exemplars
- Response templates

Think of this as:

**“What the organisation knows.”**

The Learner Agent should not modify this knowledge directly without an approval and validation process.

---

## 2\. Foundry Memory: Candidate Knowledge

Memory holds newly observed patterns that may eventually become organisational knowledge.

Examples include:

- Emerging logistics terminology
- Factory\-specific language
- Repeated classification corrections
- Potential new mappings between phrases and classifications
- Patterns associated with Unknown outcomes

Think of this as:

**“What the system currently believes.”**

A memory is not automatically treated as fact. It is a hypothesis supported by evidence.

---

## 3\. Evaluation and Feedback Data: Evidence

Evaluation data provides the evidence used to create, enrich or challenge memories.

Evidence can include:

- Specialist classification corrections
- Significant edits to generated drafts
- Low\-confidence outputs
- Failed evaluation results
- Unknown classifications
- Escalations and exceptions
- Successful outcomes that confirm an existing pattern

Think of this as:

**“Why the system believes something.”**

---

# Agent Responsibilities

## Classification Agent

The Classification Agent operates in the live processing path.

It reads:

1. Foundry IQ for authoritative classification knowledge
2. Relevant validated memories for recent or context\-specific patterns

It does not write or amend memory directly.

Its role is to apply existing knowledge and useful learned context while maintaining predictable production behaviour.

---

## Learner Agent

The Learner Agent runs offline.

It reads:

- Evaluation results
- Human corrections
- Unknown classifications
- Low\-confidence outcomes
- Existing candidate memories
- Current Foundry IQ knowledge

It then:

1. Identifies recurring patterns
2. Checks whether a related memory already exists
3. Creates a memory when the observation is new
4. Enriches an existing memory when more information becomes available
5. Adds supporting evidence
6. Updates confidence and validation metadata
7. Proposes mature memories for promotion into Foundry IQ

The Learner Agent is therefore not simply a memory writer. It is a **memory curator**.

---

# How Memory Evolves

Memory should evolve rather than accumulate duplicate records.

### Human example

First encounter:

**“His name is John.”**

Later observation:

**“His full name is John Smith.”**

The second observation enriches the first memory. It should not result in unrelated records for “John” and “John Smith”.

### ***\-AI example

Initial observation:

**“Carrier Hold may indicate a Transport Delay.”**

Further specialist corrections confirm the pattern.

The existing memory is amended with:

- Additional evidence
- Higher confidence
- More precise context
- Factory or TSP scope
- Latest validation status

The memory evolves from an uncertain observation into a stronger candidate for organisational knowledge.

---

# Memory Lifecycle

Production observation

        ↓

Evaluation or human correction

        ↓

Learner Agent identifies a pattern

        ↓

Create or amend candidate memory

        ↓

Accumulate evidence and confidence

        ↓

Validate against existing knowledge

        ↓

Human or policy approval

        ↓

Promote to Foundry IQ

        ↓

Archive, expire or mark memory as superseded

A promoted memory should not remain as a competing retrieval result containing the same information.

Once Foundry IQ becomes authoritative, the corresponding memory should be archived, expired or marked as superseded.

---

# End\-to\-End Architecture

Incoming Email

      ↓

Classification Agent

      ↓

Foundry IQ \+ Relevant Validated Memory

      ↓

Classification and Response Workflow

      ↓

Specialist Review and Operational Outcome

      ↓

Foundry Evaluations

      ↓

Feedback and Evaluation Dataset

      ↓

Offline Learner Agent

      ↓

Create or Amend Candidate Memory

      ↓

Evidence Accumulation

      ↓

Validation and Approval

      ↓

Promotion to Foundry IQ

---

# Preventing Conflicting Information

The same classification exemplar should not remain active in both Memory and Foundry IQ indefinitely.

Retrieval precedence should be clear:

1. **Foundry IQ:** authoritative and approved
2. **Validated Memory:** contextual or emerging information
3. **Unvalidated candidate memory:** available only to the Learner Agent

If Memory conflicts with Foundry IQ, Foundry IQ wins and the conflict is sent to the Learner Agent for review.

This prevents the Classifier Agent from receiving contradictory exemplars.

---

# Governance Rules

## Operational Agents

- May read authorised memory
- Must not create knowledge from their own outputs
- Must not modify production prompts or policies
- Must not write directly to Foundry IQ

## Learner Agent

- May create and amend candidate memories
- Must retain evidence and provenance
- Must check for existing related memories before creating new ones
- May recommend promotion to Foundry IQ
- Must not promote material automatically unless an approved policy explicitly permits it

## Human or Policy Approval

- Confirms whether a candidate has sufficient evidence
- Resolves conflicts with existing organisational knowledge
- Approves promotion into Foundry IQ
- Provides an auditable decision point

---

# Recommended Summary

The architectural enhancement is to introduce Foundry Memory as a governed staging area:

**Observation → Evidence → Candidate Memory → Validation → Authoritative Knowledge**

This allows ***\-AI to improve continuously while keeping Foundry IQ clean, authoritative and explainable.

The resulting system does not autonomously retrain itself. It **learns by gathering evidence, enriching memories and promoting validated knowledge through a controlled process**.

