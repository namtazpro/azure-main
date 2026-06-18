// ============================================================================
// Contoso Construction — RFP Response Builder — Server
// ============================================================================

const express = require("express");
const multer = require("multer");
const path = require("path");
const { projects, staffingRoles, contactInfo } = require("./data");

const app = express();
const PORT = 3000;

// --- Middleware ---------------------------------------------------------------
app.use(express.json());
app.use(express.static(path.join(__dirname, "public")));

// --- File Upload (multer) ----------------------------------------------------
const storage = multer.diskStorage({
  destination: (_req, _file, cb) => cb(null, path.join(__dirname, "uploads")),
  filename: (_req, file, cb) => {
    const unique = Date.now() + "-" + Math.round(Math.random() * 1e9);
    cb(null, unique + "-" + file.originalname);
  },
});
const upload = multer({ storage, limits: { fileSize: 50 * 1024 * 1024 } }); // 50 MB

// --- API Routes --------------------------------------------------------------

// GET all projects (light list for dropdown)
app.get("/api/projects", (_req, res) => {
  const list = projects.map((p) => ({
    id: p.id,
    name: p.name,
    client: p.client,
    sector: p.sector,
    status: p.status,
  }));
  res.json(list);
});

// GET single project details
app.get("/api/projects/:id", (req, res) => {
  const project = projects.find((p) => p.id === req.params.id);
  if (!project) return res.status(404).json({ error: "Project not found" });
  res.json(project);
});

// POST upload document for a project
app.post("/api/projects/:id/documents", upload.single("file"), (req, res) => {
  const project = projects.find((p) => p.id === req.params.id);
  if (!project) return res.status(404).json({ error: "Project not found" });
  if (!req.file) return res.status(400).json({ error: "No file provided" });

  const ext = path.extname(req.file.originalname).toLowerCase();
  let type = "other";
  if (ext === ".pdf") type = "pdf";
  else if ([".xls", ".xlsx"].includes(ext)) type = "excel";
  else if ([".eml", ".msg"].includes(ext)) type = "email";

  const newDoc = {
    id: "DOC-" + Date.now(),
    name: req.file.originalname,
    type,
    size: (req.file.size / 1024).toFixed(0) + " KB",
    uploaded: new Date().toISOString().split("T")[0],
    uploadedBy: req.body.uploadedBy || "Current User",
  };

  project.documents.push(newDoc);
  res.json(newDoc);
});

// GET staffing for a project
app.get("/api/projects/:id/staffing", (req, res) => {
  const roles = staffingRoles[req.params.id];
  if (!roles) return res.status(404).json({ error: "Staffing data not found" });
  // Merge contact info into each candidate
  const enriched = roles.map((role) => ({
    ...role,
    candidates: role.candidates.map((c) => ({
      ...c,
      ...(contactInfo[c.id] || {}),
    })),
  }));
  res.json(enriched);
});

