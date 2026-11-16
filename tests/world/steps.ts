/** Steps the tests share, taken in a world: Claude asking, a turn ending, Lee moving about the board; and reads of what the window wrote. */
import type { RenderPropsOf } from 'claude-code'
import { expect, type Mounted } from '../kit'
import { parseEntries, parsePresence, type SessionPaths } from '../../core'
import { PROJECT, REVIEW, W1 } from '../data'
import { postedId } from './calls'
import type { World } from './index'
import { DOCKED } from './panes'

/** What a test asks with the ask tool. */
type Ask = { [key: string]: unknown }

/** Claude posts an ask, and the board opens it, as it does a new one: its id. */
export const asked = async (w: World, ask: Ask = REVIEW) => postedId(await w.call('ask', ask))

/**
 * The session begun, Claude asking `asks` in order (one review unless told),
 * and the board drawn as `props`, docked unless told: the session's paths,
 * the asks' ids, the first one's on its own, and the board.
 */
export const asking = async (
  w: World,
  {
    asks = [REVIEW],
    props = DOCKED,
  }: { asks?: readonly Ask[]; props?: RenderPropsOf['Pane'] } = {},
) => {
  const { paths } = await w.begin()
  const ids: string[] = []

  for (const ask of asks) {
    ids.push(await asked(w, ask))
  }

  const ui = await w.pane('terminal', props)
  const [id = ''] = ids

  return { paths, id, ids, ui }
}

/** The main conversation's turn ending, and what it set going settled. */
export const turnEnded = async (w: World, how?: Parameters<World['turnEnds']>[0]) => {
  await w.turnEnds(how)
  await w.clock.settle()
}

/** The band's count of what waits on Lee in this session, as it reads whole. */
export const asksOnBand = async (w: World) =>
  (await (await w.band()).find({ key: 'band:asks' }))?.text

/** The board on a project's view, reached as Lee reaches it from the tabs: All projects, then the project. */
export const toProject = async (ui: Pick<Mounted, 'press'>, key = PROJECT.key) => {
  await ui.press({ key: 'tab:all' })
  await ui.press({ key: `proj:${key}` })
}

/** Lee opens an ask the board holds closed, by its address: asserted closed before his pick and open after it, by the item the pane holds open. */
export const openAsk = async (w: World, ui: Pick<Mounted, 'press'>, key: string) => {
  expect(w.state.pane?.selected, `${key} stands closed`).not.toBe(key)
  await ui.press({ key: `pick:${key}` })
  expect(w.state.pane?.selected, `${key} opened`).toBe(key)
}

/** Lee presses an open yes ask's yes, by its address: asserted drawn first, so an ask standing closed, or of another kind, fails the step. */
export const pressYes = async (ui: Pick<Mounted, 'find' | 'press'>, key: string) => {
  expect(await ui.find({ key: `yes:${key}` }), `${key}'s yes drawn`).toBeDefined()
  await ui.press({ key: `yes:${key}` })
}

/**
 * Lets go of what waits on a prompt a held turn then lost: no hook ever
 * answers it, so the kit rejects it as the test ends. The rejection is
 * caught here, so it never surfaces as an unhandled one, reported against
 * another test, whatever the mod beneath makes of it.
 */
export const lost = (waiting: Promise<unknown>) => {
  void waiting.catch(() => {})
}

/** The kinds of line a file holds, in order. */
export const kindsIn = (w: World, path: string) => parseEntries(w.text(path)).map(line => line.type)

/** What the window's heartbeat says it sends its session. */
export const sendingIn = (w: World, paths: SessionPaths) =>
  parsePresence(w.text(paths.heartbeat(W1)), W1)?.sending
