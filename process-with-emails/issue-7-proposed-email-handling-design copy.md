---
title: Issue 7 - Proposed Email Handling Design
description: Proposed email handling design addressing non-automated email hand-off and centralized email redirection.
author: Vincent Rouet
ms.date: 2026-09-30
ms.topic: concept
keywords:
  - email handling
  - non-automated email
  - email redirection
  - solution design
estimated_reading_time: 1
---

## Issue 7 -  New email handling design - 29th Sept 2026

Questions

# ***-AI Architecture Revision: Microsoft Guidance on the Seven Questions

**Date:** 30 September 2026  
**Scope:** Consolidated guidance from the two architecture calls on 30 September 2026, the written questions in the email thread, and Microsoft documentation.  
**Business requirement confirmed:** ***-AI must send automated follow-up questions and responses **from the dedicated Bot mailbox** to the requester. The reply must remain associated with the existing business conversation as far as the mail clients allow. Sending as the Specialist mailbox is not the target design.

> **Important design distinction:** Outlook's visual conversation grouping, message-level correlation, and ***-AI's own business-case correlation are related but are not the same thing. The implementation should not rely on a single Outlook property to provide all three.

## Executive recommendation

Use a **Bot-mailbox-owned outbound message**, a *****-AI correlation model in Cosmos DB**, and a resilient event-ingestion pattern:

1. Subscribe to new messages in each Specialist mailbox through Microsoft Graph using application permissions scoped to the required mailboxes.
2. Receive each notification through a lightweight webhook that validates and durably queues the event, then returns `202 Accepted` within three seconds.
3. Fetch or process message content asynchronously from the queue.
4. Store mailbox ID, Graph message ID using immutable IDs, `internetMessageId`, `conversationId`, timestamps, participants and a ***-AI request/correlation ID in Cosmos DB.
5. Send requests for more information and automated responses **from the Bot mailbox**.
6. Treat `internetMessageId` plus mailbox/message context as correlation evidence, not as the only database key.
7. Manage subscription renewal and lifecycle notifications as a first-class production workload.

---

## 1. Conversation preservation across mailboxes

### Question

The initial customer email is received in a Specialist mailbox, while ***-AI sends automated responses using a dedicated Bot mailbox. What is the Microsoft-recommended approach to preserve the same Outlook conversation/thread when the source message and the automated response are handled by different mailboxes?

### Guidance

The revised requirement means the outbound response must originate from the Bot mailbox. Therefore, the implementation should **not** call `reply` or `replyAll` against the copy stored in the Specialist mailbox and then attempt to replace the sender with the Bot mailbox. A Graph reply operation is executed in the mailbox identified by the reply endpoint, and the resulting message is saved in that mailbox's Sent Items.

The recommended ***-AI pattern is:

- Keep the user-visible subject unchanged, including the existing `Re:` convention where applicable.
- Send the outbound message from the Bot mailbox.
- Preserve the original RFC message relationship where technically possible by using MIME-formatted mail with the original message's `Message-ID` represented through `In-Reply-To` and `References`.
- Maintain an authoritative ***-AI conversation record in Cosmos DB, independent of Outlook's visual grouping.
- Include an internal ***-AI correlation identifier in Cosmos DB and, where the chosen sending path supports it, an `x-` custom Internet header. Custom Internet headers must be added when the message is created and must start with `x-`.

Outlook conversation grouping can depend on client and Exchange conversation behaviour. Consequently, same-thread visual presentation across different sender mailboxes should be validated through a focused POC using Outlook desktop, Outlook on the web and the actual external recipient domains. It should not be the sole correlation mechanism.

**Relevant Microsoft documentation**

