// GGC PARTENAIRE - Authentification admin (pas d'auto-inscription : comptes créés côté backend uniquement)

document.getElementById("loginForm").addEventListener("submit", async (e) => {
  e.preventDefault();
  const username = document.getElementById("username").value;
  const password = document.getElementById("password").value;
  const errorMsg = document.getElementById("errorMsg");
  errorMsg.textContent = "";

  try {
    const res = await fetch(`${API_BASE_URL}/api/admin/login`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ username, password }),
    });
    const data = await res.json();

    if (!res.ok) {
      errorMsg.textContent = data.detail || "Identifiants incorrects.";
      return;
    }

    localStorage.setItem("ggc_token", data.token);
    localStorage.setItem("ggc_username", data.username);
    localStorage.setItem("ggc_role", data.role);
    window.location.href = "dashboard.html";
  } catch (err) {
    errorMsg.textContent = "Impossible de contacter le serveur.";
  }
});

// Utilitaire partagé par les autres pages
function requireAuth() {
  const token = localStorage.getItem("ggc_token");
  if (!token) {
    window.location.href = "index.html";
    return null;
  }
  return token;
}

function logout() {
  localStorage.clear();
  window.location.href = "index.html";
}

function authHeaders() {
  return {
    "Content-Type": "application/json",
    "Authorization": `Bearer ${localStorage.getItem("ggc_token")}`,
  };
}
