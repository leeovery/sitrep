/**
 * `here.json` as SitRep writes it, its encoder's output byte for byte: the
 * app's tests hold its encoder to the text between the backticks of
 * `APP_FILE`, read from the source tree, writing `APP_SESSIONS` and
 * `APP_TTYS` at `APP_AT`, and core's tests read it with `sightingsOf`, so
 * the file the app writes is the one the panel reads (see "Storage" in
 * DESIGN.md). The addresses are documentation's own (RFC 5737, RFC 3849).
 */

/** When the file was written, in milliseconds since the epoch. */
export const APP_AT = 1_763_650_000_123

/** Each held session's viewers, in the order the app writes them: sorted. */
export const APP_SESSIONS = {
  'sr-ct0002': ['ssh:192.0.2.7', 'ssh:2001:db8::7'],
  'sr-fb0003': [],
  'sr-nw0001': ['mac', 'ssh:192.0.2.7'],
}

/** Each multiplexer tty's viewers, by its device. */
export const APP_TTYS = {
  '/dev/ttys004': ['ssh:192.0.2.7'],
  '/dev/ttys1024': ['mac'],
}

export const APP_FILE = `{"at":1763650000123,"sessions":{"sr-ct0002":["ssh:192.0.2.7","ssh:2001:db8::7"],"sr-fb0003":[],"sr-nw0001":["mac","ssh:192.0.2.7"]},"ttys":{"/dev/ttys004":["ssh:192.0.2.7"],"/dev/ttys1024":["mac"]},"v":2}`

/**
 * A terminal's numbers and the device they name, or none, as JSON: the
 * panel's own, `fstatSync(0).rdev` as Bun gives it, through core's `ttyOf`,
 * and each process's, the kernel's `e_tdev`, through the app's `device(of:)`,
 * so a tty `ttys` names is the one the panel looks itself up by. A pty is
 * major 16; 0 is a file's or a pipe's, 3/2 another device's, and -1 the
 * kernel's for no terminal.
 */
export const TTY_NUMBERS = `[[268435460,"/dev/ttys004"],[268436480,"/dev/ttys1024"],[0,null],[50331650,null],[-1,null]]`
