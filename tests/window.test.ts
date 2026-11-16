import { expect, test, tier } from './kit'
import {
  attach,
  HEARTBEAT_MS,
  metaText,
  parseEntries,
  parsePresence,
  presenceText,
  sessionPaths,
  STALE_MS,
  type SessionPaths,
} from '../core'
import { boardOf, sessionOf } from '../hooks/board'
import { TTY_WALK } from '../hooks/where'
import { WATCH_MS } from '../hooks/window'
import type { SitrepAttachment } from '../types'
import {
  HELP_DESK,
  META,
  PLUGIN_VERSION,
  PROJECT,
  REPO,
  reviewRound,
  ROOT,
  SENDER,
  T0,
  W1,
  W2,
} from './data'
import { choiceAsk, file, fold, note, reply, status, yesAsk } from './lines'
import {
  asked,
  CONVERSATION,
  manifestOf,
  postedId,
  startedId,
  TTY,
  WHERE,
  world,
  type Walk,
  type World,
} from './world'

tier('user')

/** The tmux server's socket, as `$TMUX` starts. */
const SOCKET = '/private/tmp/tmux-501/default'

/** A /clear: the conversation ends, and the window goes on under another of Claude Code's session ids. */
const CLEARED = { reason: 'clear' as const, sessionId: W1, resume: { id: W1 } }

test('a session started in one window and joined by a second writer is one session to both', async ($, on) => {
  const w = world($, on)
  const { id, paths } = await w.begin()
  const posted = await asked(w, reviewRound(1))

  await $.session.end(CLEARED)
  w.become({ conversation: W2 })
  await w.clock.advance(60_000)

  const joined = String((await w.call('join', { session: id })).result)
  const noted = postedId(await w.call('note', { text: 'Drew round 2' }))

  expect(joined).toContain(`- ${posted} wants a yes (Approve), waiting on Lee: Review round 1`)
  expect(parseEntries(w.text(paths.log(W1))).map(line => line.type)).toEqual(['ask'])
  expect(parseEntries(w.text(paths.log(W2))).map(line => line.type)).toEqual(['note'])
  expect(w.state.board?.asks.map(item => item.id)).toEqual([posted])
  expect(w.state.board?.log.map(line => line.id)).toEqual([noted])
  expect(parsePresence(w.text(paths.heartbeat(W1)), W1)?.leftAt).toBe(T0)
  expect(parsePresence(w.text(paths.heartbeat(W2)), W2)?.leftAt).toBeUndefined()
  expect(w.state.board?.isOpen).toBe(true)
})

test('a window joining a session it wrote to before counts on from where its file left off', async ($, on) => {
  const w = world($, on)
  const { id, paths } = await w.begin()

  await w.call('note', { text: 'Drew round 1' })
  await w.call('note', { text: 'Drew round 2' })
  await w.call('start', { ...HELP_DESK, name: 'Lobby' })
  await w.call('join', { session: id })
  await w.call('note', { text: 'Drew round 3' })

  expect(
    parseEntries(w.text(paths.log(W1))).map(line => [line.seq, line.type === 'note' && line.text]),
  ).toEqual([
    [1, 'Drew round 1'],
    [2, 'Drew round 2'],
    [3, 'Drew round 3'],
  ])
})

test('after a reload, the window takes up the session $.state names, reads its file back and counts on', async ($, on) => {
  const w = world($, on, { now: T0 + 60_000 })
  const paths = sessionPaths(ROOT, PROJECT.key, META.id)
  const kept: SitrepAttachment = {
    project: PROJECT.key,
    session: META.id,
    writer: W1,
    attachedAt: T0,
  }
  const before = file(
    [T0, status(['Drawing round 1'])],
    [T0, yesAsk('k1', 'Review round 1')],
    [T0, note('n1', 'Drew round 1')],
  )
  let isReloaded = false

  // What a reload finds: nothing in the module, the attachment still in $.state.
  on('state.get', { plugin: 'sitrep', key: 'attachment' }, ($, e, next) => {
    if (isReloaded) {
      return next(e)
    }

    isReloaded = true

    return { value: { value: kept, version: 1 } }
  })

  w.put(paths.meta, metaText(META))
  w.put(paths.log(W1), before)
  await $.session.start(CONVERSATION)
  await w.call('note', { text: 'Drew round 2' })

  const lines = parseEntries(w.text(paths.log(W1)))

  expect(w.text(paths.log(W1)).startsWith(before)).toBe(true)
  expect(lines.map(line => line.seq)).toEqual([1, 2, 3, 4])
  expect(parsePresence(w.text(paths.heartbeat(W1)), W1)).toEqual({
    writer: W1,
    attachedAt: T0,
    seenAt: T0 + 60_000,
    where: WHERE,
    directory: REPO,
    version: PLUGIN_VERSION,
    state: { is: 'yourTurn', since: T0 },
    loadedAt: T0 + 60_000,
  })
  expect(w.state.board?.asks.map(item => item.id)).toEqual(['k1'])
})

