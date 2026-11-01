// Cloudflare Workers entry point; the logic lives in assistant.mjs.
import { handle } from './assistant.mjs';

export default {
  fetch: (req, env) => handle(req, env),
};
