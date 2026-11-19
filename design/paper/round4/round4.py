#!/usr/bin/env python3
"""Round 4 of the board in a terminal: round 3's Two-line under rules, its
section headings in grey capitals, in the rule's tone and a step louder.

    python3 round4.py [page id] [file id]

It writes frames/, paper/ and preview.html beside itself (jobs/ too, given a
page and a file), reads every .ansi back against its canvas, and runs the
width checks on every frame. Everything but the headings is round 3's.
"""
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, '..', 'round3'))
import round3 as r3  # noqa: E402
from round3 import r1, tg  # noqa: E402


class GreyCapitals(r3.TwoLineUnderRules):
    """Round 3's look with its headings' words in capitals, the pane's grey at
    regular weight, over the rule's fainter grey; plain capitals without colour."""
    key, name = 'caps', 'Grey capital headings'

    def canvas(self, scene, w, h):
        c = super().canvas(scene, w, h)
        c.styles['head.words'] = tg.pen(r1.GREY) if scene.colour else tg.pen()
        return c

    def heading_words(self, c, y, name):
        return c.put(r3.MARK, y, name.upper(), 'head.words')


LOOK = GreyCapitals()

CHANGE = ('round 4 · grey capital headings', [
    'Round 3, its section headings in capitals, in the pane\'s grey at regular weight,',
    'a step louder than the rule; the counts keep their orange and blue.',
])

if __name__ == '__main__':
    sys.exit(r3.run(LOOK, r3.readme(CHANGE, HERE), HERE, sys.argv[1:]))
