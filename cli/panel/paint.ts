/**
 * The panel's colours: the notch's inks over the terminal's own background,
 * at the level the terminal draws, and the pens each word is drawn in.
 *
 * - The level comes from the environment: none with `NO_COLOR`; else 24-bit,
 *   256 or 16 as `COLORTERM` and `TERM` say, raised to the least
 *   `FORCE_COLOR` asks for, or none where it says `0`.
 * - A light background, said by `COLORFGBG` or by the terminal's own
 *   answer, draws in the terminal's 16, the palette being drawn for dark
 *   ones.
 * - Names and the keys are in the terminal's own ink, never a hex.
 * - Three things mix toward the background: an away row's words, a Snoozed
 *   row's mark, and a new ask's wash. They mix only with both of the
 *   terminal's answers, at 256 colours or more; otherwise a dim is faint.
 *   On the band, a dim mixes toward the band's ground instead.
 *   The wash is left out below 24-bit, where its nearest colour sits beside
 *   the band's, so an arriving row would look chosen: `◉` says it alone.
 * - An answer sending is drawn ink on white: the background's colour on the
 *   terminal's ink, with both answers at 256 colours or more; else reverse
 *   video.
 * - The band stands off the background by one step of contrast, the
 *   faintest that still reads as a chosen row and a touch more: the
 *   background moved toward `BAND` by the least that reaches it, or toward
 *   the terminal's ink where `BAND` can't. With no background answered,
 *   it is the step over a near-black one.
 * - Without colour, faint carries the metadata, never on a bold word, since
 *   many terminals draw SGR 1 and 2 as one intensity.
 */

export type Level = 'truecolor' | '256' | '16' | 'none'

export type Rgb = readonly [number, number, number]

/** A colour as a pen holds it: red, green and blue, drawn at 256 colours as the nearest of xterm's; or one of the terminal's own 16. */
export type Ink = { rgb: Rgb } | { ansi: number }

export type Pen = { fg?: Ink; bg?: Ink; bold?: boolean; faint?: boolean; reverse?: boolean }

/** What the terminal said: the level it draws at, and its foreground and background where it answered. */
export type Paint = { level: Level; fg?: Rgb; bg?: Rgb }

export const rgbOf = (hex: string): Rgb => [
  Number.parseInt(hex.slice(1, 3), 16),
  Number.parseInt(hex.slice(3, 5), 16),
  Number.parseInt(hex.slice(5, 7), 16),
]

/** The inks round 4 was drawn and picked in, and round 5's for Claude's pick: Claude Code's suggestion lilac, and its tag's. */
export const PALETTE = {
  orange: rgbOf('#D77757'),
  blue: rgbOf('#7AA2F7'),
  soft: rgbOf('#A9B1D6'),
  grey: rgbOf('#7A82AB'),
  rule: rgbOf('#565F89'),
  pick: rgbOf('#B1B9F9'),
  pickTag: rgbOf('#9AA2EE'),
}

/** The cool grey the band's ground leans toward from the background. */
export const BAND = rgbOf('#3E4A5B')

/** How far toward `BAND` the band's step is measured on `DARK`: a touch above the faintest that reads (Lee, 20 November 2026). */
const BANDED = 0.25

/** The background the band's step is measured on, and mixed from where the terminal didn't answer: a near-black, as most dark themes are. */
const DARK = rgbOf('#212121')

const WHITE: Rgb = [255, 255, 255]

/** How far a dimmed ink goes toward the background: the notch keeps 0.61 of it. */
const DIMMED = 0.39

/** How much orange a new ask's wash mixes into the background. */
const WASHED = 0.22

/** How far a held answer's `· Recommended` goes from the background toward the terminal's ink, its ground: the notch draws it in ink at half. */
const HELD_TAG = 0.4

/** A word's ink: one of the palette's, or the terminal's own. */
export type Tone = keyof typeof PALETTE | 'ink'

/** How a word is drawn at any level: its ink, its weight, and whether it is metadata, faint without colour. */
export type Style = { tone: Tone; bold?: boolean; isMeta?: boolean }

/** The terminal's own 16 standing in for the palette: none for the terminal's ink. */
const SIXTEEN: Record<Tone, number | undefined> = {
  ink: undefined,
  orange: 3,
  blue: 4,
  soft: undefined,
  grey: 8,
  rule: 8,
  pick: 12,
  pickTag: 4,
}

/** The tones drawn faint at 16 colours, where their own 16 is too loud: the rule, and the pick's tag. */
const FAINT_AT_16: ReadonlySet<Tone> = new Set(['rule', 'pickTag'])

/** `a` moved `t` of the way to `b`. */
export const mix = (a: Rgb, b: Rgb, t: number): Rgb => [
  Math.round(a[0] + (b[0] - a[0]) * t),
  Math.round(a[1] + (b[1] - a[1]) * t),
  Math.round(a[2] + (b[2] - a[2]) * t),
]

const CUBE = [0, 95, 135, 175, 215, 255]

