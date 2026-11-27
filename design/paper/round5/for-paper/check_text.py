"""Check a drawn frame's text against its chunks.

python3 check_text.py <frame> <tree.json>

<frame> is the frame's folder under paper/ (field 1 of its job line, or its
basename). <tree.json> holds get_tree_summary's result for the frame's artboard
at depth 6, the JSON object copied exactly as the tool returned it (a file
holding only the summary text works too). Prints each row whose text differs
from its chunk, with the row's node id, or OK. The summary shows only the
first 60 characters of a Text node, so a run longer than that is checked that
far.

Copy it beside the round script, so a frame can be named by its basename;
from anywhere else, pass the frame's folder.
"""
import html.parser
import json
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
LINE = re.compile(r'^( *)(\S+) "(.*?)" \(([A-Za-z0-9]+-\d+)\) \S+?(?: "(.*)")?$')


class Rows(html.parser.HTMLParser):
    """Each chunk's rows: for every div directly inside its wrapper, the text
    of each run in it, in order, as Paper makes a Text node of each."""

    def __init__(self):
        super().__init__(convert_charrefs=True)
        self.depth = 0
        self.rows = []

    def handle_starttag(self, tag, attrs):
        if tag == 'div':
            self.depth += 1
            if self.depth == 2:
                self.rows.append([])

    def handle_endtag(self, tag):
        if tag == 'div':
            self.depth -= 1

    def handle_data(self, data):
        if self.depth >= 2:
            self.rows[-1].append(data)


def expected(folder):
    rows = []
    n = 1
    while os.path.exists(os.path.join(folder, f'{n:02d}.html')):
        p = Rows()
        with open(os.path.join(folder, f'{n:02d}.html')) as f:
            p.feed(f.read())
        rows.append(p.rows)
        n += 1
    t = Rows()
    with open(os.path.join(folder, 'titlebar.html')) as f:
        t.feed('<div>' + f.read() + '</div>')
    return rows, [d for r in t.rows for d in r]


def tree(text):
    try:
        text = json.loads(text)['summary']
    except (ValueError, KeyError, TypeError):
        pass
    nodes = []  # (indent, kind, name, id, content, children)
    stack = []
    for line in text.splitlines():
        m = LINE.match(line)
        if not m:
            m2 = re.match(r'^( *)(\S+) ', line)
            if not m2:
                continue
            raise SystemExit(f'cannot read line: {line!r}')
        ind, kind, name, nid, content = len(m.group(1)), m.group(2), m.group(3), m.group(4), m.group(5)
        node = [ind, kind, name, nid, content, []]
        while stack and stack[-1][0] >= ind:
            stack.pop()
        if stack:
            stack[-1][5].append(node)
        else:
            nodes.append(node)
        stack.append(node)
    return nodes


def texts(node):
    """The contents of a node's Text nodes, in order."""
    if node[1] == 'Text':
        return [node[4] or '']
    return [t for c in node[5] for t in texts(c)]


CUT = 60  # get_tree_summary shows a Text node's first 60 characters


def same(want, got):
    return len(want) == len(got) and all(g == w[:CUT] for w, g in zip(want, got))


def find(nodes, name):
    for n in nodes:
        if n[2] == name and n[1] == 'Frame':
            return n
        hit = find(n[5], name)
        if hit:
            return hit
    return None


def main(frame, path):
    folder = frame if os.path.isdir(frame) else os.path.join(HERE, 'paper', os.path.basename(frame.rstrip('/')))
    want, title = expected(folder)
    with open(path) as f:
        nodes = tree(f.read())
    bad = []
    bar = find(nodes, 'Title bar')
    if bar is None or not same(title, texts(bar)):
        bad.append(f'title: want {title!r}, got {texts(bar) if bar else None!r}')
    term = find(nodes, 'Terminal')
    if term is None:
        raise SystemExit('no Terminal frame in the tree: was it fetched at depth 6?')
    chunks = term[5]
    if len(chunks) != len(want):
        bad.append(f'{len(chunks)} chunks drawn, {len(want)} expected')
    row_no = 0
    for ci, (chunk, rows) in enumerate(zip(chunks, want), 1):
        got = chunk[5]
        if len(got) != len(rows):
            bad.append(f'chunk {ci} ({chunk[3]}): {len(got)} rows drawn, {len(rows)} expected')
        for ri, (node, row) in enumerate(zip(got, rows), 1):
            have = texts(node)
            if not same(row, have):
                bad.append(f'chunk {ci} row {ri} (frame row {row_no + ri}, node {node[3]}):\n'
                           f'    want {[w[:CUT] for w in row]!r}\n    got  {have!r}')
        row_no += len(rows)
    print('\n'.join(bad) if bad else f'OK: {sum(len(r) for r in want)} rows and the title match')
    return 1 if bad else 0


if __name__ == '__main__':
    sys.exit(main(*sys.argv[1:3]))