test('a hold another conversation left in $.state is dropped, not taken up', async ($, on) => {
  const w = world($, on)
  const paths = sessionPaths(ROOT, PROJECT.key, META.id)
  let isReloaded = false

  on('state.get', { plugin: 'sitrep', key: 'attachment' }, ($, e, next) => {
    if (isReloaded) {
      return next(e)
    }

    isReloaded = true

    return {
      value: {
        value: { project: PROJECT.key, session: META.id, writer: W2, attachedAt: T0 },
        version: 1,
      },
    }
  })

  w.put(paths.meta, metaText(META))
  await $.session.start(CONVERSATION)

  expect(w.files.has(paths.heartbeat(W1))).toBe(false)
  expect(w.files.has(paths.heartbeat(W2))).toBe(false)
  expect(w.state.attachment).toBeNull()
})

test('the heartbeat is rewritten every 30 seconds while attached, and says when the window let go', async ($, on) => {
  const w = world($, on)
  const { paths } = await w.begin()
  const beat = () => parsePresence(w.text(paths.heartbeat(W1)), W1)
  const seenAt = (at: number) => ({
    writer: W1,
    attachedAt: T0,
    seenAt: at,
    where: WHERE,
    directory: REPO,
    version: PLUGIN_VERSION,
    state: { is: 'yourTurn', since: T0 },
    loadedAt: T0,
  })

  expect(beat()).toEqual(seenAt(T0))

  await w.clock.advance(HEARTBEAT_MS)

  expect(beat()).toEqual(seenAt(T0 + HEARTBEAT_MS))

  await w.clock.advance(10_000)
  await $.session.end(CLEARED)

  expect(beat()?.leftAt).toBe(T0 + HEARTBEAT_MS + 10_000)

  await w.clock.advance(3 * HEARTBEAT_MS)

  expect(beat()?.seenAt).toBe(T0 + HEARTBEAT_MS)
})

for (const [reason, livesOn] of [
  ['clear', true],
  ['resume', true],
  ['prompt_input_exit', undefined],
  ['logout', undefined],
  ['other', undefined],
] as const) {
  test(`a window letting go as its conversation ends by ${reason} says ${livesOn ? 'that its Claude lives on into the next' : 'nothing of its Claude living on'}`, async ($, on) => {
    const w = world($, on)
    const { paths } = await w.begin()

    await $.session.end({ reason, sessionId: W1, resume: { id: W1 } })

    expect(parsePresence(w.text(paths.heartbeat(W1)), W1)?.livesOn).toBe(livesOn)
  })
}

test('attaching in tmux records the device, the terminal and the pane in the heartbeat, and every later beat keeps them', async ($, on) => {
  const w = world($, on, {
    env: { TMUX: `${SOCKET},4242,0`, TMUX_PANE: '%12', TERM_PROGRAM: 'tmux' },
  })
  const { paths } = await w.begin()
  const where = () => parsePresence(w.text(paths.heartbeat(W1)), W1)?.where
  const inTmux = { device: `/dev/${TTY}`, terminal: 'tmux', tmux: { socket: SOCKET, pane: '%12' } }

  expect(where()).toEqual(inTmux)

  await w.clock.advance(HEARTBEAT_MS)

  expect(where()).toEqual(inTmux)

  await $.session.end(CLEARED)

  expect(where()).toEqual(inTmux)
  expect(w.runs, 'the walk ran once, as the window attached').toEqual([['/bin/sh', '-c', TTY_WALK]])
})

