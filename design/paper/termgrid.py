#!/usr/bin/env python3
"""termgrid: terminal screens as grids of cells, drawn for Paper and kept as golden frames.

A Canvas is a terminal screen, W columns by H rows. Each cell holds one glyph
in a Pen: a foreground, a background, bold, faint and reverse. A colour is the
terminal's own ('default', 'ansi:0' to 'ansi:15', '256:N') or 24-bit
('#RRGGBB'), as the SGR that sets it says. A Theme, the terminal's own colours,
resolves them to hex for Paper; the same theme gives look.tape its Set Theme.

Out of a Canvas come:
- HTML that Paper draws as a terminal does (the terminal-design skill's
  references/paper.md has the rules);
- golden frames: <key>.txt, the glyphs, and <key>.ansi, every cell as SGR;
- a preview page to open in a browser.

read_ansi() reads a real build's output into the same Canvas: SGR, newlines,
and the cursor moves a live region makes. compare() and describe() hold one
grid to another, cell for cell, as a golden-frame test does. sweep() runs the
width checks on a drawn frame.

Python 3 standard library only. Import it, or run it:

    termgrid.py read <file> --key K [--width W] [--height H] [--theme T] [--out DIR]
    termgrid.py compare <frame.ansi> <drawn.ansi>
    termgrid.py rows <dir of chunks>
    termgrid.py theme <name>
"""
import argparse
import html
import json
import os
import re
import sys
import unicodedata
from html.parser import HTMLParser
from typing import NamedTuple

# ---------------------------------------------------------------- colours

DEFAULT = 'default'

ANSI_NAMES = ['black', 'red', 'green', 'yellow', 'blue', 'magenta', 'cyan', 'white',
              'brightBlack', 'brightRed', 'brightGreen', 'brightYellow', 'brightBlue',
              'brightMagenta', 'brightCyan', 'brightWhite']

_HEX = re.compile(r'#[0-9A-Fa-f]{6}')


def colour(spec):
    """A colour spec normalised: 'default', 'ansi:N', '256:N' or '#RRGGBB'.
    An ANSI colour may be named, as 'cyan' or 'brightBlack'."""
    if spec is None or spec == DEFAULT:
        return DEFAULT
    if spec in ANSI_NAMES:
        return f'ansi:{ANSI_NAMES.index(spec)}'
    if _HEX.fullmatch(spec):
        return spec.upper()
    kind, _, n = spec.partition(':')
    if kind in ('ansi', '256') and n.isdigit() and int(n) < (16 if kind == 'ansi' else 256):
        return spec
    raise ValueError(f'not a colour: {spec!r}')


def hx(c):
    c = c.lstrip('#')
    return tuple(int(c[i:i + 2], 16) for i in (0, 2, 4))


def mix(a, b, t):
    """The hex colour t of the way from a to b."""
    a, b = hx(a), hx(b)
    return '#%02X%02X%02X' % tuple(round(a[i] + (b[i] - a[i]) * t) for i in range(3))


