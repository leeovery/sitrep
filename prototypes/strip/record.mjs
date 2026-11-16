// Records strip.html every animation frame through scripted scenarios, each on a fresh page, its store seeded with the
// scenario's settings (Lee's defaults where it has none). The clock is Playwright's fake one, run 16ms a frame, so every
// frame's step is exactly 16ms, as the model's are.
// bun record.mjs > recording.json: every scenario, as fixture.mjs needs them; bun record.mjs <scenario>... records only
// those named, to look at, which fixture.mjs refuses
import { chromium } from 'playwright-core';
const PAGE = new URL('strip.html', import.meta.url).href;
const browser = await chromium.launch({ headless: true });

// Each scenario: steps, each { at: ms since the start, ... } run between frames once t >= at, and how long.
//   { pointer: 'Wi' | 0 | 'last' | 'more' | 'moreN' | 'moreS' | 'lip' | null, x?, dy? } puts the pointer on a mark (x 18
//     into the strip, or x; dy further along it, past its centre), by its letters, its place, the last placed, a count
//     or the notch at rest, or off the page;
//   { call: name, arg? } runs one of __strip's own with arg, 'restN0' the first ask folded into needs you's count;
//   { click: 'mark' | 'tab' } clicks the strip at the pointer, or the open tab;
//   { drag: 'down' | 'up' | dy } presses the strip at the pointer, moves it dy along the edge, or lets go.
// Full: the scenarios recorded before Length, at Full, as the strip then always was.
const FULL = { length: 'full' };
const SCENARIOS = {
  hover: { seed: FULL, ms: 2300, steps: [{ at: 0, pointer: 'Wi' }, { at: 700, pointer: 'Lu' }, { at: 1300, pointer: null }] },
  fit: { seed: FULL, ms: 1800, steps: [{ at: 0, pointer: 0 }, { at: 800, pointer: null }] },
  arrive: { seed: FULL, ms: 2200, steps: [{ at: 0, call: 'newAsk' }] },
  // an ask answered, Claude working again: Trey Research's leaves needs you for working at once, the marks between sliding
  // up (Lee, 14 November 2026; until then it changed in place and moved a settle later)
  answer: { seed: FULL, ms: 2000, steps: [{ at: 0, call: 'answer' }] },
  jump: { seed: FULL, ms: 1200, steps: [{ at: 0, pointer: 'Lu' }, { at: 50, click: 'mark' }, { at: 900, pointer: null }] },
  tabJump: { seed: FULL, ms: 1400, steps: [{ at: 0, pointer: 'BY' }, { at: 600, click: 'tab' }] },
  many: { seed: FULL, ms: 1800, steps: [{ at: 0, call: 'tooMany' }, { at: 900, pointer: 'more' }] },
  // eight new asks: sixteen marks, all that fit, the last on the last place
  last: { seed: FULL, ms: 3100, steps: [...Array(8)].map(() => ({ at: 0, call: 'newAsk' })).concat([{ at: 1600, pointer: 'last' }, { at: 2400, pointer: null }]) },
  bottom: { seed: FULL, ms: 3400, steps: [{ at: 0, call: 'tooMany' }, { at: 900, pointer: 'last' }, { at: 1700, pointer: 'more' }, { at: 2500, pointer: null }] },
  // Grows, Lee's default: two working sessions end and it shrinks, the ends following the marks in; a new ask, and it
  // grows, the ends leading them out
  grows: { ms: 2600, steps: [{ at: 0, call: 'remove' }, { at: 0, call: 'remove' }, { at: 1300, call: 'newAsk' }] },
  // Max 6, five new asks: nine asks and four others, the newest folding into needs you's orange count; a settle
  // after, the strip takes the panel's order, the oldest new ask showing where the away one did (Lee, 14 November 2026)
  maxSix: { seed: { max: 6 }, ms: 1800, steps: [...Array(5)].map(() => ({ at: 0, call: 'newAsk' })) },
  // ... and one more, landing in the count, which flashes, as the settle takes the panel's order
  lands: { seed: { max: 6 }, ms: 2800, steps: [...Array(5)].map(() => ({ at: 0, call: 'newAsk' })).concat([{ at: 1000, call: 'newAsk' }]) },
  // ... the orange count's tab, its rows the folded asks, an away one last
  countTab: { seed: { max: 6 }, ms: 2600, steps: [...Array(5)].map(() => ({ at: 0, call: 'newAsk' })).concat([{ at: 900, pointer: 'moreN' }, { at: 1800, pointer: null }]) },
  // Max 6, six asks: an answer to one in the count takes it out at once, into the grey count, though the pointer
  // rests on the orange one, whose tab takes its new rows (Lee, 14 November 2026; until then the row changed in place,
  // and moved a settle after the pointer left); a settle after the pointer leaves, the strip takes the panel's order
  answerOut: { seed: { max: 6 }, ms: 4000, steps: [{ at: 0, call: 'newAsk' }, { at: 0, call: 'newAsk' }, { at: 900, pointer: 'moreN' }, { at: 1700, call: 'answerOne', arg: 'restN0' }, { at: 2100, pointer: null }] },
  // nothing running: the strip draws back into the notch at rest; hovered, it says so; a new ask grows it back out
  empty: { ms: 4400, steps: [{ at: 0, call: 'none' }, { at: 1400, pointer: 'lip', x: 4 }, { at: 2400, pointer: null }, { at: 3000, call: 'newAsk' }] },
  // a turn ends: the longest running working session, BlueYonder's, stops and moves into needs you at once, before
  // the stopped, the marks below sliding down, the hairline with them (14 November 2026)
  stops: { ms: 2200, steps: [{ at: 0, call: 'turnEnds' }] },
  // Max 6, five new asks, then a turn ends: BlueYonder's lands in needs you's count, the marks showing staying where
  // they are, and the grey count, left one, goes as Proseware's comes out of it; a settle after each, the panel's order
  stopsLand: { seed: { max: 6 }, ms: 2600, steps: [...Array(5)].map(() => ({ at: 0, call: 'newAsk' })).concat([{ at: 1000, call: 'turnEnds' }]) },
  // Max 7, a turn ends, a new ask, another: BlueYonder's stop lands in needs you's new count beside Lucerne's; the
  // first ask takes its place and Wingtip's stopped mark, the last showing, goes into the count, the marks between
  // sliding down; the second, with no stopped mark showing, lands in the count (Lee, 14 November 2026); then the
  // count's tab pours what it holds, the ask landed there and the stopped, and draws back
  displace: { seed: { max: 7 }, ms: 4200, steps: [{ at: 0, call: 'turnEnds' }, { at: 900, call: 'newAsk' }, { at: 1800, call: 'newAsk' }, { at: 2400, pointer: 'moreN' }, { at: 3300, pointer: null }] },
  // a press on Wingtip's mark carried 100 down the edge, the strip and its marks following, then let go
  drag: { ms: 1600, steps: [{ at: 0, pointer: 'Wi' }, { at: 60, drag: 'down' }].concat([...Array(10)].map((_, i) => ({ at: 80 + 16 * i, drag: 10 }))).concat([{ at: 400, drag: 'up' }, { at: 1100, pointer: null }]) },
  // The sections (14 November 2026). Working folds into its grey count, the strip shrinking and the hairline going,
  // then needs you into its orange one, the two counts the strip's only marks
  fold: { ms: 2600, steps: [{ at: 0, call: 'fold', arg: 'rest' }, { at: 1200, call: 'fold', arg: 'needs' }] },
  // working folded: its count's tab pours its rows, and a click on the count unfolds it, the tab drawing back and the
  // marks sliding out of it, the strip growing; the mark the pointer is left on pours its own, the pointer 6 under the
  // count's centre, nearer the second mark than the first, never midway, where the browser's rounding would choose
  unfold: { ms: 3400, steps: [{ at: 0, call: 'fold', arg: 'rest' }, { at: 900, pointer: 'more', dy: 6 }, { at: 1600, click: 'mark' }, { at: 2600, pointer: null }] },
  // three sessions snoozed land in Snoozed's count, folded at first, under its own hairline; Snoozed unfolds, its
  // marks dimmed, and one pours its tab
  snoozed: { ms: 3600, steps: [{ at: 0, call: 'snooze' }, { at: 0, call: 'snooze' }, { at: 0, call: 'snooze' }, { at: 900, call: 'fold', arg: 'snoozed' }, { at: 1900, pointer: 'Co' }, { at: 2700, pointer: null }] },
  // Snoozed folded, its count's tab pours its rows
  snoozedTab: { ms: 2400, steps: [{ at: 0, call: 'snooze' }, { at: 0, call: 'snooze' }, { at: 0, call: 'snooze' }, { at: 700, pointer: 'moreS' }, { at: 1600, pointer: null }] },
  // Max 10, all three sections: needs you and working whole, Snoozed past its room in its count; a new ask takes a
  // place, and Snoozed's last mark goes into its count; working folds to its one place, and one comes back out
  manyAll: { seed: { max: 10 }, ms: 3400, steps: [{ at: 0, call: 'snooze' }, { at: 0, call: 'snooze' }, { at: 0, call: 'snooze' }, { at: 0, call: 'fold', arg: 'snoozed' }, { at: 900, call: 'newAsk' }, { at: 1900, call: 'fold', arg: 'rest' }] },
  // needs you folded: a new ask lands in its count, which flashes, washed
  foldedArrive: { ms: 2600, steps: [{ at: 0, call: 'fold', arg: 'needs' }, { at: 900, call: 'newAsk' }] },
};

