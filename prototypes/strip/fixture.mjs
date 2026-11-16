// Writes the recording as SitRep's test fixture: node fixture.mjs recording.json
// A JSON file per scenario goes into app/Tests/SitRepPanelTests/Recorded/Strip, a frame to a line, and the
// declarations StripRecording.swift makes of them, each scenario's and the values beside them, replace its own, the
// rest of it kept. The frames are data, never Swift literals: as those they cost the compiler 20 GB and more.
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
if (!process.argv[2]) throw new Error('usage: node fixture.mjs recording.json');
const r = JSON.parse(fs.readFileSync(process.argv[2], 'utf8'));
const tests = fileURLToPath(new URL('../../app/Tests/SitRepPanelTests/', import.meta.url));
const folder = path.join(tests, 'Recorded/Strip');
const swift = path.join(tests, 'StripRecording.swift');
fs.mkdirSync(folder, { recursive: true });

// The marks each scenario checks, beyond the tabs, the hairline, the ends and the counts.
const MARKS = {
  hover: [], fit: [], arrive: ['s4', 's5', 's9'], answer: ['s1', 's2', 's5', 's8'], jump: ['s6'], tabJump: [],
  many: ['s6', 's8', 's20'], last: ['s4', 's8', 's9', 's16'], bottom: ['s6', 's9'],
  grows: ['s4', 's5', 's7', 's8', 's9'], maxSix: ['s3', 's4', 's5', 's9', 's10', 's13'], lands: ['s4', 's9', 's13', 's14'],
  countTab: ['s4', 's9'], answerOut: ['s4', 's5', 's9', 's10'], empty: ['s1', 's8', 's9'], drag: ['s1', 's5', 's8'],
  stops: ['s5', 's6', 's7', 's8'], stopsLand: ['s4', 's7', 's8', 's9'], displace: ['s4', 's5', 's9', 's10'],
  fold: ['s1', 's6', 's7', 's8'], unfold: ['s7', 's8'], snoozed: ['s8', 's9', 's10', 's11'], snoozedTab: ['s9', 's11'],
  manyAll: ['s6', 's8', 's9', 's10', 's11', 's12'], foldedArrive: ['s4', 's9'],
};
const KEY = { more: 'more', moreN: 'moreNeeds', moreS: 'moreSnoozed', none: 'empty' };
const num = (n) => String(+n.toFixed(6));
const str = (s) => JSON.stringify(KEY[s] ?? s);
const list = (xs) => `[${xs.join(', ')}]`;
const object = (fields) => `{${fields.map(([k, v]) => `"${k}": ${v}`).join(', ')}}`;
const words = (l) => list([str(l.key), num(l.a)]);
const end = (e) => list([...e.slice(0, 4).map(num), e[4] ? '"s"' : '"edge"']);
const tab = (t) => object([
  ['key', str(t.key)], ['phase', `"${t.phase}"`], ['w', num(t.w)], ['h', num(t.h)], ['y', num(t.y)],
  ['press', num(t.press)], ['alpha', num(t.alpha)], ['words', list(t.layers.map(words))],
  ...(t.fit ? [['top', end(t.fit.top)], ['bottom', end(t.fit.bot)]] : []),
]);
const mark = (m) => (m ? list([num(m.y), num(m.sc), num(m.op)]) : 'null');
// how many it holds: past its room "+3", folded "3"
const count = (c) => list([c.n.replace(/^\+/, ''), num(c.y), num(c.sc), num(c.op)]);

// A frame's fields after its time.
function fields(f, ids) {
  const out = [['p', f.p ? list(f.p.map(num)) : 'null'], ['hair', list([num(f.hair[0]), '1', num(f.hair[1])])]];
  // the hairline over Snoozed, once it has shown
  if (f.hairS && f.hairS[0] !== 0) out.push(['snoozedHair', list([num(f.hairS[0]), '1', num(f.hairS[1])])]);
  out.push(['ends', list(f.ends.map(num))]);
  if (f.jumping) out.push(['jumping', JSON.stringify(f.jumping)]);
  if (f.tabs.length) out.push(['tabs', list(f.tabs.map(tab))]);
  if (ids.length) out.push(['marks', list(ids.map((id) => mark(f.marks.find((m) => m.id === id))))]);
  if (f.more) out.push(['more', count(f.more)]);
  if (f.moreN) out.push(['moreNeeds', count(f.moreN)]);
  if (f.moreS) out.push(['moreSnoozed', count(f.moreS)]);
  return out;
}

