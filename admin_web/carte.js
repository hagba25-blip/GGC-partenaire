requireAuth();
document.getElementById("adminBadge").textContent = localStorage.getItem("ggc_username");

const map = L.map("map").setView([6.1319, 1.2228], 7); // centré Togo par défaut
L.tileLayer("https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png", {
  attribution: "&copy; OpenStreetMap contributors",
}).addTo(map);

async function loadPositions() {
  const res = await fetch(`${API_BASE_URL}/api/admin/clients`, { headers: authHeaders() });
  if (res.status === 401) return logout();
  const clients = await res.json();

  clients.forEach(c => {
    const device = c.devices?.[0];
    if (!device?.derniere_position_lat) return;

    const color = device.statut_appareil === "restreint" ? "red" : "#0288D1";
    const marker = L.circleMarker([device.derniere_position_lat, device.derniere_position_lng], {
      radius: 9, fillColor: color, color: "white", weight: 2, fillOpacity: 0.9,
    }).addTo(map);

    marker.bindPopup(`
      <strong>${c.prenom} ${c.nom}</strong><br>
      IMEI: ${device.imei}<br>
      Statut: ${device.statut_appareil}<br>
      Dernière position: ${new Date(device.derniere_position_at).toLocaleString("fr-FR")}<br>
      <a href="client-detail.html?id=${c.id}">Voir le détail →</a>
    `);
  });
}

loadPositions();
