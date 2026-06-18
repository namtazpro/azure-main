// ============================================================================
// Contoso Construction — RFP Response Builder — Client-Side App
// ============================================================================

(() => {
  "use strict";

  // --- State -----------------------------------------------------------------
  let currentProjectId = null;

  // --- DOM refs --------------------------------------------------------------
  const $dropdown = document.getElementById("project-dropdown");
  const $details = document.getElementById("project-details");
  const $screenProject = document.getElementById("screen-project");
  const $screenStaffing = document.getElementById("screen-staffing");

  // --- Init ------------------------------------------------------------------
  loadProjects();

  // --- Event Listeners -------------------------------------------------------
  $dropdown.addEventListener("change", (e) => {
    const id = e.target.value;
    if (id) {
      currentProjectId = id;
      loadProjectDetails(id);
    } else {
      $details.classList.add("hidden");
      currentProjectId = null;
    }
  });

  document.getElementById("btn-go-staffing").addEventListener("click", () => {
    if (!currentProjectId) return;
    showScreen("staffing");
    loadStaffing(currentProjectId);
  });

  document.getElementById("btn-back-project").addEventListener("click", () => {
    showScreen("project");
  });

  document.getElementById("file-upload").addEventListener("change", (e) => {
    if (e.target.files.length > 0) {
      uploadDocument(e.target.files[0]);
      e.target.value = "";
    }
  });

  document.getElementById("chat-send").addEventListener("click", sendChat);
  document.getElementById("chat-input").addEventListener("keydown", (e) => {
    if (e.key === "Enter") sendChat();
  });

  // --- Load Projects ---------------------------------------------------------
  async function loadProjects() {
    const res = await fetch("/api/projects");
    const data = await res.json();
    data.forEach((p) => {
      const opt = document.createElement("option");
      opt.value = p.id;
      opt.textContent = `${p.name}  —  ${p.client}  (${p.sector})`;
      $dropdown.appendChild(opt);
    });
  }

  // --- Load Project Details --------------------------------------------------
  async function loadProjectDetails(id) {
    const res = await fetch(`/api/projects/${id}`);
    const p = await res.json();

    document.getElementById("detail-name").textContent = p.name;
    document.getElementById("detail-description").textContent = p.description;
    document.getElementById("detail-id").textContent = p.id;
    document.getElementById("detail-client").textContent = p.client;
    document.getElementById("detail-location").textContent = p.location;
    document.getElementById("detail-sector").textContent = p.sector;
    document.getElementById("detail-value").textContent = p.estimatedValue;
    document.getElementById("detail-deadline").textContent = formatDate(p.rfpDeadline);
    document.getElementById("detail-created").textContent = formatDate(p.dateCreated);
    document.getElementById("detail-bidmanager").textContent = p.bidManager;
    document.getElementById("detail-status").textContent = "To win";

    renderDocuments(p.documents);
    renderPastProjects(p.pastProjects);

    $details.classList.remove("hidden");
  }

  // --- Render Documents ------------------------------------------------------
  function renderDocuments(docs) {
    const tbody = document.getElementById("doc-table-body");
    tbody.innerHTML = docs
      .map((d) => {
        const iconClass = getDocIcon(d.type);
        return `
        <tr>
          <td><i class="fas ${iconClass.icon} doc-icon ${d.type}"></i>${d.name}</td>
          <td>${d.type.toUpperCase()}</td>
          <td>${d.size}</td>
          <td>${formatDate(d.uploaded)}</td>
          <td>${d.uploadedBy}</td>
        </tr>`;
      })
      .join("");
  }

  function getDocIcon(type) {
    switch (type) {
      case "pdf": return { icon: "fa-file-pdf" };
      case "excel": return { icon: "fa-file-excel" };
      case "email": return { icon: "fa-envelope" };
      default: return { icon: "fa-file" };
    }
  }

  // --- Render Past Projects --------------------------------------------------
  function renderPastProjects(projects) {
    const container = document.getElementById("past-projects-list");
    container.innerHTML = projects
      .map((p) => {
        const scoreClass = p.matchScore >= 90 ? "high" : p.matchScore >= 80 ? "medium" : "low";
        return `
        <div class="past-project-card">
          <div class="pp-score ${scoreClass}">${p.matchScore}%</div>
          <div class="pp-info">
            <h4>${p.name}</h4>
            <div class="pp-meta">${p.year} &nbsp;·&nbsp; ${p.value}</div>
            <div class="pp-relevance">${p.relevance}</div>
          </div>
        </div>`;
      })
      .join("");
  }

  // --- Upload Document -------------------------------------------------------
  async function uploadDocument(file) {
    const formData = new FormData();
    formData.append("file", file);
    formData.append("uploadedBy", "Sarah Mitchell");

    const res = await fetch(`/api/projects/${currentProjectId}/documents`, {
      method: "POST",
      body: formData,
    });
    const newDoc = await res.json();

    // Re-fetch project to get updated doc list
    loadProjectDetails(currentProjectId);
  }

  // --- Load Staffing ---------------------------------------------------------
  async function loadStaffing(projectId) {
    document.getElementById("staffing-project-name").textContent =
      $dropdown.options[$dropdown.selectedIndex].textContent.split("—")[0].trim();

    const [staffRes, notesRes] = await Promise.all([
      fetch(`/api/projects/${projectId}/staffing`),
      fetch(`/api/projects/${projectId}/notes`),
    ]);
    const roles = await staffRes.json();
    const savedNotes = await notesRes.json();
    // Merge notes into candidates
    roles.forEach((role) =>
      role.candidates.forEach((c) => {
        c._note = savedNotes[c.id] || "";
      })
    );
    _cachedRoles = roles;

    const container = document.getElementById("staffing-roles-container");
    container.innerHTML = roles
      .map(
        (role, ri) => `
      <div class="role-section">
        <div class="role-header" onclick="toggleRole(${ri})">
          <div>
            <h3><i class="fas fa-briefcase"></i> ${role.role}</h3>
            <div class="role-desc">${role.description}</div>
          </div>
          <i class="fas fa-chevron-down role-toggle open" id="role-toggle-${ri}"></i>
        </div>
        <div class="role-candidates" id="role-body-${ri}">
          ${role.candidates
            .map(
              (c) => `
            <div class="candidate-card ${c.locked ? "locked-card" : ""}" id="card-${c.id}">
              <div class="candidate-score ${scoreClass(c.matchScore)}">
                ${c.matchScore}%
                <small>match</small>
              </div>
              <div class="candidate-info">
                <div class="candidate-name clickable" onclick="openCandidateModal('${projectId}', '${c.id}', this)" title="Click to view full profile & score breakdown">${c.name} <i class="fas fa-external-link-alt candidate-name-icon"></i></div>
                <div class="candidate-location"><i class="fas fa-map-marker-alt"></i> ${c.location}</div>
                <div class="candidate-contact">
                  <span class="contact-item"><i class="fas fa-phone-alt"></i> ${c.phone || 'N/A'}</span>
                  <span class="contact-item"><a href="mailto:${c.email}"><i class="fas fa-envelope"></i> ${c.email || 'N/A'}</a></span>
                </div>
                <div class="candidate-links">
                  <a href="${c.linkedin}" target="_blank"><i class="fab fa-linkedin"></i> LinkedIn</a>
                  <a href="${c.resumeUrl}" target="_blank"><i class="fas fa-file-alt"></i> Resume (SharePoint)</a>
                  <a href="https://teams.microsoft.com/l/chat/0/0?users=${encodeURIComponent(c.teamsId || '')}" target="_blank" class="teams-link"><i class="fab fa-microsoft"></i> Chat on Teams</a>
                </div>
                <div class="candidate-skills">${c.skills}</div>
                <div class="candidate-projects-label">Key Projects</div>
                <div class="candidate-projects">
                  ${c.pastProjects.map((pp) => `<span class="project-chip">${pp}</span>`).join("")}
                </div>
              </div>
              <div class="candidate-actions">
                <button class="lock-btn ${c.locked ? "locked" : ""}"
                        onclick="toggleLock('${projectId}', '${c.id}', this)"
                        id="lock-${c.id}">
                  <i class="fas ${c.locked ? "fa-lock" : "fa-lock-open"}"></i>
                  ${c.locked ? "Locked" : "Lock Resource"}
                </button>
              </div>
              <div class="candidate-notes">
                <label class="notes-label"><i class="fas fa-sticky-note"></i> Notes</label>
                <textarea class="notes-input" id="notes-${c.id}" placeholder="Add notes about this candidate…" rows="3">${c._note || ''}</textarea>
                <button class="notes-save-btn" onclick="saveNote('${projectId}', '${c.id}')">
                  <i class="fas fa-save"></i> Save
                </button>
              </div>
            </div>`
            )
            .join("")}
        </div>
      </div>`
      )
      .join("");
  }

  function scoreClass(score) {
    if (score >= 90) return "score-high";
    if (score >= 80) return "score-med";
    return "score-low";
  }

  // --- Cached staffing data for modal ----------------------------------------
  let _cachedRoles = [];

  // --- Global: Open Candidate Modal ------------------------------------------
  window.openCandidateModal = async function (projectId, candidateId) {
    // Find candidate in cached data
    let candidate = null;
    let roleName = "";
    for (const role of _cachedRoles) {
      const found = role.candidates.find((c) => c.id === candidateId);
      if (found) { candidate = found; roleName = role.role; break; }
    }
    if (!candidate) return;

    // Populate static parts immediately
    const overlay = document.getElementById("modal-overlay");
    document.getElementById("modal-name").textContent = candidate.name;
    document.getElementById("modal-role").textContent = roleName;
    const scoreEl = document.getElementById("modal-score");
    scoreEl.textContent = candidate.matchScore + "%";
    scoreEl.className = "modal-score " + scoreClass(candidate.matchScore);

    document.getElementById("modal-meta").innerHTML = `
      <div class="modal-meta-item"><i class="fas fa-map-marker-alt"></i> ${candidate.location}</div>
      <div class="modal-meta-item"><i class="fas fa-phone-alt"></i> ${candidate.phone || 'N/A'}</div>
      <div class="modal-meta-item"><i class="fas fa-envelope"></i> <a href="mailto:${candidate.email}">${candidate.email || 'N/A'}</a></div>
      <div class="modal-meta-item"><i class="fab fa-linkedin"></i> <a href="${candidate.linkedin}" target="_blank">LinkedIn Profile</a></div>
      <div class="modal-meta-item"><i class="fas fa-file-alt"></i> <a href="${candidate.resumeUrl}" target="_blank">Resume (SharePoint)</a></div>
    `;
    document.getElementById("modal-skills").textContent = candidate.skills;
    document.getElementById("modal-projects").innerHTML =
      candidate.pastProjects.map((pp) => `<span class="project-chip">${pp}</span>`).join("");

    // Show modal with loading state for score breakdown
    document.getElementById("modal-match-intro").textContent = "Loading score analysis…";
    document.getElementById("modal-score-bars").innerHTML = '<div class="modal-loading"><i class="fas fa-spinner fa-spin"></i></div>';
    overlay.classList.remove("hidden");
    document.body.style.overflow = "hidden";

    // Fetch score breakdown
    try {
      const res = await fetch(`/api/projects/${projectId}/staffing/${candidateId}/score`);
      const data = await res.json();
      document.getElementById("modal-match-intro").textContent = data.summary;
      document.getElementById("modal-score-bars").innerHTML = data.factors
        .map((f) => `
          <div class="score-factor">
            <div class="score-factor-header">
              <span class="score-factor-label">${f.label}</span>
              <span class="score-factor-value ${f.score >= 90 ? 'sf-high' : f.score >= 80 ? 'sf-med' : 'sf-low'}">${f.score}%</span>
            </div>
            <div class="score-bar-track">
              <div class="score-bar-fill ${f.score >= 90 ? 'sf-high' : f.score >= 80 ? 'sf-med' : 'sf-low'}" style="width: ${f.score}%"></div>
            </div>
            <p class="score-factor-detail">${f.detail}</p>
          </div>
        `)
        .join("");
    } catch {
      document.getElementById("modal-score-bars").innerHTML = '<p>Unable to load score breakdown.</p>';
    }
  };

  // --- Global: Close Modal ---------------------------------------------------
  window.closeModal = function (event) {
    if (event && event.target !== event.currentTarget) return;
    document.getElementById("modal-overlay").classList.add("hidden");
    document.body.style.overflow = "";
  };
  // Close on Escape key
  document.addEventListener("keydown", (e) => {
    if (e.key === "Escape") closeModal();
  });

  // --- Global: Save Note -----------------------------------------------------
  window.saveNote = async function (projectId, candidateId) {
    const textarea = document.getElementById(`notes-${candidateId}`);
    const note = textarea.value;
    const btn = textarea.nextElementSibling;
    btn.disabled = true;
    btn.innerHTML = '<i class="fas fa-spinner fa-spin"></i> Saving…';
    try {
      const res = await fetch("/api/staffing/notes", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ projectId, candidateId, note }),
      });
      const result = await res.json();
      if (result.success) {
        btn.innerHTML = '<i class="fas fa-check"></i> Saved';
        btn.classList.add("saved");
        setTimeout(() => {
          btn.innerHTML = '<i class="fas fa-save"></i> Save';
          btn.classList.remove("saved");
          btn.disabled = false;
        }, 1500);
      }
    } catch {
      btn.innerHTML = '<i class="fas fa-save"></i> Save';
      btn.disabled = false;
    }
  };

  // --- Global: Toggle Role Collapse ------------------------------------------
  window.toggleRole = function (index) {
    const body = document.getElementById(`role-body-${index}`);
    const icon = document.getElementById(`role-toggle-${index}`);
    if (body.style.display === "none") {
      body.style.display = "";
      icon.classList.add("open");
    } else {
      body.style.display = "none";
      icon.classList.remove("open");
    }
  };

  // --- Global: Toggle Lock ---------------------------------------------------
  window.toggleLock = async function (projectId, candidateId, btn) {
    const isLocked = btn.classList.contains("locked");
    const res = await fetch("/api/staffing/lock", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ projectId, candidateId, locked: !isLocked }),
    });
    const result = await res.json();
    if (result.success) {
      btn.classList.toggle("locked");
      const card = document.getElementById(`card-${candidateId}`);
      card.classList.toggle("locked-card");
      if (result.locked) {
        btn.innerHTML = '<i class="fas fa-lock"></i> Locked';
      } else {
        btn.innerHTML = '<i class="fas fa-lock-open"></i> Lock Resource';
      }
    }
  };

  // --- Chat ------------------------------------------------------------------
  async function sendChat() {
    const input = document.getElementById("chat-input");
    const msg = input.value.trim();
    if (!msg) return;

    appendChat("user", msg);
    input.value = "";

    const res = await fetch("/api/chat", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ message: msg, projectId: currentProjectId }),
    });
    const data = await res.json();
    appendChat("assistant", formatChatReply(data.reply));
  }

  function appendChat(role, html) {
    const body = document.getElementById("chat-body");
    const icon = role === "assistant" ? "fa-robot" : "fa-user";
    const msgDiv = document.createElement("div");
    msgDiv.className = `chat-message ${role}`;
    msgDiv.innerHTML = `
      <div class="chat-avatar"><i class="fas ${icon}"></i></div>
      <div class="chat-bubble">${html}</div>
    `;
    body.appendChild(msgDiv);
    body.scrollTop = body.scrollHeight;
  }

  function formatChatReply(text) {
    // Convert markdown-ish bold and newlines to HTML
    return text
      .replace(/\*\*(.*?)\*\*/g, "<strong>$1</strong>")
      .replace(/_(.*?)_/g, "<em>$1</em>")
      .replace(/\n/g, "<br />");
  }

  // --- Screen Navigation -----------------------------------------------------
  function showScreen(name) {
    $screenProject.classList.remove("active");
    $screenStaffing.classList.remove("active");
    if (name === "project") $screenProject.classList.add("active");
    if (name === "staffing") $screenStaffing.classList.add("active");
  }

  // --- Helpers ---------------------------------------------------------------
  function formatDate(dateStr) {
    if (!dateStr) return "";
    const d = new Date(dateStr + "T00:00:00");
    return d.toLocaleDateString("en-US", { year: "numeric", month: "short", day: "numeric" });
  }
})();