/** xterm's colour `n`, from 16: its 6×6×6 cube, then its 24 greys. */
const xterm = (n: number): Rgb => {
  if (n >= 232) {
    const grey = 8 + (n - 232) * 10

    return [grey, grey, grey]
  }

  const at = n - 16

  return [CUBE[Math.floor(at / 36)] ?? 0, CUBE[Math.floor(at / 6) % 6] ?? 0, CUBE[at % 6] ?? 0]
}

const XTERM = Array.from({ length: 240 }, (_, at) => xterm(at + 16))

const distance = (a: Rgb, b: Rgb) => (a[0] - b[0]) ** 2 + (a[1] - b[1]) ** 2 + (a[2] - b[2]) ** 2

/** The nearest of xterm's 256 colours past the terminal's own 16. */
export const nearest256 = (rgb: Rgb): number =>
  XTERM.reduce((best, each, at) => (distance(each, rgb) < distance(XTERM[best] ?? each, rgb) ? at : best), 0) + 16

const luminance = (rgb: Rgb) => {
  const linear = (channel: number) => {
    const c = channel / 255

    return c <= 0.03928 ? c / 12.92 : ((c + 0.055) / 1.055) ** 2.4
  }

  return 0.2126 * linear(rgb[0]) + 0.7152 * linear(rgb[1]) + 0.0722 * linear(rgb[2])
}

/** A background with more contrast against black than against white. */
const isLight = (rgb: Rgb) => (luminance(rgb) + 0.05) / 0.05 > 1.05 / (luminance(rgb) + 0.05)

/** The contrast between two colours, as WCAG measures it. */
const contrast = (a: Rgb, b: Rgb) => {
  const [one, other] = [luminance(a) + 0.05, luminance(b) + 0.05]

  return Math.max(one, other) / Math.min(one, other)
}

/** The step the band stands off any background by: `BANDED` toward `BAND` on `DARK`, about 1.13 : 1. */
const STEP = contrast(mix(DARK, BAND, BANDED), DARK)

/** The loudest a band may stand off its background: `BAND` itself on `DARK`, the band before 20 November 2026, about 1.79 : 1. */
const LOUDEST = contrast(BAND, DARK)

/** The amounts a band's mix tries, in hundredths, least first. */
const AMOUNTS = Array.from({ length: 101 }, (_, at) => at / 100)

/** The background moved toward `target` by the least amount that stands it off by `STEP`, never past `LOUDEST`. */
const steppedToward = (bg: Rgb, target: Rgb): Rgb | undefined => {
  const isStep = (ground: Rgb) => contrast(ground, bg) >= STEP && contrast(ground, bg) <= LOUDEST
  const amount = AMOUNTS.find(each => isStep(mix(bg, target, each)))

  return amount === undefined ? undefined : mix(bg, target, amount)
}

/** The band's ground: the background stepped toward `BAND`, for its cool tint; else toward the terminal's ink, white unanswered; else, with neither, `BANDED` toward `BAND`. */
const bandOn = (bg: Rgb, fg: Rgb = WHITE): Rgb => steppedToward(bg, BAND) ?? steppedToward(bg, fg) ?? mix(bg, BAND, BANDED)

/** The environment the level reads. */
export type ColourEnv = {
  NO_COLOR?: string
  FORCE_COLOR?: string
  COLORTERM?: string
  TERM?: string
  COLORFGBG?: string
}

/** The levels, from none up. */
const LEVELS: readonly Level[] = ['none', '16', '256', 'truecolor']

/** The level `COLORTERM` and `TERM` say. */
const detected = (env: ColourEnv): Level => {
  const term = env.TERM ?? ''

  if (/^(truecolor|24bit)$/i.test(env.COLORTERM ?? '') || term.includes('ghostty') || term.endsWith('-direct')) {
    return 'truecolor'
  }

  return term.includes('256color') ? '256' : '16'
}

/** The least level `FORCE_COLOR` asks for, as chalk reads it: none for `0` or `false`; 256 for 2; 24-bit for 3 or more; else 16. */
const leastOf = (force: string): Level => {
  const level = /^\d+$/.test(force) ? Number(force) : force === 'false' ? 0 : 1

  return level === 0 ? 'none' : level === 1 ? '16' : level === 2 ? '256' : 'truecolor'
}

/** The level the terminal says, raised to what `FORCE_COLOR` asks for at least; `0` or `false` turns colour off. */
const forced = (env: ColourEnv): Level => {
  const least = env.FORCE_COLOR === undefined ? '16' : leastOf(env.FORCE_COLOR)
  const said = detected(env)

  if (least === 'none') {
    return 'none'
  }

  return LEVELS.indexOf(said) > LEVELS.indexOf(least) ? said : least
}

/** `COLORFGBG`'s background, its last field, as rxvt numbers it: 7, and 9 to 15, are light. */
const isLightByEnv = (env: ColourEnv) => {
  const background = Number(env.COLORFGBG?.split(';').at(-1) ?? '')

  return background === 7 || (background >= 9 && background <= 15)
}