- [Reply to an Outlook message with Microsoft Graph](https://learn.microsoft.com/en-us/graph/api/message-reply?view=graph-rest-1.0)
- [Send Outlook messages from another user](https://learn.microsoft.com/en-us/graph/outlook-send-mail-from-other-user)
- [Microsoft Graph message resource and custom Internet headers](https://learn.microsoft.com/en-us/graph/api/resources/message?view=graph-rest-1.0)

### Agreed implementation action

Dev team should run a POC in which the Bot mailbox sends a MIME response referencing the original message, and verify conversation grouping across the supported Outlook clients. Regardless of the result, Cosmos DB remains the system of record for the ***-AI business conversation.

---

## 2. Conversation correlation across mailboxes

### Question

Can `conversationId` be reliably used when one conversation involves the Specialist mailbox, Bot mailbox and customer? If not, which Microsoft Graph properties or RFC headers should be used?

### Guidance

Do **not** use `conversationId` as the sole cross-mailbox key. Treat it as mailbox/Exchange conversation context. The two calls correctly converged on building a ***-AI-owned mapping in Cosmos DB.

Store a correlation envelope for every message containing at least:

- ***-AI request/case ID.
- Tenant and mailbox identifier.
- Graph message ID, requested with `Prefer: IdType="ImmutableId"`.
- `internetMessageId`.
- `conversationId`.
- Parent `internetMessageId` derived from `In-Reply-To`, where available.
- `References`, where available.
- Sender, recipients, normalised subject and `receivedDateTime`.
- Processing state and idempotency status.

Microsoft documents that normal Outlook item IDs can change when items move. Immutable IDs remain stable while the item remains in the same mailbox, although they are not cross-mailbox identifiers. This makes the immutable Graph ID appropriate for locating a message within one mailbox, while `internetMessageId` and RFC reply headers are stronger evidence for relationships between copies crossing mailboxes.

The custom ***-AI ID is valuable for application observability and orphan-message investigation, but the team should test whether it survives every external mail hop and reply path. It must therefore complement, not replace, native message identifiers.

**Relevant Microsoft documentation**

- [Obtain immutable identifiers for Outlook resources](https://learn.microsoft.com/en-us/graph/outlook-immutable-id)
- [Microsoft Graph message resource](https://learn.microsoft.com/en-us/graph/api/resources/message?view=graph-rest-1.0)
- [Use the Outlook mail REST API](https://learn.microsoft.com/en-us/graph/api/resources/mail-api-overview?view=graph-rest-1.0)

### Agreed implementation action

Create and document the Cosmos DB correlation schema and test it against: normal reply; reply-all; multiple back-and-forth messages; subject edits; message moves; multiple Specialist recipients; delayed notifications; and external recipients.

---

## 3. Graph Reply / ReplyAll across mailboxes

### Question

Can an application reply to a message residing in a Specialist mailbox while sending the response from the Bot mailbox?

### Guidance

Not through a straightforward cross-mailbox use of the `reply` or `replyAll` action. The endpoint identifies the mailbox containing the original message, and the reply operation runs in that mailbox context. Microsoft Graph does support sending mail from another user, but this depends on the Graph permission model and Exchange `Send As` or `Send on Behalf` permissions. That feature is intended to make mail appear from another mailbox; it does not change the fact that a reply action is anchored to the mailbox/message addressed by the API call.

For ***-AI, the business requirement is explicitly to send from the Bot mailbox. The recommended implementation is therefore:

1. Read the original message and correlation metadata from the Specialist mailbox.
2. Build the response as a new Bot-mailbox draft or MIME message.
3. Address the requester and preserve the required Specialist recipients according to the business rule.
4. Preserve RFC reply relationships where possible and maintain the authoritative ***-AI link in Cosmos DB.
5. Send through the Bot mailbox.

In addition, as discussed, the bot email can be added to the cc in CosmosDB and further emails sent from the botmail box will contain the bot email in the cc in further exchanges. In addition of a x-.. custom header correlation key. 

**Relevant Microsoft documentation**

- [Reply to an Outlook message](https://learn.microsoft.com/en-us/graph/api/message-reply?view=graph-rest-1.0)
- [Send Outlook messages from another user](https://learn.microsoft.com/en-us/graph/outlook-send-mail-from-other-user)
- [Microsoft Graph mail API overview](https://learn.microsoft.com/en-us/graph/api/resources/mail-api-overview?view=graph-rest-1.0)

### Agreed implementation action

Prototype the Bot-owned MIME send pattern. Confirm the expected To/CC behaviour with the business, particularly whether the Specialist mailbox must receive every Bot follow-up and whether requester replies should include both the Bot and Specialist.

---

## 4. Change Notification reliability

### Question

For approximately 40–60 Specialist mailboxes, what delivery behaviour should be expected, and how should missed, delayed or duplicate notifications be handled?

### Guidance

Design the endpoint for **at-least-once-style processing**, meaning duplicates are possible and the consumer must be idempotent. Microsoft Graph considers a notification delivered when the endpoint returns a `2xx` response within three seconds. If processing can comp***e within that period, return `200 OK`. Otherwise, validate and persist the notification to a queue and return `202 Accepted` within three seconds.

If Graph receives a non-2xx response or no response within three seconds, it retries delivery for up to four hours using exponential backoff. Microsoft also warns that an endpoint which does not respond reliably may have notifications dropped, and dropped notifications cannot be recovered from the webhook itself.

Therefore:

- Keep the HTTP-triggered Azure Function thin.
- Validate `clientState` and notification authenticity.
- Persist the notification to Service Bus or another durable queue before acknowledging it.
- Use an idempotency key and conditional insert/update in Cosmos DB.
- Process attachments and Graph lookups asynchronously, after acknowledgement.
- Implement lifecycle notifications, including `missed`, `subscriptionRemoved` and `reauthorizationRequired` where supported.
- Use message delta query per monitored folder as the recovery/reconciliation path when a gap is suspected or a lifecycle `missed` event is received.

**Relevant Microsoft documentation**

- [Receive Microsoft Graph change notifications through webhooks](https://learn.microsoft.com/en-us/graph/change-notifications-delivery-webhooks)
- [Reduce missing subscriptions and change notifications](https://learn.microsoft.com/en-us/graph/change-notifications-lifecycle-events)
- [Use delta query to track changes](https://learn.microsoft.com/en-us/graph/delta-query-overview)
- [Use message delta query](https://learn.microsoft.com/en-us/graph/api/message-delta?view=graph-rest-1.0)

### Agreed implementation action

Implement durable queueing, idempotency and delta reconciliation before production. Monitor webhook response latency, non-2xx responses, queue depth, notification age, duplicate rate and reconciliation discoveries.

---

## 5. Subscription lifecycle management

### Question

What is the recommended production approach for creating, renewing, monitoring and recovering Graph subscriptions for approximately 40–60 mailboxes through one Entra application?

### Guidance

Use a subscription registry and renewal service rather than treating subscription creation as a deployment-time activity.

The registry should store subscription ID, mailbox/resource, change type, expiration, notification URL, lifecycle URL, client-state reference, status, last renewal attempt and last successful notification. A scheduled process should renew subscriptions ahead of expiry, retry transient failures and recreate subscriptions that are removed or cannot be renewed.

When creating the subscriptions:

- Use application permissions for subscribing to other users' mailboxes. Delegated Outlook permissions only support folders in the signed-in user's mailbox.
- Apply least privilege and scope the application to the required mailboxes through the organisation's Exchange/identity controls.
- Supply a `lifecycleNotificationUrl` at creation time. Microsoft states that it cannot be added later by updating an existing subscription; the subscription must be recreated.
- Use the immutable-ID preference when creating subscriptions if downstream processing stores Graph IDs.
- Maintain a delta token per monitored mail folder so that a removed or missed subscription can be reconciled.

The documented limit is 1,000 active Outlook-resource subscriptions per mailbox across all applications. The proposed one-subscription-per-mailbox pattern for 40–60 mailboxes is not close to that per-mailbox limit, but the application must still manage each subscription's expiry and health.

**Relevant Microsoft documentation**

- [Outlook change notifications overview](https://learn.microsoft.com/en-us/graph/outlook-change-notifications-overview)
- [Manage change notification subscriptions](https://learn.microsoft.com/en-us/graph/change-notifications-overview)
- [Lifecycle notifications](https://learn.microsoft.com/en-us/graph/change-notifications-lifecycle-events)
- [Immutable IDs with change notifications](https://learn.microsoft.com/en-us/graph/outlook-immutable-id)

### Agreed implementation action

Build the subscription registry, automated renewal/recreation process and operational alerts. Run an expiry-and-recovery test before go-live rather than validating only steady-state delivery.

---

## 6. Duplicate or same email across multiple mailboxes

### Question

If the same email is delivered to multiple Specialist mailboxes, how should ***-AI identify and deduplicate the underlying email event? Can `internetMessageId` be used across mailboxes?

### Guidance

`internetMessageId` is the strongest native candidate for recognising copies of the same Internet email across mailboxes, but the implementation should not use it as an unqualified global primary key.

Use two levels of identity:

1. **Physical mailbox item:** mailbox ID + immutable Graph message ID.
2. **Logical email event:** normalised `internetMessageId`, supported by sender, sent/received time, subject and recipient information where needed.

For retry duplicates affecting the same mailbox item, prefer the mailbox ID plus immutable message ID. For the same original email delivered independently to two Specialist mailboxes, use `internetMessageId` as the first cross-mailbox deduplication signal and verify the business rule before suppressing processing.

This distinction matters because two Specialist mailboxes may legitimately represent different operational responsibilities. Technical duplication does not automatically mean that one business work item should be discarded. The deduplication record should therefore retain all mailbox deliveries and elect one canonical ***-AI case only when the routing rules say they represent the same work.

A content hash can be used as a fallback diagnostic signal, but it is weaker than native IDs because transport systems can modify headers, body formatting or signatures. A hash should not replace `internetMessageId` and mailbox-specific identity.

**Relevant Microsoft documentation**

- [Microsoft Graph message resource](https://learn.microsoft.com/en-us/graph/api/resources/message?view=graph-rest-1.0)
- [Obtain immutable identifiers for Outlook resources](https://learn.microsoft.com/en-us/graph/outlook-immutable-id)

### Agreed implementation action

Test one message addressed simultaneously to two or more Specialist mailboxes and capture `internetMessageId`, `conversationId`, immutable Graph ID and headers in each mailbox. Define whether ***-AI creates one case with multiple mailbox deliveries or separate cases based on the business routing model.

---

## 7. Graph throttling and concurrent processing

### Question

For messages and attachments across approximately 40–60 mailboxes, what throttling, concurrency and retry behaviour should be implemented, and is EP1 sufficient?

### Guidance

Microsoft Graph throttling limits vary by workload and request type; there is no single supported requests-per-second number for this design. When throttled, Graph returns `429 Too Many Requests` and normally supplies `Retry-After`. The application should wait for that duration before retrying. If no `Retry-After` value is present, use capped exponential backoff with jitter. Immediate repeated retries increase throttling pressure.

Separate notification acceptance from message processing:

- **Ingress Function:** validate, enqueue, acknowledge within three seconds.
- **Queue-triggered workers:** retrieve message metadata, body and attachments from Graph.
- **Concurrency control:** set worker concurrency according to Graph response behaviour, attachment sizes, Service Bus capacity and downstream systems.
- **Per-mailbox fairness:** prevent a busy mailbox from consuming all worker capacity.
- **Retry policy:** distinguish `429`, transient `5xx`, permanent `4xx`, expired/missing messages and poison events.
- **Telemetry:** record Graph request duration, status, `Retry-After`, mailbox, operation type, queue age and end-to-end processing latency.

EP1 is an Elastic Premium Azure Functions size that can scale out, but Microsoft does not publish a universal "messages per second" throughput for an EP1 workload. Capacity depends on execution time, memory/CPU use, language worker, attachment processing, concurrency and dependencies. The call's estimate of roughly 40–60 simultaneous arrivals is not sufficient evidence to prescribe EP1 or EP2. Start with EP1 only as a measured baseline, configure scale-out appropriately, and load-test the actual two-stage pipeline. Scaling the Function will not remove Microsoft Graph throttling, so downstream concurrency must remain controlled.

**Relevant Microsoft documentation**

- [Microsoft Graph throttling guidance](https://learn.microsoft.com/en-us/graph/throttling)
- [Azure Functions Premium plan](https://learn.microsoft.com/en-us/azure/azure-functions/functions-premium-plan)
- [Concurrency in Azure Functions](https://learn.microsoft.com/en-us/azure/azure-functions/functions-concurrency)
- [Receive Graph notifications through webhooks](https://learn.microsoft.com/en-us/graph/change-notifications-delivery-webhooks)

### Agreed implementation action

Run load tests at expected average, peak and burst rates, including realistic attachment sizes and Graph latency. Success criteria should cover webhook acknowledgement under three seconds, zero unreconciled message loss, controlled duplicate processing, bounded queue age, acceptable end-to-end latency and stable Graph `429` rates.

---

## Required actions and ownership

###  development team

- Implement the Bot-mailbox-owned outbound pattern and prove conversation behaviour with real clients.
- Define the Cosmos DB correlation and idempotency schema.
- Add immutable-ID preferences to relevant Graph requests and subscriptions.
- Azure Function: Implement durable webhook queueing and return `202` after persistence.
- Build subscription registry, automatic renewal/recreation and lifecycle handling.
- Implement delta-query reconciliation per monitored folder.
- Implement retry handling based on `Retry-After`, with capped exponential backoff and jitter as fallback.
- Load-test EP1 with realistic messages, attachments and downstream processing.
- Confirm the business deduplication rule when one customer message reaches multiple Specialist mailboxes.

## Evidence from the calls

The first call established that the proposed architecture replaces mailbox redirection and Logic App ingestion with Microsoft Graph change notifications, a common webhook, Cosmos DB correlation data and Service Bus. The second call clarified that sending responses through the Bot mailbox is a business requirement, that ***-AI already maintains message history in Cosmos DB, and that the team needs guidance on change-notification reliability, subscription management, deduplication and scaling.

The two calls also identified the following implementation principles: maintain a ***-AI-owned conversation model; test a custom correlation header as a secondary diagnostic mechanism; make notification processing idempotent; acknowledge notifications quickly and process asynchronously; and benchmark the actual EP1 workload rather than assuming a fixed throughput.

## Source material

- First call:  Part 1, 30 September 2026.
- Second call:  Part 2, 30 September 2026.
- Email thread: `RE: ***-AI Architecture Revision - Removing Mailbox Redirection Rules`, containing the seven written questions.
- Microsoft Learn documentation linked under each question.



