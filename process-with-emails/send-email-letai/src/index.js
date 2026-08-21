import { randomUUID } from 'node:crypto';
import { writeFileSync } from 'node:fs';

import { loadDotEnv, requireEnv, getAccessToken, GraphError, graph } from './graph.js';

async function sendLetAiEmail() {
  loadDotEnv();

  const tenantId = requireEnv('TENANT_ID');
  const clientId = requireEnv('CLIENT_ID');
  const clientSecret = requireEnv('CLIENT_SECRET');
  const mailbox = requireEnv('SENDER_MAILBOX');
  const recipient = requireEnv('RECIPIENT_ADDRESS');
  const requestId = process.env.LETAI_REQUEST_ID || randomUUID();
  const deliveryAttemptId = randomUUID();

  const token = await getAccessToken(tenantId, clientId, clientSecret);

  // One-step sendMail carries custom "x-" Internet headers and needs only Mail.Send.
  // (Creating a draft via POST /messages would additionally require Mail.ReadWrite.)
  await graph(token, 'POST', `/users/${mailbox}/sendMail`, {
    message: {
      subject: 'LetAI test message',
      body: {
        contentType: 'Text',
        content: `This message carries the X-LetAI-Request-Id header: ${requestId}`
      },
      toRecipients: [{ emailAddress: { address: recipient } }],
      internetMessageHeaders: [
        { name: 'X-LetAI-Request-Id', value: requestId },
        { name: 'X-LetAI-Delivery-Attempt-Id', value: deliveryAttemptId }
      ]
    },
    saveToSentItems: true
  });

  // Record the send so check-ndr.js can correlate the bounce without re-typing the id.
  writeFileSync(
    '.last-send.json',
    JSON.stringify({ requestId, deliveryAttemptId, mailbox, recipient, sentAt: new Date().toISOString() }, null, 2)
  );

  console.log(`Sent from ${mailbox} to ${recipient}.`);
  console.log(`  X-LetAI-Request-Id         : ${requestId}`);
  console.log(`  X-LetAI-Delivery-Attempt-Id: ${deliveryAttemptId}`);
}

sendLetAiEmail().catch((error) => {
  console.error('Failed to send LetAI email:', error.message);
  if (error instanceof GraphError && error.code === 'ErrorInvalidUser') {
    console.error(
      '\nHint: SENDER_MAILBOX is not a valid Exchange Online mailbox in this tenant.\n' +
        '  - Confirm the UPN exists and is spelled correctly.\n' +
        '  - Ensure the account has a licensed Exchange Online mailbox.\n' +
        '  - If an application access policy is configured, ensure this mailbox is in scope.'
    );
  }
  process.exitCode = 1;
});
