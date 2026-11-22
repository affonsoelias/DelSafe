const DOC_SEARCH_INDEX = [
  { name: "geometria", kind: "module", link: "geometria.html", desc: "Módulo de cálculos geométricos e estatísticos de alta precisão." },
  { name: "Ponto", kind: "record", link: "geometria.html#type-Ponto", desc: "Representa um Ponto 2D no plano cartesiano." },
  { name: "ModoRender", kind: "enum", link: "geometria.html#type-ModoRender", desc: "Modo de renderização de formas geométricas." },
  { name: "FormaGeometrica", kind: "trait", link: "geometria.html#trait-FormaGeometrica", desc: "Contrato para formas geométricas com cálculo de área." },
  { name: "CriarPonto", kind: "function", link: "geometria.html#func-CriarPonto", desc: "Cria um novo ponto no plano cartesiano." },
  { name: "DeslocarPonto", kind: "function", link: "geometria.html#func-DeslocarPonto", desc: "Desloca as coordenadas de um ponto diretamente na memória." },
  { name: "CalcularAreaAsync", kind: "function", link: "geometria.html#func-CalcularAreaAsync", desc: "Computa a área assíncrona de um retângulo delimitador." },
];

function initSearch() {
  const input = document.getElementById("searchInput");
  const results = document.getElementById("searchResults");
  if (!input || !results) return;
  input.addEventListener("input", (e) => {
    const q = e.target.value.trim().toLowerCase();
    if (q.length === 0) { results.style.display = "none"; return; }
    const matches = DOC_SEARCH_INDEX.filter(item => item.name.toLowerCase().includes(q) || item.desc.toLowerCase().includes(q)).slice(0, 8);
    if (matches.length === 0) {
      results.innerHTML = '<div class="search-item" style="color: #8b949e;">Nenhum simbolo encontrado.</div>';
    } else {
      results.innerHTML = matches.map(m => `<div class="search-item" onclick="window.location.href='${m.link}'"><span class="badge badge-async" style="margin-right: 8px;">${m.kind}</span><strong>${m.name}</strong><br><small style="color: #8b949e;">${m.desc || ""}</small></div>`).join("");
    }
    results.style.display = "block";
  });
  document.addEventListener("click", (e) => {
    if (!input.contains(e.target) && !results.contains(e.target)) results.style.display = "none";
  });
}
window.addEventListener("DOMContentLoaded", initSearch);
