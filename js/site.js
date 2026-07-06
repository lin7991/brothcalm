/* BrothCalm — Language Toggle + Newsletter */
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

  var form = document.getElementById("newsletter-form");
  var msg = document.getElementById("newsletter-msg");
  if (form) {
    form.addEventListener("submit", function (e) {
      e.preventDefault();
      var emailInput = form.querySelector('input[type="email"]');
      var email = emailInput.value.trim();
      var btn = form.querySelector("button");
      if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) {
        if (msg) { msg.textContent = (isCN ? "请输入有效的邮箱地址" : "Please enter a valid email address."); msg.className = "newsletter-msg error"; }
        return;
      }
      btn.disabled = true;
      btn.textContent = isCN ? "提交中..." : "Submitting...";
      fetch("/api/subscribe", { method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify({ email: email }) })
        .then(function (r) { return r.json(); })
        .then(function (d) {
          if (d.ok) {
            if (msg) { msg.textContent = isCN ? "✅ 订阅成功！感谢您的关注。" : "✅ Subscribed! Thank you."; msg.className = "newsletter-msg success"; }
            emailInput.value = "";
          } else { throw new Error("fail"); }
        })
        .catch(function () {
          if (msg) { msg.textContent = isCN ? "❌ 提交失败，请稍后重试。" : "❌ Submission failed. Please try again."; msg.className = "newsletter-msg error"; }
        })
        .finally(function () { btn.disabled = false; btn.textContent = isCN ? "订阅" : "Subscribe"; });
    });
  }
})();
