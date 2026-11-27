#!/usr/bin/env python3
"""Round 5 of the board in a terminal: the notch's one-line rows, and a row's
asks opened under it and answered by number, as the notch's asks panel answers.

    python3 round5.py [page id] [file id]

It writes frames/, paper/ and preview.html beside itself (jobs/ too, given a
page and a file), reads every .ansi back against its canvas, and runs the
width checks on every frame. The worlds, colours and helpers are round 1's,
the headings round 4's; the page draws as the build does since 20 November
2026, a blank top row and no title.
"""
import os
import sys
import textwrap

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, '..', 'round3'))
import round3 as r3  # noqa: E402
from round3 import r1, tg  # noqa: E402

MARK, NAME = 1, 3          # the mark's column, and the words' after it
GAP = 2                    # between the words and the project, and the project and the time
LANE = 3                   # an age's lane: now, 4m, 26m, 2h
WORDS_LEAST = 12           # the words keep this much before the project gives way
PROJECT_LEAST = 4          # a project cut shorter than this goes
ANSWER = NAME + 2          # an answer's words, after its number and a space
CLOSED, OPENED = '▹', '▿'  # the band's row with asks, and its asks open
DOT_ON, DOT_OFF = '━━', '━'

# The band as the build draws it on Nordfox since 20 November 2026: the background
# stepped toward #3E4A5B by the least that reaches 1.13 : 1 (cli/panel/paint.ts),
# where rounds 1 to 4 drew #3E4A5B itself.
r1.SELECTED = '#343D4B'

LILAC = '#B1B9F9'          # Claude's pick: Claude Code's suggestion lilac
LILAC_TAG = '#9AA2EE'      # its "· Recommended"


def styles(colour):
    """Round 1's pens, and the asks': the title, Claude's pick and its tag,
    the page dots, and an answer held for its two seconds."""
    out = dict(r1.COLOUR if colour else r1.PLAIN)
    out['head.words'] = tg.pen(r1.GREY) if colour else tg.pen()

    def c(fg, bg='default', bold=False, faint=False):
        return tg.pen(fg, bg, bold=bold) if colour else tg.pen(bold=bold, faint=faint)
    out.update({
        'ask.title': c('default', bold=True),
        'answer': c('default'),
        'pick': c(LILAC),
        'pick.tag': c(LILAC_TAG, faint=True),
        'dot.on': c(r1.ORANGE, bold=True),
        'dot.off': c(r1.FAINT, faint=True),
        'arrow': c('default', bold=True),
        'held': tg.pen(r1.BG, r1.INK) if colour else tg.pen(reverse=True),
        'held.tag': tg.pen(tg.mix(r1.BG, r1.INK, 0.4), r1.INK) if colour else tg.pen(reverse=True),
        'ring': c(r1.ORANGE),
    })
    return out


COLOUR, PLAIN = styles(True), styles(False)

_cut = tg.cut


def cut(text, width):
    """A cut that never leaves a space before its ellipsis."""
    out = _cut(text, width)
    return out[:-2].rstrip() + '…' if out.endswith(' …') else out


tg.cut = cut


def keyline(c, y, x0, x1, hints):
    """The keys that work, dropping whole hints from the right when short of
    room, but never the last: q quit, or esc close while the asks are open."""
    last = hints[-1:]
    parts, kept = [], []
    for hint in hints[:-1] + last:
        trial = kept + [hint] if hint not in last else kept + last
        width = sum(tg.width_of(k) + 1 + tg.width_of(w) for k, w in trial) + 2 * (len(trial) - 1)
        if hint not in last and width + 2 + sum(tg.width_of(k) + 1 + tg.width_of(w) for k, w in last) > x1 - x0:
            continue
        kept = trial if hint not in last else kept
    for key, word in kept + last:
        parts += ([('  ', None)] if parts else []) + [(key, 'key'), (' ' + word, 'grey')]
    c.run(x0, y, parts)

# ---------------------------------------------------------------- the asks


class Ask:
    """A board ask the view answers: a yes, a choice, or words, which only opens."""

    def __init__(self, title, wants, age, options=(), recommended=None, yes=None):
        self.title, self.wants, self.age = title, wants, age
        self.options, self.recommended, self.yes = list(options), recommended, yes

    @property
    def answers(self):
        """Its answer rows, Claude's pick first, as the notch orders them."""
        if self.wants == 'yes':
            return [self.yes]
        if self.wants == 'choice':
            rest = [o for o in self.options if o != self.recommended]
            return ([self.recommended] if self.recommended else []) + rest
        return []


