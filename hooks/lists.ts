/**
 * The lists of the board's past, by the names the pane keeps how much each
 * shows under (`shown`): Status's history and RESOLVED, each a session's;
 * Parked's picked up, a project's, which every view of it draws; and a
 * project's old sessions, in its view. The look carries as much of a
 * project's as it shows (around.ts).
 */

const PROJECT = 'project'

/** Whose a list is: a session's, by its id, or a project's. */
export const projectScope = (key: string) => `${PROJECT}:${key}`

export const historyList = (scope: string) => `history:${scope}`

export const pickedUpList = (scope: string) => `pickedup:${scope}`

export const oldList = (scope: string) => `old:${scope}`

export const resolvedList = (scope: string) => `resolved:${scope}`

/** Whether a list is a project's, which the look carries as much of as it shows. */
export const isProjectList = (list: string) =>
  list.slice(list.indexOf(':') + 1).startsWith(`${PROJECT}:`)
