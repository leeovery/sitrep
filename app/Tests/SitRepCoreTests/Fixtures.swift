import Foundation
@testable import SitRepCore
import Testing

/// An instant as the CLI prints it, in milliseconds since 1970.
func at(_ milliseconds: Double) -> Date {
    Date(timeIntervalSince1970: milliseconds / 1000)
}

/// A line of `sitrep watch`, as cli/output.ts's `watchLine` prints it but
/// pretty: Lee's board of 19 October 2026 cut to three sessions, an ask, a
/// permission prompt and a turn, the prompt new on it. Every field always
/// there, null where there is none.
let watched = """
{
  "v": 3,
  "at": 1792445574706,
  "version": "0.1.0",
  "head": { "needYou": 2, "sessions": 3 },
  "rows": [
    {
      "session": "sr-7e68fj",
      "section": "needsYou",
      "isAway": false,
      "project": "terrace",
      "name": "Plan the tool",
      "projectName": "Terrace",
      "letters": "Te",
      "lines": [
        {
          "key": "ask:sr-7e68fj:k1hs",
          "is": "ask",
          "ask": "k1hs",
          "writer": null,
          "first": {
            "lead": "Approve saved plans for anything needing a human",
            "mono": null,
            "more": null
          },
          "since": 1791991983206
        }
      ],
      "second": "Terrace · Plan the tool",
      "since": 1791991983206
    },
    {
      "session": "sr-y4d0qj",
      "section": "needsYou",
      "isAway": false,
      "project": "switchboard-7a75d7ba",
      "name": "Dashboard memory and snags",
      "projectName": "Switchboard",
      "letters": "Sw",
      "lines": [
        {
          "key": "stop:sr-y4d0qj:6c847b5b-722d-4343-88e0-42ece4662e7d:1792445500000",
          "is": "permission",
          "ask": null,
          "writer": "6c847b5b-722d-4343-88e0-42ece4662e7d",
          "first": { "lead": "Allow Bash", "mono": "gh pr create", "more": null },
          "since": 1792445500000
        }
      ],
      "second": "Switchboard · Dashboard memory and snags",
      "since": 1792445500000
    },
    {
      "session": "sr-aw3bgs",
      "section": "yourTurn",
      "isAway": false,
      "project": "code-84dbac88",
      "name": "Build the Mac app",
      "projectName": "SitRep",
      "letters": "SR",
      "lines": [
        {
          "key": "turn:sr-aw3bgs",
          "is": "yourTurn",
          "ask": null,
          "writer": "408a755f-ed3a-4ee1-9cc0-c0208cf3e03b",
          "first": {
            "lead": "Build phase 4b: sitrep watch, the feed the app reads",
            "mono": null,
            "more": null
          },
          "since": 1792259685462
        }
      ],
      "second": "SitRep · Build the Mac app",
      "since": 1792259685462
    }
  ],
  "projects": [
    {
      "key": "terrace",
      "name": "Terrace",
      "directory": null,
      "open": 1,
      "waiting": 1,
      "parked": 0,
      "updatedAt": 1791991983206,
      "sessions": [
        {
          "id": "sr-7e68fj",
          "name": "Plan the tool",
          "summary": "Settle terrace's open decisions, then write the spec and milestones",
          "now": [],
          "next": null,
          "isOpen": true,
          "waiting": 1,
          "parked": 0,
          "updatedAt": 1791991983206,
          "state": "needsYou",
          "since": 1791991983206,
          "doing": {
            "is": "yourTurn",
            "line": {
              "lead": "Settle terrace's open decisions, then write the spec and milestones",
              "mono": null,
              "more": null
            },
            "since": 1791991983206
          },
          "asks": [
            {
              "id": "k1hs",
              "wants": "yes",
              "yes": "Approve",
              "title": "Approve saved plans for anything needing a human",
              "where": "In the chat: decision 3, what an approval binds to",
              "options": [],
              "needs": null,
              "ref": "infra-tooling-roadmap memory, decision 3",
              "state": "waiting",
              "at": 1791991983206
            }
          ]
        }
      ]
    },
    {
      "key": "switchboard-7a75d7ba",
      "name": "Switchboard",
      "directory": "/Users/leeovery/Code/switchboard",
      "open": 2,
      "waiting": 0,
      "parked": 16,
      "updatedAt": 1792441698646,
      "sessions": [
        {
          "id": "sr-y4d0qj",
          "name": "Dashboard memory and snags",
          "summary": "Phase 1 merged; now phase 2: a session's page opens fast from day digests",
          "now": ["Close the day back from rows' small test gaps", "Build a turn read from rows"],
          "next": "Merge the turn, then the guard",
          "isOpen": true,
          "waiting": 0,
          "parked": 16,
          "updatedAt": 1792441698646,
          "state": "needsYou",
          "since": 1792445500000,
          "doing": {
            "is": "permission",
            "line": { "lead": "Allow Bash", "mono": "gh pr create", "more": null },
            "since": 1792445500000
          },
          "asks": []
        }
      ]
    },
    {
      "key": "code-84dbac88",
      "name": "SitRep",
      "directory": "/Users/leeovery/Code/sitrep",
      "open": 1,
      "waiting": 0,
      "parked": 13,
      "updatedAt": 1792445247692,
      "sessions": [
        {
          "id": "sr-aw3bgs",
          "name": "Build the Mac app",
          "summary": "Decide a desktop surface that pops what needs Lee",
          "now": ["Build phase 4b: sitrep watch, the feed the app reads"],
          "next": "Then the strip, the menu and Settings",
          "isOpen": true,
          "waiting": 0,
          "parked": 13,
          "updatedAt": 1792445247692,
          "state": "yourTurn",
          "since": 1792259685462,
          "doing": {
            "is": "yourTurn",
            "line": { "lead": "Build phase 4b: sitrep watch, the feed the app reads", "mono": null, "more": null },
            "since": 1792259685462
          },
          "asks": []
        }
      ]
    }
  ],
  "windows": [
    {
      "writer": "408a755f-ed3a-4ee1-9cc0-c0208cf3e03b",
      "session": "sr-aw3bgs",
      "name": "Build the Mac app",
      "project": "SitRep",
      "version": null,
      "needsReload": true,
      "where": {
        "device": "/dev/ttys043",
        "terminal": "tmux",
        "tmux": { "socket": "/private/tmp/tmux-501/default", "pane": "%148" }
      },
      "state": null,
      "attachedAt": 1792259685462
    },
    {
      "writer": "6c847b5b-722d-4343-88e0-42ece4662e7d",
      "session": "sr-y4d0qj",
      "name": "Dashboard memory and snags",
      "project": "Switchboard",
      "version": "0.1.0",
      "needsReload": false,
      "where": { "device": "/dev/ttys052", "terminal": "ghostty", "tmux": null },
      "state": {
        "is": "permission",
        "since": 1792445500000,
        "tool": { "name": "Bash", "subject": "gh pr create" },
        "question": null
      },
      "attachedAt": 1792328734797
    }
  ],
  "new": ["stop:sr-y4d0qj:6c847b5b-722d-4343-88e0-42ece4662e7d:1792445500000"],
  "boards": {}
}
"""

/// The first line of `sitrep watch` over an empty board, on one line as it prints it.
let watchedEmpty = #"{"v":3,"at":1792445580000,"version":"0.1.0","head":{"needYou":0,"sessions":0},"rows":[],"projects":[],"windows":[],"new":[],"boards":{}}"#
