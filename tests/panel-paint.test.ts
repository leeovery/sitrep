import { expect, test } from './kit'
import {
  levelOf,
  nearest256,
  PALETTE,
  BAND,
  pensOf,
  rgbOf,
  sgr,
  type Paint,
  type Style,
} from '../cli/panel/paint'

/** Nordfox, the background and foreground the frames are drawn on. */
const FG = rgbOf('#CDCECF')
const BG = rgbOf('#2E3440')

const ESC = '\u001b'

/** The pens every word of the panel is drawn in, by what each draws. */
const STYLES: Record<string, Style> = {
  name: { tone: 'ink', bold: true },
  orange: { tone: 'orange' },
  blue: { tone: 'blue', bold: true },
  soft: { tone: 'soft' },
  heading: { tone: 'grey' },
  meta: { tone: 'grey', isMeta: true },
  rule: { tone: 'rule', isMeta: true },
}

/** Each style's escape at the level, the band's last. */
const escapes = (paint: Paint) => {
  const pens = pensOf(paint)

  return [...Object.values(STYLES).map(style => pens.of(style)), pens.band].map(pen => sgr(pen, paint.level))
}

test('the level: none with NO_COLOR, else 24-bit, 256 or 16 as COLORTERM and TERM say, in any case', () => {
  const envs = [
    { NO_COLOR: '', TERM: 'xterm-256color' },
    { COLORTERM: 'truecolor', TERM: 'xterm' },
    { COLORTERM: 'TrueColor' },
    { COLORTERM: '24BIT' },
    { TERM: 'xterm-ghostty' },
    { TERM: 'xterm-direct' },
    { TERM: 'tmux-256color' },
    { TERM: 'xterm' },
    {},
  ]

  expect(envs.map(levelOf)).toEqual(['256', 'truecolor', 'truecolor', 'truecolor', 'truecolor', 'truecolor', '256', '16', '16'])
})

test('FORCE_COLOR is a least level, as chalk reads it, 3 and more 24-bit: the terminal says more where it can; 0 or false turns colour off; NO_COLOR wins over all', () => {
  const envs = [
    { FORCE_COLOR: '1', COLORTERM: 'truecolor' },
    { FORCE_COLOR: '1', TERM: 'xterm-256color' },
    { FORCE_COLOR: '', TERM: 'dumb' },
    { FORCE_COLOR: 'true' },
    { FORCE_COLOR: '2', TERM: 'xterm' },
    { FORCE_COLOR: '2', COLORTERM: 'truecolor' },
    { FORCE_COLOR: '3', TERM: 'dumb' },
    { FORCE_COLOR: '4', TERM: 'dumb' },
    { FORCE_COLOR: '0', COLORTERM: 'truecolor' },
    { FORCE_COLOR: 'false', TERM: 'xterm-256color' },
    { NO_COLOR: '1', FORCE_COLOR: '3', COLORTERM: 'truecolor' },
  ]

  expect(envs.map(levelOf)).toEqual([
    'truecolor',
    '256',
    '16',
    '16',
    '256',
    'truecolor',
    'truecolor',
    'truecolor',
    'none',
    'none',
    'none',
  ])
})

test("a light background by COLORFGBG draws in the terminal's 16; a dark one keeps its level", () => {
  expect(levelOf({ COLORTERM: 'truecolor', COLORFGBG: '0;15' })).toBe('16')
  expect(levelOf({ TERM: 'xterm-256color', COLORFGBG: '0;default;7' })).toBe('16')
  expect(levelOf({ COLORTERM: 'truecolor', COLORFGBG: '15;0' })).toBe('truecolor')
  expect(levelOf({ NO_COLOR: '1', COLORFGBG: '0;15' })).toBe('none')
})

test("the palette at 256 colours is the nearest of xterm's to each ink", () => {
  expect(Object.values(PALETTE).map(nearest256)).toEqual([173, 111, 146, 103, 60])
})

test("the band is the terminal's background moved a quarter of the way toward #3E4A5B, its nearest at 256 colours; the foreground isn't needed", () => {
  const grounds = [BG, rgbOf('#212121')].flatMap(bg => [
    sgr(pensOf({ level: 'truecolor', fg: FG, bg }).band, 'truecolor'),
    sgr(pensOf({ level: '256', bg }).band, '256'),
  ])

  expect(grounds).toEqual([`${ESC}[0;48;2;50;58;71m`, `${ESC}[0;48;5;237m`, `${ESC}[0;48;2;40;43;48m`, `${ESC}[0;48;5;236m`])
  expect(pensOf({ level: 'truecolor', bg: BAND }).band).toEqual({ bg: { rgb: BAND } })
})

test("without the background's answer, the band is that quarter step over a near-black #212121, darker than #3E4A5B", () => {
  expect(pensOf({ level: 'truecolor', fg: FG }).band).toEqual({ bg: { rgb: [40, 43, 48] } })
  expect(sgr(pensOf({ level: '256' }).band, '256')).toBe(`${ESC}[0;48;5;236m`)
})

test("on the band, a dim mixes toward the band's ground, so a hollow row's words keep there the step they have off it", () => {
  const pens = pensOf({ level: 'truecolor', fg: FG, bg: BG })

  expect(
    [
      pens.bandDimmed({ tone: 'ink', bold: true }),
      pens.bandDimmed({ tone: 'grey', isMeta: true }),
      pens.bandDimmed({ tone: 'orange' }),
    ].map(pen => sgr(pen, 'truecolor')),
  ).toEqual([`${ESC}[0;1;38;2;145;148;154m`, `${ESC}[0;38;2;94;102;132m`, `${ESC}[0;38;2;151;95;81m`])
  expect(sgr(pens.dimmed({ tone: 'grey', isMeta: true }), 'truecolor')).toBe(`${ESC}[0;38;2;92;100;129m`)
})

