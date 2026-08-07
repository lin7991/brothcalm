// BrothCalm Newsletter Worker — KV REST API
// NOTE: Deployed version uses real CF_TOKEN. This file is the git-safe placeholder.
// Deployment: upload /tmp/worker-deploy.js (with real token) via CF API.
const CF_ACCOUNT = "1ab16cdc3d0d43621d7a6b5307b9c94b";
const CF_KV_ID = "c660adf76b5e4f7fa080d6a42b97cb8f";
const CF_TOKEN = "CF_TOKEN_PLACEHOLDER_DO_NOT_COMMIT";

addEventListener("fetch", event => {
  const r = event.request;
  if (r.method === "OPTIONS") {
    return event.respondWith(new Response(null, { status: 204,
      headers: {"Access-Control-Allow-Origin":"*","Access-Control-Allow-Methods":"POST, OPTIONS","Access-Control-Allow-Headers":"Content-Type","Access-Control-Max-Age":"86400"}}));
  }
  if (r.method !== "POST") {
    return event.respondWith(new Response(JSON.stringify({ok:false,error:"POST only"}),{status:405,headers:cors()}));
  }
  event.respondWith(handle(r));
});

async function handle(request) {
  try {
    const { email } = await request.json();
    if (!email || !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) {
      return new Response(JSON.stringify({ok:false,error:"Invalid email"}), {status:400, headers:cors()});
    }
    // Store via KV REST API
    const url = "https://api.cloudflare.com/client/v4/accounts/" + CF_ACCOUNT + "/storage/kv/namespaces/" + CF_KV_ID + "/values/" + encodeURIComponent(email);
    const resp = await fetch(url, {
      method: "PUT",
      headers: { "Authorization": "Bearer " + CF_TOKEN, "Content-Type": "text/plain" },
      body: new Date().toISOString()
    });
    if (!resp.ok) {
      return new Response(JSON.stringify({ok:false,error:"Storage failed"}), {status:500, headers:cors()});
    }
    return new Response(JSON.stringify({ok:true}), {status:200, headers:cors()});
  } catch(e) {
    return new Response(JSON.stringify({ok:false,error:"Server error"}),{status:500,headers:cors()});
  }
}
function cors() {
  return {"Content-Type":"application/json", "Access-Control-Allow-Origin":"*"};
}
