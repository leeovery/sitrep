/**
 * The CLI's run, on the words it was given: what bin/sitrep runs on Bun,
 * and what `bun build --compile` compiles for the copy the app carries,
 * since Bun reads a file only by its extension.
 */
import { shell } from '.'

await shell()