test("each pen's escape at 24-bit: the palette's own inks, the terminal's ink for names, the band a ground", () => {
  expect(escapes({ level: 'truecolor' })).toEqual([
    `${ESC}[0;1m`,
    `${ESC}[0;38;2;215;119;87m`,
    `${ESC}[0;1;38;2;122;162;247m`,
    `${ESC}[0;38;2;169;177;214m`,
    `${ESC}[0;38;2;122;130;171m`,
    `${ESC}[0;38;2;122;130;171m`,
    `${ESC}[0;38;2;86;95;137m`,
    `${ESC}[0;48;2;40;43;48m`,
  ])
})

test("each pen's escape at 256 colours: the nearest of each", () => {
  expect(escapes({ level: '256' })).toEqual([
    `${ESC}[0;1m`,
    `${ESC}[0;38;5;173m`,
    `${ESC}[0;1;38;5;111m`,
    `${ESC}[0;38;5;146m`,
    `${ESC}[0;38;5;103m`,
    `${ESC}[0;38;5;103m`,
    `${ESC}[0;38;5;60m`,
    `${ESC}[0;48;5;236m`,
  ])
})

test("each pen's escape at 16 colours: the terminal's own, the rule faint, the band reverse video", () => {
  expect(escapes({ level: '16' })).toEqual([
    `${ESC}[0;1m`,
    `${ESC}[0;33m`,
    `${ESC}[0;1;34m`,
    `${ESC}[0m`,
    `${ESC}[0;90m`,
    `${ESC}[0;90m`,
    `${ESC}[0;2;90m`,
    `${ESC}[0;7m`,
  ])
})

test('with NO_COLOR, no colour at all: metadata faint, never a bold word, the band reverse video', () => {
  expect(escapes({ level: 'none' })).toEqual([
    `${ESC}[0;1m`,
    `${ESC}[0m`,
    `${ESC}[0;1m`,
    `${ESC}[0m`,
    `${ESC}[0m`,
    `${ESC}[0;2m`,
    `${ESC}[0;2m`,
    `${ESC}[0;7m`,
  ])
  expect(sgr({ fg: { rgb: PALETTE.orange }, bg: { ansi: 4 }, bold: true }, 'none')).toBe(`${ESC}[0;1m`)
})

test("with both of the terminal's answers, an away row's words, a Snoozed mark and the wash are mixed toward its background", () => {
  const pens = pensOf({ level: 'truecolor', fg: FG, bg: BG })

  expect(
    [
      pens.dimmed({ tone: 'ink', bold: true }),
      pens.dimmed({ tone: 'grey', isMeta: true }),
      pens.dimmed({ tone: 'orange' }),
      pens.dimmed({ tone: 'blue' }),
      pens.wash ?? {},
    ].map(pen => sgr(pen, 'truecolor')),
  ).toEqual([
    `${ESC}[0;1;38;2;143;146;151m`,
    `${ESC}[0;38;2;92;100;129m`,
    `${ESC}[0;38;2;149;93;78m`,
    `${ESC}[0;38;2;92;119;176m`,
    `${ESC}[0;48;2;83;67;69m`,
  ])
})

test("at 256 colours the dims mix, as at 24-bit, but the wash is left out: its nearest sits beside the band's", () => {
  const pens = pensOf({ level: '256', fg: FG, bg: BG })

  expect(pens.wash).toBeUndefined()
  expect(sgr(pens.dimmed({ tone: 'orange' }), '256')).toBe(`${ESC}[0;38;5;95m`)
  expect(sgr(pens.dimmed({ tone: 'ink', bold: true }), '256')).toBe(`${ESC}[0;1;38;5;246m`)
})

test("without both answers, or at 16 colours, a dim is faint, never on a bold word, and there's no wash", () => {
  const paints: Paint[] = [
    { level: 'truecolor', bg: BG },
    { level: '256', fg: FG },
    { level: '16', fg: FG, bg: BG },
    { level: 'none', fg: FG, bg: BG },
  ]

  for (const paint of paints) {
    const pens = pensOf(paint)

    expect(pens.wash).toBeUndefined()
    expect(pens.isColoured).toBe(paint.level !== 'none')
    expect(pens.dimmed({ tone: 'ink' }).faint).toBe(true)
    expect(pens.dimmed({ tone: 'orange' }).faint).toBe(true)
    expect(pens.dimmed({ tone: 'ink', bold: true })).toEqual({ bold: true })
    expect(pens.bandDimmed({ tone: 'ink' })).toEqual(pens.dimmed({ tone: 'ink' }))
    expect(pens.bandDimmed({ tone: 'ink', bold: true })).toEqual({ bold: true })
  }

  expect(sgr(pensOf({ level: 'truecolor' }).dimmed({ tone: 'grey' }), 'truecolor')).toBe(
    `${ESC}[0;2;38;2;122;130;171m`,
  )
  expect(sgr(pensOf({ level: '16' }).dimmed({ tone: 'orange' }), '16')).toBe(`${ESC}[0;2;33m`)
})

test("a light background the terminal answered draws in its own 16, with no mix", () => {
  const pens = pensOf({ level: 'truecolor', fg: rgbOf('#2E3440'), bg: rgbOf('#ECEFF4') })

  expect(sgr(pens.of(STYLES.orange as Style), 'truecolor')).toBe(`${ESC}[0;33m`)
  expect(pens.band).toEqual({ reverse: true })
  expect(pens.wash).toBeUndefined()
})
