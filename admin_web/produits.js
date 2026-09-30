requireAuth();
document.getElementById("adminBadge").textContent = localStorage.getItem("ggc_username");

let produits = [];

async function charger() {
  const res = await fetch(`${API_BASE_URL}/api/admin/produits`, { headers: authHeaders() });
  if (res.status === 401) return logout();
  produits = await res.json();
  render();
}

function render() {
  const tbody = document.getElementById("produitsBody");
  tbody.innerHTML = produits.map(p => `
    <tr>
      <td>${p.nom}</td>
      <td>${Number(p.prix_normal).toLocaleString()} FCFA</td>
      <td>${p.prix_tontine ? Number(p.prix_tontine).toLocaleString() + " FCFA" : "—"}</td>
      <td>${(p.images || []).length} image(s)</td>
      <td>
        <button class="btn-action btn-lock" onclick='modifier(${JSON.stringify(p).replace(/'/g, "&apos;")})'>Modifier</button>
        <button class="btn-action btn-lock" onclick="supprimer('${p.id}')">Supprimer</button>
      </td>
    </tr>
  `).join("") || `<tr><td colspan="5" style="text-align:center;color:#6B8299;padding:20px;">Aucun produit</td></tr>`;
}

function ouvrirFormulaire() {
  document.getElementById("modalTitre").textContent = "Ajouter un produit";
  document.getElementById("produitForm").reset();
  document.getElementById("produitId").value = "";
  document.getElementById("modalOverlay").style.display = "flex";
}

function modifier(p) {
  document.getElementById("modalTitre").textContent = "Modifier le produit";
  document.getElementById("produitId").value = p.id;
  document.getElementById("nom").value = p.nom;
  document.getElementById("description").value = p.description || "";
  document.getElementById("prixNormal").value = p.prix_normal;
  document.getElementById("prixTontine").value = p.prix_tontine || "";
  document.getElementById("images").value = (p.images || []).join("\n");
  document.getElementById("modalOverlay").style.display = "flex";
}

function fermerFormulaire() {
  document.getElementById("modalOverlay").style.display = "none";
}

async function supprimer(id) {
  if (!confirm("Supprimer ce produit ?")) return;
  await fetch(`${API_BASE_URL}/api/admin/produits/${id}`, { method: "DELETE", headers: authHeaders() });
  charger();
}

document.getElementById("produitForm").addEventListener("submit", async (e) => {
  e.preventDefault();
  const id = document.getElementById("produitId").value;
  const payload = {
    nom: document.getElementById("nom").value,
    description: document.getElementById("description").value || null,
    prix_normal: parseFloat(document.getElementById("prixNormal").value),
    prix_tontine: document.getElementById("prixTontine").value
      ? parseFloat(document.getElementById("prixTontine").value) : null,
    images: document.getElementById("images").value.split("\n").map(s => s.trim()).filter(Boolean),
  };

  if (id) {
    await fetch(`${API_BASE_URL}/api/admin/produits/${id}`, {
      method: "PUT", headers: authHeaders(), body: JSON.stringify(payload),
    });
  } else {
    await fetch(`${API_BASE_URL}/api/admin/produits`, {
      method: "POST", headers: authHeaders(), body: JSON.stringify(payload),
    });
  }
  fermerFormulaire();
  charger();
});

charger();
