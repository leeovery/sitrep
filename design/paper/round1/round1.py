#!/usr/bin/env python3
"""Round 1 of the board in a terminal: four looks, List, Card, Two-line and
Marks, each on every screen of design/terminal-ui.md's stage 1.

    python3 round1.py [page id] [file id]

It writes frames/, paper/ and preview.html beside itself (jobs/ too, given a
page and a file), reads every .ansi back against its canvas, and runs the
width checks on every frame.
"""
import math
import os
import sys
import textwrap

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), '..'))
import termgrid as tg  # noqa: E402

HERE = os.path.dirname(os.path.abspath(__file__))

# ---------------------------------------------------------------- colours

BG = tg.NORDFOX.background
INK = tg.NORDFOX.foreground
ORANGE = '#D77757'   # an ask or a permission prompt: Claude Code's own orange
BLUE = '#7AA2F7'     # Stopped: the pane's blue
SOFT = '#A9B1D6'     # a status line, a working session's name: the pane's soft
GREY = '#7A82AB'     # times, counts, projects, the keys' words: the pane's grey
FAINT = '#565F89'    # rules, a box, a fold's chevron: the pane's faint
TRACK = '#3B4261'    # a working pill's ground: the pane's rule
SHELF = '#292E42'    # an own-work pill's ground: the pane's tab
SELECTED = tg.NORDFOX.selection
DIMMED = 0.39        # how far a dimmed ink goes toward the ground: the notch's 0.61
WASH = tg.mix(BG, ORANGE, 0.22)  # a new ask's row, for its two seconds


def dim(colour):
    return tg.mix(colour, BG, DIMMED)


def styles(colour=True):
    """The pens a frame draws in, by name; with colour off (NO_COLOR), no colour
    at all, bold and faint carrying what they can. A name ending '.dim' is its
    ink dimmed as the notch dims an away row, every word of it by the same 0.61."""
    def c(fg, bg='default', bold=False, faint=False):
        return tg.pen(fg, bg, bold=bold) if colour else tg.pen(bold=bold, faint=faint)
    words = {'name': (INK, False), 'name.bold': (INK, True), 'name.work': (SOFT, False),
             'name.snoozed': (GREY, False), 'name.snoozed.bold': (GREY, True),
             'soft': (SOFT, False), 'grey': (GREY, False)}
    out = {
        'title': c('default', bold=True),
        'head': c('default', bold=True),
        'eyebrow': c(GREY, bold=True, faint=True),
        'faint': c(FAINT, faint=True),
        'ask': c(ORANGE),
        'ask.bold': c(ORANGE, bold=True),
        'stop': c(BLUE),
        'stop.bold': c(BLUE, bold=True),
        'work': c(SOFT),
        'own': c(GREY),
        'ask.snoozed': c(dim(ORANGE)),
        'stop.snoozed': c(dim(BLUE)),
        'work.snoozed': c(dim(SOFT)),
        'own.snoozed': c(dim(GREY)),
        'cursor': c('default', bold=True),
        'key': c('default', bold=True),
        'say': c('default', bold=True),
        # Marks' pills: filled here, the letters alone in the colour away, dimmed in Snoozed.
        'pill.ask': c(BG, ORANGE, bold=True),
        'pill.stop': c(BG, BLUE, bold=True),
        'pill.work': c(SOFT, TRACK),
        'pill.own': c(GREY, SHELF),
        'pill.ask.away': c(ORANGE, bold=True),
        'pill.stop.away': c(BLUE, bold=True),
        'pill.work.away': c(dim(SOFT), TRACK),
        'pill.own.away': c(dim(GREY), SHELF),
        'pill.ask.snoozed': c(BG, dim(ORANGE)),
        'pill.stop.snoozed': c(BG, dim(BLUE)),
        'pill.work.snoozed': c(dim(SOFT), TRACK),
        'pill.own.snoozed': c(dim(GREY), SHELF),
    }
    for name, (ink, bold) in words.items():
        # Without colour a bold name is never faint too: many terminals draw SGR 1
        # and 2 as one intensity, and the bold is all that tells an ask from a turn.
        out[name] = c(ink, bold=bold, faint=not bold and name in ('grey', 'name.snoozed'))
        out[name + '.dim'] = c(dim(ink), bold=bold, faint=not bold)
    return out


COLOUR, PLAIN = styles(True), styles(False)

# ---------------------------------------------------------------- marks