THREAD = Ask('Thread replies, or keep them flat?', 'choice', '4m',
             ['Flat', 'Threaded', 'Flat, with a quote of the one it answers'], recommended='Threaded')
OFFICE = Ask('Which office moves to the new desk first?', 'words', '12m')
ROTA = Ask('Approve the rota for the first week of December', 'yes', '26m', yes='Approve')
PLAIN_TEXT = Ask('Keep the plain-text versions?', 'choice', '2h', ['Keep them', 'Drop them'])

# The sessions the view answers asks of; Data import's lines are a permission
# prompt alone, which only its window answers, so it has no arrow.
ASKS = {'Help desk redesign': [THREAD, OFFICE], 'Shift schedules': [ROTA],
        'Email templates': [PLAIN_TEXT]}


def with_counts(sessions):
    """The world with each session's count its waiting lines: Help desk
    redesign's two asks."""
    out = []
    for s in sessions:
        if s.name in ASKS and not s.snoozed and len(ASKS[s.name]) > 1:
            s = r1.S(s.name, s.project, s.state, s.status, s.time, len(ASKS[s.name]), s.away)
        out.append(s)
    return out


REST = with_counts(r1.REST)
BUSY = with_counts(r1.BUSY)
NEW_ASK = r1.NEW_ASK


def named(sessions, name):
    return next(s for s in sessions if s.name == name)


class Scene(r1.Scene):
    """Round 1's scene, and the asks: the band's row expanded or its asks open
    on one of them, an answer held for its two seconds and how far it has run."""

    def __init__(self, sessions, opened=None, page=0, held=None, ran=0.25, expanded=False, **kw):
        super().__init__(sessions, **kw)
        self.opened, self.page, self.held, self.ran, self.expanded = opened, page, held, ran, expanded

    def asks_of(self, s):
        return [] if s.snoozed else ASKS.get(s.name, [])

    def keys(self):
        if not self.sessions:
            return [('q', 'quit')]
        fold = [('s', 'snoozed')] if any(s.snoozed for s in self.sessions) else []
        if self.opened is not None:
            ask = self.asks_of(self.opened)[self.page]
            if self.held is not None:
                return [('u', 'undo'), ('esc', 'close')]
            n = len(ask.answers)
            answer = [(f'1–{n}' if n > 1 else '1', 'answer')] if n else []
            page = [('←→', 'ask')] if len(self.asks_of(self.opened)) > 1 else []
            return answer + page + [('esc', 'close')]
        if self.cursor is None:
            return [('↑↓', 'pick')] + fold + [('q', 'quit')]
        s = self.cursor
        look = 'asks' if self.asks_of(s) else 'fold' if self.expanded else 'expand'
        snooze = [('z', 'wake' if s.snoozed else 'snooze')] if s.snoozed or s.section == 'Needs you' else []
        return [('↑↓', 'move'), ('⏎', look), ('o', 'open')] + snooze + fold + [('q', 'quit')]


# ---------------------------------------------------------------- a row on one line


def words_of(s):
    """What a row says, as the notch's row says it: an ask's session name and
    count; a stop's what Claude left you; a working row's what it is doing; a
    snoozed row's session name. Each as (text, style) parts, and its width."""
    if s.snoozed or s.state == 'ask':
        return None
    style = 'name' if s.state == 'stopped' else 'soft'
    return [(s.status, s.ink(style))]


def lane_of(rows):
    """A section's time lane: its widest time, an age's at the least."""
    return max([LANE] + [tg.width_of(s.time) for s in rows])


def project_cut(s, room):
    """The project in what the words leave it: whole, else cut, else gone."""
    whole = tg.width_of(s.project)
    if room >= whole:
        return s.project
    return tg.cut(s.project, room) if room >= PROJECT_LEAST else ''


def one_line(c, y, cw, s, scene, lane):
    """A session on one line: its mark, its words, its project at their right
    ending where the time's lane starts, and the time; on the band's row with
    asks the view answers, the arrow in the time's place."""
    glyph, style = r1.mark_of(s, scene)
    c.put(MARK, y, glyph, style)
    end = cw - 1                                    # the time ends at W-2
    project_end = end - lane - GAP
    room = project_end - NAME - GAP                 # the words and the project share it
    words = words_of(s)
    natural = r1.name_cells(s) if words is None else tg.width_of(s.status)
    project = project_cut(s, room - min(natural, WORDS_LEAST))
    words_w = room - tg.width_of(project) if project else project_end - NAME
    if words is None:
        c.run(NAME, y, r1.name_parts(s, words_w))
    else:
        c.put(NAME, y, tg.cut(s.status, words_w), words[0][1])
    if project:
        c.right(project_end, y, [(project, s.ink('grey'))])
    if scene.cursor is s and scene.asks_of(s):
        c.right(end, y, [(OPENED if scene.opened is s else CLOSED, 'arrow')])
    else:
        c.right(end, y, [(s.time, s.ink('grey'))])


