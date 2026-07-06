/* BrothCalm — Language Toggle + Newsletter */
(function () {
  "use strict";
  var path = window.location.pathname.replace(/\/$/, "");
  var isCN = path.indexOf("/zh") === 0;
  var btn = document.getElementById("lang-toggle");
  if (btn) {
    btn.addEventListener("click", function (e) {
      e.preventDefault();
      window.location.href = (isCN ? path.replace(/^\/zh/, "") || "/" : "/zh" + (path || "")) + "/";
    });
  }
  var form = document.getElementById("newsletter-form");
  var msg = document.getElementById("newsletter-msg");
  if (form) {
    form.addEventListener("submit", function (e) {
      e.preventDefault();
      var email = form.querySelector('input[type="email"]').value.trim();
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
