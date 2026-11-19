/**
 * The terminal the CLI runs on, bound to Bun, for the panel: there only
 * while standard input and output are both a terminal.
 *
 * - Raw mode is on while anything listens to the keys or waits on an
 *   answer to a query, and off once nothing does.
 * - A query waits for DA1's answer up to a second. An answer that comes
 *   later reaches the keys, whose reader passes it over.
 * - The size is asked of the terminal each time: Bun's `columns` and `rows`
 *   change only on a SIGWINCH, which a resize made while the run is stopped
 *   sends to the shell instead (proven live, 19 November 2026).
 * - A terminal gone, as after a hang-up, fails nothing: a write to it is
 *   lost, and raw mode is let go without a word, so the panel gives the
 *   terminal back on every path, that one included. While raw mode is on,
 *   its input ending or failing, or its output failing, is heard as SIGHUP,
 *   for a terminal can go without one, as one that was never this run's
 *   controlling terminal does.
 */
import type { Signal, Terminal } from '../io'

/** How long a query waits for DA1's answer. */
const ANSWER_MS = 1_000

/** DA1's answer: `CSI ? <attributes> c`. */
const DA1 = /\x1b\[\?[\d;]*c/

/** Does what it can with a terminal that may be gone: an error there means only that it is. */
const tried = (act: () => void) => {
  try {
    act()
  } catch {}
}

/** Hears a write's error from a terminal gone, which unheard would end the run before the panel gives the terminal back. */
const lost = () => {}

/**
 * Raw mode while any hold it, standard input read only then, and the
 * terminal's going heard by `gone`: each hold, counted once raw mode is on,
 * gives what lets it go, once.
 */
const rawHolds = (gone: () => void) => {
  let holds = 0

  const hearGoing = (isHearing: boolean) => {
    const on = isHearing ? 'on' : 'off'

    process.stdin[on]('end', gone)
    process.stdin[on]('close', gone)
    process.stdin[on]('error', gone)
    process.stdout[on]('error', gone)
  }

  return () => {
    let isHeld = true

    if (holds === 0) {
      process.stdin.setEncoding('utf8')
      process.stdin.setRawMode(true)
      hearGoing(true)
      process.stdin.resume()
    }

    holds += 1

    return () => {
      if (isHeld && --holds === 0) {
        hearGoing(false)
        tried(() => process.stdin.setRawMode(false))
        process.stdin.pause()
      }

      isHeld = false
    }
  }
}

/** The terminal, while standard input and output are both one; none otherwise. */
export const terminalOf = (): Terminal | undefined => {
  if (process.stdin.isTTY !== true || process.stdout.isTTY !== true) {
    return undefined
  }

  const hangUps = new Set<() => void>()
  const raw = rawHolds(() => hangUps.forEach(heard => heard()))
  let isWriting = false

  const listen = (heard: (bytes: string) => void) => {
    const release = raw()

    process.stdin.on('data', heard)

    return () => {
      process.stdin.off('data', heard)
      release()
    }
  }

  const write = (text: string) => {
    if (!isWriting) {
      process.stdout.on('error', lost)
      isWriting = true
    }

    tried(() => void process.stdout.write(text))
  }

  const ask = (query: string) =>
    new Promise<string>(resolve => {
      let heard = ''
      const stop = listen(bytes => {
        heard += bytes

        const at = heard.search(DA1)

        if (at !== -1) {
          finish(heard.slice(0, at))
        }
      })
      const timer = setTimeout(() => finish(heard), ANSWER_MS)
      const finish = (answer: string) => {
        clearTimeout(timer)
        stop()
        resolve(answer)
      }

      write(query)
    })

  return {
    size: () => {
      process.stdout._refreshSize?.()

      const { columns, rows } = process.stdout

      return columns !== undefined && rows !== undefined && columns > 0 && rows > 0 ? { width: columns, height: rows } : undefined
    },
    onResize: heard => {
      process.stdout.on('resize', heard)

      return () => process.stdout.off('resize', heard)
    },
    keys: listen,
    write,
    ask,
    onSignal: (signal: Signal, heard) => {
      process.on(signal, heard)

      if (signal === 'SIGHUP') {
        hangUps.add(heard)
      }

      return () => {
        process.off(signal, heard)
        hangUps.delete(heard)
      }
    },
    suspend: () => void process.kill(process.pid, 'SIGTSTP'),
  }
}
