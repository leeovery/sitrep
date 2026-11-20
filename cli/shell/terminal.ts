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
 * - A program handed the terminal runs with the run's standard input,
 *   output and error, raw mode let go already by the panel. While it runs,
 *   SIGINT and SIGQUIT are heard and ignored, so the keys that send them to
 *   the whole job reach the program alone: a caught signal goes back to its
 *   default in a program started, where an ignored one would stay ignored.
 *   SIGTSTP keeps its default, so Ctrl-Z stops the run with the program,
 *   and the shell's `fg` goes on with both: the run can't see a program
 *   stop, so a run that heard it would hold the terminal from the shell,
 *   the program stopped (proven live, 19 November 2026).
 * - A program run apart from the terminal reads nothing, its output and
 *   error piped back. Past its time it is killed, SIGKILL, which it can't
 *   hear, and the run answers then, never waiting on its pipes: what it
 *   started may hold them open.
 */
import { KEYED, type Ran, type Signal, type Terminal } from '../io'

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

/** What hears the keyed signals while a program has the terminal, keeping their defaults from the run. */
const ignored = () => {}

/** The program, given the terminal until it ends: its exit code. */
const hand = async (argv: readonly string[]) => {
  KEYED.forEach(signal => process.on(signal, ignored))

  try {
    return await Bun.spawn([...argv], { stdin: 'inherit', stdout: 'inherit', stderr: 'inherit' }).exited
  } finally {
    KEYED.forEach(signal => process.off(signal, ignored))
  }
}

/** The program, run apart from the terminal up to `ms`: how it ended and what it wrote; rejected at `ms`, killed, where it hasn't ended by then. */
const run = async (argv: readonly string[], ms: number): Promise<Ran> => {
  const child = Bun.spawn([...argv], { stdin: 'ignore', stdout: 'pipe', stderr: 'pipe' })
  const ran = Promise.all([new Response(child.stdout).text(), new Response(child.stderr).text(), child.exited])
  let timer: ReturnType<typeof setTimeout> | undefined
  const late = new Promise<never>((_, reject) => {
    timer = setTimeout(() => {
      child.kill('SIGKILL')
      reject(new Error(`${argv[0] ?? 'the program'} gave no answer within ${ms} ms`))
    }, ms)
  })

  try {
    const [out, err, exit] = await Promise.race([ran, late])

    return { exit, out, err }
  } finally {
    clearTimeout(timer)
  }
}

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
    hand,
    run,
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
