/**
 * The lines the panel writes: a snooze, or a wake, each run as `sitrep
 * snooze` or `sitrep wake` runs it (acts.ts), on the words the app's row
 * menu gives the command (`SitRepCLI.snooze`, `.wake`), so each is the
 * command's own line in the CLI's own file, refused as the command refuses
 * it. A snooze whose time has come already writes nothing, said as the
 * notch says it (`WakeTime.comeAlready`), as Tonight's has on a menu opened
 * before its time and chosen after.
 */
import { wakeWords } from '../../core'
import { actOnWords, type Acted } from '../acts'
import { snooze, wake } from '../commands'
import type { Io } from '../io'
import type { Write } from './state'

const COMMANDS = { snooze, wake }

/** The words `sitrep` is given after the command's name: a snooze's time, where it has one, its session, then after `--` the asks its row showed, so none reads as a flag. */
export const wordsOf = (write: Write): string[] =>
  write.command === 'wake'
    ? ['--session', write.session]
    : [...(write.until === undefined ? [] : ['--until', String(write.until)]), '--session', write.session, '--', ...write.asks]

/** Why a snooze to a time come already at `now` writes nothing, in the notch's words; nothing for a time still to come, or none. */
const comeAlready = (write: Write, now: number) =>
  write.command === 'snooze' && write.until !== undefined && write.until <= now ? `${wakeWords(write.until, now)} has come already.` : undefined

/** The line written, or why not. */
export const written = async (io: Io, write: Write): Promise<Acted> => {
  const why = comeAlready(write, io.now())

  return why === undefined ? actOnWords(io, COMMANDS[write.command], wordsOf(write)) : { ok: false, error: why, ending: 'refused' }
}