test('attaching in zmx records the device, the terminal and the zmx session in the heartbeat', async ($, on) => {
  const w = world($, on, {
    env: { ZMX_SESSION: 'litware · invoice-card', TERM_PROGRAM: 'ghostty' },
  })
  const { paths } = await w.begin()

  expect(parsePresence(w.text(paths.heartbeat(W1)), W1)?.where).toEqual({
    device: `/dev/${TTY}`,
    terminal: 'ghostty',
    zmx: { session: 'litware · invoice-card' },
  })
})

test("the heartbeat says the folder its Claude runs in: a shell's cd moves it not, entering a worktree moves it at the next beat", async ($, on) => {
  const w = world($, on)
  const { paths } = await w.begin()
  const directory = () => parsePresence(w.text(paths.heartbeat(W1)), W1)?.directory
  const worktree = `${REPO}/.claude/worktrees/lobby`

  expect(directory()).toBe(REPO)

  w.become({ cwd: `${REPO}/hooks` })
  await w.clock.advance(HEARTBEAT_MS)

  expect(directory()).toBe(REPO)

  w.become({ root: worktree })
  await w.clock.advance(HEARTBEAT_MS)

  expect(directory()).toBe(worktree)
})

test("a folder that does not read leaves the heartbeat's last, says so in the debug log, and the window beats all the same", async ($, on) => {
  const w = world($, on)
  const { paths } = await w.begin()
  const beat = () => parsePresence(w.text(paths.heartbeat(W1)), W1)

  w.become({ root: null })
  await w.clock.advance(HEARTBEAT_MS)

  expect(beat()?.seenAt).toBe(w.clock.now())
  expect(beat()?.directory).toBe(REPO)
  expect(w.logs).toEqual([expect.stringContaining("sitrep: reading the window's folder failed")])
})

test("a reload's attach whose folder does not read keeps the folder the window's heartbeat said", async ($, on) => {
  const w = world($, on, { now: T0 + 60_000 })
  const paths = sessionPaths(ROOT, PROJECT.key, META.id)
  const worktree = `${REPO}/.claude/worktrees/lobby`
  let isReloaded = false

  on('state.get', { plugin: 'sitrep', key: 'attachment' }, ($, e, next) => {
    if (isReloaded) {
      return next(e)
    }

    isReloaded = true

    return {
      value: {
        value: { project: PROJECT.key, session: META.id, writer: W1, attachedAt: T0 },
        version: 1,
      },
    }
  })

  w.put(paths.meta, metaText(META))
  w.put(paths.heartbeat(W1), presenceText(attach(W1, T0, { directory: worktree })))
  w.become({ root: null })
  await $.session.start(CONVERSATION)

  expect(parsePresence(w.text(paths.heartbeat(W1)), W1)?.directory).toBe(worktree)
  expect(w.logs).toEqual([expect.stringContaining("sitrep: reading the window's folder failed")])
})

test("every heartbeat says the version the plugin's manifest gave as the mod loaded, though the manifest changes after", async ($, on) => {
  const w = world($, on)

  w.manifestGives(manifestOf('0.4.2'))

  const { paths } = await w.begin()
  const version = (at: SessionPaths) => parsePresence(w.text(at.heartbeat(W1)), W1)?.version

  w.manifestGives(manifestOf('0.5.0'))
  await w.clock.advance(HEARTBEAT_MS)

  const later = startedId(await w.call('start', { ...HELP_DESK, name: 'Lobby' }))

  expect(version(paths)).toBe('0.4.2')
  expect(version(sessionPaths(ROOT, PROJECT.key, later))).toBe('0.4.2')
  expect(w.logs).toEqual([])
})

for (const [why, manifest] of [
  ['cannot be read', undefined],
  ['is torn', '{"name":"sitrep","vers'],
  ['gives no version', manifestOf(undefined)],
  ['gives a version that is not text', manifestOf(1)],
] as const) {
  test(`a manifest that ${why} leaves the version out, says so in the debug log, and the window beats all the same`, async ($, on) => {
    const w = world($, on)

    w.manifestGives(manifest)

    const { paths } = await w.begin()
    const beat = () => parsePresence(w.text(paths.heartbeat(W1)), W1)

    expect(beat()?.version).toBeUndefined()
    expect(JSON.parse(w.text(paths.heartbeat(W1)))).not.toHaveProperty('version')
    expect(w.logs).toEqual([expect.stringContaining("sitrep: reading the plugin's version failed")])

    w.manifestGives(manifestOf(PLUGIN_VERSION))
    await w.clock.advance(HEARTBEAT_MS)

    expect(beat()?.seenAt).toBe(w.clock.now())
    expect(beat()?.version, 'not read again, though it reads by now').toBeUndefined()
    expect(w.logs, 'read once a load').toHaveLength(1)
  })
}

