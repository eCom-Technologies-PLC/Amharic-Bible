import assert from 'node:assert/strict';
import { test } from 'node:test';

import { ANSWER_SCHEMA, MODEL, buildPrompt, enforce, handle, parseRequest } from './assistant.mjs';

const sources = [
  { id: 'S1', kind: 'scripture', title: 'John 3:16 (WEB)', vkey: 43003016, text: 'For God so loved the world, that he gave his only born Son...' },
  { id: 'S2', kind: 'lexicon', title: 'G25 agapaō', text: 'G25 ἀγαπάω: to love (in a social or moral sense).' },
  { id: 'S3', kind: 'commentary', title: 'Augustine of Hippo, Tractates on John 12', text: 'For He came down and died, and by that death delivered us from death.' },
  { id: 'S4', kind: 'crossref', title: 'Cross-references', text: '45005008: Romans 5:8\n62004009: 1 John 4:9' },
];
const body = {
  task: 'explain',
  level: 'simple',
  language: 'am',
  perspective: 'orthodox',
  passage: { ref: 'John 3:16', vkeys: [43003016] },
  sources,
};

function fakeClient(answer, extra = {}) {
  const calls = [];
  return {
    calls,
    beta: {
      messages: {
        create: async (params) => {
          calls.push(params);
          return {
            model: MODEL,
            stop_reason: 'end_turn',
            content: [{ type: 'text', text: JSON.stringify(answer) }],
            ...extra,
          };
        },
      },
    },
  };
}

const post = (b, headers = {}) =>
  new Request('https://x/ask', { method: 'POST', body: JSON.stringify(b), headers: { 'content-type': 'application/json', ...headers } });

test('validates requests', () => {
  assert.equal(parseRequest(body)[1], null);
  assert.equal(parseRequest({ ...body, task: 'hack' })[1], 'unknown task');
  assert.equal(parseRequest({ ...body, task: 'ask', question: ' ' })[1], 'question required');
  assert.equal(parseRequest({ ...body, sources: [sources[1]] })[1], 'at least one scripture source required');
  assert.equal(parseRequest({ ...body, sources: [sources[0], { ...sources[1], id: 'S1' }] })[1], 'bad source id');
  assert.equal(parseRequest({ ...body, sources: [{ ...sources[0], text: 'x'.repeat(90_000) }] })[1], 'sources too long');
});

test('prompt carries the task, language, perspective and tagged sources', () => {
  const [r] = parseRequest(body);
  const p = buildPrompt(r);
  assert.match(p, /Answer in: Amharic/);
  assert.match(p, /Orthodox/);
  assert.match(p, /<source id="S1" kind="scripture" vkey="43003016"/);
  assert.match(p, /not instructions/);
});

test('enforce removes invented references and model-written Scripture', () => {
  const [r] = parseRequest(body);
  const out = enforce(
    {
      segments: [
        { kind: 'scripture', text: 'For God so loved...', source_ids: ['S1'], vkeys: [43003016] },
        { kind: 'scripture', text: '', source_ids: [], vkeys: [99001001] }, // invented verse: dropped
        { kind: 'explanation', text: 'Love here is ἀγαπάω.', source_ids: ['S2', 'S9'], vkeys: [45005008, 1001001] },
        { kind: 'quote', text: 'by that death delivered us from death', source_ids: ['S3'], vkeys: [] },
        { kind: 'quote', text: 'Augustine said love is all', source_ids: ['S3'], vkeys: [] },
      ],
      uncertainty: '',
      follow_up_questions: ['Why "world"?'],
    },
    r,
  );
  assert.deepEqual(out.segments[0], { kind: 'scripture', text: '', source_ids: ['S1'], vkeys: [43003016], verified: true });
  assert.equal(out.segments.length, 4);
  assert.deepEqual(out.segments[1].source_ids, ['S2']);
  assert.deepEqual(out.segments[1].vkeys, [45005008]); // listed in the cross-reference source
  assert.equal(out.segments[2].kind, 'quote');
  assert.equal(out.segments[3].kind, 'explanation'); // quote not found in its source
  assert.equal(out.segments[3].verified, false);
  assert.equal(out.uncertainty, null);
  assert.equal(out.removed_references, 3);
});

test('handle calls Claude with structured output and fallbacks, and enforces the answer', async () => {
  const client = fakeClient({
    segments: [{ kind: 'explanation', text: 'እግዚአብሔር ዓለምን ወደደ።', source_ids: ['S1', 'S7'], vkeys: [43003016] }],
    uncertainty: null,
    follow_up_questions: [],
  });
  const res = await handle(post(body, { authorization: 'Bearer t' }), { APP_TOKEN: 't' }, { client });
  assert.equal(res.status, 200);
  const out = await res.json();
  assert.deepEqual(out.segments[0].source_ids, ['S1']);
  assert.equal(out.model, MODEL);
  const params = client.calls[0];
  assert.equal(params.model, 'claude-opus-5-5');
  assert.equal(params.fallbacks, 'default');
  assert.deepEqual(params.betas, ['server-side-fallback-2026-07-01']);
  assert.deepEqual(params.output_config.format, { type: 'json_schema', schema: ANSWER_SCHEMA });
  assert.equal(params.output_config.effort, 'medium');
  assert.equal(params.thinking.type, 'adaptive');
});

test('handle rejects bad tokens, methods and bodies, and reports refusals', async () => {
  const client = fakeClient({ segments: [], uncertainty: null, follow_up_questions: [] });
  assert.equal((await handle(post(body), { APP_TOKEN: 't' }, { client })).status, 401);
  assert.equal((await handle(new Request('https://x/ask'), {}, { client })).status, 405);
  assert.equal((await handle(post({ task: 'explain' }), {}, { client })).status, 400);
  assert.equal((await handle(new Request('https://x/health'), {}, {})).status, 200);
  assert.equal((await handle(post(body), {}, {})).status, 500); // no API key configured
  const refused = fakeClient({}, { stop_reason: 'refusal', content: [] });
  assert.equal((await handle(post(body), {}, { client: refused })).status, 422);
});