# ---------------------------------------------------------------- a row looked at closer


def wrap(text, width):
    return textwrap.wrap(text, width, break_long_words=True) or ['']


def head_lines(s, scene, cw, lane):
    """An expanded or opened row's head, as the expanded row draws it since 20
    November 2026: the name and count wrapped whole under the names' column,
    the time or the arrow kept at the first line's right; then its project."""
    width = cw - 1 - lane - GAP - NAME
    count = f' {s.count}' if s.count > 1 else ''
    lines = wrap(s.name + count, width)
    style = s.ink(r1.MARKS[s.state][3])
    out = []
    for i, line in enumerate(lines):
        def draw(c, y, i=i, line=line):
            if i == 0:
                glyph, mark_style = r1.mark_of(s, scene)
                c.put(MARK, y, glyph, mark_style)
                right = OPENED if scene.opened is s else s.time
                c.right(cw - 1, y, [(right, 'arrow' if scene.opened is s else s.ink('grey'))])
            if count and i == len(lines) - 1 and line.endswith(count):
                c.run(NAME, y, [(line[:-len(count)], style), (count, s.ink('grey'))])
            else:
                c.put(NAME, y, line, style)
        out.append(draw)
    return out


def expanded_lines(s, scene, cw, lane):
    """The expanded row: its head, then its project · status wrapped as one."""
    out = head_lines(s, scene, cw, lane)
    text = f'{s.project} · {s.status}'
    for i, line in enumerate(wrap(text, cw - 1 - NAME)):
        def draw(c, y, i=i, line=line):
            if i == 0 and line.startswith(s.project + ' ·'):
                lead = s.project + ' · '
                c.run(NAME, y, [(lead, s.ink('grey')), (line[len(lead):], s.ink('soft'))])
            else:
                c.put(NAME, y, line, s.ink('soft'))
        out.append(draw)
    return out


def answer_lines(ask, n, cw, scene, held):
    """An answer row: its number in grey, its words after it wrapped to two
    lines at most, the second cut with …; Claude's pick in lilac, " · Recommended"
    after its words, on a line of its own where they leave no room. Held, it
    turns ink on white, a check at its right."""
    words = ask.answers[n]
    pick = ask.wants == 'choice' and words == ask.recommended
    tag = ' · Recommended' if pick else ''
    width = cw - 1 - ANSWER - (2 if held else 0)
    lines = wrap(words, width)
    if len(lines) > 2:
        lines = [lines[0], tg.cut(' '.join(lines[1:]), width)]
    if tag:
        if tg.width_of(lines[-1] + tag) <= width:
            lines[-1] = (lines[-1], tag)
        elif len(lines) < 2:
            lines.append(('', tag.lstrip()))
        else:
            lines[-1] = (tg.cut(lines[-1], width - len(tag)), tag)
    word_style = 'held' if held else 'pick' if pick else 'answer'
    tag_style = 'held.tag' if held else 'pick.tag'
    out = []
    for i, line in enumerate(lines):
        text, t = line if isinstance(line, tuple) else (line, '')

        def draw(c, y, i=i, text=text, t=t):
            if held:
                c.fill(NAME, y, cw - 1 - NAME, 1, 'held')
            c.put(NAME, y, str(n + 1) if i == 0 else ' ', 'held' if held else 'grey')
            x = c.put(ANSWER, y, text, word_style) if text else ANSWER
            if t:
                c.put(x, y, t, tag_style)
            if held and i == 0:
                c.put(cw - 2, y, '✓', 'held')
        draw.held = held
        out.append(draw)
    return out