// GET score breakdown for a candidate on a project
app.get("/api/projects/:projectId/staffing/:candidateId/score", (req, res) => {
  const { projectId, candidateId } = req.params;
  const roles = staffingRoles[projectId];
  if (!roles) return res.status(404).json({ error: "Project not found" });
  const project = projects.find((p) => p.id === projectId);

  let candidate = null;
  let roleName = "";
  let roleDesc = "";
  for (const role of roles) {
    const found = role.candidates.find((c) => c.id === candidateId);
    if (found) { candidate = found; roleName = role.role; roleDesc = role.description; break; }
  }
  if (!candidate) return res.status(404).json({ error: "Candidate not found" });

  // Deterministic but varied score breakdown based on candidate match score
  const base = candidate.matchScore;
  const jitter = (seed) => {
    const v = ((seed * 7 + 13) % 17) - 8;  // -8 to +8
    return Math.max(60, Math.min(100, base + v));
  };
  const idNum = parseInt(candidateId.replace("EMP-", ""), 10);

  const factors = [
    { label: "Relevant Experience", score: jitter(idNum * 3 + 1), detail: `Candidate has worked on ${candidate.pastProjects.length} projects with similar scope, scale, and technical requirements to this RFP.` },
    { label: "Technical Qualifications", score: jitter(idNum * 5 + 2), detail: "Assessment of professional certifications, licensed credentials, and specialized technical competencies aligned with the role requirements." },
    { label: "Role Fit", score: jitter(idNum * 7 + 3), detail: `Alignment between the candidate's career trajectory and the ${roleName} position including years of relevant seniority and leadership scope.` },
    { label: "Geographic & Availability", score: jitter(idNum * 11 + 4), detail: `Evaluation of the candidate's proximity to ${project ? project.location : 'the project site'}, travel flexibility, and current availability window.` },
    { label: "Past Performance", score: jitter(idNum * 13 + 5), detail: "Track record on prior projects considering on-time delivery, budget adherence, client satisfaction ratings, and safety performance." },
    { label: "Industry Sector Match", score: jitter(idNum * 17 + 6), detail: `Depth of experience within the ${project ? project.sector : 'target'} sector and familiarity with sector-specific regulations and standards.` },
  ];

  const summary = base >= 90
    ? `${candidate.name.split(",")[0]} is an outstanding match for the ${roleName} role on this project. Their combination of relevant experience, technical qualifications, and sector expertise closely align with the RFP requirements.`
    : base >= 80
    ? `${candidate.name.split(",")[0]} is a strong candidate for the ${roleName} role. While there are some areas where fit could be stronger, their overall profile demonstrates solid capability for this project.`
    : `${candidate.name.split(",")[0]} is a viable candidate for the ${roleName} role. Some gaps exist relative to the ideal profile, but their transferable skills and experience offer clear value.`;

  res.json({ roleName, roleDesc, factors, summary, overallScore: base });
});

// In-memory notes store keyed by "projectId::candidateId"
const candidateNotes = {};

// POST save a note for a candidate
app.post("/api/staffing/notes", (req, res) => {
  const { projectId, candidateId, note } = req.body;
  if (!projectId || !candidateId) return res.status(400).json({ error: "projectId and candidateId required" });
  candidateNotes[`${projectId}::${candidateId}`] = note || "";
  return res.json({ success: true, candidateId, note: candidateNotes[`${projectId}::${candidateId}`] });
});

// GET notes for a project
app.get("/api/projects/:id/notes", (req, res) => {
  const prefix = `${req.params.id}::`;
  const notes = {};
  for (const [key, val] of Object.entries(candidateNotes)) {
    if (key.startsWith(prefix)) {
      notes[key.replace(prefix, "")] = val;
    }
  }
  res.json(notes);
});

// POST lock / unlock a candidate
app.post("/api/staffing/lock", (req, res) => {
  const { projectId, candidateId, locked } = req.body;
  const roles = staffingRoles[projectId];
  if (!roles) return res.status(404).json({ error: "Project not found" });

  for (const role of roles) {
    const candidate = role.candidates.find((c) => c.id === candidateId);
    if (candidate) {
      candidate.locked = locked;
      return res.json({ success: true, candidateId, locked });
    }
  }
  res.status(404).json({ error: "Candidate not found" });
});

