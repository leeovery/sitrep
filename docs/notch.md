# The edge of your screen: the notch, the strip and the menu bar

SitRep shows the board at the edge of your Mac's screen, whatever app you are in. The notch lights up when a session needs you, and opens into a list of your sessions when you point at it. A click takes you to the session. Use it when you run Claude Code in several windows and want to see which one waits on you.

<img src="../art/screens/notch.webp" alt="SitRep's notch at the left edge of a Mac's screen, lit orange: the pointer comes to it and it pours open into a panel listing Needs you, two sessions with asks in orange and two stopped in blue, then Working and Snoozed; the pointer leaves and it closes" width="444">

*The notch opens when the pointer reaches it, and closes when the pointer leaves.*

## Try it

1. Move the pointer to the left edge of your screen, a little above the middle. The notch opens into the panel.
2. Click a row. SitRep takes you to the Claude Code window running that session.
3. To try the strip, click the SitRep icon in the menu bar, and choose **Strip** under Show.

## What happens

- **The panel lists your sessions in three sections.** Needs you comes first, then Working, then Snoozed. Working also holds the sessions that wait on work of their own, such as a background agent. A click on a section heading folds it.
- **A click on a row jumps.** It brings forward the window running that session. See [A click takes you there](jump.md).
- **A right-click on a row gives its menu.** **Jump to the window** does what a click does. A row with asks, or a Stopped row, also offers **Snooze**. A row in Snoozed offers **Wake now**. See [Putting a session off](snooze.md).
- **The notch shows what waits.** While something needs you, the notch grows and lights: orange for an ask or a permission prompt, blue for a Stopped session. By default, a new ask makes it swell twice and flash.
- **You can move it.** Drag the notch along the edge. Drag it past the middle of the screen, and it moves to the other edge.
- **The menu bar item lists the same sessions.** Its menu gives one total, such as "3 need you", over a row for each session. A click on a row jumps. Under Show, you choose Notch, Strip or Nothing for the edge. Show Welcome Window, Settings… and Quit SitRep come last.

## Good to know

- **It never takes the keyboard.** Your typing stays where it was, in the app you were in. There is no Esc: move the pointer away and the panel closes.
- **Dimmed rows still work.** SitRep dims a session that no terminal on this Mac shows. A click on one carries the session on, in a new window if it needs one. See [A click takes you there](jump.md).
- **Full-screen apps come first.** While a full-screen app has the display, the notch and the strip step off it. They come back when the app leaves full screen.
- **The menu speaks up first.** Above the sessions, the menu says when the plugin is in trouble. Under "Needs /reload-plugins", it lists each window that runs an older plugin, until you reload it. If the board stops updating, it says "SitRep can't read the board" and why.

## Reference

The strip stands in for the notch if you choose it: a narrow column along the edge, with a mark for each session. Point at a mark to see its row, and click to jump.

![The strip at the left edge of the screen: a narrow black column with a ring for each session, each ring holding two letters of the project. Orange rings need you, blue rings are Stopped, and grey rings with a turning arc are working. Hairlines divide the sections.](../art/screens/strip.webp)

*The strip shows a mark for each session, and the ring carries its state.*

| A mark on the strip | Means |
|---|---|
| Orange ring | Needs you: an ask or a prompt |
| Blue ring | Stopped: your turn |
| Grey ring, arc turning | Working |
| Dotted grey ring | Waiting on work of its own |
| Dimmed ring, faint letters | Snoozed |
| Dim letters, or a hollow ring | No terminal on this Mac shows it |
| A number, such as "+3" | More sessions than the strip has room for |

At **Grows**, the default, the strip is as long as its marks need. At **Full**, it runs the height of the screen. Both are in Settings › Edge.

## Related

- [Sounds, banners and the pulse](notifications.md)
- [Settings, pane by pane](settings.md)
- [Asks: what waits on you](asks.md)
