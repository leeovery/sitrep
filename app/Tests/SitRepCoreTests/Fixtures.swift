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
