/**
 * The golden frames' checker, on Bun: `bun cli/frames/check.ts`.
 *
 * - Every fixture is drawn and held to its frame in tests/frames,
 *   `panel-<screen>-<W>x<H>`, cell for cell: its `.txt` row for row, its
 *   `.ansi` read back into cells. A kept frame nothing draws fails.
 * - `--update` writes every frame again from what the panel draws, and
 *   deletes those nothing draws.
 * - The sweep draws every fixture at the rounds' sizes and runs the width
 *   checks; a break fails, but the ones drawn on purpose, which fail once
 *   no longer drawn.
 *
 * It exits 1 on any failure, saying each.
 */
import { existsSync, mkdirSync, readdirSync, readFileSync, unlinkSync, writeFileSync } from 'node:fs'
import type { Size } from '../panel/cells'
import { ansi, text } from '../panel/draw'
import { compare, describe, read } from './cells'
import { drawn, FIXTURES, frameName, NAMES, ZONE, type Fixture } from './fixtures'
import { sweep, type Rule } from './sweep'

const FRAMES = `${import.meta.dir}/../../tests/frames`

const FRAME_FILE = /^panel-.+\.(txt|ansi)$/

/** The sizes the sweep draws at: the iPad's small window, its slide-over, a Ghostty pane, the iPad's main window, the widest, and short. */
const SWEEP_SIZES: readonly Size[] = [
  { width: 39, height: 27 },
  { width: 69, height: 46 },
  { width: 73, height: 36 },
  { width: 114, height: 45 },
  { width: 173, height: 53 },
  { width: 73, height: 15 },
]

/** What a frame drawn on purpose shows that a width check takes for a break. */
const ON_PURPOSE: readonly { screen: string; rule: Rule; why: string }[] = [
  {
    screen: 'quiet',
    rule: 'a wasted third',
    why: 'an empty board says "All clear" and one short line, centred; nothing is there to widen',
  },
]

/** The widest the panel lays out. */
const MOST = 120

const MARKS = /[●○✻◌◉]/u

const OUT_OF_VIEW = /▼ \d+ more/u

/** The most rows of a `.txt` a failure names. */
const SHOWN = 20

type Frame = { name: string; size: Size; txt: string; ansi: string }

const frameOf = (fixture: Fixture): Frame => {
  const lines = drawn(fixture)

  return { name: frameName(fixture), size: fixture.size, txt: text(lines), ansi: ansi(lines, fixture.paint.level) }
}

const pathOf = (file: string) => `${FRAMES}/${file}`

/** The rows a `.txt` is drawn otherwise than its frame, counted from 1. */
const txtHeld = (name: string, kept: string, txt: string): string[] => {
  const [was, now] = [kept.split('\n'), txt.split('\n')]
  const rows = Array.from({ length: Math.max(was.length, now.length) }, (_, at) => at).filter(at => was[at] !== now[at])
  const more = rows.length > SHOWN ? [`  and ${rows.length - SHOWN} more`] : []

  return rows.length === 0
    ? []
    : [
        `${name}.txt draws ${rows.length} rows otherwise than its frame:`,
        ...rows.slice(0, SHOWN).map(at => `  row ${at + 1}: the frame's ${JSON.stringify(was[at] ?? '')}, drawn ${JSON.stringify(now[at] ?? '')}`),
        ...more,
      ]
}

const ansiHeld = (name: string, kept: string, output: string, size: Size): string[] => {
  try {
    const diffs = compare(read(kept, size, false), read(output, size, false))

    return diffs.length === 0 ? [] : [describe(`${name}.ansi`, diffs)]
  } catch (error) {
    return [`${name}.ansi: ${error instanceof Error ? error.message : String(error)}`]
  }
}

/** How the frame is drawn otherwise than its files in tests/frames. */
const held = ({ name, size, txt, ansi: output }: Frame): string[] => {
  const [txtPath, ansiPath] = [pathOf(`${name}.txt`), pathOf(`${name}.ansi`)]

  if (!existsSync(txtPath) || !existsSync(ansiPath)) {
    return [`${name}: no frame; bun cli/frames/check.ts --update writes it`]
  }

  return [...txtHeld(name, readFileSync(txtPath, 'utf8'), txt), ...ansiHeld(name, readFileSync(ansiPath, 'utf8'), output, size)]
}

