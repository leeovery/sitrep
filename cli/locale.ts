/** An environment as the CLI reads it: each variable's value, or none. */
export type Environment = Readonly<Record<string, string | undefined>>

/**
 * The environment the CLI's programs run in: its own, with a UTF-8
 * character type where it names no locale at all. SitRep starts the CLI
 * with none, and there `ps` mangles a path that isn't ASCII (an app at
 * `Café.app`), so the board would name the app wrongly and a jump could not
 * bring it forward. A locale set by
 * `LC_ALL`, `LC_CTYPE` or `LANG` is left as it is.
 */
export const childEnvironment = (env: Environment): Environment =>
  [env.LC_ALL, env.LC_CTYPE, env.LANG].some(name => name !== undefined && name !== '')
    ? env
    : { ...env, LC_CTYPE: 'UTF-8' }
