const DOC_SEARCH_INDEX = [
  { name: "geometria", kind: "module", link: "geometria.html", desc: "High-precision geometric and statistical calculations module." },
  { name: "Point", kind: "record", link: "geometria.html#type-Point", desc: "Represents a 2D Point on the Cartesian plane." },
  { name: "RenderMode", kind: "enum", link: "geometria.html#type-RenderMode", desc: "Rendering mode for geometric shapes." },
  { name: "GeometricShape", kind: "trait", link: "geometria.html#trait-GeometricShape", desc: "Contract for geometric shapes supporting area calculation." },
  { name: "CreatePoint", kind: "function", link: "geometria.html#func-CreatePoint", desc: "Creates a new point on the Cartesian plane." },
  { name: "ShiftPoint", kind: "function", link: "geometria.html#func-ShiftPoint", desc: "Translates the coordinates of a point directly in memory." },
  { name: "ComputeAreaAsync", kind: "function", link: "geometria.html#func-ComputeAreaAsync", desc: "Asynchronously computes the area of a bounding rectangle." },
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
      results.innerHTML = '<div class="search-item" style="color: #8b949e;">No symbols found.</div>';
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
