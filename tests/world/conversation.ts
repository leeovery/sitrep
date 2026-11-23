/** The conversation beneath the mod: its id and folders, its turns, and the walk up its processes for its terminal. */
import type { On, TurnStartInput } from 'claude-code'
import type { Engine } from 'claude-code/testing'
import type { Where } from '../../core'
import { REPO, W1 } from '../data'

export const CONVERSATION = { cwd: REPO, surface: 'terminal' as const, isInteractive: true }

export const PROMPT = { text: 'Carry on.', wait: false, origin: { kind: 'composer' as const } }

/** The terminal Claude Code is on, as the walk up its processes prints it. */
export const TTY = 'ttys001'

/** Where the world's window is unless told otherwise: a Ghostty window outside tmux. */
export const WHERE: Where = { device: `/dev/${TTY}`, terminal: 'ghostty' }

/** What the walk up Claude Code's processes for its terminal gives: what it printed and how it exited, or why it could not run. */
export type Walk = { stdout: string; exitCode?: number } | { refused: string }

/** The conversation, started in `cwd`. */
export function conversation(engine: Engine, on: On, cwd: string) {
  let id = W1
  /** The folder the window's Claude runs in, which a shell's `cd` never moves; none, as one that does not read. */
  let root: string | undefined = cwd
  let turns = 0

  on('session.start', ($, e) => ({ cwd: e.cwd }))
  on('session.end', ($, e) => ({ sessionId: e.sessionId }))
  on('turn.start', ($, e) => ({ turnId: e.turnId }))
  on('turn.complete', ($, e) => ({ text: e.answer }))
  on('classic.SessionStart', () => ({}))
  on('prompt.context', ($, e) => ({ blocks: e.blocks }))
  on('session.id', () => ({ value: id }))
  on('session.cwd', () => ({ value: cwd }))
  on('session.root', () => (root === undefined ? { deny: 'no folder' } : { value: root }))

  return {
    /** The conversation from here on: another id, as after a /clear; another folder, as a shell's `cd` takes it to; or another folder its Claude runs in, as entering a worktree moves it, null for one that does not read. */
    become: (next: { conversation?: string; cwd?: string; root?: string | null }) => {
      id = next.conversation ?? id
      cwd = next.cwd ?? cwd
      root = next.root === null ? undefined : (next.root ?? root)
    },

    /** A turn of the main conversation starting with `text`, as the engine starts one. */
    turnStarts: async (text: string) => {
      turns += 1
      await engine.turn.start({ text, turnId: `turn-${turns}` })
    },

    /** A run of a subagent's loop starting, as Claude Code 2.1.318 raises one: a turn's start carrying the subagent's id. */
    agentRunStarts: async (agentId: string) => {
      const start: TurnStartInput & { agentId: string } = {
        text: 'Review the change on this branch.',
        turnId: `${agentId}-run`,
        agentId,
      }

      await engine.turn.start(start)
    },

    /** The main conversation's turn ending, its answer given; or stopped by Lee; or a subagent's turn, given its id. */
    turnEnds: (how: { isAborted?: boolean; agentId?: string } = {}) =>
      engine.turn.complete({
        answer: 'Done.',
        durationMs: 1_000,
        isAborted: how.isAborted ?? false,
        turnId: `turn-${turns}`,
        reason: how.isAborted === true ? 'aborted' : 'answer',
        ...(how.agentId === undefined ? {} : { agentId: how.agentId }),
      }),
  }
}

/** How a process the mod runs ended, as the engine gives it. */
export const exited = (exitCode: number, stdout = '', stderr = '') => ({
  value: { exitCode, stdout, stderr, isStdoutTruncated: false, isStderrTruncated: false },
})

/** Answers a process the mod runs that is not the walk, given its argument vector and standard input; undefined for the walk. */
export type Runs = (
  argv: readonly string[],
  stdin?: string,
) => ReturnType<typeof exited> | undefined

/** The walk up Claude Code's processes for its terminal, as the mod runs it: printing TTY unless told otherwise; any other process the mod runs, as `others` answers it. */
export function walking(on: On, others: Runs = () => undefined) {
  /** The commands the mod ran, each as its argument vector. */
  const runs: (readonly string[])[] = []
  let walk: Walk = { stdout: `${TTY}\n` }

  on('process.run', ($, e) => {
    runs.push(e.argv)

    const other = others(e.argv, e.init?.stdin)

    if (other !== undefined) {
      return other
    }

    return 'refused' in walk
      ? { deny: walk.refused }
      : exited(walk.exitCode ?? 0, walk.stdout)
  })

  return {
    runs,
    /** The walk for the terminal gives `next` from here on. */
    walkGives: (next: Walk) => {
      walk = next
    },
  }
}