const out = [];
for (const [name, v] of Object.entries(r)) {
  const ids = MARKS[name];
  const seed = v.seed ? `At ${Object.entries(v.seed).map(([k, x]) => `${k} ${x}`).join(', ')}. ` : "At Lee's settings. ";
  out.push(`    /// ${seed}${ids.length ? `Its marks: ${ids.join(', ')}.` : 'No marks move.'}`);
  out.push(`    static let ${name} = recorded("${name}")`);
  out.push('');
  // the tail where nothing changes any more is left off, but for a frame of it
  const body = v.frames.map((f) => object(fields(f, ids)));
  let last = body.length - 1;
  while (last > 0 && body[last] === body[last - 1]) last--;
  const frames = v.frames.slice(0, last + 2).map((f) => `  ${object([['t', num(f.t)], ...fields(f, ids)])}`);
  fs.writeFileSync(path.join(folder, `${name}.json`), `[\n${frames.join(',\n')}\n]\n`);
}
const many = r.many.frames.at(-1);
const names = (ids) => list(ids.map((id) => `"${id}"`));
out.push(`    /// Too many, settled: the order the marks end in.`);
out.push(`    static let manyOrder: [String] = ${names(many.display)}`);
out.push(`
    /// When the new mark arrived, growing into its place, since the ask.
    static let arrived: Double = ${num(r.arrive.frames.find((f) => f.marks.find((m) => m.id === 's9' && m.arrived != null)).marks.find((m) => m.id === 's9').arrived)}`);
const landed = r.lands.frames.map((f) => f.moreN && f.moreN.arrived).filter((a) => a != null && a > 0)[0];
out.push(`
    /// When the ask landed in needs you's count, which flashed, since the first five asks.
    static let landed: Double = ${num(landed)}`);
const foldedLanded = r.foldedArrive.frames.map((f) => f.moreN && f.moreN.arrived).filter((a) => a != null && a > 0)[0];
out.push(`
    /// When the ask landed in needs you's count, folded, which flashed, since needs you folded.
    static let foldedLanded: Double = ${num(foldedLanded)}`);
out.push(`
    /// Max 10, all three sections, working folded at the end: what each count holds.
    static let manyAllFolded: (working: [String], snoozed: [String]) = (
        working: ${names(r.manyAll.frames.at(-1).rest)}, snoozed: ${names(r.manyAll.frames.at(-1).restS)}
    )`);
out.push(`
    /// Max 6, the five asks in and a settle after: those folded into needs you's count, the asks in the panel's
    /// order, the away one last, and the stopped after them, and the rest into the grey one.
    static let maxSixFolded: (asks: [String], rest: [String]) = (
        asks: ${names(r.maxSix.frames.at(-1).restN)}, rest: ${names(r.maxSix.frames.at(-1).rest)}
    )`);
const W = {};
for (const v of Object.values(r)) for (const f of v.frames) for (const t of f.tabs) for (const l of t.layers) W[l.sig] = l.W;
out.push(`
    /// Each tab's width as the browser measured its words, by their lines.
    static let widths: [String: Double] = [
${Object.entries(W).map(([k, w]) => `        ${JSON.stringify(k)}: ${w},`).join('\n')}
    ]`);

// The declarations run from the extension's opening to the loader's own comment, which is written by hand.
const opens = 'extension StripRecorded {\n', loader = "\n    /// The strip prototype at Lee's settings, recorded";
const was = fs.readFileSync(swift, 'utf8'), from = was.indexOf(opens), to = was.indexOf(loader);
if (from < 0 || to < from) throw new Error(`${swift} has no declarations between "${opens.trim()}" and its loader`);
fs.writeFileSync(swift, `${was.slice(0, from + opens.length)}${out.join('\n')}\n${was.slice(to)}`);
