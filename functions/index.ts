// functions/index.ts — Cardex backend entrypoint.
//
// Every route (HTTP and WebSocket upgrades alike) is dispatched into the
// single `CardexHub` Durable Object instance ("global"), which owns all beta
// state — see cardex-hub.ts. The platform stamps X-Rork-User-Id on requests
// that carry a valid Rork Auth bearer token before they reach the DO.

export { CardexHub } from "./cardex-hub";

type Env = { DO: Fetcher };

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    const url = new URL(request.url);

    if (url.pathname === "/") {
      return Response.json({ ok: true, service: "cardex-backend" });
    }

    // 2-arg form is required so WebSocket upgrade headers survive the hop.
    const wrapped = new Request(request.url, request);
    wrapped.headers.set("X-Rork-DO-Class", "CardexHub");
    wrapped.headers.set("X-Rork-DO-Id", "global");
    return env.DO.fetch(wrapped);
  },
} satisfies ExportedHandler<Env>;
