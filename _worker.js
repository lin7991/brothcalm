// BrothCalm Newsletter — Cloudflare Worker
// Deploy: Route brothcalm.com/api/subscribe → this worker
export default {
  async fetch(request, env) {
    if (request.method !== "POST") return new Response(JSON.stringify({ ok: false }), { status: 405, headers: cors() });
    try {
      const { email } = await request.json();
      if (!email || !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) return new Response(JSON.stringify({ ok: false, error: "Invalid email" }), { status: 400, headers: cors() });
      if (env.SEND_EMAIL) await env.SEND_EMAIL.send({ to: env.NOTIFY_EMAIL || "contact@brothcalm.com", from: "newsletter@brothcalm.com", subject: `[BrothCalm] New subscriber: ${email}`, text: `Email: ${email}\nTime: ${new Date().toISOString()}` });
      return new Response(JSON.stringify({ ok: true }), { status: 200, headers: cors() });
    } catch (e) {
      return new Response(JSON.stringify({ ok: false, error: "Server error" }), { status: 500, headers: cors() });
    }
  },
};
function cors() { return { "Content-Type": "application/json", "Access-Control-Allow-Origin": "*" }; }