test("another window's heartbeat saying no version, as one whose manifest gave none writes it, reads as ever, and delivers by when it attached", async ($, on) => {
  const w = world($, on)
  const { id } = await w.begin()

  w.beat(id, { writer: W2, attachedAt: w.clock.now(), seenAt: w.clock.now() })
  await w.clock.advance(WATCH_MS)

  expect(w.state.board?.presence.map(each => [each.writer, each.version])).toEqual([
    [W1, PLUGIN_VERSION],
    [W2, undefined],
  ])
  expect(w.state.board?.deliverer).toBe(W1)
})

test("another window on the session going stale between this window's beats shows on the board within a look of it, though no file changed", async ($, on) => {
  const w = world($, on)
  const { id, paths } = await w.begin()
  const seenAt = T0 + 1_000
  const beat = () => parsePresence(w.text(paths.heartbeat(W1)), W1)?.seenAt

  // Attached before this window, it delivers for the session while it is live.
  w.beat(id, { writer: W2, attachedAt: T0 - HEARTBEAT_MS, seenAt })
  await w.clock.set(seenAt + STALE_MS)

  expect(w.state.board?.deliverer, 'live').toBe(W2)
  expect(beat(), "this window's last beat, before it goes stale").toBe(T0 + 3 * HEARTBEAT_MS)

  await w.clock.advance(WATCH_MS)

  expect(w.state.board?.deliverer, 'stale').toBe(W1)
  expect(beat(), 'no beat of its own since').toBe(T0 + 3 * HEARTBEAT_MS)
})

test('outside tmux, the heartbeat holds the device and the terminal, and no tmux', async ($, on) => {
  const w = world($, on)
  const { paths } = await w.begin()
  const presence = JSON.parse(w.text(paths.heartbeat(W1)))

  expect(presence.where).toEqual({ device: `/dev/${TTY}`, terminal: 'ghostty' })
  expect(presence.where).not.toHaveProperty('tmux')
})

test('a walk that finds no device leaves it out, says so in the debug log, and the window attaches and beats all the same', async ($, on) => {
  const w = world($, on)
  const walks: Walk[] = [
    { refused: 'timed out after 2000 ms' },
    { stdout: '', exitCode: 1 },
    { stdout: '??\n' },
    { stdout: '' },
  ]

  await $.session.start(CONVERSATION)

  for (const walk of walks) {
    w.walkGives(walk)

    const id = startedId(await w.call('start', HELP_DESK))
    const paths = sessionPaths(ROOT, PROJECT.key, id)
    const beat = () => parsePresence(w.text(paths.heartbeat(W1)), W1)

    expect(w.state.attachment?.session, JSON.stringify(walk)).toBe(id)
    expect(beat()?.where, JSON.stringify(walk)).toEqual({ terminal: 'ghostty' })
    expect(w.logs.at(-1), JSON.stringify(walk)).toContain(
      'sitrep: finding the terminal device failed',
    )

    await w.clock.advance(HEARTBEAT_MS)

    expect(beat()?.seenAt, JSON.stringify(walk)).toBe(w.clock.now())
  }

  expect(w.logs).toHaveLength(walks.length)
})

/** The window starts a session of its own and attaches to it: the session's heartbeat as it reads, a reader called later. */
const startAnother = async (w: World, name: string) => {
  const id = startedId(await w.call('start', { ...HELP_DESK, name }))
  const heartbeat = sessionPaths(ROOT, PROJECT.key, id).heartbeat(W1)

  return { id, beat: () => parsePresence(w.text(heartbeat), W1) }
}

test('the walk runs once a load: later attaches take where the first found, and their heartbeats carry it', async ($, on) => {
  const w = world($, on)

  await $.session.start(CONVERSATION)

  const first = await startAnother(w, 'Lobby')
  const second = await startAnother(w, 'Invoice ledger')

  await w.call('join', { session: first.id })
  await w.clock.advance(HEARTBEAT_MS)

  expect(w.runs).toHaveLength(1)
  expect(first.beat()?.where).toEqual(WHERE)
  expect(second.beat()?.where).toEqual(WHERE)
  expect(first.beat()?.seenAt).toBe(w.clock.now())
})

