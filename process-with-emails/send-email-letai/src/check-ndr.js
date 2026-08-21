import { readFileSync } from 'node:fs';

import { loadDotEnv, requireEnv, getAccessToken, GraphError, graph } from './graph.js';

const POLL_ATTEMPTS = Number(process.env.NDR_POLL_ATTEMPTS || 12);
const POLL_INTERVAL_MS = Number(process.env.NDR_POLL_INTERVAL_MS || 10000);

const delay = (ms) => new Promise((resolve) => setTimeout(resolve, ms));

// Resolve the request id to hunt for: CLI arg > LETAI_REQUEST_ID > .last-send.json.
function resolveTarget() {
  const fromArg = process.argv[2];
  if (fromArg) {
    return { requestId: fromArg, source: 'command-line argument' };
  }
  if (process.env.LETAI_REQUEST_ID) {
    return { requestId: process.env.LETAI_REQUEST_ID, source: 'LETAI_REQUEST_ID' };
  }
  try {
    const record = JSON.parse(readFileSync('.last-send.json', 'utf8'));
    if (record.requestId) {
      return { requestId: record.requestId, deliveryAttemptId: record.deliveryAttemptId, source: '.last-send.json' };
    }
  } catch {
    // no record yet
  }
  throw new Error(
    'No X-LetAI-Request-Id to look for.\n' +
      '  Pass it as an argument (node src/check-ndr.js <request-id>),\n' +
      '  set LETAI_REQUEST_ID, or run src/index.js first to create .last-send.json.'
  );
}

// An NDR is a bounce delivered back to the sender by the mail system.
function looksLikeNdr(message) {
  const subject = (message.subject || '').toLowerCase();
  const from = (message.from?.emailAddress?.address || '').toLowerCase();
  return (
    from.includes('postmaster') ||
    from.includes('mailer-daemon') ||
    from.includes('microsoftexchange') ||
    subject.startsWith('undeliverable') ||
    subject.includes('delivery has failed') ||
    subject.includes('not delivered')
  );
}

// Pull every custom LetAI header line out of a blob of text (case-insensitive).
function extractLetAiHeaders(text) {
  if (!text) {
    return [];
  }
  const matches = text.match(/X-LetAI-[A-Za-z-]+:\s*[^\r\n<"]+/gi) || [];
  return [...new Set(matches.map((line) => line.trim()))];
}

function decodeBase64(contentBytes) {
  try {
    return Buffer.from(contentBytes, 'base64').toString('utf8');
  } catch {
    return '';
  }
}

// Gather all searchable text from an NDR: its own headers, body, and any
// embedded original message (attached as a file or an item attachment).
async function collectNdrText(token, mailbox, messageId) {
  const parts = [];

  const detail = await graph(
    token,
    'GET',
    `/users/${mailbox}/messages/${messageId}?$select=subject,from,receivedDateTime,body,internetMessageHeaders`
  );
  parts.push((detail.internetMessageHeaders || []).map((h) => `${h.name}: ${h.value}`).join('\n'));
  parts.push(detail.body?.content || '');

  const attachments = await graph(token, 'GET', `/users/${mailbox}/messages/${messageId}/attachments`);
  for (const att of attachments?.value || []) {
    if (att.contentBytes) {
      parts.push(decodeBase64(att.contentBytes));
      continue;
    }
    if (att['@odata.type'] === '#microsoft.graph.itemAttachment') {
      const expanded = await graph(
        token,
        'GET',
        `/users/${mailbox}/messages/${messageId}/attachments/${att.id}?$expand=microsoft.graph.itemAttachment/item`
      );
      const item = expanded?.item;
      if (item) {
        parts.push((item.internetMessageHeaders || []).map((h) => `${h.name}: ${h.value}`).join('\n'));
        parts.push(item.body?.content || '');
      }
    }
  }

  return { detail, text: parts.filter(Boolean).join('\n') };
}

async function checkNdr() {
  loadDotEnv();

  const tenantId = requireEnv('TENANT_ID');
  const clientId = requireEnv('CLIENT_ID');
  const clientSecret = requireEnv('CLIENT_SECRET');
  const mailbox = requireEnv('SENDER_MAILBOX');
  const target = resolveTarget();

  console.log(`Looking for the NDR carrying X-LetAI-Request-Id: ${target.requestId}`);
  console.log(`  (source: ${target.source}; mailbox: ${mailbox})\n`);

  const token = await getAccessToken(tenantId, clientId, clientSecret);
  const seen = new Set();

  for (let attempt = 1; attempt <= POLL_ATTEMPTS; attempt++) {
    const recent = await graph(
      token,
      'GET',
      `/users/${mailbox}/messages?$top=25&$orderby=receivedDateTime desc&$select=id,subject,from,receivedDateTime`
    );

    const candidates = (recent?.value || []).filter((m) => looksLikeNdr(m) && !seen.has(m.id));
    for (const candidate of candidates) {
      seen.add(candidate.id);
      const { detail, text } = await collectNdrText(token, mailbox, candidate.id);
      if (text.toLowerCase().includes(target.requestId.toLowerCase())) {
        const headers = extractLetAiHeaders(text);
        console.log('MATCH - the NDR preserves the custom LetAI header(s).');
        console.log(`  NDR subject : ${detail.subject}`);
        console.log(`  NDR from    : ${detail.from?.emailAddress?.address}`);
        console.log(`  NDR received: ${detail.receivedDateTime}`);
        console.log(
          headers.length
            ? `  Header(s)   :\n${headers.map((h) => `    ${h}`).join('\n')}`
            : `  (request id ${target.requestId} found in the NDR content)`
        );
        return;
      }
    }

    if (attempt < POLL_ATTEMPTS) {
      console.log(
        `Attempt ${attempt}/${POLL_ATTEMPTS}: no matching NDR yet, retrying in ${POLL_INTERVAL_MS / 1000}s...`
      );
      await delay(POLL_INTERVAL_MS);
    }
  }

  console.log('\nNo NDR containing that X-LetAI-Request-Id arrived within the polling window.');
  console.log('  - The bounce may still be in transit; re-run this script.');
  console.log('  - Confirm the recipient really is undeliverable in this tenant.');
  process.exitCode = 2;
}

checkNdr().catch((error) => {
  console.error('Failed to check for the NDR:', error.message);
  if (error instanceof GraphError && (error.status === 403 || error.code === 'ErrorAccessDenied')) {
    console.error(
      '\nHint: reading the mailbox needs the Mail.Read application permission (admin-consented).\n' +
        '  Mail.Send alone cannot read the inbox where the NDR lands.\n' +
        '  If an application access policy is configured, ensure SENDER_MAILBOX is in scope.'
    );
  }
  process.exitCode = 1;
});
