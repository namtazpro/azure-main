---
title: Issue 2 - Centralized Outlook Re-direction Rules
description: Why the per-mailbox redirection rules that feed the email automation bot are hard to maintain at scale, and why the ask is an Office 365 tenant-governance question rather than a solution change.
ms.topic: concept
keywords:
  - outlook rules
  - mail redirection
  - office 365
  - m365 governance
  - shared mailboxes
estimated_reading_time: 5
---

## Issue 2 - Centralized Outlook re-direction rules

Each business-user mailbox carries a **centralised redirection rule** that forwards external customer mail to the **bot ID** so the solution can pick it up. The ask is to manage these rules centrally and selectively.

## How it works today

- When a business-user receives mail from external persons or customers, a redirection rule set on the mailbox forwards it to the **bot ID**.
- This is what gives the bot its inbound feed (see [Issue 1](issue-1-non-automated-email.md) for the downstream flow).

## The problem

- The per-mailbox rule setup is **time-consuming and hard to maintain at scale**.
- Business-users also send other mail during the day (for example credit-related or personal mail) that they **do not want shared with the bot**, yet it can be forwarded unintentionally.
- They want **centralised rules** so that **only the required mail** is redirected to the bot, rather than everything.

The ask, in short: enable **centralised management or automated publishing** of redirection rules, improve **consistency**, and reduce **administrative overhead**, with selective redirection of only the mail that should reach the bot.

## Why this is a tenant-governance question

This is about the **configuration of the mail tenant**, not the application logic:

- The right owners are **Office 365 / Microsoft 365 SMEs** who handle mail-tenant configuration and rule governance.
- The **mailbox ownership needs confirming** - which organisation owns the business-user mailboxes affects which tenant and which SMEs are involved. This should be clarified before designing a solution.

## Status and next steps

- **Route Issue 2 to an Office 365 / M365 SME** for the governance and centralised-rule question.
- Confirm the tenant/ownership of the business-user mailboxes.
- Consider a rule-governance / master-data layer that checks each mailbox against controlled mapping data, and evaluate Power Automate / Logic Apps as an alternative to per-mailbox Outlook rules.

## Related

- [Issue 1 - Handling non-automated email](issue-1-non-automated-email.md).