def _xterm256(n):
    if n < 232:
        n -= 16
        levels = (0, 95, 135, 175, 215, 255)
        return '#%02X%02X%02X' % (levels[n // 36], levels[n // 6 % 6], levels[n % 6])
    g = 8 + (n - 232) * 10
    return '#%02X%02X%02X' % (g, g, g)


class Theme:
    """A terminal's own colours: its background and foreground, and its sixteen."""

    def __init__(self, name, background, foreground, colours, selection=None, cursor=None):
        assert len(colours) == 16, 'a theme has sixteen colours'
        self.name = name
        self.background = background.upper()
        self.foreground = foreground.upper()
        self.colours = [c.upper() for c in colours]
        self.selection = (selection or mix(background, foreground, .15)).upper()
        self.cursor = (cursor or background).upper()

    @classmethod
    def from_vhs(cls, text):
        """A theme from vhs's Set Theme JSON, with or without the 'Set Theme'."""
        d = json.loads(text.split('Set Theme', 1)[-1])
        return cls(d.get('name', 'theme'), d['background'], d['foreground'],
                   [d[k] for k in ANSI_NAMES], d.get('selection'), d.get('cursor'))

    def vhs(self):
        """The look.tape line that gives vhs's terminal these colours."""
        d = {'name': self.name, 'background': self.background, 'foreground': self.foreground,
             'cursor': self.cursor, 'selection': self.selection}
        d.update(zip(ANSI_NAMES, self.colours))
        return 'Set Theme ' + json.dumps(d, separators=(', ', ': '))

    def hex(self, spec, ground=False):
        """The hex a colour draws as: 'default' is the background where it's a
        ground, the foreground where it's ink."""
        spec = colour(spec)
        if spec == DEFAULT:
            return self.background if ground else self.foreground
        if spec.startswith('#'):
            return spec
        kind, n = spec.split(':')
        n = int(n)
        return self.colours[n] if n < 16 else _xterm256(n)


NORDFOX = Theme('Nordfox', '#2E3440', '#CDCECF', [
    '#3B4252', '#BF616A', '#A3BE8C', '#EBCB8B', '#81A1C1', '#B48EAD', '#88C0D0', '#E5E9F0',
    '#53648D', '#D06F79', '#B1D196', '#F0D399', '#8CAFD2', '#C895BF', '#93CCDC', '#E7ECF4'],
    selection='#3E4A5B')

NORD = Theme('nord', '#2E3440', '#D8DEE9', [
    '#3B4252', '#BF616A', '#A3BE8C', '#EBCB8B', '#81A1C1', '#B48EAD', '#88C0D0', '#E5E9F0',
    '#4C566A', '#BF616A', '#A3BE8C', '#EBCB8B', '#81A1C1', '#B48EAD', '#8FBCBB', '#ECEFF4'],
    selection='#434C5E')

THEMES = {'nordfox': NORDFOX, 'nord': NORD}

# ---------------------------------------------------------------- cells


class Pen(NamedTuple):
    """What a glyph is drawn in."""
    fg: str = DEFAULT
    bg: str = DEFAULT
    bold: bool = False
    faint: bool = False
    reverse: bool = False


PLAIN = Pen()


def read_theme(text):
    """A theme file's tokens, {token: '#RRGGBB'}: the format Lee's themed tools
    share, one `token = #RRGGBB` a line, `#` starting a comment line."""
    tokens = {}
    for n, line in enumerate(text.splitlines(), 1):
        line = line.strip()
        if not line or line.startswith('#'):
            continue
        key, sep, value = (part.strip() for part in line.partition('='))
        if not sep or not re.fullmatch(r'#[0-9A-Fa-f]{6}', value):
            raise ValueError(f'theme line {n}: want token = #RRGGBB, got {line!r}')
        tokens[key] = value.upper()
    return tokens


def pen(fg=DEFAULT, bg=DEFAULT, bold=False, faint=False, reverse=False):
    """A Pen, its colours normalised."""
    return Pen(colour(fg), colour(bg), bold, faint, reverse)


def cell_width(ch):
    """How many cells a terminal gives the character: 0 for one that joins the
    glyph before it, 2 for a wide one, else 1. Ambiguous widths count as 1,
    as Western terminals draw them."""
    if unicodedata.combining(ch) or unicodedata.category(ch) in ('Mn', 'Me', 'Cf'):
        return 0
    return 2 if unicodedata.east_asian_width(ch) in 'WF' else 1


def width_of(text):
    return sum(cell_width(ch) for ch in text)


def cut(text, n):
    """text in at most n cells, its end cut to an ellipsis where it doesn't fit."""
    if width_of(text) <= n:
        return text
    out = ''
    for ch in text:
        if width_of(out + ch) > n - 1:
            break
        out += ch
    return out + '…'


def cut_left(text, n):
    """text in at most n cells, its start cut to an ellipsis where it doesn't fit."""
    if width_of(text) <= n:
        return text
    out = ''
    for ch in reversed(text):
        if width_of(ch + out) > n - 1:
            break
        out = ch + out
    return '…' + out


TAG = re.compile(r'\{([\w.-]+)\|([^}]*)\}')
BOXES = {'light': '┌┐└┘─│', 'heavy': '┏┓┗┛━┃', 'round': '╭╮╰╯─│', 'double': '╔╗╚╝═║'}
EIGHTHS = ' ▏▎▍▌▋▊▉'


class Canvas:
    """A terminal screen of cells, each (glyph, Pen). A wide glyph takes two
    cells, the second with the glyph ''. styles names the pens a frame draws
    in, so a frame says 'accent' where the tool's code says accent. ground names
    the style of a cell nothing else styles: a themed tool's canvas, painted on
    every cell. Without it those cells are the terminal's own."""

    def __init__(self, width, height, styles=None, ground=None):
        self.width, self.height = width, height
        self.styles = dict(styles or {})
        self.ground = None
        self.ground = self.pen(ground)
        self.rows = [[(' ', self.ground) for _ in range(width)] for _ in range(height)]

    # ---- pens

    def pen(self, style):
        if style is None:
            return self.ground or PLAIN
        if isinstance(style, Pen):
            return style
        try:
            return self.styles[style]
        except KeyError:
            raise KeyError(f'no style named {style!r}: name it in the canvas styles') from None

    # ---- drawing

    def put(self, x, y, text, style=None, clip=False):
        """Write text from column x on row y; returns the column after it. Text
        past the right edge is an error, as the terminal bounds the design,
        unless clip says to cut it there."""
        if not 0 <= y < self.height:
            raise IndexError(f'row {y} is outside the {self.height} rows')
        p = self.pen(style)
        for ch in text:
            w = cell_width(ch)
            if w == 0:
                if x == 0:
                    raise ValueError(f'{ch!r} joins no glyph at the start of row {y}')
                back = x - 1 if self.rows[y][x - 1][0] else x - 2
                g, q = self.rows[y][back]
                self.rows[y][back] = (g + ch, q)
                continue
            if x + w > self.width:
                if clip:
                    break
                raise ValueError(f'row {y}: {text!r} runs past column {self.width} '
                                 f'(the terminal bounds the design; cut it)')
            if x < 0:
                raise IndexError(f'column {x} on row {y}')
            self.rows[y][x] = (ch, p)
            if w == 2:
                self.rows[y][x + 1] = ('', p)
            x += w
        return x

    def run(self, x, y, parts, clip=False):
        """Write (text, style) parts left to right."""
        for text, style in parts:
            x = self.put(x, y, text, style, clip)
        return x

    def right(self, x_end, y, parts):
        """Write parts so they end at column x_end (exclusive)."""
        return self.run(x_end - sum(width_of(t) for t, _ in parts), y, parts)

    def markup(self, x, y, s, clip=False):
        """Write markup: {style|text} draws text in a named style, the rest
        plainly."""
        return self.run(x, y, parse_markup(s), clip)

    def line(self, y, s, left=0, right=None):
        """Write a row of markup from column left. One '»' in it pushes what
        follows to end at column right, the canvas's width by default."""
        right = self.width if right is None else right
        if '»' not in s:
            return self.markup(left, y, s)
        head, tail = s.split('»', 1)
        head_parts, tail_parts = parse_markup(head), parse_markup(tail)
        end = self.run(left, y, head_parts)
        start = right - sum(width_of(t) for t, _ in tail_parts)
        if start <= end:
            raise ValueError(f'row {y}: no room between {head!r} and {tail!r}')
        return self.run(start, y, tail_parts)

    def fill(self, x, y, w, h, style=None, glyph=' '):
        """Fill a block of cells with one glyph."""
        for r in range(y, y + h):
            self.put(x, r, glyph * w, style)

    def band(self, y, bg, x0=0, x1=None):
        """Paint row y's ground from x0 to x1, its glyphs and inks kept: a
        selected row's highlight."""
        bg = colour(bg)
        for x in range(x0, self.width if x1 is None else x1):
            g, p = self.rows[y][x]
            self.rows[y][x] = (g, p._replace(bg=bg))

    def hline(self, x, y, n, style=None, glyph='─'):
        return self.put(x, y, glyph * n, style)

    def vline(self, x, y, n, style=None, glyph='│'):
        for r in range(y, y + n):
            self.put(x, r, glyph, style)

    def box(self, x, y, w, h, style=None, kind='light', title=None, title_style=None):
        """A box w by h, its title on its top edge."""
        tl, tr, bl, br, hz, vt = BOXES[kind]
        self.put(x, y, tl + hz * (w - 2) + tr, style)
        for r in range(y + 1, y + h - 1):
            self.put(x, r, vt, style)
            self.put(x + w - 1, r, vt, style)
        self.put(x, y + h - 1, bl + hz * (w - 2) + br, style)
        if title:
            self.put(x + 2, y, f' {title} ', title_style or style)

    def bar(self, x, y, width, fraction, style=None, track='░', track_style=None, glyph=None):
        """A bar width cells long, filled to fraction in eighths of a cell; or,
        given a glyph, filled to the nearest whole cell with it, as a line bar
        draws (glyph='━', track='─')."""
        f = min(max(fraction, 0), 1)
        if glyph:
            full = round(f * width)
            self.put(x, y, glyph * full, style)
            if width - full:
                self.put(x + full, y, track * (width - full), track_style or style)
            return
        e = round(f * width * 8)
        full, part = divmod(e, 8)
        self.put(x, y, '█' * full, style)
        if part:
            self.put(x + full, y, EIGHTHS[part], style)
        rest = width - full - (1 if part else 0)
        if rest:
            self.put(x + width - rest, y, track * rest, track_style or style)

    # ---- reading

    def cell(self, x, y):
        return self.rows[y][x]

    def text(self, y):
        """Row y's glyphs, its trailing blanks trimmed."""
        return ''.join(g for g, _ in self.rows[y]).rstrip()

    def txt(self):
        """The frame's .txt: a line a row, trailing blanks trimmed."""
        return '\n'.join(self.text(y) for y in range(self.height)) + '\n'

    def ansi(self):
        """The frame's .ansi: each row's cells as SGR and glyphs, the pen reset
        at the end of any row that leaves it set, rows joined by newlines, and
        no newline after the last, so cat in a terminal its size doesn't scroll
        it. A row's trailing blank, unpainted cells are left off."""
        out = []
        for row in self.rows:
            end = len(row)
            while end and row[end - 1][0] == ' ' and row[end - 1][1].bg == DEFAULT \
                    and not row[end - 1][1].reverse:
                end -= 1
            line, cur = [], PLAIN
            for g, p in row[:end]:
                if g == '':
                    continue
                if p != cur:
                    line.append(sgr(p))
                    cur = p
                line.append(g)
            if cur != PLAIN:
                line.append('\x1b[0m')
            out.append(''.join(line))
        return '\n'.join(out)


def parse_markup(s):
    """(text, style) parts of markup: {style|text} runs and the plain text
    between them."""
    parts, i = [], 0
    for m in TAG.finditer(s):
        if m.start() > i:
            parts.append((s[i:m.start()], None))
        parts.append((m.group(2), m.group(1)))
        i = m.end()
    if i < len(s):
        parts.append((s[i:], None))
    return parts


def sgr(p):
    """The SGR that sets the pen p from any other."""
    codes = ['0']
    if p.bold:
        codes.append('1')
    if p.faint:
        codes.append('2')
    if p.reverse:
        codes.append('7')
    if p.fg != DEFAULT:
        codes.append(_colour_code(p.fg, 30, 90, 38))
    if p.bg != DEFAULT:
        codes.append(_colour_code(p.bg, 40, 100, 48))
    return '\x1b[' + ';'.join(codes) + 'm'


def _colour_code(c, base, bright, extended):
    if c.startswith('#'):
        return f'{extended};2;%d;%d;%d' % hx(c)
    kind, n = c.split(':')
    n = int(n)
    if kind == '256':
        return f'{extended};5;{n}'
    return str(base + n if n < 8 else bright + n - 8)


# ---------------------------------------------------------------- reading real output

_CSI = re.compile(r'\x1b\[([0-?]*)([ -/]*)([@-~])')
_OSC = re.compile(r'\x1b\][^\x07\x1b]*(\x07|\x1b\\)')
_IGNORED_PRIVATE = {'?25', '?2026'}  # cursor shown or hidden, synchronised output


class _Screen:
    """A terminal as read_ansi applies output to it: rows written, the cursor,
    and the pen. Unbounded in width and height where none is given."""

    def __init__(self, width, height):
        self.width, self.height = width, height
        self.rows = [[]]
        self.top = 0
        self.row = self.col = 0
        self.pen = PLAIN

    def _blank(self):
        return (' ', Pen(bg=self.pen.bg))

    def _at(self, row):
        while len(self.rows) <= row:
            self.rows.append([])
        return self.rows[row]

    def line_feed(self):
        if self.height and self.row == self.top + self.height - 1:
            self.top += 1
        self.row += 1
        self._at(self.row)

    def put(self, ch):
        w = cell_width(ch)
        r = self._at(self.row)
        if w == 0:
            for i in range(min(self.col, len(r)) - 1, -1, -1):
                if r[i][0]:
                    r[i] = (r[i][0] + ch, r[i][1])
                    return
            raise ValueError(f'{ch!r} joins no glyph')
        if self.width and self.col + w > self.width:
            self.col = 0
            self.line_feed()
            r = self._at(self.row)
        while len(r) < self.col + w:
            r.append((' ', PLAIN))
        r[self.col] = (ch, self.pen)
        if w == 2:
            r[self.col + 1] = ('', self.pen)
        self.col += w

    def erase_line(self, mode):
        r = self._at(self.row)
        col = min(self.col, self.width - 1) if self.width else self.col
        if mode == 0:
            del r[col:]
            if self.pen.bg != DEFAULT and self.width:
                r.extend([self._blank()] * (self.width - col))
        elif mode == 1:
            for i in range(min(col + 1, len(r))):
                r[i] = self._blank()
        else:
            r.clear()

    def erase_below(self, mode):
        if mode == 0:
            self.erase_line(0)
            del self.rows[self.row + 1:]
        elif mode == 2:
            for i in range(self.top, len(self.rows)):
                self.rows[i] = []
        else:
            raise ValueError(f'erase J{mode} is not read')

    def csi(self, params, inter, final, seq):
        if params.startswith('?'):
            if inter == '' and final in 'hl' and params in _IGNORED_PRIVATE:
                return
            raise ValueError(f'escape {seq!r} is not read')
        if inter:
            raise ValueError(f'escape {seq!r} is not read')
        if final == 'm':
            self.pen = _apply_sgr(self.pen, params, seq)
            return
        nums = [int(n) if n else 0 for n in params.split(';')] if params else []
        n = max(nums[0], 1) if nums else 1
        if final == 'A':
            if self.row - n < self.top:
                raise ValueError(f'escape {seq!r} moves up past the screen\'s top')
            self.row -= n
        elif final == 'B':
            self.row += n
            if self.height:
                self.row = min(self.row, self.top + self.height - 1)
            self._at(self.row)
        elif final == 'C':
            self.col += n
            if self.width:
                self.col = min(self.col, self.width - 1)
        elif final == 'D':
            self.col = max(self.col - n, 0)
        elif final == 'G':
            self.col = n - 1
        elif final in 'Hf':
            r = max(nums[0], 1) if nums else 1
            c = max(nums[1], 1) if len(nums) > 1 else 1
            self.row, self.col = self.top + r - 1, c - 1
            self._at(self.row)
        elif final == 'J':
            self.erase_below(nums[0] if nums else 0)
        elif final == 'K':
            self.erase_line(nums[0] if nums else 0)
        else:
            raise ValueError(f'escape {seq!r} is not read')
        if self.width and self.col >= self.width:
            self.col = self.width - 1

    def feed(self, text):
        i = 0
        while i < len(text):
            ch = text[i]
            if ch == '\x1b':
                m = _CSI.match(text, i)
                if m:
                    self.csi(m.group(1), m.group(2), m.group(3), m.group(0))
                    i = m.end()
                    continue
                m = _OSC.match(text, i)
                if m:
                    i = m.end()
                    continue
                raise ValueError(f'escape {text[i:i + 6]!r} is not read')
            if ch == '\n':
                self.col = 0
                self.line_feed()
            elif ch == '\r':
                self.col = 0
            elif ch == '\t':
                self.col = (self.col // 8 + 1) * 8
                if self.width:
                    self.col = min(self.col, self.width - 1)
            elif ch == '\b':
                self.col = max(self.col - 1, 0)
            elif ord(ch) < 0x20 or 0x7F <= ord(ch) <= 0x9F:
                raise ValueError(f'control character {ch!r}')
            else:
                self.put(ch)
            i += 1


def _apply_sgr(p, params, seq):
    codes = params.split(';') if params else ['0']
    i = 0
    while i < len(codes):
        n = int(codes[i] or 0)
        if n == 0:
            p = PLAIN
        elif n == 1:
            p = p._replace(bold=True)
        elif n == 2:
            p = p._replace(faint=True)
        elif n == 22:
            p = p._replace(bold=False, faint=False)
        elif n == 7:
            p = p._replace(reverse=True)
        elif n == 27:
            p = p._replace(reverse=False)
        elif n == 39:
            p = p._replace(fg=DEFAULT)
        elif n == 49:
            p = p._replace(bg=DEFAULT)
        elif 30 <= n <= 37 or 90 <= n <= 97:
            p = p._replace(fg=f'ansi:{n - 30 if n < 90 else n - 82}')
        elif 40 <= n <= 47 or 100 <= n <= 107:
            p = p._replace(bg=f'ansi:{n - 40 if n < 100 else n - 92}')
        elif n in (38, 48):
            kind = codes[i + 1] if i + 1 < len(codes) else ''
            if kind == '5':
                c, i = f'256:{int(codes[i + 2])}', i + 2
            elif kind == '2':
                c, i = '#%02X%02X%02X' % tuple(int(v) for v in codes[i + 2:i + 5]), i + 4
            else:
                raise ValueError(f'SGR {seq!r}: a colour neither 5;n nor 2;r;g;b')
            p = p._replace(**{'fg' if n == 38 else 'bg': c})
        else:
            raise ValueError(f'SGR {seq!r}: attribute {n} is not read')
        i += 1
    return p


def read_ansi(text, width=None, height=None, scrollback=True):
    """A build's output as a Canvas, applied as a terminal width by height
    would apply it: SGR, newlines as carriage return and line feed, carriage
    returns, tabs, the cursor moves and erases a live region makes (CSI A B C
    D G H J K), its wrap at the width. OSC sequences draw nothing and are
    skipped, as are cursor shown or hidden and synchronised output. Anything
    else is an error rather than a guess.

    With no width, nothing wraps and the canvas is as wide as the widest row.
    The canvas holds every row written, the scrollback too, the blank rows at
    the foot left off; with a height and scrollback False, the screen alone."""
    s = _Screen(width, height)
    s.feed(text)
    rows = s.rows
    if height and not scrollback:
        rows = rows[s.top:s.top + height]
        rows += [[] for _ in range(height - len(rows))]
    else:
        while rows and not rows[-1]:
            rows = rows[:-1]
    w = width or max((len(r) for r in rows), default=0)
    c = Canvas(w, len(rows))
    for y, r in enumerate(rows):
        for x, cl in enumerate(r[:w]):
            c.rows[y][x] = cl
    return c


# ---------------------------------------------------------------- holding one grid to another

class Difference(NamedTuple):
    row: int
    col: int
    frame: tuple
    drawn: tuple


def _alike(a, b):
    """Glyph, ground and reverse alike, and the pen whole but on a blank not
    reversed: reversed, a blank's ink is the ground the terminal paints."""
    if a[0] != b[0] or a[1].bg != b[1].bg or a[1].reverse != b[1].reverse:
        return False
    return (a[0] == ' ' and not a[1].reverse and not b[1].reverse) or a[1] == b[1]


def compare(frame, drawn):
    """The cells drawn differs from frame in, rows and columns counted from 1.
    A blank's ink and weight aren't compared, as nothing shows them. A drawn
    row may be shorter than the frame's, read as blank, never wider."""
    if drawn.height != frame.height:
        raise ValueError(f'drawn {drawn.height} rows, where the frame has {frame.height}')
    diffs = []
    blank = (' ', PLAIN)
    for y in range(frame.height):
        width = max(frame.width, drawn.width)
        for x in range(width):
            a = frame.rows[y][x] if x < frame.width else blank
            b = drawn.rows[y][x] if x < drawn.width else blank
            if x >= frame.width and b != blank:
                raise ValueError(f'row {y + 1} drawn past the frame\'s {frame.width} columns')
            if not _alike(a, b):
                diffs.append(Difference(y + 1, x + 1, a, b))
    return diffs


def _named(cl):
    g, p = cl
    attrs = ''.join(f' {k}' for k in ('bold', 'faint', 'reverse') if getattr(p, k))
    return f'{g!r} {p.fg} on {p.bg}{attrs}'


def describe(name, diffs, shown=20):
    """Where name is drawn otherwise than its frame: a line a cell for the
    first 20, then how many more."""
    lines = [f'{name} draws {len(diffs)} cells otherwise than its frame:']
    for d in diffs[:shown]:
        lines.append(f'  row {d.row}, column {d.col}: the frame\'s {_named(d.frame)}, drawn {_named(d.drawn)}')
    if len(diffs) > shown:
        lines.append(f'  and {len(diffs) - shown} more')
    return '\n'.join(lines)


# ---------------------------------------------------------------- the width checks

RULE_GLYPHS = '─━┄┅┈┉╌╍═│┃┆┊╎┬┴┼├┤╵╷╴╶'
_JOINING = re.compile(r'[^\W_]')


def _cut_of(text, name):
    """(shown, cells cut) for name as text holds it cut: its longest prefix
    there, at a word's start, followed by '…'; None for a name not cut there."""
    for kept in range(len(name) - 1, 0, -1):
        prefix = name[:kept].rstrip()
        shown = prefix + '…'
        if len(prefix) < 2:
            continue
        at = text.find(shown)
        while at != -1:
            if at == 0 or not _JOINING.match(text[at - 1]):
                return shown, width_of(name) - width_of(prefix)
            at = text.find(shown, at + 1)
    return None


def reach(c, rows=None):
    """How far across the rows content runs, rules left out: the column after
    the last cell drawn on."""
    most = 0
    for y in rows if rows is not None else range(c.height):
        cells = [g for g, _ in c.rows[y]]
        end = len(cells)
        while end and (cells[end - 1] in ('', ' ') or cells[end - 1] in RULE_GLYPHS):
            end -= 1
        most = max(most, end)
    return most


def sweep(c, names=(), view=None, out_of_view=None, draws=None, fold_spare=3, least_view=6, most=None):
    """The width rules frame c breaks, as (rule, what shows it):
    - a cut name with room: one of names cut, as 'work-tea…', on a row with
      more blank cells at its end than the cut took;
    - a fold with rows spare: a row matching out_of_view (a regex: '▼ 3 more',
      a folded heading) while fold_spare or more rows are blank at the foot;
    - nothing drawn: least_view rows or more of view, and draws(rows) false;
    - a wasted third: content, rules left out, short of two thirds of the width.
    view is the (first, last) rows the checks read, the whole frame by default.
    most is the widest a capped layout draws (a view in the flow that stops at
    120 columns): past it the width is the cap's, not the frame's."""
    first, last = view or (0, c.height - 1)
    rows = range(first, last + 1)
    texts = [c.text(y) for y in rows]
    breaks = []
    for t in texts:
        spare = c.width - width_of(t)
        took = {}
        for shown, cells in filter(None, (_cut_of(t, n) for n in names)):
            took[shown] = max(took.get(shown, 0), cells)
        for shown, cells in took.items():
            if spare > cells:
                breaks.append(('a cut name with room', f'{shown!r}: {cells} cells cut, {spare} blank at its row\'s end'))
    foot = 0
    while foot < len(texts) and not texts[len(texts) - 1 - foot].strip():
        foot += 1
    if out_of_view is not None and foot >= fold_spare:
        hit = next((t.strip() for t in texts if re.search(out_of_view, t)), None)
        if hit:
            breaks.append(('a fold with rows spare', f'{hit!r} over {foot} blank rows'))
    if draws is not None and len(texts) >= least_view and not draws(texts):
        breaks.append(('nothing drawn', f'none in {len(texts)} rows of view'))
    r, room = reach(c, rows), min(c.width, most or c.width)
    if r * 3 < room * 2:
        breaks.append(('a wasted third', f'content reaches {r} of {room} columns'))
    return breaks


# ---------------------------------------------------------------- Paper

CW, LH = 9, 20  # a cell, in px: JetBrains Mono at 15px
FONT = "font-family:'JetBrains Mono';font-size:15px;line-height:20px;white-space:pre"
CHUNK_ROWS, CHUNK_BYTES = 8, 16000

# Glyphs that fill part of their cell from one side, drawn as a gradient across
# the cell's ground: (direction, how much).
FILLS = {'█': ('to right', 100), '▀': ('to bottom', 50), '▐': ('to left', 50),
         '▔': ('to bottom', 12.5), '▕': ('to left', 12.5)}
FILLS.update({g: ('to right', i * 12.5) for i, g in enumerate(EIGHTHS) if g != ' '})
FILLS.update({g: ('to top', i * 12.5) for i, g in enumerate(' ▁▂▃▄▅▆▇') if g != ' '})


def latin(ch):
    """A glyph Paper draws a cell wide from JetBrains Mono itself: ASCII,
    Latin-1, Greek, and general punctuation's dashes, dots and quotes. Paper
    draws the rest from a font of its own, wider."""
    o = ord(ch[0])
    return 0x20 <= o < 0x7F or 0xA0 <= o <= 0xFF or 0x370 <= o <= 0x3FF or 0x2010 <= o <= 0x2027


class _Ink(NamedTuple):
    fg: str
    bg: object  # hex, or None where the cell shows the canvas
    bold: bool


def _ink(p, theme):
    fg, bg = theme.hex(p.fg), theme.hex(p.bg, ground=True)
    if p.reverse:
        fg, bg = bg, fg
    if p.faint:
        fg = mix(fg, bg, .5)
    return _Ink(fg, None if bg == theme.background else bg, p.bold)


def _style(ink, *extra):
    st = [f'color:{ink.fg}']
    if ink.bold:
        st.append('font-weight:700')
    return ';'.join(st + [e for e in extra if e])


def _span(style, text):
    return f'<span style="{style}">{html.escape(text, quote=False)}</span>'


def row_html(c, y, theme, stripes=''):
    """Row y as a Paper row: one flex row 20px tall. Latin text stays text, a
    cell a glyph. Every other glyph, alone or in a run of itself, sits in a
    frame of its own as many cells wide, clipped, on its ground (its own or the
    canvas's), so a fallback font can't widen the row. A glyph that fills part
    of its cell (█, ▌, ▄ and the eighths) is drawn as its ground, a gradient
    across the cell; a glyph in stripes as a stripe down its cell's middle
    third. The .txt and .ansi keep the glyphs."""
    row = c.rows[y]
    cells = [(g, _ink(p, theme)) for g, p in row]
    end = len(cells)
    while end and cells[end - 1][0] == ' ' and cells[end - 1][1].bg is None:
        end -= 1
    if not end:
        return f'<div style="height:{LH}px"></div>'
    out, i = [], 0
    while i < end:
        g, ink = cells[i]
        if g == '':
            i += 1
            continue
        ground = ink.bg or theme.background
        if g in FILLS or g in stripes:
            j = i + 1
            while j < end and cells[j] == cells[i]:
                j += 1
            if g in stripes:
                grad = (f'linear-gradient(to right, {ground} 33.3%, {ink.fg} 33.3%, '
                        f'{ink.fg} 66.7%, {ground} 66.7%)')
            else:
                way, pct = FILLS[g]
                grad = ink.fg if pct == 100 else f'linear-gradient({way}, {ink.fg} {pct:g}%, {ground} {pct:g}%)'
            out.append(_span(f'background:{grad};width:{CW * (j - i)}px;height:{LH}px;flex-shrink:0', ' ' * (j - i)))
            i = j
        elif not latin(g):
            j = i + 1
            while j < end and cells[j] == cells[i]:
                j += 1
            n = sum(cell_width(cells[k][0][0]) for k in range(i, j))
            out.append(_span(_style(ink, f'background:{ground}', f'width:{CW * n}px', f'height:{LH}px',
                                    'flex-shrink:0', 'overflow:clip', 'display:flex', 'justify-content:center'),
                             g * (j - i)))
            i = j
        else:
            # A run of Latin in one ink; a blank joins any run on its ground.
            text, run = g, ink
            j = i + 1
            while j < end:
                h, k = cells[j]
                if h == '' or h in FILLS or h in stripes or not latin(h):
                    break
                if k == run or (h == ' ' and k.bg == run.bg):
                    text += h
                elif text.strip() == '' and k.bg == run.bg:
                    text, run = text + h, k
                else:
                    break
                j += 1
            out.append(_span(_style(run, f'background:{run.bg};height:{LH}px' if run.bg else ''), text))
            i = j
    return f'<div style="display:flex;height:{LH}px">' + ''.join(out) + '</div>'


def paper_chunks(c, theme, stripes='', rows=CHUNK_ROWS, limit=CHUNK_BYTES):
    """The frame's rows as Paper takes them: each chunk a column of up to
    eight rows in a wrapper that carries the font, fewer where eight would pass
    limit bytes, as one write_html call takes only so much."""
    lines = [row_html(c, y, theme, stripes) for y in range(c.height)]

    def wrap(y0, y1):
        return (f'<div layer-name="Rows {y0 + 1}–{y1}" style="display:flex;flex-direction:column;{FONT};'
                f'color:{theme.foreground}">' + ''.join(lines[y0:y1]) + '</div>')

    out, y0 = [], 0
    while y0 < c.height:
        y1 = min(y0 + rows, c.height)
        h = wrap(y0, y1)
        while len(h.encode()) > limit and y1 - y0 > 1:
            y1 -= 1
            h = wrap(y0, y1)
        out.append(h)
        y0 = y1
    return out


def _luminance(c):
    """WCAG relative luminance of a #RRGGBB colour, 0 black to 1 white."""
    def lin(v):
        v /= 255
        return v / 12.92 if v <= .03928 else ((v + .055) / 1.055) ** 2.4
    r, g, b = (int(c[i:i + 2], 16) for i in (1, 3, 5))
    return .2126 * lin(r) + .7152 * lin(g) + .0722 * lin(b)


def contrast(a, b):
    """WCAG contrast ratio of two #RRGGBB colours, 1 to 21."""
    la, lb = sorted((_luminance(a), _luminance(b)), reverse=True)
    return (la + .05) / (lb + .05)


def titlebar(text, theme):
    """The window's title bar, then the empty Terminal its chunks go into."""
    if _luminance(theme.background) >= .5:
        bar = mix(theme.background, theme.foreground, .08)  # a light theme's black would draw a dark bar
    elif theme.colours[0] != theme.background:
        bar = theme.colours[0]
    else:
        bar = mix(theme.background, theme.foreground, .1)
    dots = ''.join(f'<div style="width:11px;height:11px;border-radius:50%;background:{d}"></div>'
                   for d in (theme.colours[1], theme.colours[3], theme.colours[2]))
    return (f'<div layer-name="Title bar" style="display:flex;align-items:center;height:30px;padding:0 14px;gap:8px;'
            f'background:{bar};flex-shrink:0"><div style="display:flex;gap:7px">{dots}</div>'
            f'<span style="flex:1;text-align:center;font-family:\'JetBrains Mono\';font-size:12px;line-height:16px;'
            f'color:{mix(theme.background, theme.foreground, .5)}">{html.escape(text)}</span>'
            f'<div style="width:47px"></div></div>'
            f'<div layer-name="Terminal" style="display:flex;flex-direction:column;padding:16px 24px 20px"></div>')


def artboard_size(c):
    """The artboard a frame takes: its cells, the Terminal's padding and the
    title bar."""
    return c.width * CW + 48, c.height * LH + 66


class _Rows(HTMLParser):
    def __init__(self):
        super().__init__()
        self.depth, self.rows = 0, []

    def handle_starttag(self, tag, attrs):
        self.depth += 1
        if self.depth == 2:
            self.rows.append(0)
        elif self.depth == 3:
            self.rows[-1] += 1

    def handle_endtag(self, tag):
        self.depth -= 1


def row_structure(chunk):
    """A chunk's rows as get_tree_summary should show them: R for an empty row
    (Paper makes it a Rectangle), else its number of children."""
    p = _Rows()
    p.feed(chunk)
    return ' '.join('R' if n == 0 else str(n) for n in p.rows)


def preview_page(frames):
    """A page that draws frames as Paper will, to look at in a browser first.
    frames: (title, canvas, chunks, theme) each."""
    boards = []
    for title, c, chunks, theme in frames:
        w, h = artboard_size(c)
        bar = titlebar(title, theme).replace(
            '<div layer-name="Terminal" style="display:flex;flex-direction:column;padding:16px 24px 20px"></div>', '')
        boards.append(f'<div style="width:{w}px;min-height:{h}px;display:flex;flex-direction:column;'
                      f'background:{theme.background};flex-shrink:0">{bar}'
                      f'<div style="display:flex;flex-direction:column;padding:16px 24px 20px">{"".join(chunks)}</div></div>')
    return ('<!doctype html><html><head><meta charset="utf-8"><title>frames</title>'
            '<link href="https://fonts.googleapis.com/css2?family=JetBrains+Mono:wght@400;700&display=block" rel="stylesheet">'
            '<style>body{margin:0;padding:40px;background:#1C1F26;display:flex;flex-wrap:wrap;gap:60px}</style>'
            '</head><body>' + ''.join(boards) + '</body></html>')


# ---------------------------------------------------------------- a round of frames

class Round:
    """The frames of one round, written for judging, for Paper and as golden
    frames. Each frame's artboard is named '<area> · N · <what>', N counting
    from 1 in the order the page lays them out: left to right, then down.

        r = Round('design/paper/round1', area='plan', theme=NORDFOX)
        r.add('plan-73x36', canvas, 'A, the rail · 73×36 · a plan in flight')
        r.write(sys.argv[1:])   # [page id, file id] adds the jobs to draw them

    It writes, under out:
      frames/<key>.txt, .ansi   the glyphs, and every cell as SGR
      paper/<key>/titlebar.html, 01.html…, rows.txt
      preview.html              every frame, to look at in a browser
      jobs/job_<g>.txt, expected_<g>.txt, BRIEF.md   with a page and file id
    """

    def __init__(self, out, area, theme=NORDFOX, title='{key} — {w}×{h}', stripes='', gap=100):
        """out is the round's folder; area names its artboards; theme is the
        terminal the frames are drawn in; title the title bar's text; stripes the
        glyphs drawn as a stripe down their cell; gap the px between artboards."""
        self.out, self.area, self.theme = out, area, theme
        self.title, self.stripes, self.gap = title, stripes, gap
        self.frames = []

    def add(self, key, canvas, what, title=None, name=None, row=0, theme=None):
        """Add a frame. row lays frames out in rows on the page (a look a row,
        say), each row's frames left to right in the order added. name, given,
        is the artboard's whole name, and the frame takes no number: a READ ME.
        theme, given, draws this frame in a theme of its own: a round that
        shows a look on a dark and a light terminal."""
        if any(f[0] == key for f in self.frames):
            raise ValueError(f'two frames keyed {key}')
        title = title or self.title.format(key=key, w=canvas.width, h=canvas.height)
        self.frames.append((key, canvas, what, title, row, name, theme or self.theme))

    def _named(self):
        """The frames in the page's order, left to right, then down, each with
        its artboard's name."""
        out, n = [], 0
        for key, c, what, title, row, name, theme in sorted(self.frames, key=lambda f: f[4]):
            if name is None:
                n += 1
                name = f'{self.area} · {n} · {what}'
            out.append((key, c, name, title, row, theme))
        return out

    def write(self, argv=(), per_job=2):
        page, file = (list(argv) + [None, None])[:2]
        for d in ('frames', 'paper'):
            os.makedirs(os.path.join(self.out, d), exist_ok=True)
        tops, top = {}, 0
        for r in sorted({f[4] for f in self.frames}):
            tops[r] = top
            top += max(artboard_size(f[1])[1] for f in self.frames if f[4] == r) + self.gap
        lefts = dict.fromkeys(tops, 0)
        jobs, shown = [], []
        for key, c, name, title, row, theme in self._named():
            with open(os.path.join(self.out, 'frames', key + '.txt'), 'w') as f:
                f.write(c.txt())
            with open(os.path.join(self.out, 'frames', key + '.ansi'), 'w') as f:
                f.write(c.ansi())
            d = os.path.join(self.out, 'paper', key)
            os.makedirs(d, exist_ok=True)
            for old in os.listdir(d):
                os.remove(os.path.join(d, old))
            with open(os.path.join(d, 'titlebar.html'), 'w') as f:
                f.write(titlebar(title, theme))
            chunks = paper_chunks(c, theme, self.stripes)
            for i, h in enumerate(chunks, 1):
                with open(os.path.join(d, f'{i:02d}.html'), 'w') as f:
                    f.write(h)
            structure = '\n'.join(f'  chunk {i}: {row_structure(h)}' for i, h in enumerate(chunks, 1))
            with open(os.path.join(d, 'rows.txt'), 'w') as f:
                f.write(f'{key}\n{structure}\n')
            w, h = artboard_size(c)
            jobs.append((key, f'{os.path.abspath(d)} | {name} | {w} | {h} | {lefts[row]} | {tops[row]} '
                              f'| {len(chunks)} | page {page} | file {file}', f'{key}\n{structure}', theme))
            lefts[row] += w + self.gap
            shown.append((title, c, chunks, theme))
            print(f'{key}: {c.width}×{c.height}, {len(chunks)} chunks · {name}')
        with open(os.path.join(self.out, 'preview.html'), 'w') as f:
            f.write(preview_page(shown))
        if page and file:
            self._jobs(jobs, page, file, per_job)

    def _jobs(self, jobs, page, file, per_job):
        d = os.path.join(self.out, 'jobs')
        os.makedirs(d, exist_ok=True)
        for old in os.listdir(d):
            os.remove(os.path.join(d, old))
        def job_id(n):  # a to z, then aa, ab and on
            return chr(ord('a') + n) if n < 26 else job_id(n // 26 - 1) + chr(ord('a') + n % 26)

        themes = {}
        for job in jobs:
            themes.setdefault(job[3].name, []).append(job)
        n = 0
        for name, own in themes.items():
            # A job holds one theme's frames; each theme has its own brief.
            brief = 'BRIEF.md' if len(themes) == 1 else f'BRIEF-{name.lower()}.md'
            theme = own[0][3]
            with open(os.path.join(d, brief), 'w') as f:
                f.write(DRAW_BRIEF.format(dir=os.path.abspath(self.out), page=page, file=file,
                                          background=theme.background, foreground=theme.foreground))
            for i in range(0, len(own), per_job):
                g = job_id(n)
                n += 1
                part = own[i:i + per_job]
                with open(os.path.join(d, f'job_{g}.txt'), 'w') as f:
                    f.write('\n'.join(line for _, line, _, _ in part) + '\n')
                with open(os.path.join(d, f'expected_{g}.txt'), 'w') as f:
                    f.write('\n'.join(exp for _, _, exp, _ in part) + '\n')
                if len(themes) > 1:
                    print(f'job {g}: {brief}')
        print(f'jobs: {n} in {d}')


DRAW_BRIEF = """\
You are drawing generated terminal frames into a Paper file, copying HTML chunks verbatim. You do not design anything.

First call the Paper tool get_guide with topic "paper-mcp-instructions" (required once before other Paper tools). Ignore its design-brief, design-quality and "write small" advice: these frames are exact copies of generated HTML.

Work ONLY in file {file}, on page {page}, and ONLY on artboards you create. Never touch, delete or edit anything else.

Directory: {dir}
Your frames are in jobs/job_X.txt (X given in your prompt), one line each:
<frame folder> | artboard name | width | height | left | top | chunk count | page id | file id
Each frame's chunks are in its folder: titlebar.html, then 01.html, 02.html, and so on.
The expected structure is in jobs/expected_X.txt: for each frame, a line per chunk, each row in order: `R` for an empty row (Paper makes it a Rectangle) or a number (a Frame with that many children).

For each frame, in order:
1. create_artboard with the file id, the page id, the name exactly as field 2 of the frame's line (nothing added: no folder, no job letter), and styles {{"width": "<width>px", "height": "<height>px", "backgroundColor": "{background}", "display": "flex", "flexDirection": "column"}}.
2. update_styles on it with {{"left": "<left>px", "top": "<top>px"}}, then get_node_info to confirm the position.
3. Read titlebar.html and write_html it, mode "insert-children", target the artboard. It makes "Title bar" and an empty "Terminal"; get_children on the artboard gives the Terminal's id.
4. For each chunk, in order: Read it, then write_html its content EXACTLY, byte for byte, mode "insert-children", target the Terminal. Pass the text after each Read line's tab character for character; never retype, reformat, shorten or "fix" it. Copying agents have dropped a repeated span from a long row while believing they copied verbatim; step 5 catches that. If write_html returns an error, check with get_children whether the chunk landed before retrying, so none is written twice.
   After each chunk, get_jsx one of its non-empty rows and check its fontFamily includes JetBrains Mono. If it shows system-ui or sans-serif instead, STOP and report: the file's fonts stopped resolving.
5. get_tree_summary(artboard id, depth 3) and compare every row of every chunk with the expected structure. Count rows only from the tree summary: write_html's results don't show what landed. If {dir}/check_text.py exists, also save get_tree_summary(artboard id, depth 6)'s result to a file exactly as returned, never retyped, and run `python3 {dir}/check_text.py <frame folder> <file>`; for a tall frame, do it per chunk, giving each chunk's node. A row that differs: replace that row's node (write_html mode "replace", targetNodeId = the row's id) with the same row taken verbatim from the chunk file, its opening `<div style="` starting with the chunk wrapper's font: `{font};color:{foreground};`, as a row written alone loses its chunk's font. Check again. Report any you couldn't fix.
6. get_screenshot of the Terminal node: rows evenly on a 20px grid, nothing clipped or doubled, every glyph one cell wide, marks lined up in their columns, rules and bars unbroken. In a new file, look at the first frame's screenshot at scale 2 before starting the second; if any glyph is wider than its cell, stop and report.
7. finish_working_on_nodes with the artboard id.

When every frame is drawn, get_node_info on each of your artboards once more and confirm its left and top match its line; move any that don't.

If any tool call is denied or fails twice, stop and report exactly what happened rather than working round it. If a call naming this file returns "Your file is too large", stop at once and report.

Report: per frame, its artboard id, its name, whether every row matched the expected structure (and any row you fixed), whether the font held, and one line on the screenshot.
""".replace('{font}', FONT)


# ---------------------------------------------------------------- the command line

def _theme(name):
    if name in THEMES:
        return THEMES[name]
    if os.path.exists(name):
        with open(name) as f:
            return Theme.from_vhs(f.read())
    raise SystemExit(f'no theme {name!r}: one of {", ".join(THEMES)}, or a file holding a Set Theme line')


def main(argv=None):
    ap = argparse.ArgumentParser(prog='termgrid.py', description=__doc__.split('\n\n')[0])
    sub = ap.add_subparsers(dest='cmd', required=True)

    rd = sub.add_parser('read', help="a build's ANSI output as frames, Paper chunks and a preview")
    rd.add_argument('file', help="the output, as the build wrote it ('-' for stdin)")
    rd.add_argument('--key', required=True)
    rd.add_argument('--what', default='as the build draws it')
    rd.add_argument('--area', default='build')
    rd.add_argument('--width', type=int)
    rd.add_argument('--height', type=int)
    rd.add_argument('--screen', action='store_true', help='the screen alone, its scrollback left off')
    rd.add_argument('--theme', default='nordfox')
    rd.add_argument('--out', default='.')
    rd.add_argument('ids', nargs='*', help='page id and file id, to write the drawing jobs too')

    cp = sub.add_parser('compare', help='hold a drawn frame to a golden one, cell for cell')
    cp.add_argument('frame')
    cp.add_argument('drawn')

    rw = sub.add_parser('rows', help="a frame's expected row structure, from its chunks")
    rw.add_argument('dir')

    th = sub.add_parser('theme', help="a theme's Set Theme line for look.tape")
    th.add_argument('name')

    a = ap.parse_args(argv)
    if a.cmd == 'read':
        text = sys.stdin.read() if a.file == '-' else open(a.file).read()
        c = read_ansi(text, a.width, a.height, scrollback=not a.screen)
        r = Round(a.out, a.area, _theme(a.theme))
        r.add(a.key, c, a.what)
        r.write(a.ids)
    elif a.cmd == 'compare':
        frame, drawn = (read_ansi(open(p).read()) for p in (a.frame, a.drawn))
        diffs = compare(frame, drawn)
        if diffs:
            print(describe(os.path.basename(a.drawn), diffs))
            return 1
        print(f'{a.drawn} draws {a.frame} cell for cell')
    elif a.cmd == 'rows':
        for i, name in enumerate(sorted(n for n in os.listdir(a.dir) if re.fullmatch(r'\d\d\.html', n)), 1):
            with open(os.path.join(a.dir, name)) as f:
                print(f'  chunk {i}: {row_structure(f.read())}')
    elif a.cmd == 'theme':
        print(_theme(a.name).vhs())
    return 0


if __name__ == '__main__':
    sys.exit(main())