# Every mark keeps the notch's grammar: colour says what is needed, orange for
# an ask and blue for Lee's turn; fill says where the session is, filled where a
# terminal on this Mac shows it, hollow away (no window shows it, or its Claude
# ended). A permission prompt is an ask, as on the notch. Snoozed has no glyph of
# its own: its rows keep their state's mark, dimmed, under its heading.
MARKS = {  # state: (here, away, its colour's style, its name's style)
    'ask': ('●', '○', 'ask', 'name.bold'),       # without colour, its name's weight tells it from a turn
    'stopped': ('●', '○', 'stop', 'name'),
    'working': ('✻', '✻', 'work', 'name.work'),   # Claude Code's own spinner, ·✢✳✶✻✽, all in step
    'own': ('◌', '◌', 'own', 'name.work'),        # on its own work: agents, a shell, a wake
}
PILLS = {'ask': 'pill.ask', 'stopped': 'pill.stop', 'working': 'pill.work', 'own': 'pill.own'}
ARRIVING = '◉'  # a new ask, for its two seconds
CURSOR = '▸'
OPEN, FOLDED = '▿', '▹'

# ---------------------------------------------------------------- the world


class S:
    """A session on the board: its name, project, state, status line, time (an
    age, or a snoozed one's wake), and how many lines wait on it; whether it is
    away (no terminal on this Mac shows it, or its Claude ended) and snoozed."""

    def __init__(self, name, project, state, status, time, count=1, away=False, snoozed=False):
        self.name, self.project, self.state = name, project, state
        self.status, self.time, self.count = status, time, count
        self.away, self.snoozed = away, snoozed

    @property
    def letters(self):
        """The project's two letters, as the strip's marks have them (Rows.letters)."""
        caps = [ch for ch in self.project if ch.isupper()]
        return ''.join(caps[:2]) if len(caps) >= 2 else self.project[:2]

    @property
    def section(self):
        if self.snoozed:
            return 'Snoozed'
        return 'Needs you' if self.state in ('ask', 'stopped') else 'Working'

    def ink(self, style):
        """A style for one of the row's words: an away row's dimmed, all its words as one."""
        return style + '.dim' if self.away and not self.snoozed else style

    @property
    def pill(self):
        return PILLS[self.state] + ('.snoozed' if self.snoozed else '.away' if self.away else '')


def ask(name, project, status, time, count=1, away=False):
    return S(name, project, 'ask', status, time, count, away)


def turn(name, project, status, time, away=False):
    return S(name, project, 'stopped', status, time, away=away)


def working(name, project, status, time, away=False):
    return S(name, project, 'working', status, time, away=away)


def own(name, project, status, time):
    return S(name, project, 'own', status, time)


def snoozed(state, name, project, status, wakes, count=1):
    return S(name, project, state, status, wakes, count, snoozed=True)


# Needs you in the notch's order: its asks, here then away, then its turns, here
# then away, each newest first. Email templates' Claude ended; Warehouse map's
# Claude runs where no terminal on this Mac shows it.
REST = [
    ask('Data import', 'Litware', 'Allow Bash: psql -f import.sql', '1m'),
    ask('Help desk redesign', 'Northwind', 'Thread replies, or keep them flat?', '4m'),
    ask('Shift schedules', 'Contoso', 'Approve the rota', '26m'),
    ask('Email templates', 'Fabrikam', 'Keep the plain-text versions?', '2h', away=True),
    turn('Release notes', 'Tailspin', 'Drafted the 2.4 release notes', '31m'),
    turn('Warehouse map', 'Litware', 'Mapped the ground floor', '1h', away=True),
    working('Mobile app', 'Woodgrove', 'Running npm test', '6m'),
    working('Invoice ledger', 'Northwind', 'Exporting the ledger as CSV', '2m'),
    own('Catalog sync', 'Fabrikam', 'Waiting on 2 agents', '15m'),
    snoozed('ask', 'Onboarding flow', 'Contoso', 'Pick the onboarding steps', 'tomorrow 09:00'),
    snoozed('stopped', 'Pricing page', 'Litware', 'Drafted three price tiers', 'next week'),
]
NEW_ASK = ask('Room bookings', 'Woodgrove', 'Can a room be booked twice?', 'now')

