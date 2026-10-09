/**
 * The board's pane: opened on a place, a view and an item, and closed again.
 *
 * Claude Code places a pane opened by Lee's press or command at any width
 * (docked from 110 columns in fullscreen, inline otherwise), and one opened
 * unasked only from 144. So the band's buttons open the board inside the
 * press itself, from the `ui.press` hook: an open made once the press has
 * settled counts as unasked.
 */
import type { SitrepAttachment, SitrepPane } from '../types'
import { endAnswering } from './answering'
import { lookAround } from './around'
import type { Host } from './host'
import { projectPlace } from './places'

/** The pane's id, as `$.ui.open` and its `ui.render` name it. */
export const PANE = 'sitrep'

const TITLE = 'sitrep'

/** The columns asked for, and the rows inline. */
const COLUMNS = 62
const ROWS = 24

/** The band's buttons: each a way into the board, or, while Lee answers an ask in the prompt, the way out of that. */
export const BAND = {
  forYou: 'band:for-you',
  elsewhere: 'band:elsewhere',
  parked: 'band:parked',
  board: 'band:board',
  cancelAnswer: 'band:cancel-answer',
} as const

export const BAND_KEYS = Object.values(BAND)

/** Where the board opens: where it looks, its view, and the item opened under its line. */
export type Focus = Partial<Pick<SitrepPane, 'place' | 'view' | 'selected'>>

/** Where each of the band's counts opens the board: this session, its project, or what this session parked. */
const COUNTED: Readonly<Record<string, (held: SitrepAttachment) => Focus>> = {
  [BAND.forYou]: () => ({ place: null, view: 'board' }),
  [BAND.elsewhere]: held => ({ place: projectPlace(held.project), view: 'board' }),
  [BAND.parked]: () => ({ place: null, view: 'parked' }),
}

/** Where the board opens once it has been closed: home, on the board, nothing opened. */
const HOME: Focus = { place: null, view: 'board', selected: null }

const markOpen = (host: Host, isOpen: boolean) =>
  host.state.pane.update(pane => ({ ...pane, isOpen }))

/** The board closed: the band's button follows, and the board forgets where it had gone. */
const markClosed = (host: Host) =>
  host.state.pane.update(pane => ({ ...pane, ...HOME, isOpen: false }))

const isUp = async (host: Host) => (await host.ui.panes()).some(pane => pane.id === PANE)

/**
 * Opens the board, and reads what it shows; one Claude Code would not draw
 * is closed again, and a toast says why.
 */
export const openBoard = async (host: Host, focus: Focus = {}) => {
  await host.state.pane.update(pane => ({ ...pane, ...focus }))

  const opened = await host.ui.open({ id: PANE, title: TITLE, columns: COLUMNS, rows: ROWS })

  if (!opened.isPlaced) {
    // Open but undrawn, the band would say "hide board" over nothing.
    await host.ui.close(PANE)
    await markClosed(host)
    host.ui.toast(`Claude Code didn't draw the board: ${opened.reason}`)

    return
  }

  await markOpen(host, true)
  await lookAround(host)
}

/** Closes the board: by the band's button, or once an inline board's send is claimed. */
export const closeBoard = async (host: Host) => {
  await host.ui.close(PANE)
  // A plugin's own close never reaches its own ui.close hook, so the band hears of it here.
  await markClosed(host)
}

/** Shows the board, or hides it, as the engine has it rather than as the band's label says. */
const toggleBoard = async (host: Host) => ((await isUp(host)) ? closeBoard(host) : openBoard(host))

/** Brings the band's word on the board into line with the engine's record, after a reload. */
export const syncBoard = async (host: Host) => markOpen(host, await isUp(host))

/** The board closed by Lee's ✕. */
export const boardClosed = markClosed

/** A press on one of the band's buttons: a count opens the board on what it counts. */
export const pressBand = async (host: Host, element: string) => {
  if (element === BAND.cancelAnswer) {
    return endAnswering(host)
  }

  const held = await host.state.attachment.read()
  const focus = Object.hasOwn(COUNTED, element) ? COUNTED[element] : undefined

  return held === null || focus === undefined ? toggleBoard(host) : openBoard(host, focus(held))
}