/** The frame files kept that no fixture draws. */
const keptUndrawn = (frames: readonly Frame[]) => {
  const drawnFiles = new Set(frames.flatMap(({ name }) => [`${name}.txt`, `${name}.ansi`]))

  return existsSync(FRAMES) ? readdirSync(FRAMES).filter(file => FRAME_FILE.test(file) && !drawnFiles.has(file)) : []
}

const update = (frames: readonly Frame[]): string[] => {
  mkdirSync(FRAMES, { recursive: true })
  frames.forEach(({ name, txt, ansi: output }) => {
    writeFileSync(pathOf(`${name}.txt`), txt)
    writeFileSync(pathOf(`${name}.ansi`), output)
  })

  const undrawn = keptUndrawn(frames)

  undrawn.forEach(file => unlinkSync(pathOf(file)))

  return [`${frames.length} frames written`, ...undrawn.map(file => `deleted ${file}: nothing draws it`)]
}

const check = (frames: readonly Frame[]): { said: string[]; failures: string[] } => {
  const failures = [...frames.flatMap(held), ...keptUndrawn(frames).map(file => `${file}: kept, but nothing draws it`)]

  return { said: failures.length === 0 ? [`${frames.length} frames drawn, each to its frame, cell for cell`] : [], failures }
}

/** Whether a frame of the screen breaks the rule on purpose. */
const isOnPurpose = (screen: string, rule: Rule) => ON_PURPOSE.some(each => each.screen === screen && each.rule === rule)

/** Every rule every fixture breaks at every size the sweep draws at. */
const breaksSwept = () =>
  FIXTURES.flatMap(fixture => {
    const draws = fixture.screen === 'quiet' ? undefined : (rows: readonly string[]) => rows.some(row => MARKS.test(row))

    return SWEEP_SIZES.flatMap(size => {
      const grid = read(ansi(drawn(fixture, size), fixture.paint.level), size, false)
      const at = `${frameName(fixture)} at ${size.width}×${size.height}`

      return sweep(grid, { names: NAMES, outOfView: OUT_OF_VIEW, draws, most: MOST }).map(found => ({ screen: fixture.screen, at, ...found }))
    })
  })

/** The width checks: a break fails, but one on purpose, which fails once no frame draws it. */
const swept = (): { said: string[]; failures: string[] } => {
  const breaks = breaksSwept()
  const broken = breaks.filter(each => !isOnPurpose(each.screen, each.rule)).map(each => `${each.at}: ${each.rule}, ${each.shown}`)
  const onPurpose = ON_PURPOSE.map(({ screen, rule, why }) => {
    const hits = breaks.filter(each => each.screen === screen && each.rule === rule).length

    return { line: `on purpose, ${screen}, ${rule}: ${hits === 0 ? 'NO LONGER DRAWN' : `${hits} frames`} (${why})`, isGone: hits === 0 }
  })

  return {
    said: [`width checks: ${broken.length === 0 ? 'none broken' : `${broken.length} broken`}`, ...onPurpose.map(each => each.line)],
    failures: [...broken, ...onPurpose.filter(each => each.isGone).map(each => each.line)],
  }
}

const main = (args: readonly string[]) => {
  const unknown = args.filter(arg => arg !== '--update')

  if (unknown.length > 0) {
    process.stdout.write(`usage: bun cli/frames/check.ts [--update]; not read: ${unknown.join(' ')}\n`)
    return 2
  }

  process.env.TZ = ZONE

  const frames = FIXTURES.map(frameOf)
  const golden = args.includes('--update') ? { said: update(frames), failures: [] } : check(frames)
  const widths = swept()
  const failures = [...golden.failures, ...widths.failures]

  process.stdout.write([...golden.said, ...widths.said, ...failures].map(line => `${line}\n`).join(''))

  return failures.length === 0 ? 0 : 1
}

process.exitCode = main(process.argv.slice(2))
