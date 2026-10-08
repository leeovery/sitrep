/**
 * The board's pane: opened full or as the glance, on a view and an item,
 * and closed again.
 *
 * Claude Code places a pane opened by Lee's press or command at any width
 * (docked from 110 columns in fullscreen, inline otherwise), and one opened
 * unasked only from 144. So the band's buttons open the board inside the
 * press itself, from the `ui.press` hook: an open made once the press has
 * settled counts as unasked.
 */
import type { SitrepMode, SitrepPane } from '../types'
import type { Host } from './host'

/** The pane's id, as `$.ui.open` and its `ui.render` name it. */
export const PANE = 'board'

const TITLE = 'sitrep'

/** The columns asked for, full and as the glance, and the rows inline. */
const COLUMNS: Record<SitrepMode, number> = { full: 62, glance: 28 }
const ROWS = 24

/** The band's buttons, each a way into the board. */
export const BAND = {
  forYou: 'band:for-you',
  parked: 'band:parked',
  board: 'band:board',
} as const

export const BAND_KEYS = Object.values(BAND)

/** Where the board opens: its view, and the item opened under its line. */
export type Focus = Partial<Pick<SitrepPane, 'view' | 'selected'>>

const markOpen = (host: Host, isOpen: boolean) =>
  host.state.pane.update(pane => ({ ...pane, isOpen }))

const isUp = async (host: Host) => (await host.ui.panes()).some(pane => pane.id === PANE)

/** Opens the board; one Claude Code would not draw is closed again, and a toast says why. */
export const openBoard = async (host: Host, mode: SitrepMode, focus: Focus = {}) => {
  await host.state.pane.update(pane => ({ ...pane, ...focus, mode }))

  const opened = await host.ui.open({ id: PANE, title: TITLE, columns: COLUMNS[mode], rows: ROWS })

  if (!opened.isPlaced) {
    // Open but undrawn, the band would say "hide board" over nothing.
    await host.ui.close(PANE)
    await markOpen(host, false)
    host.ui.toast(`Claude Code didn't draw the board: ${opened.reason}`, { timeoutMs: 8_000 })

    return
  }

  await markOpen(host, true)
}

const closeBoard = async (host: Host) => {
  await host.ui.close(PANE)
  // A plugin's own close never reaches its own ui.close hook, so the band hears of it here.
  await markOpen(host, false)
}

/** Shows the board, or hides it, as the engine has it rather than as the band's label says. */
const toggleBoard = async (host: Host) =>
  (await isUp(host)) ? closeBoard(host) : openBoard(host, 'full')

/** Brings the band's word on the board into line with the engine's record, after a reload. */
export const syncBoard = async (host: Host) => markOpen(host, await isUp(host))

/** The board closed by Lee: the band's button follows. */
export const boardClosed = (host: Host) => markOpen(host, false)

/** A press on one of the band's buttons: the count opens the board on what it counts. */
export const pressBand = (host: Host, element: string) => {
  if (element === BAND.board) {
    return toggleBoard(host)
  }

  return openBoard(host, 'full', { view: element === BAND.parked ? 'parked' : 'session' })
}
