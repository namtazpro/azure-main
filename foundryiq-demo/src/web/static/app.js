const form = document.querySelector("#chat-form");
const input = document.querySelector("#message");
const conversation = document.querySelector("#conversation");
const submit = form.querySelector("button[type='submit']");

function addMessage(role, text) {
  const article = document.createElement("article");
  article.className = `message ${role}`;

  if (role === "assistant") {
    const avatar = document.createElement("div");
    avatar.className = "avatar";
    avatar.textContent = "IQ";
    article.appendChild(avatar);
  }

  const bubble = document.createElement("div");
  const label = document.createElement("strong");
  label.textContent = role === "user" ? "You" : "Travel Policy Assistant";
  const content = document.createElement("p");
  content.textContent = text;
  bubble.append(label, content);
  article.appendChild(bubble);
  conversation.appendChild(article);
  conversation.scrollTop = conversation.scrollHeight;
  return content;
}

async function ask(message) {
  addMessage("user", message);
  const pending = addMessage("assistant", "Searching the travel-policy knowledge base…");
  submit.disabled = true;

  try {
    const response = await fetch("/api/chat", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ message }),
    });
    const body = await response.json();
    if (!response.ok) {
      throw new Error(body.detail || "The request failed.");
    }
    pending.textContent = body.answer;
  } catch (error) {
    pending.textContent = `Unable to answer: ${error.message}`;
  } finally {
    submit.disabled = false;
    input.focus();
  }
}

form.addEventListener("submit", (event) => {
  event.preventDefault();
  const message = input.value.trim();
  if (!message) return;
  input.value = "";
  ask(message);
});

document.querySelectorAll(".examples button").forEach((button) => {
  button.addEventListener("click", () => {
    input.value = button.textContent;
    input.focus();
  });
});
