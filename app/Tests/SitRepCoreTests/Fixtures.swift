/// `sitrep list --json` as cli/output.ts's `listJson` prints it: every field
/// always there, null where there is none. The project the CLI runs in is
/// listed even with no works; Fumi has two works on screen and one off.
let listed = """
{
  "v": 1,
  "here": "code-84dbac88",
  "projects": [
    {
      "key": "code-84dbac88",
      "name": "SitRep",
      "open": 0,
      "waiting": 0,
      "parked": 0,
      "updatedAt": 1791975967152,
      "works": []
    },
    {
      "key": "fumi",
      "name": "Fumi",
      "open": 2,
      "waiting": 1,
      "parked": 0,
      "updatedAt": 1791922649367,
      "works": [
        {
          "id": "sr-047c7y",
          "name": "Management window discussion",
          "summary": "Settle the Library and Settings windows' remaining design questions",
          "now": ["Deciding how the Library's rail holds hundreds of tags"],
          "next": null,
          "isOpen": true,
          "waiting": 1,
          "parked": 0,
          "updatedAt": 1791922649367,
          "onScreen": true
        },
        {
          "id": "sr-95dkk3",
          "name": "Rename the triage queue and inbox",
          "summary": "Rename the per-topic triage queue to a mailbox",
          "now": [],
          "next": "Start idea #54",
          "isOpen": false,
          "waiting": 0,
          "parked": 1,
          "updatedAt": 1791737931624,
          "onScreen": false
        },
        {
          "id": "sr-sa13jv",
          "name": "Commercialization discussion",
          "summary": "Settle what's premium",
          "now": [],
          "next": null,
          "isOpen": true,
          "waiting": 0,
          "parked": 0,
          "updatedAt": 1791922420332,
          "onScreen": true
        }
      ]
    },
    {
      "key": "switchboard-7a75d7ba",
      "name": "Switchboard",
      "open": 1,
      "waiting": 0,
      "parked": 5,
      "updatedAt": 1791975725419,
      "works": [
        {
          "id": "sr-y4d0qj",
          "name": "Milestone 7 stages 4 to 14",
          "summary": "Milestone 7's stages 4–14",
          "now": ["Draw Runway on a phone"],
          "next": "Runway's PR and its review",
          "isOpen": true,
          "waiting": 0,
          "parked": 5,
          "updatedAt": 1791975725419,
          "onScreen": true
        }
      ]
    }
  ]
}
"""

/// `list --json` with nothing on the board: the CLI ran outside any project.
let listedEmpty = """
{
  "v": 1,
  "here": null,
  "projects": []
}
"""

/// A line of `sitrep watch`, as cli/output.ts's `watchLine` prints it but
/// pretty: Lee's board of 19 October 2026 cut to three sessions, an ask, a
/// permission prompt and a turn, the prompt new on it. Every field always
/// there, null where there is none.
let watched = """
{
  "v": 1,
  "at": 1792445574706,
  "version": "0.1.0",
  "head": { "needYou": 2, "sessions": 3 },
  "rows": [
    {
      "key": "ask:sr-7e68fj:k1hs",
      "is": "ask",
      "isAway": false,
      "session": "sr-7e68fj",
      "project": "terrace",
      "letters": "Te",
      "ask": "k1hs",
      "writer": null,
      "first": {
        "lead": "Approve saved plans for anything needing a human",
        "mono": null,
        "more": null
      },
      "second": "Terrace · Plan the tool",
      "since": 1791991983206
    },
    {
      "key": "stop:sr-y4d0qj:6c847b5b-722d-4343-88e0-42ece4662e7d:1792445500000",
      "is": "permission",
      "isAway": false,
      "session": "sr-y4d0qj",
      "project": "switchboard-7a75d7ba",
      "letters": "Sw",
      "ask": null,
      "writer": "6c847b5b-722d-4343-88e0-42ece4662e7d",
      "first": { "lead": "Allow Bash:", "mono": "gh pr create", "more": null },
      "second": "Switchboard · Dashboard memory and snags",
      "since": 1792445500000
    },
    {
      "key": "turn:sr-aw3bgs",
      "is": "yourTurn",
      "isAway": false,
      "session": "sr-aw3bgs",
      "project": "code-84dbac88",
      "letters": "SR",
      "ask": null,
      "writer": "408a755f-ed3a-4ee1-9cc0-c0208cf3e03b",
      "first": {
        "lead": "Build phase 4b: sitrep watch, the feed the app reads",
        "mono": null,
        "more": null
      },
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
  "changed": ["sr-y4d0qj"]
}
"""

/// The first line of `sitrep watch` over an empty board, on one line as it prints it.
let watchedEmpty = #"{"v":1,"at":1792445580000,"version":"0.1.0","head":{"needYou":0,"sessions":0},"rows":[],"projects":[],"windows":[],"new":[],"changed":[]}"#
