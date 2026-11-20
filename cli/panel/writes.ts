/**
 * The lines the panel writes: a snooze, or a wake, each run as `sitrep
 * snooze` or `sitrep wake` runs it (acts.ts), on the words the app's row
 * menu gives the command (`SitRepCLI.snooze`, `.wake`), so each is the
 * command's own line in the CLI's own file, refused as the command refuses
 * it.
 */
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

/** The line written, or why not. */
export const written = (io: Io, write: Write): Promise<Acted> => actOnWords(io, COMMANDS[write.command], wordsOf(write))
