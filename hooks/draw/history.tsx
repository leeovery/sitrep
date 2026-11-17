/**
 * Status's history: every change of a session's status, the newest first,
 * folded away under Status until Lee opens it, and in a project's view
 * under its sessions, each change naming its session. A change opens to its
 * detail as a tree, each line opening with its label.
 */
import { labelOf, type StatusLine } from '../../core'
import { C, GLYPH } from '../look'
import { itemKey } from '../places'
import { drawRow, type Block, type Branch, type Drawing } from './kit'
import { drawPast } from './past'

/** A change is a thing gone by, so its mark is faint. */
const MARK = { glyph: GLYPH.now, color: C.faint }

/** A change as a history lists it: the session it came from, and in a project's, that session's name. */
export type Changed = { line: StatusLine; session: string; name?: string }

/** A change and its address on the board, which its row and its press are keyed by. */
type Addressed = Changed & { address: string }

/**
 * Each change with its address: its session, its time and its writer, and
 * where a writer changed the status twice in one millisecond, its place
 * among those, the older first, so a newer change never moves an older's.
 * Two blocks of one key leave the whole board undrawn.
 */
const addressed = (changes: readonly Changed[]): Addressed[] => {
  const seen = new Map<string, number>()

  return changes
    .toReversed()
    .map(changed => {
      const base = itemKey(changed.session, `${changed.line.at}:${changed.line.by}`)
      const before = seen.get(base) ?? 0

      seen.set(base, before + 1)

      return { ...changed, address: before === 0 ? base : `${base}:${before}` }
    })
    .toReversed()
}

const opensOf = ({ address }: Addressed) => `status:${address}`

/** A line of a change's detail as its branch: opening with its label, in the now colour. */
const branchOf = (text: string): Branch => {
  const labelled = labelOf(text)

  return labelled === undefined ? text : { ...labelled, color: C.now }
}

/** A change, as a block of its own. */
const drawChange = (d: Drawing, changed: Addressed): Block => {
  const { line, name, address } = changed
  const key = opensOf(changed)
  const isOpen = d.scene.pane.selected === key
  const row = `change:${address}`

  return {
    key: row,
    element: drawRow(d, {
      key: row,
      mark: MARK,
      title: name === undefined ? line.text : `${name}: ${line.text}`,
      at: line.at,
      isOpen,
      press: { key, onPress: () => d.act.select(key) },
      branches: isOpen ? line.detail.map(branchOf) : [],
    }),
  }
}

/** The history of a session's status, or of a project's sessions', `scope` naming whose: its press, and the changes it shows once opened. */
export const drawHistory = (d: Drawing, scope: string, changes: readonly Changed[]): Block[] =>
  drawPast(d, {
    list: `history:${scope}`,
    entries: addressed(changes),
    draw: changed => drawChange(d, changed),
    opens: opensOf,
    folding: { show: 'show history', hide: 'hide history' },
  })