def asks_lines(s, scene, cw, lane):
    """The opened row: its head, then the ask on screen under it, as the
    notch's asks panel shows it: its title, when it was asked and the page
    dots, its answers, and the foot, or the sending line while an answer is
    held."""
    asks = scene.asks_of(s)
    ask = asks[scene.page]
    out = head_lines(s, scene, cw, lane)
    out.append(lambda c, y: c.put(NAME, y, s.project, s.ink('grey')))
    for line in wrap(ask.title, cw - 1 - NAME):
        out.append(lambda c, y, line=line: c.put(NAME, y, line, 'ask.title'))

    def age(c, y):
        c.put(NAME, y, f'Asked {ask.age} ago', 'grey')
        if len(asks) > 1:
            parts = []
            for i in range(len(asks)):
                parts += ([(' ', None)] if i else []) + [(DOT_ON, 'dot.on') if i == scene.page else (DOT_OFF, 'dot.off')]
            c.right(cw - 1, y, parts)
    out.append(age)
    for n in range(len(ask.answers)):
        out += answer_lines(ask, n, cw, scene, held=scene.held == n)
    if scene.held is not None:
        ring = '◔◑◕●'[min(3, int(scene.ran * 4))]

        def sending(c, y):
            words = ask.answers[scene.held]
            x = c.put(NAME, y, 'Sending ', 'grey')
            tail = [('  ', None), (ring, 'ring'), ('  ', None), ('u', 'key'), (' undo', 'grey')]
            room = cw - 1 - x - sum(tg.width_of(t) for t, _ in tail)
            x = c.put(x, y, tg.cut(words, room), 'answer')
            c.run(x, y, tail)
        out.append(sending)
    else:
        foot = [('x', 'Ignore'), ('z', 'Snooze'), ('o', 'Open')]

        def footer(c, y):
            parts = []
            for key, word in foot:
                parts += ([('  ', None)] if parts else []) + [(key, 'key'), (' ' + word, 'grey')]
            c.run(NAME, y, parts)
        out.append(footer)
    return out


# ---------------------------------------------------------------- the page


def blocks_of(scene, gaps=True):
    """The body as blocks (height, kind, payload, draw): a heading, a row on
    one line, the band's row expanded or opened, and a gap between sections."""
    blocks = []
    for i, (name, rows, is_open) in enumerate(scene.sections()):
        if i and gaps:
            blocks.append((1, 'gap', None))
        blocks.append((1, 'head', (name, rows, is_open)))
        if is_open:
            for s in rows:
                if scene.cursor is s and (scene.opened is s or scene.expanded):
                    blocks.append(('lines', 'row', s))
                else:
                    blocks.append((1, 'row', s))
    return blocks


class OneLine:
    """The notch's rows on one line under round 4's headings; the band's row
    looks closer under ⏎: its asks open under it where the view answers them,
    else it expands."""
    key, name = 'oneline', 'One line, asks under the row'

    def heading(self, c, y, cw, name, rows, is_open):
        x = c.put(MARK, y, name.upper(), 'head.words')
        x = r1.counts(c, x + 1, y, rows)
        c.hline(x + 1, y, cw - 4 - x, 'faint')
        c.put(cw - 2, y, r1.OPEN if is_open else r1.FOLDED, 'faint')

    def draw(self, scene, w, h):
        c = tg.Canvas(w, h, COLOUR if scene.colour else PLAIN)
        cw = min(w, r1.MOST)
        msg = r1.message_lines(scene, cw - 4)
        foot = h - 1 - (len(msg) + 1 if msg else 0)
        body_end = foot - 1                          # a blank row stands above the key line
        if not scene.sessions:
            r1.quiet(c, MARK, cw - 1, 1, h - 1)
        else:
            lanes = {name: lane_of(rows) for name, rows, _ in scene.sections()}
            section = {s: name for name, rows, _ in scene.sections() for s in rows}
            lines, lit = {}, {}
            blocks = []
            for b in blocks_of(scene, gaps=h >= 13):
                if b[0] == 'lines':
                    s = b[2]
                    lane = lanes[section[s]]
                    if scene.opened is s:
                        lines[s] = asks_lines(s, scene, cw, lane)
                        lit[s] = len(lines[s])          # the band over the asks too: one card, as the notch's asks panel
                    else:
                        lines[s] = expanded_lines(s, scene, cw, lane)
                        lit[s] = len(lines[s])
                    b = (len(lines[s]), b[1], s)
                blocks.append(b)
            total = sum(b[0] for b in blocks)
            top = 1 if total <= body_end - 1 else 0

            def ground(s, y, n):
                r1.row_ground(c, scene, s, y, MARK, cw - 1, n)
                if not scene.colour and scene.cursor is s:
                    for r in range(y, y + n):
                        r3.reverse(c, r, MARK, cw - 1)

            def block(b, y):
                if b[1] == 'head':
                    self.heading(c, y, cw, *b[2])
                elif b[1] == 'row':
                    s = b[2]
                    if s in lines:
                        for i, draw in enumerate(lines[s]):
                            draw(c, y + i)
                            if i < lit[s] and not getattr(draw, 'held', False):
                                ground(s, y + i, 1)
                    else:
                        one_line(c, y, cw, s, scene, lanes[section[s]])
                        ground(s, y, 1)
            r1.draw_body(c, blocks, MARK, top, body_end, r3.in_view(blocks, scene), block)
        if msg:
            r1.say_message(c, MARK, h - 1 - len(msg), msg)
        keyline(c, h - 1, MARK, cw - 1, scene.keys())
        return c