test('a walk that found no device is tried again at the next attach, until one finds it', async ($, on) => {
  const w = world($, on)

  await $.session.start(CONVERSATION)
  w.walkGives({ refused: 'timed out after 2000 ms' })

  const failed = await startAnother(w, 'Lobby')

  w.walkGives({ stdout: `${TTY}\n` })

  const found = await startAnother(w, 'Invoice ledger')
  const after = await startAnother(w, 'Release notes')

  expect(failed.beat()?.where).toEqual({ terminal: 'ghostty' })
  expect(found.beat()?.where).toEqual(WHERE)
  expect(after.beat()?.where).toEqual(WHERE)
  expect(w.runs, 'the third attach walked no more').toHaveLength(2)
})

test('the watch folds a line another writer added, and puts the board in $.state only when it changed', async ($, on) => {
  const w = world($, on)
  const { paths } = await w.begin()
  const written = w.writes.board ?? 0

  await w.clock.advance(4 * WATCH_MS)

  expect(w.writes.board ?? 0, 'nothing changed, so nothing is put').toBe(written)

  w.put(paths.log(W2), file([w.clock.now(), yesAsk('k9', 'Try it on the iPad', 'It works')]))
  await w.clock.advance(WATCH_MS)

  expect(w.writes.board ?? 0).toBe(written + 1)
  expect(w.state.board?.asks.map(item => [item.id, item.by])).toEqual([['k9', W2]])

  await w.clock.advance(4 * WATCH_MS)

  expect(w.writes.board ?? 0).toBe(written + 1)
  expect(w.logs, 'no look failed').toEqual([])
})

test("another window's state changing puts nothing in $.state, so no pane redraws", async ($, on) => {
  const w = world($, on)
  const { id } = await w.begin()
  const peer = { writer: W2, attachedAt: w.clock.now(), seenAt: w.clock.now() }

  w.beat(id, { ...peer, state: { is: 'yourTurn', since: w.clock.now() } })
  await w.clock.advance(WATCH_MS)
  const writes = { ...w.writes }
  const written = w.writes.board ?? 0

  for (const tool of ['Read', 'Edit', 'Bash']) {
    w.beat(id, { ...peer, state: { is: 'working', since: w.clock.now(), tool: { name: tool } } })
    await w.clock.advance(WATCH_MS)
  }

  expect(w.writes.board ?? 0, 'the board unwritten').toBe(written)
  expect(w.writes, 'nothing a pane draws from written').toEqual(writes)
  expect(w.state.board?.presence.map(each => each.writer)).toEqual([W1, W2])
  expect(w.state.board?.presence.some(each => 'state' in each)).toBe(false)
})

test("the watch reads another window's heartbeat and the letters in the inbox too", async ($, on) => {
  const w = world($, on)
  const { id, paths } = await w.begin()
  const posted = await asked(w, reviewRound(1))

  await w.clock.advance(WATCH_MS)
  w.beat(id, { writer: W2, attachedAt: w.clock.now(), seenAt: w.clock.now() })
  w.put(paths.letters(SENDER), file([w.clock.now(), reply('r1', posted, 'yes')]))
  await w.clock.advance(WATCH_MS)

  expect(w.state.board?.presence.map(each => each.writer)).toEqual([W1, W2])
  expect(w.state.board?.replies).toMatchObject([{ id: 'r1', item: posted, by: SENDER }])
})

test('a conversation that ends lets go: the board and the attachment leave $.state', async ($, on) => {
  const w = world($, on)

  await w.begin()
  await $.session.end(CLEARED)

  expect(w.state.board).toBeNull()
  expect(w.state.attachment).toBeNull()
  expect((await w.call('board')).deny).toContain('No session is attached')
})

test('the board in $.state is plain data, and rebuilds into the session core folds', () => {
  const session = fold({
    logs: {
      [W1]: file(
        [T0, choiceAsk('k1', 'Keep it?', ['Keep it', 'Drop it'])],
        [T0, note('n1', 'Drew round 1')],
      ),
    },
  })
  const kept = JSON.parse(JSON.stringify(boardOf(session)))

  expect(kept).toEqual(boardOf(session))
  expect(sessionOf(kept)).toEqual(session)
  expect(sessionOf(kept).items.get('k1')?.type).toBe('ask')
})
