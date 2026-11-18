/**
 * The JSX factory Claude Code gives the mod, for the board drawn on Bun with
 * no engine beneath: as the engine's, a component tag called with its props
 * and its children, making the plain data the element table's constructors
 * make. Imported before anything that draws, which reads it by name.
 */
type Tag = (props: Record<string, unknown>) => unknown

Object.assign(globalThis, {
  h: (tag: Tag | string, props: Record<string, unknown> | null, ...children: unknown[]) => {
    if (typeof tag === 'string') {
      throw new Error(`the board draws no string tag: ${tag}`)
    }

    return tag({ ...props, children })
  },
})
