/**
 * Status's history: every change of a session's status, the newest first,
 * folded away under Status until Lee opens it. A change opens to its detail
 * as a tree, each line opening with its label.
 */
import { carried, labelOf, type Session, type StatusLine } from '../../core'
import { historyList } from '../lists'
import { C, GLYPH } from '../look'
import { itemKey } from '../places'
import { drawRow, type Block, type Branch, type Drawing } from './kit'
import { drawPast } from './past'

/** A change is a thing gone by, so its mark is faint. */
const MARK = { glyph: GLYPH.now, color: C.faint }

/** A change and its address on the board, which its row and its press are keyed by. */
type Addressed = { line: StatusLine; address: string }

/**
 * A session's changes with their addresses: its id, the change's time and
 * its writer, and where a writer changed the status twice in one
 * millisecond, its place among those, the older first, so a newer change
 * never moves an older's. Two blocks of one key leave the whole board
 * undrawn.
 */
const addressed = ({ id, history }: Pick<Session, 'id' | 'history'>): Addressed[] => {
  const seen = new Map<string, number>()

  return history
    .toReversed()
    .map(line => {
      const base = itemKey(id, `${line.at}:${line.by}`)
      const before = seen.get(base) ?? 0

      seen.set(base, before + 1)

      return { line, address: before === 0 ? base : `${base}:${before}` }
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
  const { line, address } = changed
  const key = opensOf(changed)
  const isOpen = d.scene.pane.selected === key
  const row = `change:${address}`

  return {
    key: row,
    element: drawRow(d, {
      key: row,
      mark: MARK,
      title: line.text,
      at: line.at,
      isOpen,
      press: { key, onPress: () => d.act.select(key) },
      branches: isOpen ? line.detail.map(branchOf) : [],
    }),
  }
}

/** The history of a session's status: its press, and the changes it shows once opened. */
export const drawHistory = (d: Drawing, session: Pick<Session, 'id' | 'history'>): Block[] =>
  drawPast(d, {
    list: historyList(session.id),
    carried: carried(addressed(session), true),
    draw: changed => drawChange(d, changed),
    opens: opensOf,
    folding: { show: 'show history', hide: 'hide history' },
  })
