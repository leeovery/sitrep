/**
 * The terminal the CLI runs on, bound to Bun, for the panel: there only
 * while standard input and output are both a terminal.
 *
 * - Raw mode is on while anything listens to the keys or waits on an
 *   answer to a query, and off once nothing does.
 * - A query waits for DA1's answer up to a second. Past that, what comes
 *   in the second after is dropped, so a late answer is never read as keys.
 * - A terminal gone, as after a hang-up, fails nothing: a write to it is
 *   lost, and raw mode is let go without a word, so the panel gives the
 *   terminal back on every path, that one included.
 */
import type { Signal, Terminal } from '../io'

/** How long a query waits for DA1's answer, and how long after it gave up an answer is dropped. */
const ANSWER_MS = 1_000

/** DA1's answer: `CSI ? <attributes> c`. */
const DA1 = /\x1b\[\?[\d;]*c/

/** Does what it can with a terminal that may be gone: an error there means only that it is. */
const tried = (act: () => void) => {
  try {
    act()
  } catch {}
}

/** Hears a stream's error from a terminal gone, which unheard would end the run before the panel gives the terminal back. */
const lost = () => {}

/** Raw mode while any hold it, standard input read only then: each hold gives what lets it go, once. */
const rawHolds = () => {
  let holds = 0

  return () => {
    let isHeld = true

    if (holds++ === 0) {
      process.stdin.setEncoding('utf8')
      process.stdin.on('error', lost)
      process.stdin.setRawMode(true)
      process.stdin.resume()
    }

    return () => {
      if (isHeld && --holds === 0) {
        tried(() => process.stdin.setRawMode(false))
        process.stdin.pause()
        process.stdin.off('error', lost)
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

  const raw = rawHolds()
  let dropsUntil = 0
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
      const finish = (answer: string) => {
        clearTimeout(timer)
        stop()
        resolve(answer)
      }
      const timer = setTimeout(() => {
        dropsUntil = Date.now() + ANSWER_MS
        finish(heard)
      }, ANSWER_MS)
      const stop = listen(bytes => {
        heard += bytes

        const at = heard.search(DA1)

        if (at !== -1) {
          finish(heard.slice(0, at))
        }
      })

      write(query)
    })

  return {
    size: () => {
      const { columns, rows } = process.stdout

      return columns !== undefined && rows !== undefined && columns > 0 && rows > 0 ? { width: columns, height: rows } : undefined
    },
    onResize: heard => {
      process.stdout.on('resize', heard)

      return () => process.stdout.off('resize', heard)
    },
    keys: heard =>
      listen(bytes => {
        if (Date.now() >= dropsUntil) {
          heard(bytes)
        }
      }),
    write,
    ask,
    onSignal: (signal: Signal, heard) => {
      process.on(signal, heard)

      return () => process.off(signal, heard)
    },
    suspend: () => void process.kill(process.pid, 'SIGTSTP'),
  }
}
