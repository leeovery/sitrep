/**
 * A drawing read back as a mounted one is: its tree, and `find` and
 * `findAll` matching an element by its type, its key and the words it shows,
 * as the kit's do (render.test.tsx holds them to the kit's). It reads only
 * the elements the board draws with (render.ts), and the board's own tree,
 * never a `Client`'s module's.
 */
import type { ElementQuery, FoundElement, Mounted } from 'claude-code/testing'

/** An element as a surface's table builds it, as `drawn()` has it: a Button's press and a hover out of its props, a Text's key, which a surface never keeps, and no children where it draws none. */
export type Element = {
  type: string
  props: Record<string, unknown>
  hover?: unknown
  children?: (Element | string)[]
}

/** The words an element shows: a Button's label, then its children's. */
const textOf = (node: Element | string): string =>
  typeof node === 'string'
    ? node
    : `${node.type === 'Button' ? String(node.props.label ?? '') : ''}${(node.children ?? []).map(textOf).join('')}`

const found = (node: Element): FoundElement => ({
  type: node.type,
  key: node.props.key as string | undefined,
  props: node.props,
  text: textOf(node),
  children: node.children ?? [],
})

const matches = (node: Element, { type, key, text }: ElementQuery) =>
  (type === undefined || node.type === type) &&
  (key === undefined || node.props.key === key) &&
  (text === undefined ||
    (typeof text === 'string' ? textOf(node).includes(text) : text.test(textOf(node))))

/** Every element of a tree, outermost first in document order. */
const elementsOf = (node: Element | string): Element[] =>
  typeof node === 'string' ? [] : [node, ...(node.children ?? []).flatMap(elementsOf)]

/** A drawing read as a mounted one is: its tree, and `find` and `findAll` matching as the kit's do. */
export type Drawn = Pick<Mounted, 'drawn' | 'find' | 'findAll'>

/** Refuses a read in a `Client`'s module: the board's own tree is all a drawing here holds. */
const inTree = (scope?: { in?: string }) => {
  if (scope?.in !== undefined) {
    throw new Error(`no Client's module is drawn here to read in: ${scope.in}`)
  }
}

/** The tree `drawing` makes, read as a mounted drawing is. */
export const reading = (drawing: Promise<Element>): Drawn => {
  const matching = async (query: ElementQuery) => {
    inTree(query)

    return elementsOf(await drawing).filter(node => matches(node, query))
  }

  return {
    drawn: async scope => {
      inTree(scope)

      return (await drawing) as never
    },
    find: async query => {
      const [first] = await matching(query)

      return first === undefined ? undefined : found(first)
    },
    findAll: async query => (await matching(query)).map(found),
  }
}
