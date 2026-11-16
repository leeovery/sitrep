/** The board and the band as the surfaces draw them. */
import type { RenderPropsOf, RenderViewport } from 'claude-code'
import type { Engine } from 'claude-code/testing'
import { PANE } from '../../hooks/pane'

/** The board pane as a fullscreen terminal docks it, and as the main screen draws it inline. */
export const DOCKED: RenderPropsOf['Pane'] = {
  title: 'sitrep',
  isFocused: false,
  bodyColumns: 56,
  placement: 'dock',
  scroll: { offset: 0, bodyRows: 30 },
  view: {},
}

/** The cells the docked board draws a row across, inside the column it keeps free each side. */
export const ACROSS = DOCKED.bodyColumns - 2

export const INLINE: RenderPropsOf['Pane'] = { ...DOCKED, placement: 'inline' }

/** The board docked beside a 150-column terminal, as it measured live: room for every tab's full label, counts and all. */
export const WIDE: RenderPropsOf['Pane'] = { ...DOCKED, bodyColumns: 67 }

/** The band above the prompt, 100 columns across. */
export const BAND: RenderPropsOf['AbovePrompt'] = {
  hasSurvey: false,
  isCollapsed: false,
  isWorking: false,
  maxRows: 6,
  bodyColumns: 100,
  scroll: { offset: 0, bodyRows: 6 },
  view: {},
}

/** The surfaces the tests draw the board and the band on. */
export const SURFACES = ['terminal', 'desktop'] as const

type Surface = (typeof SURFACES)[number]

export function panes(engine: Engine) {
  /** The board pane drawn on a surface, as a docked pane unless told otherwise. */
  const pane = (surface: Surface = 'terminal', props: RenderPropsOf['Pane'] = DOCKED) =>
    engine.ui.mount({ plugin: 'sitrep', surface, component: 'Pane', requestId: PANE, props })

  return {
    pane,

    /** The board opened by /sitrep, as Lee opens it, then drawn docked unless told otherwise. */
    opened: async (props: RenderPropsOf['Pane'] = DOCKED) => {
      await engine.command.run({
        command: 'sitrep',
        args: '',
        origin: { kind: 'composer' },
        presentation: { isFullscreen: true, columns: 160 },
      })

      return pane('terminal', props)
    },

    /** The band drawn on a surface, `columns` across, on a screen that measured as `viewport` where given. */
    band: (surface: Surface = 'terminal', columns = BAND.bodyColumns, viewport?: RenderViewport) =>
      engine.ui.mount({
        plugin: 'sitrep',
        surface,
        component: 'AbovePrompt',
        props: { ...BAND, bodyColumns: columns },
        viewport,
      }),
  }
}