// POST chat with data (simple keyword-based mock)
app.post("/api/chat", (req, res) => {
  const { message, projectId } = req.body;
  if (!message) return res.status(400).json({ error: "Message required" });

  const project = projects.find((p) => p.id === projectId);
  const roles = staffingRoles[projectId] || [];
  const allCandidates = roles.flatMap((r) =>
    r.candidates.map((c) => ({ ...c, role: r.role }))
  );
  const lowerMsg = message.toLowerCase();

  let reply = "";

  if (lowerMsg.includes("who") && lowerMsg.includes("lock")) {
    const locked = allCandidates.filter((c) => c.locked);
    if (locked.length === 0) {
      reply = "No resources have been locked for this project yet.";
    } else {
      reply =
        "The following resources are currently locked:\n\n" +
        locked.map((c) => `• **${c.name}** — ${c.role}`).join("\n");
    }
  } else if (
    lowerMsg.includes("highest") ||
    lowerMsg.includes("best") ||
    lowerMsg.includes("top")
  ) {
    const sorted = [...allCandidates].sort(
      (a, b) => b.matchScore - a.matchScore
    );
    const top3 = sorted.slice(0, 3);
    reply =
      "Top 3 candidates by match score:\n\n" +
      top3
        .map(
          (c, i) =>
            `${i + 1}. **${c.name}** — ${c.role} (${c.matchScore}% match)`
        )
        .join("\n");
  } else if (lowerMsg.includes("role") || lowerMsg.includes("position")) {
    reply =
      "The following roles are required for this project:\n\n" +
      roles.map((r) => `• **${r.role}** — ${r.candidates.length} candidate(s)`).join("\n");
  } else if (lowerMsg.includes("document") || lowerMsg.includes("file")) {
    if (project) {
      reply =
        `There are ${project.documents.length} documents uploaded for this project:\n\n` +
        project.documents
          .map((d) => `• **${d.name}** (${d.type.toUpperCase()}, ${d.size})`)
          .join("\n");
    } else {
      reply = "Please select a project first to view documents.";
    }
  } else if (lowerMsg.includes("experience") || lowerMsg.includes("project")) {
    if (project && project.pastProjects) {
      reply =
        "SmartBids has matched the following past projects:\n\n" +
        project.pastProjects
          .map(
            (p) =>
              `• **${p.name}** (${p.year}) — ${p.value}, ${p.matchScore}% match\n  _${p.relevance}_`
          )
          .join("\n");
    } else {
      reply = "Please select a project to see past project matches.";
    }
  } else if (lowerMsg.includes("summary") || lowerMsg.includes("overview")) {
    if (project) {
      const lockedCount = allCandidates.filter((c) => c.locked).length;
      reply =
        `**Project Summary — ${project.name}**\n\n` +
        `• **Client:** ${project.client}\n` +
        `• **Estimated Value:** ${project.estimatedValue}\n` +
        `• **Bid Manager:** ${project.bidManager}\n` +
        `• **RFP Deadline:** ${project.rfpDeadline}\n` +
        `• **Documents:** ${project.documents.length} uploaded\n` +
        `• **Roles:** ${roles.length} positions identified\n` +
        `• **Locked Resources:** ${lockedCount} of ${allCandidates.length} candidates`;
    } else {
      reply = "Please select a project to get a summary.";
    }
  } else if (lowerMsg.includes("help")) {
    reply =
      "I can help you with the following queries:\n\n" +
      "• **\"Who is locked?\"** — See locked resources\n" +
      "• **\"Top candidates\"** — See highest-scoring candidates\n" +
      "• **\"List roles\"** — See required positions\n" +
      "• **\"Documents\"** — View uploaded documents\n" +
      "• **\"Past projects\"** — See SmartBids matches\n" +
      "• **\"Summary\"** — Get a project overview";
  } else {
    // Find candidates whose name or skills match keywords
    const keywords = lowerMsg.split(/\s+/).filter((w) => w.length > 3);
    const matches = allCandidates.filter((c) =>
      keywords.some(
        (k) =>
          c.name.toLowerCase().includes(k) ||
          c.skills.toLowerCase().includes(k) ||
          c.role.toLowerCase().includes(k)
      )
    );
    if (matches.length > 0) {
      reply =
        "Here are the matching candidates based on your query:\n\n" +
        matches
          .map(
            (c) =>
              `• **${c.name}** — ${c.role} (${c.matchScore}% match)\n  ${c.skills.substring(0, 120)}…`
          )
          .join("\n\n");
    } else {
      reply =
        "I'm not sure how to interpret that query. Try asking about **locked resources**, **top candidates**, **roles**, **documents**, **past projects**, or type **help** for options.";
    }
  }

  res.json({ reply });
});

// --- SPA fallback ------------------------------------------------------------
app.get("/{*splat}", (_req, res) => {
  res.sendFile(path.join(__dirname, "public", "index.html"));
});

// --- Start -------------------------------------------------------------------
app.listen(PORT, () => {
  console.log(`\n  🏗️  Contoso Construction — RFP Response Builder`);
  console.log(`  ➜  http://localhost:${PORT}\n`);
});