/** The level the environment says the terminal draws at. */
export const levelOf = (env: ColourEnv): Level => {
  if ((env.NO_COLOR ?? '') !== '') {
    return 'none'
  }

  const level = forced(env)

  return level !== 'none' && isLightByEnv(env) ? '16' : level
}

/** The pens a frame draws in, from what the terminal said. */
export type Pens = {
  of: (style: Style) => Pen
  /** The style dimmed as the notch dims, 0.61 of the way from the background. */
  dimmed: (style: Style) => Pen
  /** The style dimmed on the band, 0.61 of the way from the band's ground, so it reads there as it does off it. */
  bandDimmed: (style: Style) => Pen
  /** What the band lays over the chosen row's cells. */
  band: Pen
  /** What a new ask's wash lays over its row's cells, at 24-bit with both answers. */
  wash?: Pen
  /** An answer sending: the background's colour on the terminal's ink, with both answers at 256 colours or more; else reverse video. */
  held: Pen
  /** A held answer's `· Recommended`: its ink part of the way from the background toward the ground, as `held` falls back. */
  heldTag: Pen
  /** Whether the pens carry colour: without it, bold alone tells an ask. */
  isColoured: boolean
}

/** The level the palette draws at: the terminal's 16 on a light background. */
const levelFor = (paint: Paint): Level =>
  (paint.level === 'truecolor' || paint.level === '256') && paint.bg !== undefined && isLight(paint.bg)
    ? '16'
    : paint.level

const inkAt = (tone: Tone, level: Level): Ink | undefined => {
  if (level === 'none' || tone === 'ink') {
    return undefined
  }

  if (level === '16') {
    const ansi = SIXTEEN[tone]

    return ansi === undefined ? undefined : { ansi }
  }

  return { rgb: PALETTE[tone] }
}

const isFaintAt = (style: Style, level: Level) =>
  (level === 'none' && style.isMeta === true && style.bold !== true) || (level === '16' && FAINT_AT_16.has(style.tone))

/** A pen with only what it sets, so two pens alike compare alike. */
const penOf = (fg: Ink | undefined, bold: boolean, faint: boolean): Pen => ({
  ...(fg === undefined ? {} : { fg }),
  ...(bold ? { bold } : {}),
  ...(faint ? { faint } : {}),
})

export const pensOf = (paint: Paint): Pens => {
  const level = levelFor(paint)
  const { fg, bg } = paint
  const canMix = (level === 'truecolor' || level === '256') && fg !== undefined && bg !== undefined
  const of = (style: Style) => penOf(inkAt(style.tone, level), style.bold === true, isFaintAt(style, level))

  const bandGround = bandOn(bg ?? DARK, fg)

  const dimmedOver = (ground: Rgb | undefined) => (style: Style) => {
    if (!canMix || ground === undefined) {
      return penOf(inkAt(style.tone, level), style.bold === true, style.bold !== true)
    }

    const ink = style.tone === 'ink' ? fg : PALETTE[style.tone]

    return penOf({ rgb: mix(ink, ground, DIMMED) }, style.bold === true, false)
  }

  const isGround = level === 'truecolor' || level === '256'

  return {
    of,
    dimmed: dimmedOver(bg),
    bandDimmed: dimmedOver(bandGround),
    band: isGround ? { bg: { rgb: bandGround } } : { reverse: true },
    held: canMix ? { fg: { rgb: bg }, bg: { rgb: fg } } : { reverse: true },
    heldTag: canMix ? { fg: { rgb: mix(bg, fg, HELD_TAG) }, bg: { rgb: fg } } : { reverse: true },
    isColoured: level !== 'none',
    ...(canMix && level === 'truecolor' ? { wash: { bg: { rgb: mix(bg, PALETTE.orange, WASHED) } } } : {}),
  }
}

const colourCode = (ink: Ink, level: Level, ground: boolean) => {
  if ('ansi' in ink) {
    const base = ink.ansi < 8 ? (ground ? 40 : 30) : ground ? 92 : 82

    return String(base + ink.ansi)
  }

  const extended = ground ? 48 : 38

  return level === 'truecolor' ? `${extended};2;${ink.rgb.join(';')}` : `${extended};5;${nearest256(ink.rgb)}`
}

/** The SGR that sets the pen from any other, at the level: no colour at all with none. */
export const sgr = (pen: Pen, level: Level): string => {
  const codes = ['0']
  const inks = level === 'none' ? [] : ([[pen.fg, false], [pen.bg, true]] as const)

  if (pen.bold === true) {
    codes.push('1')
  }

  if (pen.faint === true) {
    codes.push('2')
  }

  if (pen.reverse === true) {
    codes.push('7')
  }

  for (const [ink, ground] of inks) {
    if (ink !== undefined) {
      codes.push(colourCode(ink, level, ground))
    }
  }

  return `\x1b[${codes.join(';')}m`
}