LOOK = OneLine()

# ---------------------------------------------------------------- the screens

HELP = named(REST, 'Help desk redesign')
ROTA_ROW = named(REST, 'Shift schedules')
PROMPT_ROW = named(REST, 'Data import')
BUSY_HELP = named(BUSY, 'Help desk redesign')
BUSY_CURSOR = named(BUSY, 'Invoice ledger')

SMALL, SLIDE, PANE, WIDE, WIDEST, SHORT = r1.SMALL, r1.SLIDE, r1.PANE, r1.WIDE, r1.WIDEST, r1.SHORT
NARROW, TINY = (30, 27), (24, 8)

SCREENS = [
    # key, what, scene, sizes
    ('rest', 'at rest', lambda: Scene(REST), (SMALL, SLIDE, PANE, NARROW)),
    ('picked', 'the band on a row with asks: its arrow', lambda: Scene(REST, cursor=HELP), (SMALL, SLIDE, PANE)),
    ('asks', '⏎ opens its asks: a choice, the first of two',
     lambda: Scene(REST, cursor=HELP, opened=HELP), (SMALL, SLIDE, PANE, WIDE, WIDEST, NARROW)),
    ('words', '→ pages to its second ask, a words ask',
     lambda: Scene(REST, cursor=HELP, opened=HELP, page=1), (SMALL, SLIDE)),
    ('yes', 'a yes ask, alone', lambda: Scene(REST, cursor=ROTA_ROW, opened=ROTA_ROW), (SMALL, SLIDE)),
    ('sending', '2 pressed: the answer held, u takes it back',
     lambda: Scene(REST, cursor=HELP, opened=HELP, held=1, ran=0.3), (SMALL, SLIDE)),
    ('prompt', 'the band on a prompt alone: no arrow', lambda: Scene(REST, cursor=PROMPT_ROW), (SMALL,)),
    ('expanded', '⏎ on a prompt alone expands it',
     lambda: Scene(REST, cursor=PROMPT_ROW, expanded=True), (SMALL, SLIDE)),
    ('unfolded', 'Snoozed open', lambda: Scene(REST, snoozed_open=True), (SMALL, SLIDE)),
    ('busy', '30 sessions, scrolled', lambda: Scene(BUSY, cursor=BUSY_CURSOR), (SMALL, SLIDE, PANE, SHORT)),
    ('busyasks', '30 sessions, asks open', lambda: Scene(BUSY, cursor=BUSY_HELP, opened=BUSY_HELP),
     (SMALL, SHORT)),
    ('arriving', 'a new ask lands', lambda: Scene(r1.with_new(REST, NEW_ASK), arrived=NEW_ASK), (SMALL,)),
    ('quiet', 'an empty board', lambda: Scene([]), (SMALL,)),
    ('nocolor', 'NO_COLOR, asks open', lambda: Scene(REST, cursor=HELP, opened=HELP, colour=False), (SMALL,)),
]

# The frames that go to Paper, row by row: (screen, size).
PAPER = [
    [('rest', SMALL), ('picked', SMALL), ('asks', SMALL), ('words', SMALL), ('yes', SMALL), ('sending', SMALL)],
    [('expanded', SMALL), ('nocolor', SMALL), ('asks', SLIDE), ('asks', WIDE)],
]

