/**
 * Where a window is, so a click can find the terminal showing its session:
 * the terminal device Claude Code is on, the terminal program, its tmux
 * pane and its zmx session. Read from the raw facts the mod gathers, and
 * leniently, field by field: a heartbeat is never lost over where its window
 * is.
 */
import { isFilled, isObject } from './entries'
import type { Where } from './types'

/** The environment variables a window's whereabouts are read from. */
export type WhereEnv = {
  TMUX?: string
  TMUX_PANE?: string
  TERM_PROGRAM?: string
  ZMX_SESSION?: string
}

/** A terminal device, `/dev/ttys043`: only a tty, the form Ghostty's terminals give as their `tty`, which the jump asks for. */
export const isDevice = (value: unknown): value is string =>
  typeof value === 'string' && /^\/dev\/tty\w+$/.test(value)

const isPane = (value: unknown): value is string =>
  typeof value === 'string' && /^%\d+$/.test(value)

const isTmux = (value: unknown): value is NonNullable<Where['tmux']> =>
  isObject(value) && isFilled(value.socket) && isPane(value.pane)

const isZmx = (value: unknown): value is NonNullable<Where['zmx']> =>
  isObject(value) && isFilled(value.session)

/** Each well-formed field of `raw`, the rest dropped; undefined when none is. */
export const parseWhere = (raw: unknown): Where | undefined => {
  if (!isObject(raw)) {
    return undefined
  }

  const { device, terminal, tmux, zmx } = raw
  const where: Where = {
    ...(isDevice(device) ? { device } : {}),
    ...(isFilled(terminal) ? { terminal } : {}),
    ...(isTmux(tmux) ? { tmux: { socket: tmux.socket, pane: tmux.pane } } : {}),
    ...(isZmx(zmx) ? { zmx: { session: zmx.session } } : {}),
  }

  return Object.keys(where).length === 0 ? undefined : where
}

/**
 * Where a window is, from its environment and its terminal device; undefined
 * when nothing is known. The tmux socket is `$TMUX` up to its first comma,
 * and `tmux` is set only with a pane; the zmx session is `$ZMX_SESSION`,
 * spaces and all.
 */
export const whereOf = (env: WhereEnv, device?: string): Where | undefined =>
  parseWhere({
    device,
    terminal: env.TERM_PROGRAM,
    tmux: { socket: env.TMUX?.split(',')[0], pane: env.TMUX_PANE },
    zmx: { session: env.ZMX_SESSION },
  })

/** The device a tty name names (`ttys043` as `/dev/ttys043`); undefined for anything else, `??` and nothing among it. */
export const parseDevice = (output: string): string | undefined => {
  const device = `/dev/${output.trim()}`

  return isDevice(device) ? device : undefined
}
