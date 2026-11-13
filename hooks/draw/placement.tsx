/**
 * A surface module in the board's header, drawing nothing: it posts where
 * Claude Code seated the board, as the board was drawn with it, whenever
 * that changes, and the band learns from it which button closes the board.
 */
import type { ClientModule, RenderPropsOf } from 'claude-code'

/** Where the board was drawn: as its props had it, and as last posted. */
type Seated = { placement: RenderPropsOf['Pane']['placement'] }

const Placement: ClientModule<Seated, Seated> = ({ placement }, surface) => {
  if (placement !== surface.state?.placement) {
    surface.post({ placement })
    surface.setState({ placement })
  }

  return <surface.elements.Box width={1} />
}

export default Placement
