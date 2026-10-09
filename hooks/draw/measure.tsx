/**
 * A surface module spanning one block of the docked board's list, drawing
 * nothing: it posts the rows the block takes as laid out, whenever they
 * change, and the board learns from them how tall its list is and where
 * each block sits in it.
 */
import type { ClientModule } from 'claude-code'

/** The block it measures, by its key. */
type Props = { id: string }

/** The rows last posted. */
type Posted = { rows: number }

const Measure: ClientModule<Props, Posted> = ({ id }, surface) => {
  // 0 is a region not laid out yet: no reading.
  if (surface.rows > 0 && surface.rows !== surface.state?.rows) {
    surface.post({ id, rows: surface.rows })
    surface.setState({ rows: surface.rows })
  }

  return <surface.elements.Box width={1} />
}

export default Measure
