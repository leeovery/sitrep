# The edge of your screen: the notch and the menu bar

SitRep shows the board at the edge of your Mac's screen, whatever app you are in. The notch lights up when a session needs you, and opens into a list of your sessions when you point at it. A click takes you to the session, so you never look through your windows.

<img src="../art/screens/notch.webp" alt="SitRep's notch at the left edge of a Mac's screen, lit orange: the pointer comes to it and it pours open into a panel listing Needs you, two sessions with asks in orange and two stopped in blue, then Working and Snoozed; the pointer leaves and it closes" width="444">

*The notch opens when the pointer reaches it, and closes when the pointer leaves.*

## Try it

1. Move the pointer to the left edge of your screen, a little above the middle. The notch opens into the panel.
2. Click a row. SitRep takes you to the Claude Code window running that session.

## What happens

- **The panel lists your sessions in three sections.** Needs you comes first, then Working, then Snoozed. Working also holds the sessions that wait on work of their own. A click on a section heading folds it, and Snoozed starts folded.
- **A click on a row jumps.** See [A click takes you there](jump.md). A right-click gives the row a menu, with **Jump to the window**. A row with asks or a Stopped row adds **Snooze**. A row in Snoozed adds **Wake now**. See [Putting a session off](snooze.md).
- **An arrow opens the asks panel.** Point at a row with an ask, and an arrow shows. See [Answering from the edge of your screen](answering-edge.md).
- **The notch shows what waits.** While something needs you, the notch grows and lights. The light is orange while an ask or a permission prompt waits. With neither, it is blue while a session is Stopped. By default, a new ask or a new permission prompt makes it swell twice and flash.
- **You can move it.** Drag the notch along the edge. Drag it past the middle of the screen, and it moves to the other edge.
- **The menu bar item lists the same sessions, except the snoozed ones.** Its icon lights orange or blue, the same way the notch does. Its menu gives one total, such as "3 need you", over a row for each session to click. Under Show, you choose Notch or Nothing: with Nothing, the icon is the only light.

## Good to know

- **It never takes the keyboard.** Your typing stays in the app you were in. There is no Esc: move the pointer away and the panel closes.
- **Dimmed rows still work.** SitRep dims a session that no terminal on this Mac shows. A click on one resumes the session: see [A click takes you there](jump.md).
- **Full-screen apps come first.** While one has the display, the notch leaves that display. It comes back when the app leaves full screen.
- **The menu speaks up first.** Above the sessions, it says when the plugin is in trouble. Under "Needs /reload-plugins", it lists each window on an older plugin, until you run `/reload-plugins` there. A click on one takes you to it. If the board stops updating, the menu says "SitRep can't read the board" and why.

## Reference

| Setting | Choices |
|---|---|
| Show | Notch, or Nothing: the menu bar item only |
| Edge | Left or Right; or drag the notch across |
| Display | The main display, or another |
| Style | Meniscus pours open, Card slides open |
| Reduce motion | Less movement; the Mac's own setting counts too |

Each is in Settings › Edge, and Show is in the menu too. See [Settings, pane by pane](settings.md).

## Related

- [Sounds, banners and the pulse](notifications.md)
- [Settings, pane by pane](settings.md)
- [Asks: what waits on you](asks.md)
