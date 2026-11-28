/**
 * The lines the panel writes: a snooze, a wake, an answer or an ignore, and
 * one ask snoozed alone, each run as `sitrep snooze`, `sitrep wake` or
 * `sitrep answer` runs it (acts.ts), on the words the app gives the command
 * (`SitRepCLI.snooze`, `.wake`, `.answer`), so each is the command's own
 * line in the command's own file, refused as the command refuses it. An
 * answer names what its ask wanted as shown (`--wants`), and comes after
 * `--` with its ask, so words such as `--force` arrive whole. A snooze whose
 * time has come already writes nothing, said as the notch says it
 * (`WakeTime.comeAlready`), as Tonight's has on a menu opened before its
 * time and chosen after.
 */
import { wakeWords } from '../../core'
import { actOnWords, type Acted } from '../acts'
import { answer, snooze, wake, type SessionCommand } from '../commands'
import type { Io } from '../io'
import type { Write } from './state'

/** The command each write runs. */
const COMMANDS: Record<Write['command'], SessionCommand> = { snooze, wake, answer, ignore: answer, snoozeAsk: snooze }

/** The words `sitrep` is given after the command's name: a snooze's time, where it has one, its session, then after `--` the asks its row showed, so none reads as a flag; an answer's session and what its ask wanted, then after `--` the ask and its answer. */
export const wordsOf = (write: Write): string[] => {
  switch (write.command) {
    case 'wake':
      return ['--session', write.session]
    case 'snooze':
      return [...(write.until === undefined ? [] : ['--until', String(write.until)]), '--session', write.session, '--', ...write.asks]
    case 'snoozeAsk':
      return ['--ask', write.ask, '--until', String(write.until), '--session', write.session]
    case 'answer':
      return ['--session', write.session, '--wants', write.wants, '--', write.ask, write.answer]
    case 'ignore':
      return ['--session', write.session, '--wants', write.wants, '--ignore', '--', write.ask]
  }
}

/** When a snooze wakes, where the write is one with a time. */
const untilOf = (write: Write) => (write.command === 'snooze' || write.command === 'snoozeAsk' ? write.until : undefined)

/** Why a snooze to a time come already at `now` writes nothing, in the notch's words; nothing for a time still to come, or none. */
const comeAlready = (write: Write, now: number) => {
  const until = untilOf(write)

  return until !== undefined && until <= now ? `${wakeWords(until, now)} has come already.` : undefined
}

/** The line written, or why not. */
export const written = async (io: Io, write: Write): Promise<Acted> => {
  const why = comeAlready(write, io.now())

  return why === undefined ? actOnWords(io, COMMANDS[write.command], wordsOf(write)) : { ok: false, error: why, ending: 'refused' }
}
