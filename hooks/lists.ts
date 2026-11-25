/**
 * The lists of the pane that fold, by the names the pane keeps how much
 * each shows under (`shown`): Status's history and RESOLVED, each a
 * session's; PARKED and its picked up, a project's, which every view of it
 * draws; and a project's old sessions, in its view. The look carries as
 * much of a project's picked up and old sessions as it shows (around.ts),
 * and every parked item always.
 */

const PROJECT = 'project'

const PICKED_UP = 'pickedup'

const OLD = 'old'

/** Whose a list is: a session's, by its id, or a project's. */
export const projectScope = (key: string) => `${PROJECT}:${key}`

export const historyList = (scope: string) => `history:${scope}`

export const parkedList = (scope: string) => `parked:${scope}`

export const pickedUpList = (scope: string) => `${PICKED_UP}:${scope}`

export const oldList = (scope: string) => `${OLD}:${scope}`

export const resolvedList = (scope: string) => `resolved:${scope}`

/** Whether a list is a project's that the look carries only as much of as it shows. */
export const isCarriedAsShown = (list: string) =>
  [PICKED_UP, OLD].some(kind => list.startsWith(`${kind}:${PROJECT}:`))
