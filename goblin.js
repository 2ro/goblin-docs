// goblin.js: small progressive enhancement for Goblin Docs.
// Wraps any image whose alt text begins with "shot:" in a phone frame,
// so authors can write plain Markdown ![shot: Home tab](...) and get the
// mobile-framed screenshot treatment without raw HTML.
(function () {
  function frameShots() {
    document.querySelectorAll(".content img").forEach(function (img) {
      var alt = img.getAttribute("alt") || "";
      if (!/^shot:/i.test(alt) || img.closest(".shot")) return;
      var cap = alt.replace(/^shot:\s*/i, "");
      var wrap = document.createElement("p");
      wrap.className = "shot";
      img.parentNode.insertBefore(wrap, img);
      wrap.appendChild(img);
      if (cap) {
        var em = document.createElement("em");
        em.textContent = cap;
        wrap.appendChild(em);
      }
    });
  }
  if (document.readyState !== "loading") frameShots();
  else document.addEventListener("DOMContentLoaded", frameShots);
})();
