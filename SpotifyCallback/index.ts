const page = "<!doctype html><html lang=\"en\"><meta charset=\"utf-8\"><meta name=\"viewport\" content=\"width=device-width,initial-scale=1\"><title>DJ TUT · Spotify</title><body style=\"font-family:system-ui;background:#101018;color:#fff;padding:48px;max-width:640px;margin:auto\"><h1>DJ TUT</h1><p>Return to DJ TUT to finish connecting Spotify.</p><p>If the app did not receive the callback, close this page and start Connect Spotify again inside the app.</p></body></html>";
Bun.serve({
  port: Number(Bun.env.PORT || 3000),
  hostname: "0.0.0.0",
  fetch(request) {
    const path = new URL(request.url).pathname;
    const headers = {
      "Cache-Control": "no-store",
      "Referrer-Policy": "no-referrer",
      "Content-Security-Policy": "default-src 'none'; style-src 'unsafe-inline'; frame-ancestors 'none'; base-uri 'none'; form-action 'none'",
      "X-Content-Type-Options": "nosniff"
    };
    if (request.method !== "GET" && request.method !== "HEAD") return new Response("Method not allowed", {status:405, headers:{...headers, Allow:"GET, HEAD"}});
    if (path === "/.well-known/apple-app-site-association" || path === "/apple-app-site-association") {
      return new Response(request.method === "HEAD" ? null : JSON.stringify({webcredentials:{apps:["ZBMURWWFQS.com.djtut.app"]}}), {headers:{...headers,"Content-Type":"application/json"}});
    }
    if (path === "/health") return new Response(request.method === "HEAD" ? null : "ok", {headers});
    if (path !== "/" && path !== "/spotify/callback") return new Response("Not found", {status:404, headers});
    return new Response(request.method === "HEAD" ? null : page, {headers:{...headers,"Content-Type":"text/html; charset=utf-8"}});
  }
});
