---
title: Issue 1 - Handling Non-Automated Email
description: Requirements and solution options for returning non-automated email to business-users without losing the original requester, message context, or existing automated processing.
ms.topic: concept
keywords:
  - microsoft graph
  - create forward
  - eml attachment
  - non-automated email
  - business-user mailbox
estimated_reading_time: 8
---

## Issue 1 - Handling non-automated email

Some scenarios are, by design or by classification, **not automated**. For those, the bot hands the email back to a business-user. The ask is to make that hand-back easier for the business-user to action.

## How the flow works today

1. A requester emails a **Contoso business-user mailbox**.
2. That mailbox has a **redirection rule** that forwards the mail to the **bot ID**, so the bot receives every incoming request (see [Issue 2](issue-2-redirection-rules.md)).
3. A Logic App reads the message and extracts fields such as sender, recipients, subject, body, importance, attachment indicators, and message ID. Actual file attachments are stored in Blob Storage.
4. Automated scenarios continue through the existing processing path.
5. When the solution flags a request as **non-automated or unknown**, the function application returns it to the originating business-user.

The return currently uses the Microsoft Graph **`createForward`** operation to create a draft from the captured message ID, followed by a send operation to the business-user.

## The problem

Because the message is forwarded **from LetAI**, the business-user loses important parts of the existing email workflow:

- Forwarded messages appear to come from LetAI, so sender-based folders and workload groupings no longer work as expected.
- Selecting **Reply** addresses LetAI rather than the original requester.
- The business-user must scroll through the forwarded content, identify and copy the original sender, and create or locate the correct email thread.
- A requester can send several messages with the same subject or reference ID at different points in a shipment lifecycle. Searching by subject or requester can therefore select the wrong request.
- Business-users process approximately **80 to 100 emails per day**, so the extra steps create material operational overhead.
- The users work in a browser-managed Citrix session rather than a standard desktop Outlook experience, which makes scrolling, copying, and switching context more cumbersome.

### Requirements

| ID | Requirement | Status |
|----|-------------|--------|
| R1 | A non-automated or unknown message must return to the business-user mailbox from which it originated. | Supported today through forwarding |
| R2 | The business-user must be able to reply to the original requester without manually reconstructing the recipient. | Not met |
| R3 | The returned item must preserve enough original message and thread context to distinguish messages with the same requester, subject, or reference ID. | Not met |
| R4 | The workflow must remain efficient at approximately 80 to 100 emails per business-user per day in a browser-based Citrix environment. | Not met |
| R5 | The change must preserve the current Logic App fields, attachment processing, conditional Service Bus flows, and existing automated scenarios. | Required for any option |
| R6 | Internal LetAI processing or audit content must not be exposed in a response to the external requester. | Required for any option |

## Constraints

- Microsoft Graph supports forwarding but does not provide an equivalent dynamic redirect operation for this flow.
- Sending on behalf of a business-user requires the appropriate authentication token and mailbox permissions and is not the intended solution.
- The current ingestion process stores selected message properties and file attachments, but it does not archive the complete original message as an `.eml` or `.msg` object.
- Nine automated scenarios and downstream dependencies already rely on the fields and conditional flows produced by the Logic App. The Issue 1 change must be additive and must not replace that processing.
- External requesters must not receive internal LetAI processing or audit history.

## Options explored

### Option 1 - Decorate the forward

Add the original requester or more original-message content at the top of the forwarded body or in the subject.

This is **not the preferred approach**. It still requires the business-user to search for the correct message, and repeated subjects, requesters, and reference IDs remain ambiguous.

### Option 2 - Dynamically redirect the original message

Replace the return forward with a redirect to the originating business-user. This would best preserve the original sender and Reply behavior.

The feasibility is unresolved. Microsoft Graph does not appear to support redirecting an already processed message. Exchange Online SMEs need to confirm whether a server-side rule or another supported API can apply a dynamic target after LetAI classifies the message.

### Option 3 - Attach the original message

Create a new contextual email to the business-user and attach the original message. The business-user can open the attachment and work from the original sender and content, while the covering email can explain why LetAI could not automate it.

Two implementation paths require investigation:

1. Use the stored original message ID with Microsoft Graph to create a new message and add the original message as an attachment. This may avoid Blob Storage entirely, but it must be proved with a working prototype.
2. Archive every incoming email in its raw `.eml` or `.msg` form in Blob Storage, keyed by a unique identifier, and retrieve it only when a non-automated message must be returned. This adds traceability but requires retention, purge, and storage design.

The attachment approach is promising, but either path must remain additive so that the current extracted fields and automated processing continue unchanged.

## Status and next steps

- Prototype creating a new email with the original message attached directly through Microsoft Graph using the existing message ID.
- Investigate whether Logic Apps can archive the complete raw email in Blob Storage while retaining all existing extracted attributes and processing behavior.
- Ask Exchange Online SMEs whether a supported dynamic redirect is possible after LetAI classification.
- Validate the selected option against requirements R1 through R6 and confirm that the nine live automated scenarios do not regress.

## Related

- [Issue 2 - Centralized Outlook re-direction rules](issue-2-redirection-rules.md) - the redirection rules that put mail on the bot in the first place.
