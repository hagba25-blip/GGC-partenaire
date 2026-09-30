requireAuth();
document.getElementById("adminBadge").textContent = localStorage.getItem("ggc_username");

async function charger() {
  const res = await fetch(`${API_BASE_URL}/api/admin/offres`, { headers: authHeaders() });
  if (res.status === 401) return logout();
  const offres = await res.json();
  document.getElementById("offresBody").innerHTML = offres.map(o => `
    <tr>
      <td>${o.titre}</td>
      <td>${o.description || "—"}</td>
      <td><button class="btn-action btn-lock" onclick="supprimer('${o.id}')">Supprimer</button></td>
    </tr>
  `).join("") || `<tr><td colspan="3" style="text-align:center;color:#6B8299;padding:20px;">Aucune offre</td></tr>`;
}

function ouvrirFormulaire() {
  document.getElementById("offreForm").reset();
  document.getElementById("modalOverlay").style.display = "flex";
}
function fermerFormulaire() {
  document.getElementById("modalOverlay").style.display = "none";
}

async function supprimer(id) {
  if (!confirm("Supprimer cette offre ?")) return;
  await fetch(`${API_BASE_URL}/api/admin/offres/${id}`, { method: "DELETE", headers: authHeaders() });
  charger();
}

document.getElementById("offreForm").addEventListener("submit", async (e) => {
  e.preventDefault();
  const payload = {
    titre: document.getElementById("titre").value,
    description: document.getElementById("description").value || null,
    image: document.getElementById("image").value || null,
  };
  await fetch(`${API_BASE_URL}/api/admin/offres`, {
    method: "POST", headers: authHeaders(), body: JSON.stringify(payload),
  });
  fermerFormulaire();
  charger();
});

charger();