LEGEND = [
    ('●', 'ask', 'an ask, a permission prompt or a question waits, here', 'orange'),
    ('○', 'ask', 'the same, away', 'orange'),
    ('●', 'stop', 'Stopped: Claude finished its turn, here', 'blue'),
    ('✻', 'work', 'working', 'soft'),
    ('◌', 'own', 'on its own work', 'grey'),
    ('▹', 'arrow', 'on the band\'s row: asks this view answers; ⏎ opens them', 'ink'),
    ('▿', 'arrow', 'its asks open, under it', 'ink'),
    ('━━ ━', 'dot.on', 'the ask on screen, of two', 'orange, faint'),
    ('1', 'grey', 'an answer\'s number: the digit sends it', 'grey'),
    ('·', 'pick.tag', 'Claude\'s pick: lilac, "· Recommended" after it', 'lilac'),
    ('✓', 'arrow', 'an answer held for its two seconds, ink on white', ''),
]


def readme(w=86):
    head = [
        ('sitrep · the board in a terminal · round 5 · one line, asks under the row', 'title'),
        ('', None),
        ('Each session on one line, as the notch draws it: its words, its project at their', None),
        ('right, its time. An ask\'s row says its session; a stop\'s what Claude left you;', None),
        ('a working row what it is doing. ⏎ looks closer: on a row with asks this view', None),
        ('answers, it opens them under the row, one at a time, as the notch\'s asks panel;', None),
        ('on any other row it expands it. 1–9 answer, with two seconds to undo by u.', None),
        ('', None),
        ('Legend', 'title'),
    ]
    foot = [
        ('', None),
        ('Sizes: 39×27 the iPad\'s small window, 69×46 its slide-over, 114×45 its main', None),
        ('window. Every screen at every size is in design/paper/round5/preview.html.', None),
    ]
    c = tg.Canvas(w, len(head) + len(LEGEND) + len(foot) + 2, COLOUR)
    y = 1
    for t, style in head:
        c.put(1, y, t, style)
        y += 1
    for glyph, style, meaning, colour in LEGEND:
        if glyph == '━━ ━':
            c.run(3, y, [('━━', 'dot.on'), (' ', None), ('━', 'dot.off')])
        elif glyph == '✓':
            c.put(3, y, ' ✓', 'held')
        else:
            c.put(3, y, glyph, style)
        c.put(9, y, meaning)
        c.put(70, y, colour, 'grey')
        y += 1
    for t, style in foot:
        c.put(1, y, t, style)
        y += 1
    return c


ON_PURPOSE = r1.ON_PURPOSE


def run(argv):
    def frame_key(skey, w, h):
        return f'{LOOK.key}-{skey}-{w}x{h}'
    r = tg.Round(HERE, area='board', theme=tg.NORDFOX)
    to_paper = tg.Round(os.path.join(HERE, 'for-paper'), area='board', theme=tg.NORDFOX)
    for rnd in (r, to_paper):
        rnd.add('readme', readme(), '', name='READ ME')
    screens = {k: (what, sc) for k, what, sc, _ in SCREENS}
    for row, frames in enumerate(PAPER, 1):
        for skey, (w, h) in frames:
            what, scene = screens[skey]
            to_paper.add(frame_key(skey, w, h), LOOK.draw(scene(), w, h), f'{w}×{h} · {what}', row=row)
    breaks, kept, drawn = [], [], []
    names = r1.NAMES + sorted({a.title for asks in ASKS.values() for a in asks})
    for skey, what, scene, sizes in SCREENS:
        for w, h in sizes:
            c = LOOK.draw(scene(), w, h)
            key = frame_key(skey, w, h)
            r.add(key, c, f'{w}×{h} · {what}', row=1)
            drawn.append((key, c))
            if skey == 'tiny':
                continue
            draws = None if skey == 'quiet' else (
                lambda rows: any(g in t for t in rows for g in '●○✻◌◉'))
            for rule, shown in tg.sweep(c, names, out_of_view=r'▼ \d+ more', draws=draws, most=r1.MOST):
                (kept if r1.listed(key, rule) else breaks).append((key, rule, shown))
    r.write()
    to_paper.write(argv)
    bad = 0
    for key, c in drawn:
        with open(os.path.join(HERE, 'frames', key + '.ansi')) as f:
            back = tg.read_ansi(f.read(), width=c.width, height=c.height, scrollback=False)
        diffs = tg.compare(c, back)
        if diffs:
            bad += 1
            print(tg.describe(key + '.ansi read back', diffs))
    print(f'{len(drawn)} frames read back' + ('' if bad else ', each to its canvas, cell for cell'))
    print('width checks: ' + ('\n  '.join([''] + [f'{k}: {r}, {s}' for k, r, s in breaks])
                              if breaks else 'none broken'))
    return 1 if bad else 0


if __name__ == '__main__':
    sys.exit(run(sys.argv[1:]))
