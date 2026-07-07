// BrothCalm Newsletter Worker — stores subscribers via CF API
const CF_ACCOUNT = "1ab16cdc3d0d43621d7a6b5307b9c94b";
const CF_KV_ID = "c660adf76b5e4f7fa080d6a42b97cb8f";
const CF_API_KEY = "cfk_IxQmjwOsVOhCwVrMCAdxCJC5FR1mnxB8qKxcBAeS48b5059d";

addEventListener("fetch", event => {
  const r = event.request;
  const url = new URL(r.url);

  if (r.method === "GET" && url.pathname === "/api/subscribe" && url.searchParams.has("list")) {
    return event.respondWith(listSubscribers());
  }
  if (r.method === "OPTIONS") {
    return event.respondWith(new Response(null, { status: 204,
      headers: cors_preflight() }));
  }
  if (r.method !== "POST") {
    return event.respondWith(new Response(JSON.stringify({ok:false,error:"POST only"}),{status:405,headers:cors()}));
  }
  event.respondWith(handle(r));
});

async function listSubscribers() {
  try {
    const resp = await fetch(`https://api.cloudflare.com/client/v4/accounts/${CF_ACCOUNT}/storage/kv/namespaces/${CF_KV_ID}/keys`, {
      headers: { "X-Auth-Email": "5004378@qq.com", "X-Auth-Key": CF_API_KEY }
    });
    const data = await resp.json();
    const emails = (data.result || []).map(k => k.name);
    return new Response(JSON.stringify({ok:true, subscribers: emails}), {status:200, headers:cors()});
  } catch(e) {
    return new Response(JSON.stringify({ok:false, error:e.toString()}), {status:500, headers:cors()});
  }
}

async function handle(request) {
  try {
    const { email } = await request.json();
    if (!email || !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) {
      return new Response(JSON.stringify({ok:false,error:"Invalid email"}), {status:400, headers:cors()});
    }
    // Store in KV via CF API
    await fetch(`https://api.cloudflare.com/client/v4/accounts/${CF_ACCOUNT}/storage/kv/namespaces/${CF_KV_ID}/values/${encodeURIComponent(email)}`, {
      method: "PUT",
      headers: { "X-Auth-Email": "5004378@qq.com", "X-Auth-Key": CF_API_KEY, "Content-Type": "text/plain" },
      body: new Date().toISOString()
    });
    return new Response(JSON.stringify({ok:true}), {status:200, headers:cors()});
  } catch(e) {
    return new Response(JSON.stringify({ok:false,error:"Server error"}),{status:500,headers:cors()});
  }
}
function cors() { return {"Content-Type":"application/json","Access-Control-Allow-Origin":"*"}; }
function cors_preflight() { return {"Access-Control-Allow-Origin":"*","Access-Control-Allow-Methods":"POST, GET, OPTIONS","Access-Control-Allow-Headers":"Content-Type","Access-Control-Max-Age":"86400"}; }
