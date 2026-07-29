---
title: Issue 3 - Undelivered Email Tracking (CR)
description: Why bounced outbound emails from the automation bot cannot be mapped back to the originating request, the non-delivery report correlation gap in Microsoft Graph, and why this change request may be descoped pending further investigation.
ms.topic: concept
keywords:
  - non-delivery report
  - undelivered email
  - microsoft graph
  - conversation id
  - message id
estimated_reading_time: 7
---

## Issue 3 - Undelivered email tracking (CR)

This is a **change request** that may be **descoped or put on hold** unless a correlation approach is found.

## Context

At some stages the bot must email an external party, using addresses supplied by an **upstream transportation/logistics system** - typically loading-location or location-related addresses. Two things go wrong:

1. **Placeholder addresses.** When the upstream system has no real address, it stores a default placeholder (for example `undelivered@example.com`) that is not a valid mailbox.
2. **Mistyped / misspelt addresses.** A wrong or misspelt domain.

The bot sends via the Microsoft Graph API. In either case the mail **bounces**.

## How threading works today

- Each inbound request gets a **custom request ID** - the unique identifier for the whole thread.
- A **conversation ID** and a **messages array** (incoming and outgoing mails) are maintained per thread and stored in the system (a document database).
- On a **successful** send (HTTP 200) Graph returns metadata including a **message ID**, which the system stores against the conversation so the thread stays linked.

## The problem

When a send fails, the **non-delivery report (NDR)** comes back from a **random Microsoft Exchange address** - a different, randomly-numbered `...@...prod...exchangelabs.com`-style address each time, never a stable or unique sender.

- The NDR contains the **subject and body** (and the original mail attached), but **no identifier that maps back** to the request ID or conversation ID.
- Because the send did **not** succeed, Graph does **not** return the success JSON with the message ID, so there is nothing to correlate the bounce to the originating thread.
- If two emails fail at the **same timestamp** (for example 16:10 and 16:10:11) with the **same subject**, the system cannot tell which request bounced and which succeeded - a **valid case can be marked invalid**. The duplicate-detection process (which keys on subject) then blocks it.

For these reasons the feature was **blocked technically** in the development environment.

## What Microsoft support suggested

- A support ticket was raised. Microsoft support suggested **matching on the subject**.
- This is insufficient: functionally, **the same subject can belong to two different requests**, so subject alone cannot uniquely identify the request.

## An observation to investigate

More header information (message hops, original message headers) appears to be visible in some Outlook configurations than in others. This may be an **extended feature in Office** or a mailbox/tenant configuration difference. Forwarding a test email between configurations is worth doing to investigate why the available information differs.

## Status and next steps

- This is **hard to unpack** without deep investigation and is a candidate to **descope or hold**.
- Investigate **why the header information differs** between configurations, and whether the NDR headers / original message headers can carry a usable correlation ID.
- Directions worth evaluating: **validate the recipient address via Graph before sending** and route invalids to a **dead-letter queue** with a defined business process; review the earlier support-ticket trace.

## Related

- [Issue 1 - Handling non-automated email](issue-1-non-automated-email.md).
- [Issue 2 - Centralized Outlook re-direction rules](issue-2-redirection-rules.md).
