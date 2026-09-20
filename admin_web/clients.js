requireAuth();
document.getElementById("adminBadge").textContent = localStorage.getItem("ggc_username");

let allClients = [];

async function loadClients() {
  const res = await fetch(`${API_BASE_URL}/api/admin/clients`, { headers: authHeaders() });
  if (res.status === 401) return logout();
  allClients = await res.json();
  render(allClients);
}

function render(clients) {
  const tbody = document.getElementById("clientsTableBody");
  tbody.innerHTML = clients.map(c => {
    const device = c.devices?.[0];
    const position = device?.derniere_position_at
      ? new Date(device.derniere_position_at).toLocaleString("fr-FR")
      : "—";
    return `
      <tr onclick="window.location.href='client-detail.html?id=${c.id}'">
        <td>${c.prenom} ${c.nom}</td>
        <td>${c.email}</td>
        <td>${c.telephone}</td>
        <td>${device?.imei || "—"}</td>
        <td><span class="badge badge-${c.statut}">${c.statut}</span></td>
        <td>${position}</td>
      </tr>
    `;
  }).join("");
}

document.getElementById("searchInput").addEventListener("input", (e) => {
  const q = e.target.value.toLowerCase();
  const filtered = allClients.filter(c =>
    `${c.nom} ${c.prenom} ${c.email} ${c.telephone} ${c.devices?.[0]?.imei || ""}`.toLowerCase().includes(q)
  );
  render(filtered);
});

loadClients();
