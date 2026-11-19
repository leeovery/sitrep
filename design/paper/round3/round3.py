#!/usr/bin/env python3
"""Round 3 of the board in a terminal: one look, Two-line under rules, on every
screen of design/terminal-ui.md. Two-line's rows under List's headings, with
no indent and no cursor mark: the band alone marks the chosen row.

    python3 round3.py [page id] [file id]

It writes frames/, paper/ and preview.html beside itself (jobs/ too, given a
page and a file), reads every .ansi back against its canvas, and runs the
width checks on every frame. The worlds, scenes, colours and helpers are
round 1's.
"""
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, '..', 'round1'))
import round1 as r1  # noqa: E402
from round1 import tg  # noqa: E402

MARK, NAME = 1, 3   # the mark sits in the headings' first column; the name, and line two under it


def reverse(c, y, x0, x1):
    """Row y from x0 to x1 in reverse video, glyphs kept: the band without colour."""
    for x in range(x0, x1):
        g, p = c.rows[y][x]
        c.rows[y][x] = (g, p._replace(reverse=True))


def ground(c, scene, s, y, x0, x1):
    """The chosen row's band, or a new ask's wash, under both its lines;
    without colour, the chosen row in reverse video."""
    if scene.colour:
        r1.row_ground(c, scene, s, y, x0, x1, 2)
    elif scene.cursor is s:
        for r in (y, y + 1):
            reverse(c, r, x0, x1)


def in_view(blocks, scene):
    """The block the view keeps in sight: the cursor's row; with no cursor and
    Snoozed just opened, Snoozed's last row, so `s` scrolls its rows into view."""
    at = r1.cursor_index(blocks, scene)
    if at is None and scene.snoozed_open:
        return len(blocks) - 1
    return at


class TwoLineUnderRules:
    """Two-line's rows under List's headings: the mark at the left edge, the
    name and time on line one, project · status under the name on line two."""
    key, name = 'rules', 'Two-line under rules'

    def heading(self, c, y, cw, name, rows, is_open):
        """List's heading: the name, its counts, a rule out to the fold's chevron."""
        x = self.heading_words(c, y, name)
        x = r1.counts(c, x + 1, y, rows)
        c.hline(x + 1, y, cw - 4 - x, 'faint')
        c.put(cw - 2, y, r1.OPEN if is_open else r1.FOLDED, 'faint')

    def heading_words(self, c, y, name):
        """The heading's name, as List draws it; returns the column after it."""
        return c.put(MARK, y, name, 'head')

    def row(self, c, y, cw, s, scene):
        glyph, style = r1.mark_of(s, scene)
        c.put(MARK, y, glyph, style)
        time_w = tg.width_of(s.time)
        c.run(NAME, y, r1.name_parts(s, cw - 1 - NAME - time_w - 2))
        c.right(cw - 1, y, [(s.time, s.ink('grey'))])
        x = c.put(NAME, y + 1, tg.cut(s.project + ' · ', cw - 1 - NAME), s.ink('grey'))
        if x < cw - 1:
            c.put(x, y + 1, tg.cut(s.status, cw - 1 - x), s.ink('soft'))
        ground(c, scene, s, y, MARK, cw - 1)

    def canvas(self, scene, w, h):
        return r1.canvas(scene, w, h)

    def draw(self, scene, w, h):
        c = self.canvas(scene, w, h)
        cw = min(w, r1.MOST)
        c.put(MARK, 0, 'sitrep', 'title')
        msg = r1.message_lines(scene, cw - 4)
        foot = h - 1 - (len(msg) + 1 if msg else 0)
        if not scene.sessions:
            r1.quiet(c, MARK, cw - 1, 1, h - 1)
        else:
            blocks = r1.row_blocks(scene, 2)

            def block(b, y):
                if b[1] == 'head':
                    self.heading(c, y, cw, *b[2])
                elif b[1] == 'row':
                    self.row(c, y, cw, b[2], scene)
            r1.draw_body(c, blocks, MARK, 2, foot, in_view(blocks, scene), block)
        if msg:
            r1.say_message(c, MARK, h - 1 - len(msg), msg)
        r1.keyline(c, h - 1, MARK, cw - 1, scene.keys())
        return c


LOOK = TwoLineUnderRules()

LEGEND = [entry for entry in r1.LEGEND if entry[0] != r1.CURSOR]