BUSY = [
    ask('Data import', 'Litware', 'Allow Bash: psql -f import.sql', '1m'),
    ask('Help desk redesign', 'Northwind', 'Thread replies, or keep them flat?', '4m', 2),
    ask('Room bookings', 'Adventure Works', 'Can a room be booked twice?', '9m'),
    ask('Shift schedules', 'Contoso', 'Approve the rota', '26m'),
    ask('Expense claims', 'Trey Research', 'Which receipts need a scan?', '40m', 3),
    ask('Tax rates', 'Wingtip', 'Allow Edit: src/tax/rates.ts', '52m'),
    ask('Email templates', 'Fabrikam', 'Keep the plain-text versions?', '2h', away=True),
    ask('Gift cards', 'Tailspin', 'Should a card expire?', '3h', away=True),
    turn('Release notes', 'Tailspin', 'Drafted the 2.4 release notes', '31m'),
    turn('Search index', 'Wingtip', 'Rebuilt the index; 3 fields left', '1h'),
    turn('Staff directory', 'Contoso', 'Added the new starters', '2h'),
    turn('Warehouse map', 'Litware', 'Mapped the ground floor', '1h', away=True),
    working('Payroll export', 'Contoso', 'Writing payroll.csv', '22m'),
    working('Stock levels', 'Wingtip', 'Reading src/stock/levels.ts', '12m'),
    working('Delivery slots', 'Northwind', 'Running the slot planner', '9m', away=True),
    working('Mobile app', 'Woodgrove', 'Running npm test', '6m'),
    working('Route planner', 'Trey Research', 'Searching for route costs', '5m'),
    working('Sales dashboard', 'Adventure Works', 'Editing src/charts/sales.tsx', '4m'),
    working('Loyalty points', 'Woodgrove', 'Reading the points ledger', '3m'),
    working('Invoice ledger', 'Northwind', 'Exporting the ledger as CSV', '2m'),
    working('Login page', 'Adventure Works', 'Editing src/login/form.tsx', '1m'),
    working('Error alerts', 'Trey Research', 'Fetching the alert rules', '1m'),
    own('Report builder', 'Fabrikam', 'Wakes in 12m', '1h'),
    own('Audit log', 'Tailspin', 'Watching the nightly export', '48m'),
    own('Catalog sync', 'Fabrikam', 'Waiting on 2 agents', '15m'),
    own('Booking reminders', 'Litware', 'Running the reminder job', '8m'),
    snoozed('ask', 'Onboarding flow', 'Contoso', 'Pick the onboarding steps', 'tomorrow 09:00'),
    snoozed('ask', 'Survey results', 'Woodgrove', 'Keep the free-text answers?', 'Sat 09:00'),
    snoozed('stopped', 'Holiday calendar', 'Northwind', 'Added the bank holidays', 'Sun 09:00'),
    snoozed('stopped', 'Pricing page', 'Litware', 'Drafted three price tiers', 'next week'),
]
assert len(BUSY) == 30 and len({s.project for s in BUSY}) == 9

NAMES = sorted({s.name for s in REST + BUSY + [NEW_ASK]} | {s.project for s in REST + BUSY})
SECTIONS = ('Needs you', 'Working', 'Snoozed')


class Scene:
    """What a frame shows: the sessions, Snoozed open or folded, the cursor's
    session, a new ask arriving, the message after a pick, and the keys."""

    def __init__(self, sessions, snoozed_open=False, cursor=None, arrived=None, message=None,
                 colour=True):
        self.sessions, self.snoozed_open, self.cursor = sessions, snoozed_open, cursor
        self.arrived, self.message, self.colour = arrived, message, colour

    def sections(self):
        """(name, its sessions, open) for each section with sessions, in the notch's order."""
        out = []
        for name in SECTIONS:
            rows = [s for s in self.sessions if s.section == name]
            if rows:
                out.append((name, rows, name != 'Snoozed' or self.snoozed_open))
        return out

    def keys(self):
        """The key line's hints, most needed first: the line drops them from the right."""
        if not self.sessions:
            return [('q', 'quit')]
        fold = [('s', 'snoozed')] if any(s.snoozed for s in self.sessions) else []
        if self.cursor is None:
            return [('↑↓', 'pick')] + fold + [('q', 'quit')]
        return [('↑↓', 'move'), ('⏎', 'open')] + fold + [('q', 'quit')]


def with_new(sessions, new):
    """The board with a new ask landed: Needs you's newest, so its first row."""
    return [new] + sessions


# Release notes shows in a terminal on this Mac with no tmux or zmx, so the panel
# can't attach it. Email templates, whose Claude ended, isn't unreachable: picking
# it resumes it in place.
UNREACHABLE = "Release notes can't be opened here: its terminal has no tmux or zmx."

# ---------------------------------------------------------------- shared drawing


def counts(c, x, y, rows):
    """A section's counts after its name: Needs you's asks (orange ●) and stopped (blue ●), as
    the notch's two; Working's rows; Snoozed's lines, in grey, as the notch's."""
    if rows[0].snoozed:
        return c.put(x, y, str(sum(s.count for s in rows)), 'grey')
    asks = sum(s.count for s in rows if s.state == 'ask')
    stops = sum(1 for s in rows if s.state == 'stopped')
    if asks or stops:
        if asks:
            x = c.run(x, y, [('●', 'ask'), (str(asks), 'ask.bold'), (' ', None)])
        if stops:
            x = c.run(x, y, [('●', 'stop'), (str(stops), 'stop.bold'), (' ', None)])
        return x - 1
    return c.put(x, y, str(len(rows)), 'grey')


def keyline(c, y, x0, x1, hints):
    """The keys that work, dropping whole hints from the right when short of room."""
    parts = []
    for key, word in hints:
        trial = parts + ([('  ', None)] if parts else []) + [(key, 'key'), (' ' + word, 'grey')]
        if x0 + sum(tg.width_of(t) for t, _ in trial) > x1:
            break
        parts = trial
    c.run(x0, y, parts)


