// GGC PARTENAIRE - Dashboard logic

requireAuth();
document.getElementById("adminBadge").textContent = localStorage.getItem("ggc_username");

const badgeClass = {
  actif: "badge-actif",
  en_retard: "badge-retard",
  bloque: "badge-bloque",
  solde: "badge-solde",
};
const badgeLabel = {
  actif: "Actif",
  en_retard: "En retard",
  bloque: "Bloqué",
  solde: "Soldé",
};

async function loadClients() {
  try {
    const res = await fetch(`${API_BASE_URL}/api/admin/clients`, { headers: authHeaders() });
    if (res.status === 401) return logout();
    const clients = await res.json();

    document.getElementById("statTotal").textContent = clients.length;
    document.getElementById("statActifs").textContent = clients.filter(c => c.statut === "actif").length;
    document.getElementById("statRetard").textContent = clients.filter(c => c.statut === "en_retard").length;
    document.getElementById("statBloques").textContent = clients.filter(c =>
      c.devices?.some(d => d.statut_appareil === "restreint")
    ).length;

    const tbody = document.getElementById("clientsTableBody");
    tbody.innerHTML = clients.map(c => `
      <tr onclick="window.location.href='client-detail.html?id=${c.id}'">
        <td>${c.prenom} ${c.nom}</td>
        <td>${c.telephone}</td>
        <td>${Number(c.prix_total).toLocaleString()} FCFA</td>
        <td>${c.mode_paiement}</td>
        <td><span class="badge ${badgeClass[c.statut] || ''}">${badgeLabel[c.statut] || c.statut}</span></td>
      </tr>
    `).join("");
  } catch (e) {
    console.error(e);
  }
}

loadClients();
