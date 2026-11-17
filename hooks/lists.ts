/**
 * The lists of the board's past, by the names the pane keeps how much each
 * shows under (`shown`): Status's history, Parked's picked up and RESOLVED,
 * each of a session, or of a project in its view, whose lists the look
 * carries (around.ts).
 */

const PROJECT = 'project'

/** Whose a list is: a session's, by its id, or a project's, in its view. */
export const projectScope = (key: string) => `${PROJECT}:${key}`

export const historyList = (scope: string) => `history:${scope}`

export const pickedUpList = (scope: string) => `pickedup:${scope}`

export const resolvedList = (scope: string) => `resolved:${scope}`

/** Whether a list is a project's, which the look carries as much of as it shows. */
export const isProjectList = (list: string) =>
  list.slice(list.indexOf(':') + 1).startsWith(`${PROJECT}:`)
