/** Steps the tests share, taken in a world: Claude asking, a turn ending, Lee moving about the board; and reads of what the window wrote. */
import type { RenderPropsOf } from 'claude-code'
import type { Mounted } from 'claude-code/testing'
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

/** The band's count of what waits on Lee in this session, where it says `text`. */
export const asksOnBand = async (w: World, text: string) =>
  (await w.band()).find({ key: 'band:asks', text })

/** The board on a project's view, reached as Lee reaches it from the tabs: All projects, then the project. */
export const toProject = async (ui: Pick<Mounted, 'press'>, key = PROJECT.key) => {
  await ui.press({ key: 'tab:all' })
  await ui.press({ key: `proj:${key}` })
}

/** The kinds of line a file holds, in order. */
export const kindsIn = (w: World, path: string) => parseEntries(w.text(path)).map(line => line.type)

/** What the window's heartbeat says it sends its session. */
export const sendingIn = (w: World, paths: SessionPaths) =>
  parsePresence(w.text(paths.heartbeat(W1)), W1)?.sending
