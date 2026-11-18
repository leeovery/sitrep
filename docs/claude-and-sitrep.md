# How Claude keeps the board

You keep talking to Claude in the chat, and Claude keeps the board as it works. It starts a session for real work, sets the status when the work moves on, and posts an ask only when it needs you. Each ask is said in the chat as well, so you never have to read the board to follow along.

## Try it

1. In Claude Code, start a piece of work: "Let's redesign the help desk for Northwind."
2. Claude starts a session, and Help desk redesign appears on the board, with its status.
3. Mention something for later, and say "put that on the board". Claude parks it.
4. Type `/sitrep` to see the session, its status and the parked item.

## What happens

- **Claude starts a session for work that lasts.** That means work across several turns, or work that will need you, such as a feature or a design. A quick question gets no session.
- **Each conversation starts with a guide.** The first message tells Claude how to keep the board. It also lists the sessions on the board, each with its session id.
- **Claude joins a session you carry on with.** Say "let's carry on with the help desk redesign" in a new window, and Claude joins that session by its id. It joins again after `/clear` too. A resumed conversation takes up its session by itself.
- **Claude asks only when it needs you.** It posts an ask when it can't go on without you, or when your judgement changes what comes next. It also asks when it leaves you something to do, such as a merge. It says the ask in full in the chat as well.
- **The shape follows what you give back.** A go or an approval is a yes. Claude words its button as the go you'd give, such as `✓ Go` or `✓ Ship it`. One of several options is a choice, with the option Claude leans toward marked `· recommended`. Something you write back is a words ask.
- **Board changes reach Claude.** When the board changes, such as when you drop an item, Claude gets the session's board as it now stands at its next turn. A join hands Claude the session's status, open asks and the project's parked items, to correct anything stale.

## Good to know

- **Only the main conversation writes to the board.** A subagent that calls a sitrep tool is refused, and told to put it in its report instead.
- **Claude can't snooze a session.** It has no tool for it: only you put a session off. Claude can finish a session once nothing is left on it, and what it parked stays with the project.
- **An answer in the chat counts.** If you answer an ask in the chat, Claude resolves the ask itself.
- **Claude is told never to name ids to you.** Session and item ids are for the tools. In the chat, Claude names an ask or a session by its words.

## Reference

Claude calls these tools. You never call them yourself.

| Tool | What it does |
|---|---|
| `start` / `join` | Starts a session in a project, or joins one by its id |
| `status` | Sets the name, summary, what is under way, and what is next |
| `ask` | Posts an ask that wants a yes, a choice or words |
| `park` | Parks something for later, on the project |
| `resolve` / `reopen` / `edit` | Closes, reopens or corrects an item, with a reason if given |
| `finish` | Finishes the session once nothing is left on it |
| `project` / `move` | Renames the project or says where it lives; moves the session at your word |
| `board` | Reads the board back, so Claude can check and repair it |

## Related

- [What waits on you](asks.md)
- [Answering from the board](answering.md)
- [Sessions outlive their windows](sessions.md)
