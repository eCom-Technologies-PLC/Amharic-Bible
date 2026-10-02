// Entry point for Cloudflare Workers (`wrangler deploy`). For Deno Deploy use:
//   Deno.serve((req) => handle(req, Deno.env.toObject()));
import { handle } from './proxy.mjs';

export default {
  fetch: (req, env) => handle(req, env),
};