CHANGE = ('round 3 · two-line under rules', [
    'Two-line\'s rows under List\'s headings, no indent, and no ▸: the band alone marks',
    'the chosen row, over both its lines, in reverse video without colour.',
])


def readme(change=CHANGE, here=HERE, w=86):
    """The READ ME: the round, what changed from the round before, the marks."""
    title, lines = change
    head = [(f'sitrep · the board in a terminal · {title}', 'title'), ('', None)]
    head += [(t, None) for t in lines] + [('', None), ('Legend', 'title')]
    foot = [
        ('', None),
        ('Sizes: 39×27 the iPad\'s small window, 69×46 its slide-over, 73×36 a Ghostty', None),
        ('pane, 114×45 the iPad\'s main window, 173×53 the widest, 73×15 short.', None),
        ('The terminal notification a new ask posts is not drawn.', 'grey'),
        ('Paper holds the frames that decide the look; every screen at every size is in', None),
        (f'the repo\'s preview, design/paper/{os.path.basename(here)}/preview.html.', None),
    ]
    c = tg.Canvas(w, len(head) + len(LEGEND) + 1 + len(foot) + 2, r1.COLOUR)
    y = 1
    for t, style in head:
        c.put(1, y, t, style)
        y += 1
    for glyph, style, meaning, colour in LEGEND:
        c.put(3, y, glyph, style)
        c.put(7, y, meaning)
        c.put(54, y, colour, 'grey')
        y += 1
    c.band(y, r1.SELECTED, 3, 5)
    c.put(7, y, 'the chosen row: a band over its two lines')
    c.put(54, y, 'reverse video without colour', 'grey')
    y += 1
    for t, style in foot:
        c.put(1, y, t, style)
        y += 1
    return c


def scene_of(skey):
    return next((sc, what) for k, what, sc, _ in r1.SCREENS if k == skey)


def run(look, notes, here, argv):
    """Every frame of look to here's frames/ and the preview, under the READ ME
    notes; the Paper set, with its jobs where a page and a file id are given,
    to here's for-paper/."""
    def frame_key(skey, w, h):
        return f'{look.key}-{skey}-{w}x{h}'
    r = tg.Round(here, area='board', theme=tg.NORDFOX)
    to_paper = tg.Round(os.path.join(here, 'for-paper'), area='board', theme=tg.NORDFOX)
    for rnd in (r, to_paper):
        rnd.add('readme', notes, '', name='READ ME')
    for skey, (w, h) in r1.PAPER:
        scene, what = scene_of(skey)
        to_paper.add(frame_key(skey, w, h), look.draw(scene(), w, h), f'{look.name} · {w}×{h} · {what}', row=1)
    breaks, kept, frames = [], [], []
    for skey, what, scene, sizes in r1.SCREENS:
        for w, h in sizes:
            c = look.draw(scene(), w, h)
            key = frame_key(skey, w, h)
            r.add(key, c, f'{look.name} · {w}×{h} · {what}', row=1)
            frames.append((key, c))
            draws = None if skey == 'quiet' else (
                lambda rows: any(g in t for t in rows for g in '●○✻◌◉'))
            for rule, shown in tg.sweep(c, r1.NAMES, out_of_view=r'▼ \d+ more', draws=draws, most=r1.MOST):
                (kept if r1.listed(key, rule) else breaks).append((key, rule, shown))
    r.write()
    to_paper.write(argv)
    bad = 0
    for key, c in frames:
        with open(os.path.join(here, 'frames', key + '.ansi')) as f:
            back = tg.read_ansi(f.read(), width=c.width, height=c.height, scrollback=False)
        diffs = tg.compare(c, back)
        if diffs:
            bad += 1
            print(tg.describe(key + '.ansi read back', diffs))
    print(f'{len(frames)} frames read back' + ('' if bad else ', each to its canvas, cell for cell'))
    print('width checks: ' + ('\n  '.join([''] + [f'{k}: {r}, {s}' for k, r, s in breaks])
                              if breaks else 'none broken'))
    for screen, rule, why in r1.ON_PURPOSE:
        hits = [k for k, r, _ in kept if r == rule and f'-{screen}-' in k]
        print(f'on purpose, {screen}, {rule}: ' + (', '.join(hits) if hits else 'NO LONGER DRAWN') + f' ({why})')
        bad += 0 if hits else 1
    return 1 if bad or breaks else 0


if __name__ == '__main__':
    sys.exit(run(LOOK, readme(), HERE, sys.argv[1:]))
