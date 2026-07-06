addEventListener("fetch", event => {
  const r = event.request;
  if (r.method !== "POST") {
    return event.respondWith(new Response(JSON.stringify({ ok: false, error: "POST only" }), { status: 405, headers: cors() }));
  }
  event.respondWith(handle(r));
});
async function handle(request) {
  try {
    const { email } = await request.json();
    if (!email || !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) {
      return new Response(JSON.stringify({ ok: false, error: "Invalid email" }), { status: 400, headers: cors() });
    }
    console.log("New subscriber:", email);
    return new Response(JSON.stringify({ ok: true }), { status: 200, headers: cors() });
  } catch (e) {
    return new Response(JSON.stringify({ ok: false, error: "Server error" }), { status: 500, headers: cors() });
  }
}
function cors() { return { "Content-Type": "application/json", "Access-Control-Allow-Origin": "*" }; }