def name_parts(s, w):
    """A row's name in w cells, cut before its count, never the count."""
    style = s.ink(('name.snoozed' + ('.bold' if s.state == 'ask' else '')) if s.snoozed
                  else MARKS[s.state][3])
    count = f' {s.count}' if s.count > 1 else ''
    name = tg.cut(s.name, w - len(count))
    return [(name, style), (count, s.ink('grey'))] if count else [(name, style)]


def name_cells(s):
    return tg.width_of(s.name) + (len(f' {s.count}') if s.count > 1 else 0)


def mark_of(s, scene):
    """A row's mark: its state's, filled here and hollow away, dimmed in Snoozed."""
    here, away, style, _ = MARKS[s.state]
    if scene.arrived is s:
        return ARRIVING, 'ask.bold'
    return (away if s.away else here), style + ('.snoozed' if s.snoozed else '')


def row_ground(c, scene, s, y, x0, x1, h=1):
    """The cursor's band, or a new ask's wash, under a row's lines."""
    if not scene.colour:
        return
    ground = SELECTED if scene.cursor is s else WASH if scene.arrived is s else None
    if ground:
        for r in range(y, y + h):
            c.band(r, ground, x0, x1)


def pinned(blocks, start):
    """The heading a view scrolled to start keeps at its top: its first row's section's."""
    if start == 0 or blocks[start][1] not in ('row', 'grid'):
        return None
    return next(b for b in reversed(blocks[:start]) if b[1] == 'head')


def window(blocks, height, at):
    """The blocks that show in height rows with the block at index `at` in view,
    the heading kept over them, and how many sessions are above and below, each
    said on a line of its own."""
    def fits(start):
        used = (1 if start else 0) + (1 if pinned(blocks, start) else 0)
        end = start
        while end < len(blocks):
            more = 1 if end + 1 < len(blocks) else 0
            if used + blocks[end][0] + more > height:
                break
            used += blocks[end][0]
            end += 1
        return end
    start = 0
    while True:
        end = fits(start)
        if at is None or at < end or start >= at:
            break
        start += 1
    sessions = lambda bs: sum(len(b[2]) if b[1] == 'grid' else 1 for b in bs if b[1] in ('row', 'grid'))
    return pinned(blocks, start), blocks[start:end], sessions(blocks[:start]), sessions(blocks[end:])


def draw_body(c, blocks, x, y0, y1, cursor_block, draw_block):
    """Draws the blocks that fit between rows y0 and y1, with ▲ and ▼ lines for
    the sessions out of view, and the section's heading kept at the top."""
    head, shown, above, below = window(blocks, y1 - y0, cursor_block)
    y = y0
    if head:
        draw_block(head, y)
        y += 1
    if above:
        c.put(x, y, f'▲ {above} more', 'grey')
        y += 1
    for block in shown:
        draw_block(block, y)
        y += block[0]
    if below:
        c.put(x, y, f'▼ {below} more', 'grey')


def cursor_index(blocks, scene):
    for i, b in enumerate(blocks):
        if b[1] == 'row' and b[2] is scene.cursor or b[1] == 'grid' and scene.cursor in b[2]:
            return i
    return None


def message_lines(scene, width):
    return textwrap.wrap(scene.message, width) if scene.message else []


def say_message(c, x, y, lines):
    """The pick's answer: a mark, then its words, plainly."""
    for i, line in enumerate(lines):
        if i == 0:
            c.run(x, y, [('!', 'say'), (' ', None)])
        c.put(x + 2, y + i, line, 'name')


