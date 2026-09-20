requireAuth();
document.getElementById("adminBadge").textContent = localStorage.getItem("ggc_username");

const params = new URLSearchParams(window.location.search);
const clientId = params.get("id");

async function loadDetail() {
  const res = await fetch(`${API_BASE_URL}/api/admin/clients/${clientId}`, { headers: authHeaders() });
  if (res.status === 401) return logout();
  const data = await res.json();
  const c = data.client;
  const device = c.devices?.[0];

  document.getElementById("clientName").textContent = `${c.prenom} ${c.nom}`;

  document.getElementById("detailRows").innerHTML = `
    ${row("Email", c.email)}
    ${row("Téléphone", c.telephone)}
    ${row("Date de naissance", c.date_naissance)}
    ${row("Prix total", `${Number(c.prix_total).toLocaleString()} FCFA`)}
    ${row("Mode de paiement", `${c.mode_paiement} (${c.duree_mois} mois)`)}
    ${row("Montant par échéance", `${Number(c.montant_echeance).toLocaleString()} FCFA`)}
    ${row("Statut", `<span class="badge badge-${c.statut}">${c.statut}</span>`)}
    ${row("IMEI", device?.imei || "—")}
    ${row("Modèle", device?.modele || "—")}
    ${row("Adresse IP", device?.ip_address || "—")}
    ${row("Dernière position", device?.derniere_position_at
      ? `${device.derniere_position_lat}, ${device.derniere_position_lng} — ${new Date(device.derniere_position_at).toLocaleString("fr-FR")}`
      : "—")}
    ${row("Statut appareil", device?.statut_appareil === "restreint"
      ? '<span class="badge badge-bloque">Restreint</span>'
      : '<span class="badge badge-actif">Normal</span>')}
  `;

  document.getElementById("echeancesBody").innerHTML = data.echeances.map(e => `
    <tr>
      <td>${e.numero}</td>
      <td>${Number(e.montant).toLocaleString()} FCFA</td>
      <td>${e.date_prevue}</td>
      <td><span class="badge ${e.statut === 'payee' ? 'badge-solde' : e.statut === 'en_retard' ? 'badge-retard' : ''}">${e.statut}</span></td>
    </tr>
  `).join("");

  const actionsRes = await fetch(`${API_BASE_URL}/api/admin/actions/${clientId}`, { headers: authHeaders() });
  const actions = await actionsRes.json();
  document.getElementById("actionsBody").innerHTML = actions.map(a => `
    <tr><td>${a.action}</td><td>${a.raison || "—"}</td><td>${new Date(a.created_at).toLocaleString("fr-FR")}</td></tr>
  `).join("") || `<tr><td colspan="3" style="text-align:center;color:#6B8299;">Aucune action</td></tr>`;
}

function row(label, value) {
  return `<div class="detail-row"><span>${label}</span><strong>${value}</strong></div>`;
}

async function restreindre(action) {
  const raison = action !== "unlock_all" ? prompt("Raison de cette action :") : "Régularisation manuelle";
  if (raison === null) return;

  await fetch(`${API_BASE_URL}/api/admin/restriction`, {
    method: "POST",
    headers: authHeaders(),
    body: JSON.stringify({ client_id: clientId, action, raison }),
  });
  loadDetail();
}

loadDetail();
