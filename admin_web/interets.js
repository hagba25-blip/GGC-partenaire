requireAuth();
document.getElementById("adminBadge").textContent = localStorage.getItem("ggc_username");

let interetCourant = null;

async function charger() {
  const res = await fetch(`${API_BASE_URL}/api/admin/interets`, { headers: authHeaders() });
  if (res.status === 401) return logout();
  const interets = await res.json();

  document.getElementById("interetsBody").innerHTML = interets.map(i => {
    const client = i.clients || {};
    const statut = i.repondu
      ? '<span class="badge badge-solde">Répondu</span>'
      : '<span class="badge badge-retard">En attente</span>';
    return `
      <tr>
        <td>${client.prenom || ""} ${client.nom || ""}</td>
        <td>${client.telephone || "—"}</td>
        <td>${i.type === "produit" ? "🛍️ Produit" : "🏷️ Offre"}</td>
        <td>${i.item_nom}</td>
        <td>${statut}</td>
        <td>
          <button class="btn-action btn-unlock" onclick='ouvrirReponse(${JSON.stringify(i).replace(/'/g, "&apos;")})'>
            ${i.repondu ? "Modifier réponse" : "Répondre"}
          </button>
        </td>
      </tr>
    `;
  }).join("") || `<tr><td colspan="6" style="text-align:center;color:#6B8299;padding:20px;">Aucun intérêt signalé</td></tr>`;
}

function ouvrirReponse(interet) {
  interetCourant = interet;
  const client = interet.clients || {};
  document.getElementById("interetContexte").textContent =
    `${client.prenom || ""} ${client.nom || ""} est intéressé(e) par : ${interet.item_nom}`;
  document.getElementById("messageReponse").value = interet.message_admin || "";
  document.getElementById("modalOverlay").style.display = "flex";
}

function fermerReponse() {
  document.getElementById("modalOverlay").style.display = "none";
}

async function envoyerReponse() {
  const message = document.getElementById("messageReponse").value.trim();
  if (!message) return alert("Écrivez un message avant d'envoyer.");

  await fetch(`${API_BASE_URL}/api/admin/interets/${interetCourant.id}/repondre`, {
    method: "POST", headers: authHeaders(), body: JSON.stringify({ message }),
  });
  fermerReponse();
  charger();
}

charger();