def quiet(c, x0, x1, y0, y1):
    """An empty board: the notch's "All clear", and what it means."""
    lines = [('All clear', 'name.bold'), ('', None)] + [
        (t, 'grey') for t in textwrap.wrap('Nothing needs you, and nothing is running.', min(x1 - x0 - 2, 24))]
    top = y0 + max(0, (y1 - y0 - len(lines)) // 2 - 1)
    for i, (t, style) in enumerate(lines):
        if t:
            c.put(x0 + (x1 - x0 - tg.width_of(t)) // 2, top + i, t, style)


MOST = 120  # the widest List, Card and Two-line lay out; past it they stand at the left


class Columns:
    """A one-line row's columns in avail cells after its mark: the name, the
    status (where at least STATUS cells are left for it), the project, whole or
    its letters, and the time. Narrowing gives way in the look's order."""
    STATUS = 16

    def __init__(self, rows, avail, all_rows, letters_first):
        natural = max(name_cells(s) for s in all_rows)
        time_w = max(tg.width_of(s.time) for s in rows)
        whole = max(tg.width_of(s.project) for s in all_rows)
        least = min(natural, 14)
        self.letters = False
        self.project_w = whole
        rest = avail - natural - 2 - whole - 1 - time_w - 2
        self.status_w = min(rest, max(tg.width_of(s.status) for s in all_rows)) if rest >= self.STATUS else 0
        if not self.status_w:
            room = avail - whole - 1 - time_w - 2
            if letters_first and room < natural or room < least:
                self.letters, self.project_w = True, 2
        if self.status_w:
            self.name_w = natural
        else:
            self.name_w = min(natural, avail - self.project_w - 1 - time_w - 2)
        self.time_w = time_w

    def draw(self, c, x, y, s, end):
        """The row's name from x, then its status; its project in a lane that
        ends where the time's lane starts, so what's spare falls after the words."""
        c.run(x, y, name_parts(s, self.name_w))
        px = end - self.time_w - 1 - self.project_w
        if self.status_w:
            sx = x + self.name_w + 2
            c.put(sx, y, tg.cut(s.status, px - 2 - sx), s.ink('soft'))
        c.put(px, y, s.letters if self.letters else s.project, s.ink('grey'))
        c.right(end, y, [(s.time, s.ink('grey'))])


def row_blocks(scene, row_h):
    """The body as blocks (height, kind, payload): a section's heading, its rows
    while open, and a gap row between sections."""
    blocks = []
    for i, (name, rows, is_open) in enumerate(scene.sections()):
        if i:
            blocks.append((1, 'gap', None))
        blocks.append((1, 'head', (name, rows, is_open)))
        if is_open:
            blocks += [(row_h, 'row', s) for s in rows]
    return blocks


def canvas(scene, w, h):
    return tg.Canvas(w, h, COLOUR if scene.colour else PLAIN)


# ---------------------------------------------------------------- the looks


class List:
    """Borderless sections and rows, the pane's idiom: a heading and a rule over
    each section, its rows under it, the project in a column of its own."""
    key, name = 'list', 'List'

    def draw(self, scene, w, h):
        c = canvas(scene, w, h)
        cw = min(w, MOST)
        c.put(1, 0, 'sitrep', 'title')
        msg = message_lines(scene, cw - 4)
        foot = h - 1 - (len(msg) + 1 if msg else 0)
        if not scene.sessions:
            quiet(c, 1, cw - 1, 1, h - 1)
        else:
            blocks = row_blocks(scene, 1)
            open_rows = [s for _, rows, o in scene.sections() if o for s in rows]
            cols = {}
            for name, rows, is_open in scene.sections():
                cols[name] = Columns(rows, cw - 5 - 1, open_rows, letters_first=False)

            def block(b, y):
                kind, p = b[1], b[2]
                if kind == 'head':
                    name, rows, is_open = p
                    x = c.put(1, y, name, 'head')
                    x = counts(c, x + 1, y, rows)
                    c.put(cw - 2, y, OPEN if is_open else FOLDED, 'faint')
                    c.hline(x + 1, y, cw - 4 - x, 'faint')
                elif kind == 'row':
                    s = p
                    section = next(n for n, rows, _ in scene.sections() if s in rows)
                    if scene.cursor is s:
                        c.put(1, y, CURSOR, 'cursor')
                    glyph, style = mark_of(s, scene)
                    c.put(3, y, glyph, style)
                    cols[section].draw(c, 5, y, s, cw - 1)
                    row_ground(c, scene, s, y, 1, cw - 1)
            draw_body(c, blocks, 3, 2, foot, cursor_index(blocks, scene), block)
        if msg:
            say_message(c, 1, h - 1 - len(msg), msg)
        keyline(c, h - 1, 1, cw - 1, scene.keys())
        return c


class Card:
    """The notch's card drawn in box lines, rounded, its sections inside under
    eyebrows, told apart by space alone, as the card's are."""
    key, name = 'card', 'Card'

    def draw(self, scene, w, h):
        c = canvas(scene, w, h)
        cw = min(w, MOST)
        left, right = 1, cw - 1          # the box's columns, x0 to x1 exclusive
        inner0, inner1 = left + 2, right - 2
        msg = message_lines(scene, inner1 - inner0 - 2)
        if not scene.sessions:
            top, bottom = 0, min(h - 2, 9)
            quiet(c, left + 1, right - 1, top + 1, bottom)
            self.box(c, left, top, right - left, bottom - top + 1)
            keyline(c, h - 1, 1, cw - 1, scene.keys())
            return c
        blocks = row_blocks(scene, 1)
        body_room = h - 1 - 2 - 1 - (len(msg) + 1 if msg else 0)  # the key line, the box, a pad row
        body_h = min(sum(b[0] for b in blocks), body_room)
        bottom = 1 + body_h + 1 + (len(msg) + 1 if msg else 0)
        open_rows = [s for _, rows, o in scene.sections() if o for s in rows]
        avail = inner1 - (inner0 + 4)
        cols = {name: Columns(rows, avail, open_rows, letters_first=True)
                for name, rows, _ in scene.sections()}

        def block(b, y):
            kind, p = b[1], b[2]
            if kind == 'head':
                name, rows, is_open = p
                x = c.put(inner0, y, name, 'eyebrow')
                counts(c, x + 2, y, rows)
                c.put(inner1 - 1, y, OPEN if is_open else FOLDED, 'faint')
            elif kind == 'row':
                s = p
                section = next(n for n, rows, _ in scene.sections() if s in rows)
                if scene.cursor is s:
                    c.put(inner0, y, CURSOR, 'cursor')
                glyph, style = mark_of(s, scene)
                c.put(inner0 + 2, y, glyph, style)
                cols[section].draw(c, inner0 + 4, y, s, inner1)
                row_ground(c, scene, s, y, left + 1, right - 1)
        draw_body(c, blocks, inner0 + 2, 2, 2 + body_h, cursor_index(blocks, scene), block)
        if msg:
            say_message(c, inner0, bottom - len(msg), msg)
        self.box(c, left, 0, right - left, bottom + 1)
        keyline(c, h - 1, 1, cw - 1, scene.keys())
        return c

    def box(self, c, x, y, w, h):
        c.box(x, y, w, h, 'faint', kind='round')
        c.put(x + 2, y, ' sitrep ', 'title')


class TwoLine:
    """Each session on two lines, roomy for a phone: its name and time, then its
    project and status line, faint, under it."""
    key, name = 'two', 'Two-line'

    def draw(self, scene, w, h):
        c = canvas(scene, w, h)
        cw = min(w, MOST)
        c.put(1, 0, 'sitrep', 'title')
        msg = message_lines(scene, cw - 4)
        foot = h - 1 - (len(msg) + 1 if msg else 0)
        if not scene.sessions:
            quiet(c, 1, cw - 1, 1, h - 1)
        else:
            blocks = row_blocks(scene, 2)

            def block(b, y):
                kind, p = b[1], b[2]
                if kind == 'head':
                    name, rows, is_open = p
                    x = c.put(1, y, name.upper(), 'eyebrow')
                    x = counts(c, x + 2, y, rows)
                    c.put(x + 2, y, OPEN if is_open else FOLDED, 'faint')
                elif kind == 'row':
                    s = p
                    if scene.cursor is s:
                        c.put(1, y, CURSOR, 'cursor')
                    glyph, style = mark_of(s, scene)
                    c.put(3, y, glyph, style)
                    time_w = tg.width_of(s.time)
                    c.run(5, y, name_parts(s, cw - 1 - 5 - time_w - 2))
                    c.right(cw - 1, y, [(s.time, s.ink('grey'))])
                    lead = s.project + ' · '
                    x = c.put(5, y + 1, tg.cut(lead, cw - 6), s.ink('grey'))
                    if x < cw - 1:
                        c.put(x, y + 1, tg.cut(s.status, cw - 1 - x), s.ink('soft'))
                    row_ground(c, scene, s, y, 1, cw - 1, 2)
            draw_body(c, blocks, 3, 2, foot, cursor_index(blocks, scene), block)
        if msg:
            say_message(c, 1, h - 1 - len(msg), msg)
        keyline(c, h - 1, 1, cw - 1, scene.keys())
        return c


class Marks:
    """The strip's idea: each project's two letters on a pill in its state's
    colour, the session's name beside it; the densest, its sections running on
    without gaps, and in columns where the width holds them."""
    key, name = 'marks', 'Marks'
    TILE = 33   # the least a column of tiles takes, name and time
    WIDE = 56   # a tile with room for its status line

    def columns(self, w):
        if w >= 100:
            return max(1, min(3, (w - 1) // self.WIDE))
        return max(1, min(2, (w - 1) // self.TILE))

    def draw(self, scene, w, h):
        c = canvas(scene, w, h)
        ncol = self.columns(w)
        tile_w = (w - 1) // ncol
        c.put(1, 0, 'sitrep', 'title')
        msg = message_lines(scene, w - 4)
        foot = h - 1 - (len(msg) + 1 if msg else 0)
        if not scene.sessions:
            quiet(c, 1, w - 1, 1, h - 1)
        else:
            blocks = []
            for name, rows, is_open in scene.sections():
                blocks.append((1, 'head', (name, rows, is_open)))
                if is_open:
                    depth = math.ceil(len(rows) / ncol)
                    for r in range(depth):
                        blocks.append((1, 'grid', [rows[k * depth + r] for k in range(ncol)
                                                   if k * depth + r < len(rows)]))
            open_rows = [s for _, rows, o in scene.sections() if o for s in rows]
            natural = max(name_cells(s) for s in open_rows)

            def tile(s, x, y, x1):
                if scene.cursor is s:
                    c.put(x, y, CURSOR, 'cursor')
                glyph, style = mark_of(s, scene)
                c.put(x + 1, y, glyph, style)
                nx = x + 8
                time_w = tg.width_of(s.time)
                room = x1 - nx - time_w - 2
                status_room = room - natural - 2
                if status_room >= Columns.STATUS:
                    c.run(nx, y, name_parts(s, natural))
                    c.put(nx + natural + 2, y, tg.cut(s.status, status_room), s.ink('soft'))
                else:
                    c.run(nx, y, name_parts(s, room))
                c.right(x1, y, [(s.time, s.ink('grey'))])
                row_ground(c, scene, s, y, x, x1)
                c.put(x + 3, y, f' {s.letters:<2} ', s.pill)  # after the band, so the pill keeps its ground

            def block(b, y):
                kind, p = b[1], b[2]
                if kind == 'head':
                    name, rows, is_open = p
                    x = c.put(1, y, name, 'eyebrow')
                    x = counts(c, x + 1, y, rows)
                    c.put(x + 1, y, OPEN if is_open else FOLDED, 'faint')
                else:
                    for k, s in enumerate(p):
                        x0 = 1 + k * tile_w
                        tile(s, x0, y, x0 + tile_w - (2 if k < ncol - 1 else 1))
            at = cursor_index(blocks, scene)
            draw_body(c, blocks, 2, 1, foot, at, block)
        if msg:
            say_message(c, 1, h - 1 - len(msg), msg)
        keyline(c, h - 1, 1, w - 1, scene.keys())
        return c


LOOKS = [List(), Card(), TwoLine(), Marks()]

# ---------------------------------------------------------------- the screens

def named(sessions, name):
    return next(s for s in sessions if s.name == name)


PICKED = named(REST, 'Help desk redesign')
UNREACHED = named(REST, 'Release notes')
BUSY_CURSOR = named(BUSY, 'Invoice ledger')  # under the fold of every look at 27 rows and at 15

SMALL, SLIDE, PANE, WIDE, WIDEST, SHORT = (39, 27), (69, 46), (73, 36), (114, 45), (173, 53), (73, 15)

SCREENS = [
    # key, what, scene, sizes
    ('rest', 'at rest', lambda: Scene(REST), (SMALL, SLIDE, PANE)),
    ('picked', 'a row picked', lambda: Scene(REST, cursor=PICKED), (SMALL, SLIDE, PANE)),
    ('unfolded', 'Snoozed open', lambda: Scene(REST, snoozed_open=True), (SMALL, SLIDE)),
    ('busy', '30 sessions, scrolled', lambda: Scene(BUSY, cursor=BUSY_CURSOR),
     (SMALL, SLIDE, PANE, SHORT)),
    ('arriving', 'a new ask lands (an OSC 9 notification goes too)',
     lambda: Scene(with_new(REST, NEW_ASK), arrived=NEW_ASK), (SMALL, SLIDE)),
    ('unreachable', 'a pick it can\'t attach', lambda: Scene(REST, cursor=UNREACHED, message=UNREACHABLE),
     (SMALL, SLIDE)),
    ('quiet', 'an empty board', lambda: Scene([]), (SMALL, SLIDE)),
    ('wide', 'rows gain their status line', lambda: Scene(REST, cursor=PICKED), (WIDE, WIDEST)),
    ('nocolor', 'NO_COLOR', lambda: Scene(REST, cursor=PICKED, snoozed_open=True, colour=False), (SMALL,)),
]


LEGEND = [
    ('●', 'ask', 'an ask or a permission prompt waits, here', 'orange'),
    ('○', 'ask', 'an ask, away: no window, or its Claude ended', 'orange'),
    ('●', 'stop', 'your turn: Claude stopped, here', 'blue'),
    ('○', 'stop', 'your turn, away; its words dimmed, as one', 'blue'),
    ('✻', 'work', 'working: Claude Code\'s spinner, all in step', 'soft grey'),
    ('◌', 'own', 'on its own work: agents, a shell, a wake', 'grey'),
    ('●', 'ask.snoozed', 'in Snoozed, a row keeps its mark, dimmed', 'dimmed'),
    ('◉', 'ask.bold', 'a new ask, its row washed for two seconds', 'orange'),
    ('▸', 'cursor', 'the chosen row, on a band', ''),
    ('▿▹', 'faint', 'a section open, folded', ''),
    ('▲▼', 'grey', 'sessions out of view', ''),
    ('!', 'say', 'the answer to a pick', ''),
]


def readme(w=86):
    """The READ ME: what the round tests, each look in a sentence, the marks."""
    head = [
        ('sitrep · the board in a terminal · round 2 · circles', 'title'),
        ('', None),
        ('A row of frames is a look; along it, the screens of design/terminal-ui.md.', None),
        ('', None),
        ('List      borderless sections, a rule over each, the project in a column', None),
        ('Card      the notch\'s card in rounded box lines, sections told apart by space', None),
        ('Two-line  each session on two lines: name and time, then project · status', None),
        ('Marks     the strip\'s letters on a pill of state colour; densest, in columns', None),
        ('', None),
        ('Legend', 'title'),
    ]
    foot = [
        ('', None),
        ('Sizes: 39×27 the iPad\'s small window, 69×46 its slide-over, 73×36 a Ghostty', None),
        ('pane, 114×45 the iPad\'s main window, 173×53 the widest, 73×15 short.', None),
        ('The terminal notification a new ask posts is not drawn.', 'grey'),
        ('Paper holds the frames that decide the look; every screen at every size is in', None),
        ('the repo\'s preview, design/paper/round1/preview.html.', None),
    ]
    c = tg.Canvas(w, len(head) + len(LEGEND) + len(foot) + 2, COLOUR)
    y = 1
    for t, style in head:
        c.put(1, y, t, style)
        y += 1
    for glyph, style, meaning, colour in LEGEND:
        c.put(3, y, glyph, style)
        c.put(7, y, meaning)
        c.put(52, y, colour, 'grey')
        y += 1
    for t, style in foot:
        c.put(1, y, t, style)
        y += 1
    return c


# What the round draws on purpose that a width check takes for a break: (the
# frames' screen, the rule, why). The run fails on a listed break no longer drawn.
ON_PURPOSE = [
    ('quiet', 'a wasted third',
     'an empty board says "All clear" and one short line, centred; nothing is there to widen'),
]


def listed(key, rule):
    return next((why for screen, r, why in ON_PURPOSE if r == rule and f'-{screen}-' in key), None)


# The frames that go to Paper, each look's in this order: (screen, size).
PAPER = [('rest', SMALL), ('rest', SLIDE), ('picked', SMALL), ('unfolded', SMALL),
         ('busy', SHORT), ('wide', WIDE)]
PAPER_DIR = os.path.join(HERE, 'for-paper')


def main(argv):
    """Every frame to frames/ and the preview; the Paper set, with its jobs where
    a page and a file id are given, to for-paper/."""
    r = tg.Round(HERE, area='board', theme=tg.NORDFOX)
    r.add('readme', readme(), '', name='READ ME')
    to_paper = tg.Round(PAPER_DIR, area='board', theme=tg.NORDFOX)
    to_paper.add('readme', readme(), '', name='READ ME')
    for row, look in enumerate(LOOKS, 1):
        for skey, size in PAPER:
            scene = next(sc for k, _, sc, _ in SCREENS if k == skey)
            what = next(w for k, w, _, _ in SCREENS if k == skey)
            to_paper.add(f'{look.key}-{skey}-{size[0]}x{size[1]}', look.draw(scene(), *size),
                         f'{look.name} · {size[0]}×{size[1]} · {what}', row=row)
    breaks, kept, frames = [], [], []
    for row, look in enumerate(LOOKS, 1):
        for skey, what, scene, sizes in SCREENS:
            for w, h in sizes:
                s = scene()
                c = look.draw(s, w, h)
                key = f'{look.key}-{skey}-{w}x{h}'
                r.add(key, c, f'{look.name} · {w}×{h} · {what}', row=row)
                frames.append((key, c))
                most = None if look.key == 'marks' else MOST
                draws = None if skey == 'quiet' else (
                    lambda rows: any(g in t for t in rows for g in '●○✻◌◉'))
                for rule, shown in tg.sweep(c, NAMES, out_of_view=r'▼ \d+ more', draws=draws, most=most):
                    (kept if listed(key, rule) else breaks).append((key, rule, shown))
    r.write()
    to_paper.write(argv)
    bad = 0
    for key, c in frames:
        with open(os.path.join(HERE, 'frames', key + '.ansi')) as f:
            back = tg.read_ansi(f.read(), width=c.width, height=c.height, scrollback=False)
        diffs = tg.compare(c, back)
        if diffs:
            bad += 1
            print(tg.describe(key + '.ansi read back', diffs))
    print(f'{len(frames)} frames read back' + ('' if bad else ', each to its canvas, cell for cell'))
    print('width checks: ' + ('\n  '.join([''] + [f'{k}: {r}, {s}' for k, r, s in breaks])
                              if breaks else 'none broken'))
    for screen, rule, why in ON_PURPOSE:
        hits = [k for k, r, _ in kept if r == rule and f'-{screen}-' in k]
        print(f'on purpose, {screen}, {rule}: ' + (', '.join(hits) if hits else 'NO LONGER DRAWN') + f' ({why})')
        bad += 0 if hits else 1
    return 1 if bad or breaks else 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
