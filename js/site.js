/* BrothCalm — Language Toggle */
(function () {
  "use strict";
  var path = window.location.pathname.replace(/\/$/, "");
  var isCN = path.indexOf("/zh") === 0;
  var btn = document.getElementById("lang-toggle");

  if (btn) {
    btn.addEventListener("click", function (e) {
      e.preventDefault();
      var target = isCN
        ? (path.replace(/^\/zh/, "") || "/") + "/"
        : "/zh" + (path || "") + "/";

      // For non-Chinese pages, check if zh version exists before navigating
      if (!isCN) {
        var checkUrl = target;
        var xhr = new XMLHttpRequest();
        xhr.open("HEAD", checkUrl, true);
        xhr.onreadystatechange = function () {
          if (xhr.readyState === 4) {
            if (xhr.status === 200) {
              window.location.href = checkUrl;
            } else {
              // Chinese version not found, redirect to zh homepage
              window.location.href = "/zh/";
            }
          }
        };
        xhr.send();
      } else {
        window.location.href = target;
      }
    });
  }

})();


/* ─── Social Share Buttons ─── */
(function () {
  var shareSection = document.getElementById("share-buttons");
  if (!shareSection) return;
  var url = encodeURIComponent(window.location.href);
  var title = encodeURIComponent(document.title.replace(/\s*\|\s*BrothCalm/, ""));
  var links = {
    facebook: "https://www.facebook.com/sharer/sharer.php?u=" + url,
    twitter: "https://twitter.com/intent/tweet?url=" + url + "&text=" + title,
    linkedin: "https://www.linkedin.com/sharing/share-offsite/?url=" + url,
    whatsapp: "https://wa.me/?text=" + title + "%20" + url,
    pinterest: "https://pinterest.com/pin/create/button/?url=" + url + "&description=" + title,
    email: "mailto:?subject=" + title + "&body=" + url
  };
  var labels = { facebook: "Facebook", twitter: "X", linkedin: "LinkedIn", whatsapp: "WhatsApp", pinterest: "Pinterest", email: "Email" };
  var order = ["facebook", "twitter", "linkedin", "whatsapp", "pinterest", "email"];
  shareSection.innerHTML = "";
  order.forEach(function (k) {
    var a = document.createElement("a");
    a.href = links[k];
    a.target = k === "email" ? "_self" : "_blank";
    a.rel = "noopener";
    a.className = "share-btn " + k;
    a.textContent = labels[k];
    shareSection.appendChild(a);
  });
})();
