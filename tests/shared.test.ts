import { expect, test, tier } from 'claude-code/testing'
import { EXIT, WRITER } from '../cli/main'
import { WATCH_MS } from '../hooks/window'
import { W1 } from './support'
import { terminal } from './terminal'
import { PROMPT, world } from './world'

tier('user')

type World = ReturnType<typeof world>

/** A work the mod started, and the CLI run on the mod's own files, at the mod's own time. */
async function begun(w: World) {
  const { id, paths } = await w.begin()
  const t = terminal({ files: w.files, now: () => w.clock.now() })

  return { id, paths, cli: (...words: string[]) => t.run(...words, '--work', id) }
}

test("what the CLI posts, the mod's watch folds: its note in the log, its ask waiting and counted on the band", async ($, on) => {
  const w = world($, on)
  const { cli } = await begun(w)
  const noted = await cli('note', 'Round 3 drawn', '--detail', 'Frames 1–6')
  const asked = await cli(
    'ask',
    'Review round 3',
    '--wants',
    'yes',
    '--yes',
    'Approve',
    '--where',
    'In Paper: page "round 3"',
  )

  expect([noted.exit, asked.exit]).toEqual([EXIT.done, EXIT.done])

  await w.clock.advance(WATCH_MS)

  const board = w.state.board

  expect(board?.log.map(line => [line.kind, line.id, line.text, line.detail, line.by])).toEqual([
    ['note', noted.out.trim(), 'Round 3 drawn', ['Frames 1–6'], WRITER],
  ])
  expect(board?.asks.map(each => [each.id, each.title, each.state, each.by])).toEqual([
    [asked.out.trim(), 'Review round 3', 'waiting', WRITER],
  ])
  expect(board?.waiting).toBe(1)
  expect(
    w.toasts.some(toast => toast.includes('Review round 3')),
    'a toast names the ask',
  ).toBe(true)

  const band = await w.band()

  expect(await band.find({ key: 'band:for-you', text: '1 for you' })).toBeDefined()
  expect(w.logs, 'no look failed').toEqual([])
})

test("the CLI's posts ride into Claude's next turn: Claude was not told them", async ($, on) => {
  const w = world($, on)
  const { cli } = await begun(w)
  const noted = (await cli('note', 'Round 3 drawn')).out.trim()

  expect((await $.prompt.submit(PROMPT)).context?.[0]).toContain(`- ${noted}: Round 3 drawn`)
})

test('the CLI writes only its own file: no heartbeat, and the window’s file untouched', async ($, on) => {
  const w = world($, on)
  const { paths, cli } = await begun(w)
  const before = new Map([...w.files].map(([path, held]) => [path, held.text]))

  await cli('note', 'Round 3 drawn')
  await cli('status', '--now', 'Drawing round 4')

  const changed = [...w.files].filter(([path, held]) => before.get(path) !== held.text)

  expect(changed.map(([path]) => path)).toEqual([paths.log(WRITER)])
  expect([...w.files.keys()].filter(path => path.startsWith(`${paths.presence}/`))).toEqual([
    paths.heartbeat(W1),
  ])
})
