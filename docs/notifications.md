# Notifications: sounds, banners and the pulse

SitRep tells you when a new ask lands, even if you are in another app. It can tell you when Claude stops, too. Each comes three ways: a sound, a macOS banner and a pulse at the edge of your screen. In Settings › Notifications, you set each one separately for a new ask and for Claude stopping.

## Try it

1. Click the SitRep icon in the menu bar, choose **Settings…**, then **Notifications**.
2. Turn on **Notify me of a new ask**. macOS asks once if SitRep may send notifications: allow it.
3. Press **Send Test**. A banner titled "Test notification" shows where macOS shows banners. It names no session, so a click on it takes you nowhere.

## What happens

- **A new ask plays a sound once.** However many asks land at once, and whichever session they land in, you hear it once. An ask that wakes from a snooze plays it too. The default sound is Glass.
- **Claude stopping can play another sound.** Turn on **Play a sound when Claude stops**, and Claude stopping plays Tink, so you can tell the two apart by ear.
- **A banner names the session.** A new ask shows the ask title, over the project and the session, such as "Northwind · Help desk redesign". Claude stopping shows "Stopped", the project and the session, then a line from the session status: what is under way, or else its summary.
- **A click on a banner takes you there.** It brings forward the window running that session. See [A click takes you there](jump.md).
- **A banner leaves once its ask is done.** If the ask is answered anywhere, its banner leaves Notification Center. A banner has no buttons: to answer from your screen, use the notch or the strip. See [Answering from the edge of your screen](answering-edge.md).
- **The edge pulses.** For a new ask, the notch swells twice and its light flashes. A window that starts waiting at a permission prompt pulses it too, with no sound and no banner. On the strip, the mark flashes its ring twice instead. Turn on **Pulse when Claude stops** to pulse for a Stopped session too.

## Good to know

- **Banners are silent.** SitRep plays its own sound, at the volume of your Mac. The alert volume in System Settings › Sound doesn't change it.
- **macOS decides if banners show.** SitRep asks macOS the first time you turn on a banner switch, or press Send Test. You change the answer in System Settings › Notifications, under SitRep. If macOS stops them, the two banner switches grey out, and **Notification Settings…** takes you there.
- **One change, one sound.** If a new ask and a Stopped session come at once, you hear one sound: the new ask sound, if that sound is on.
- **Failures get a banner too.** Whatever the switches say, SitRep posts a banner when it can't do what you asked. For example, "SitRep could not jump", "Not snoozed" or "Not answered".

## Reference

| What | A new ask | Claude stops |
|---|---|---|
| Banner | Off | Off |
| Sound | On, Glass | Off, Tink |
| Pulse at the edge | On | Off |

The sounds are the alert sounds of macOS, Basso to Tink. Choosing one plays it. The sound plays whatever shows at the edge: the notch, the strip or nothing. Each switch is listed in [Settings, pane by pane](settings.md).

## Related

- [Asks: what waits on you](asks.md)
- [The edge of your screen](notch.md)
- [Settings, pane by pane](settings.md)
