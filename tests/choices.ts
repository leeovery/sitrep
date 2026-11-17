/**
 * `snooze.json` as SitRep writes it, its encoder's output byte for byte,
 * every choice set other than its default: the app's tests hold its encoder
 * to the text between the backticks of `APP_FILE`, read from the source
 * tree, and core's tests read it with `snoozeSettingsOf`, so the file the
 * app writes is the one the mod reads (see "Storage" in DESIGN.md).
 */
import type { SnoozeSettings } from '../core'

export const APP_FILE = `{
  "hour" : {
    "on" : false
  },
  "later" : {
    "hours" : 1,
    "on" : true
  },
  "tomorrow" : {
    "at" : "07:00",
    "on" : true
  },
  "tonight" : {
    "at" : "20:30",
    "on" : true
  },
  "v" : 1,
  "week" : {
    "at" : "08:30",
    "day" : "friday",
    "on" : true
  },
  "weekend" : {
    "at" : "10:00",
    "day" : "sunday",
    "on" : true
  }
}`

/** What the file says. */
export const APP_SETTINGS: SnoozeSettings = {
  hour: { isOn: false },
  later: { isOn: true, hours: 1 },
  tonight: { isOn: true, at: { hour: 20, minute: 30 } },
  tomorrow: { isOn: true, at: { hour: 7, minute: 0 } },
  weekend: { isOn: true, day: 'sunday', at: { hour: 10, minute: 0 } },
  week: { isOn: true, day: 'friday', at: { hour: 8, minute: 30 } },
}