async function record(name) {
  const sc = SCENARIOS[name];
  const page = await (await browser.newContext({ viewport: { width: 1280, height: 900 } })).newPage();
  page.on('pageerror', (e) => console.error('pageerror', e.message));
  if (sc.seed) await page.addInitScript((v) => localStorage.setItem('sitrep-strip-v2', v), JSON.stringify(sc.seed));
  await page.clock.install({ time: new Date('2026-10-18T17:00:00') });
  await page.clock.pauseAt(new Date('2026-10-18T17:00:01'));
  await page.goto(PAGE);
  await page.clock.runFor(1200);
  let done = false;
  const recorded = page.evaluate((sc) => new Promise((res) => {
    const st = window.__strip, { state, S } = st, frames = [], t0 = state.t;
    const scr = document.getElementById('screen').getBoundingClientRect();
    const keyY = (who) => (who === 'more' ? st.more().y : who === 'moreN' ? st.moreN().y : who === 'moreS' ? st.moreS().y
      : who === 'lip' ? st.layout().top + st.layout().len / 2 : who === 'last' ? st.keys().at(-1).y
      : typeof who === 'number' ? st.keys()[who].y : st.keys().find((k) => k.letters === who).y);
    const steps = sc.steps.slice();
    const r6 = (n) => Math.round(n * 1e6) / 1e6;
    const pointerEvent = (type) => {
      const p = state.pointer;
      document.dispatchEvent(new PointerEvent(type, { clientX: p.x, clientY: p.y, button: 0, pointerId: 1, pointerType: 'mouse', bubbles: true }));
    };
    const act = (e) => {
      const p = state.pointer;
      if ('pointer' in e) {
        if (e.pointer == null) p.inDoc = false;
        else Object.assign(p, { x: scr.left + (e.x ?? 18), y: scr.top + keyY(e.pointer) + (e.dy ?? 0), mouse: true, inDoc: true });
      } else if (e.call) st[e.call](e.arg === 'restN0' ? st.restN()[0] : e.arg);
      else if (e.click === 'mark') document.dispatchEvent(new MouseEvent('click', { clientX: p.x, clientY: p.y, bubbles: true }));
      else if (e.click === 'tab') st.liveTab().el.dispatchEvent(new MouseEvent('click', { bubbles: true }));
      else if (e.drag === 'down') pointerEvent('pointerdown');
      else if (e.drag === 'up') {
        pointerEvent('pointerup');
        document.dispatchEvent(new MouseEvent('click', { clientX: p.x, clientY: p.y, bubbles: true }));
      } else if (typeof e.drag === 'number') { p.y += e.drag; pointerEvent('pointermove'); }
    };
    const r4 = (e) => [r6(e.x), r6(e.y), r6(e.rho), r6(e.phi), e.onS];
    const fits = () => {
      const out = state.tabs.filter((t) => t.g && t.g.w > 0.01), F = st.fit().tabs;
      return (t) => { const f = F[out.indexOf(t)]; return f ? { top: r4(f.top), bot: r4(f.bot) } : null; };
    };
    // a layer's words, as the model measures them: each row's first and second lines
    const sig = (L) => [...L.el.querySelectorAll(L.el.classList.contains('rows') ? '.orow' : '.txt')]
      .map((r) => `${r.querySelector('.l1').textContent}|${r.querySelector('.l2').textContent}`).join('\n');
    const count = (c) => (c ? { n: c.lt.textContent, y: r6(c.y.x), sc: r6(c.sc.x), op: r6(c.op.x), arrived: c.arrived > -1e8 ? r6(c.arrived - t0) : null } : null);
    const snap = (fit = fits()) => ({
      t: r6(state.t - t0),
      p: state.sp ? [r6(state.sp.x), r6(state.sp.y)] : null,
      hair: [r6(S.hair.x), r6(S.hairOp.x)],
      hairS: [r6(S.hairS.x), r6(S.hairSOp.x)],
      ends: [r6(S.yt.x), r6(S.yb.x), r6(S.lip.x)],
      jumping: st.jumping(),
      hot: state.hot,
      tabs: state.tabs.map((t) => ({
        id: t.id, key: t.key, phase: t.phase,
        w: r6(t.w.x), h: r6(t.h.x), y: r6(t.y.x), press: r6(t.press.x), alpha: r6(t.alpha.x),
        fit: fit(t),
        g: t.g ? { w: r6(t.g.w), h: r6(t.g.h), cy: r6(t.g.cy), ft: r6(t.g.ft), fb: r6(t.g.fb), r: r6(t.g.r) } : null,
        layers: t.layers.map((L) => ({ key: L.key, sig: sig(L), W: L.W, Hb: L.Hb, out: L.out, a: +L.el.style.opacity, dy: L.el.style.translate || '' })),
      })),
      marks: [...state.marks.values()].map((m) => ({ id: m.id, y: r6(m.y.x), sc: r6(m.sc.x), op: r6(m.op.x), arrived: m.arrived > -1e8 ? r6(m.arrived - t0) : null })),
      more: count(state.more),
      moreN: count(state.moreN),
      moreS: count(state.moreS),
      display: state.display.slice(),
      restN: state.layout.restN.slice(),
      rest: state.layout.rest.slice(),
      restS: state.layout.restS.slice(),
    });
    const tick = () => {
      frames.push(snap());
      const e = state.t - t0;
      while (steps.length && e >= steps[0].at) act(steps.shift());
      if (e < sc.ms) requestAnimationFrame(tick); else res(frames);
    };
    // the first step goes in before the first recorded frame
    while (steps.length && steps[0].at <= 0) act(steps.shift());
    requestAnimationFrame(tick);
  }), sc).finally(() => { done = true; });
  while (!done) await page.clock.runFor(16);
  const out = await recorded;
  const H = await page.evaluate(() => window.__strip.state.H);
  const centre = await page.evaluate(() => window.__strip.state.centre);
  const sessions = await page.evaluate(() => window.__strip.state.sessions.map((s) => ({ id: s.id, project: s.project, kind: s.kind, away: !!s.away, since: s.since, seq: s.seq, title: s.title, wakes: s.wakes })));
  await page.close();
  return { H, centre, seed: sc.seed || null, sessions, frames: out };
}

const only = process.argv.slice(2);
const result = {};
for (const name of Object.keys(SCENARIOS)) if (!only.length || only.includes(name)) result[name] = await record(name);
console.log(JSON.stringify(result));
await browser.close();
