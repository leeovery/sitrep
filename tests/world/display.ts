import type {
  ElementTable,
  On,
  PromptSubmitInput,
  RenderElement,
  RenderPropsOf,
} from 'claude-code'

/** A drawing above the prompt that is not the band: another plugin's, or Claude Code's own. */
type AbovePrompt = (els: ElementTable, props: RenderPropsOf['AbovePrompt']) => RenderElement

/** What reaches the model as a prompt: the text, what rode beside it, whose it is, and what was attached. */
type Submitted = Pick<PromptSubmitInput, 'text' | 'context' | 'origin' | 'attachments'>

/**
 * The display beneath the mod: the panes it opens, as placed or waiting;
 * its toasts, sounds, log and command; and the prompts it submits, which can be
 * dropped or held back as a running turn holds them.
 */
export function display(on: On) {
  const panes = new Map<string, boolean>()
  const toasts: string[] = []
  /** How long each toast stays, in the order shown. */
  const toastsMs: (number | undefined)[] = []
  const sounds: string[] = []
  /** The engine's debug log. */
  const logs: string[] = []
  const commands: string[] = []
  const prompts: Submitted[] = []
  const submitted: string[] = []
  let unplaced: string | undefined
  let dropping: string | undefined
  let failing: string | undefined
  let refusingOpens: string | undefined
  let holding: { arrive: () => void; turn: Promise<void> } | undefined

  on('ui.open', ($, e) => {
    if (refusingOpens !== undefined) {
      return { deny: refusingOpens }
    }

    panes.set(e.id, unplaced === undefined)

    return {
      value: unplaced === undefined ? { isPlaced: true } : { isPlaced: false, reason: unplaced },
    }
  })

  on('ui.close', ($, e) => {
    panes.delete(e.id)

    return { value: undefined }
  })

  on('ui.panes', () => ({
    value: [...panes].map(([id, isPlaced]) => ({
      id,
      title: id,
      isShown: true,
      isFocused: false,
      isPlaced,
    })),
  }))

  on('ui.toast', ($, e) => {
    toasts.push(e.text)
    toastsMs.push(e.timeoutMs)

    return { value: undefined }
  })

  /**
   * What the test's own hooks draw above the prompt: Claude Code's drawing,
   * nothing outside a survey, unless a test stands another plugin's there.
   * From Claude Code 2.1.323 that is the test's own row, which the engine
   * stacks with the band's; before, it was what the band found beneath it.
   */
  let abovePrompt: AbovePrompt | undefined

  on('ui.render', { component: 'AbovePrompt' }, ($, e) =>
    abovePrompt === undefined ? { type: 'engine', ref: 0 } : abovePrompt($.ui.resolve(e), e.props),
  )

  on('ui.log', ($, e) => {
    logs.push(e.text)

    return { value: undefined }
  })

  on('audio.play', ($, e) => {
    sounds.push(e.clip.asset ?? '')

    return { value: undefined }
  })

  on('command.register', ($, e) => {
    commands.push(e.name)

    return { value: { command: e.name } }
  })

  /** Lee's prompt box: the draft as typed or pasted. */
  const box = { text: '' }

  on('prompt.read', () => ({ value: { text: box.text, cursor: box.text.length } }))

  on('prompt.fill', ($, e) => {
    box.text = e.mode === 'append' ? box.text + e.text : e.text

    return { isFilled: true }
  })

  on('prompt.submit', async ($, e) => {
    submitted.push(e.text)

    if (holding !== undefined) {
      holding.arrive()
      await holding.turn
    }

    if (failing !== undefined) {
      throw new Error(failing)
    }

    if (dropping !== undefined) {
      return { drop: dropping }
    }

    prompts.push({
      text: e.text,
      context: e.context,
      origin: e.origin,
      ...(e.attachments !== undefined && { attachments: e.attachments }),
    })

    return { text: e.text, context: e.context, origin: e.origin }
  })

  return {
    /** Lee's prompt box, which a test types or pastes into. */
    box,
    /** From here on, `draw` is drawn above the prompt beside the band: another plugin's row, or Claude Code's own. */
    drawAbovePrompt: (draw: AbovePrompt) => {
      abovePrompt = draw
    },
    panes,
    toasts,
    toastsMs,
    sounds,
    logs,
    commands,
    prompts,
    /** Every prompt submitted, entered or not, as it was submitted. */
    submitted,
    /** Panes opened from here on wait undrawn, for that reason; or, given none, are placed again. */
    unplacePanes: (reason?: string) => {
      unplaced = reason
    },
    /** Prompts from here on do not enter, for that reason; or, given none, they enter again. */
    dropPrompts: (reason?: string) => {
      dropping = reason
    },
    /** Prompts from here on fail beneath the mod, as a hook there throwing or timing out; or, given nothing, they enter again. */
    failPrompts: (error?: string) => {
      failing = error
    },
    /** Panes opened from here on are refused beneath the mod, for that reason; or, given none, they open again. */
    refuseOpens: (reason?: string) => {
      refusingOpens = reason
    },
    /**
     * Prompts from here on wait, as behind a running turn: `arrived` once
     * one is submitted; `end()` ends the turn, letting them in; and `lose()`
     * lets later prompts through while those waiting never go in, nor hear
     * back, as a prompt deleted from the queue or a load reloaded away.
     */
    holdPrompts: () => {
      let end = () => {}
      let arrive = () => {}
      const arrived = new Promise<void>(resolve => {
        arrive = resolve
      })

      holding = {
        arrive: () => arrive(),
        turn: new Promise(resolve => {
          end = resolve
        }),
      }

      return {
        arrived,
        end: () => {
          holding = undefined
          end()
        },
        lose: () => {
          holding = undefined
        },
      }
    },
  }
}
