/**
 * The tools beneath the mod: sitrep's own as the tests call them, and the
 * built-in tools' calls the engine runs, with their permission checks,
 * dialogs and endings; and the turn's Stop.
 */
import type { ClassicEventOf, ClassicResultOf, On } from 'claude-code'
import type { Engine } from 'claude-code/testing'

/** What a test calls a tool with: its short name and its arguments. */
type Args = { [key: string]: unknown }

/** A permission check's verdict, as the engine's rules and mode give it. */
type Verdict = 'allow' | 'ask' | 'deny'

/** How a built-in tool's call ends beneath the mod: answered, or refused. */
type Ending = { result: unknown } | { deny: string }

/** A built-in tool's call as a test runs it: what it settles to, and its ending, the test's to give. */
export type Calling = {
  done: Promise<{ result?: unknown; deny?: string; isError?: true }>
  /** The tool answers, as once it has run. */
  finish: (result?: unknown) => void
  /** The call is refused, as at a prompt Lee said no to, or one Lee stopped. */
  refuse: (why: string) => void
}

export function tools(engine: Engine, on: On) {
  const registered: { name: string; isDeferred?: boolean }[] = []

  on('tool.register', ($, e) => {
    registered.push({ name: e.name, isDeferred: e.isDeferred })

    return { value: { tool: `mcp__sitrep__${e.name}` } }
  })

  /**
   * The built-in tools' calls the engine runs beneath the mod, by the tool
   * and its arguments: a verdict to check them by, if any, whether an "ask"
   * shows Lee its dialog, their ending, and whether the engine's own check
   * of it has been let through.
   */
  const beneath = new Map<
    string,
    { verdict?: Verdict; isShown: boolean; ending: Promise<Ending>; isPrechecked?: boolean }
  >()

  const callKey = (tool: string, args: Args) => JSON.stringify({ tool, ...args })

  // As the engine runs one: its permission check, then the tool, until the
  // test ends it. Claude Code 2.1.308's harness runs its own check of the call
  // before this hook, its dialog answered at once by a headless decider that
  // denies, so that check is passed with `allow` (below) and the test's
  // verdict and dialog are replayed here, as the call's own.
  on('tool.call', async ($, e, next) => {
    const { tool, tool_use_id, agentId, ...args } = e as Args & {
      tool: string
      tool_use_id: string
      agentId?: string
    }
    const call = beneath.get(callKey(tool, args))

    if (call === undefined) {
      return next(e)
    }

    if (call.verdict !== undefined) {
      await engine.tool.check({ tool, input: args, tool_use_id, agentId })
    }

    if (call.verdict === 'ask' && call.isShown) {
      await engine.classic.PermissionRequest({
        tool_name: tool,
        tool_input: args,
        ...(agentId === undefined ? {} : { agent_id: agentId }),
      })
    }

    return (await call.ending) as never
  })

  /** What the settings hooks beneath answer a permission request: nothing, so the dialog shows, unless a test says otherwise. */
  let requestAnswer: ClassicResultOf['classic.PermissionRequest'] = {}

  on('classic.PermissionRequest', () => requestAnswer)

  /** What the settings hooks beneath answer a turn's Stop: nothing, so the turn stops, unless a test says otherwise. */
  let stopAnswer: ClassicResultOf['classic.Stop'] = {}

  on('classic.Stop', () => stopAnswer)

  on('tool.check', ($, e) => {
    const call = beneath.get(callKey(e.tool, e.input as Args))

    if (call !== undefined && e.tool_use_id !== undefined && call.isPrechecked !== true) {
      call.isPrechecked = true

      return { decision: 'allow' as const }
    }

    return { decision: call?.verdict ?? 'allow' }
  })

  return {
    registered,

    /** Calls one of sitrep's tools from the main conversation, or from a subagent given its id. */
    call: (name: string, args: Args = {}, agentId?: string) =>
      engine.tool.call({
        tool: `mcp__sitrep__${name}`,
        ...args,
        ...(agentId === undefined ? {} : { agentId }),
      } as never) as Promise<{ result?: unknown; deny?: string }>,

    /**
     * A built-in tool called from the main conversation, or from a subagent
     * given its id: checked first where given a verdict, its dialog shown to
     * Lee where an "ask" `isShown` (in auto mode, where the classifier hands
     * it to Lee), then running until the test finishes or refuses it. The
     * engine's own check of it, which its harness runs before the call's hook,
     * is passed with `allow`; the call's hook then replays the check and the
     * dialog with the test's verdict.
     */
    calls: (
      tool: string,
      args: Args = {},
      options: { verdict?: Verdict; isShown?: boolean; agentId?: string } = {},
    ): Calling => {
      let end: (ending: Ending) => void = () => {}
      const ending = new Promise<Ending>(resolve => {
        end = resolve
      })

      beneath.set(callKey(tool, args), {
        verdict: options.verdict,
        isShown: options.isShown ?? false,
        ending,
      })

      return {
        done: engine.tool.call({
          tool,
          ...args,
          ...(options.agentId === undefined ? {} : { agentId: options.agentId }),
        } as never) as Calling['done'],
        finish: (result = 'done') => end({ result }),
        refuse: why => end({ deny: why }),
      }
    },

    /** The settings hooks beneath answer every permission request from here on with `answer`, as one that allows or denies in the dialog's place. */
    answerRequests: (answer: ClassicResultOf['classic.PermissionRequest']) => {
      requestAnswer = answer
    },

    /** The settings hooks beneath answer every Stop from here on with `answer`, as one that blocks it to go on with the turn. */
    answerStops: (answer: ClassicResultOf['classic.Stop']) => {
      stopAnswer = answer
    },

    /** The main conversation's turn stopping, its Stop listing what it leaves pending, or a subagent's id where given: the classic event's answer. */
    stops: (
      pending: Pick<
        ClassicEventOf['classic.Stop'],
        'background_tasks' | 'session_crons' | 'agent_id'
      >,
    ) => engine.classic.Stop({ stop_hook_active: false, ...pending }),
  }
}

/** The session id a start's answer names. */
export const startedId = (answer: { result?: unknown }) => {
  const id = String(answer.result).match(/\bsr-[0-9a-z]+/)?.[0]

  if (id === undefined) {
    throw new Error(`no session id in ${String(answer.result)}`)
  }

  return id
}

/** The item id an answer names, ending its first sentence. */
export const postedId = (answer: { result?: unknown }) => {
  const id = String(answer.result).match(/^[^.]* ([0-9a-z]{4,})\./)?.[1]

  if (id === undefined) {
    throw new Error(`no item id in ${String(answer.result)}`)
  }

  return id
}
