/**
 * A session moved to another project, as core reads it: a line naming the
 * project by its key, the session's folder staying where it was started.
 */
import { expect, test } from './kit'
import {
  checkMove,
  checkMoveTo,
  fileSession,
  metaText,
  parseEntries,
  refiled,
  serialise,
  VERSION,
  type Project,
  type ProjectRead,
  type Session,
} from '../core'
import { CLI, ELSEWHERE, META, MIN, PROJECT, T0, W1, W2 } from './data'
import { file, fold, moveTo, park, status, yesAsk, type Line } from './lines'

/** A third project, which no session here is in. */
const FABRIKAM: Project = { key: 'fabrikam', name: 'Fabrikam' }

/** Another session, never moved, as read in the folder named. */
const other = (id: string, name: string) => fold({ meta: metaText({ ...META, id, name }) })

/** Another session of Northwind's, never moved. */
const LOBBY = other('sr-bbbbbb', 'Lobby')

/** Northwind and Contoso, each with the sessions read in its folder. */
const board = (northwind: Session[], contoso: Session[] = []): ProjectRead[] => [
  { project: PROJECT, sessions: northwind },
  { project: ELSEWHERE, sessions: contoso },
]

/** The keys of the projects listing the session under test, once filed. */
const filing = (read: readonly ProjectRead[]) =>
  refiled(read).flatMap(({ project, sessions }) =>
    sessions.some(session => session.id === META.id) ? [project.key] : [],
  )

/** The session under test, its window's file holding `lines`. */
const written = (...lines: Line[]) => fold({ logs: { [W1]: file(...lines) } })

test('a move line names the project by its key, and the session folds moved there', () => {
  const session = written([T0, yesAsk('k1', 'Review it')], [T0 + MIN, moveTo(ELSEWHERE.key)])

  expect(session.movedTo).toBe(ELSEWHERE.key)
  expect(written([T0, status(['Drawing'])]).movedTo, 'never moved').toBeUndefined()
  expect(parseEntries(file([T0, moveTo(ELSEWHERE.key)]))).toEqual([
    { v: VERSION, at: T0, seq: 1, type: 'move', project: ELSEWHERE.key },
  ])
})

test('of several moves, the latest in the order every reader reads lines names the project: time, then writer, then count', () => {
  const at = T0 + MIN
  const movedBy = (logs: Record<string, string>) => fold({ logs }).movedTo

  expect(
    movedBy({ [W1]: file([T0, moveTo('contoso')]), [W2]: file([at, moveTo('fabrikam')]) }),
    'the later in time',
  ).toBe('fabrikam')
  expect(
    movedBy({ [W2]: file([at, moveTo('contoso')]), [W1]: file([at, moveTo('fabrikam')]) }),
    'of one moment, the later writer',
  ).toBe('contoso')
  expect(
    movedBy({ [CLI]: file([at, moveTo('contoso')], [at, moveTo('fabrikam')]) }),
    "of one writer's moment, the later count",
  ).toBe('fabrikam')
})

test("a move line whose project reads as no folder's name is a bad line, skipped: no reader makes a path of it", () => {
  const bad = ['../escape', 'Contoso Ltd', '', 7, undefined].map((project, i) =>
    serialise({ v: VERSION, at: T0 + i, seq: i + 1, type: 'move', project } as never),
  )

  expect(parseEntries(bad.join(''))).toEqual([])
  expect(fold({ logs: { [W1]: bad.join('') } }).movedTo).toBeUndefined()
})

test('a move dates the session, as any line Claude is told of does', () => {
  const at = T0 + 30 * MIN

  expect(written([T0, status(['Drawing'])], [at, moveTo('contoso')]).updatedAt).toBe(at)
})

test('a session is filed under the project its latest move names, where that project is on the board, and named by it; else under its folder, as read', () => {
  const nameOf = (key: string) => [PROJECT, ELSEWHERE].find(each => each.key === key)?.name
  const never = written([T0, status(['Drawing'])])
  const moved = written([T0, moveTo(ELSEWHERE.key)])
  const away = written([T0, moveTo(FABRIKAM.key)])
  const back = written([T0, moveTo(ELSEWHERE.key)], [T0 + MIN, moveTo(PROJECT.key)])

  expect(fileSession(PROJECT.key, never, nameOf), 'never moved').toEqual({
    project: PROJECT.key,
    session: never,
  })
  expect(fileSession(PROJECT.key, moved, nameOf)).toEqual({
    project: ELSEWHERE.key,
    session: { ...moved, project: ELSEWHERE.name },
  })
  expect(fileSession(PROJECT.key, away, nameOf), 'to a project not on the board').toEqual({
    project: PROJECT.key,
    session: away,
  })
  expect(fileSession(PROJECT.key, back, nameOf), 'moved back').toEqual({
    project: PROJECT.key,
    session: back,
  })
})

test('filed, a moved session goes whole to its project, named by it; the project it left keeps nothing of it', () => {
  const moved = written(
    [T0, status(['Drawing Inbox'])],
    [T0 + MIN, yesAsk('k1', 'Review it')],
    [T0 + 2 * MIN, park('p1', 'A priority badge')],
    [T0 + 3 * MIN, status(['Drawing Settings'])],
    [T0 + 4 * MIN, moveTo(ELSEWHERE.key)],
  )
  const shifts = other('sr-0sh1ft', 'Shift schedules')
  const [northwind, contoso] = refiled(board([moved, LOBBY], [shifts]))
  const arrived = contoso?.sessions.find(session => session.id === META.id)

  expect(northwind?.sessions, 'Northwind keeps its own').toEqual([LOBBY])
  expect(northwind?.sessions[0], 'the very fold, as read').toBe(LOBBY)
  expect(contoso?.sessions.map(session => session.id).sort()).toEqual(['sr-0sh1ft', META.id])
  expect(arrived?.project, 'named by the project it is in now').toBe('Contoso')
  expect(arrived).toMatchObject({
    status: moved.status,
    asks: moved.asks,
    parked: moved.parked,
    history: moved.history,
    updatedAt: moved.updatedAt,
  })
  expect(arrived?.history).toHaveLength(2)
  expect(moved.project, 'its fold as read is left as it was').toBe('Northwind')
})

test('a session moved to a project not on the board stays filed under its folder, and moved back it is there again', () => {
  const away = written([T0, moveTo(FABRIKAM.key)])
  const back = written([T0, moveTo(ELSEWHERE.key)], [T0 + MIN, moveTo(PROJECT.key)])

  expect(filing(board([away]))).toEqual([PROJECT.key])
  expect(filing(board([back]))).toEqual([PROJECT.key])
})

test('a reader mid-move files the session under one project, never both, never neither: its old one until it reads the line, its new one from then', () => {
  const before: Line[] = [
    [T0, yesAsk('k1', 'Review it')],
    [T0 + MIN, park('p1', 'A priority badge')],
  ]

  expect(filing(board([written(...before)]))).toEqual([PROJECT.key])
  expect(filing(board([written(...before, [T0 + 2 * MIN, moveTo(ELSEWHERE.key)])]))).toEqual([
    ELSEWHERE.key,
  ])
})

test('a writer appending as the session moves loses nothing: its lines are read from the one folder, before the move and after it', () => {
  const session = fold({
    logs: {
      [W1]: file([T0, yesAsk('k1', 'Review it')], [T0 + 2 * MIN, moveTo(ELSEWHERE.key)]),
      [W2]: file([T0 + MIN, yesAsk('k2', 'Try it')], [T0 + 2 * MIN, yesAsk('k3', 'Ship it')]),
      [CLI]: file([T0 + 3 * MIN, park('p1', 'A priority badge')]),
    },
  })
  const [, contoso] = refiled(board([session]))

  expect(contoso?.sessions[0]?.asks.map(ask => ask.id)).toEqual(['k1', 'k2', 'k3'])
  expect(contoso?.sessions[0]?.parked.map(parked => parked.id)).toEqual(['p1'])
})

test('a move names the project as Lee would say it, with its directory once known; a name with nothing to match by is refused', () => {
  expect(checkMove({ project: '  Trey Research ', directory: '/Users/me/trey/' })).toEqual({
    ok: true,
    value: { project: 'Trey Research', directory: '/Users/me/trey' },
  })

  for (const project of [undefined, '', ' -!- ', 3]) {
    expect(checkMove({ project }), String(project)).toEqual({
      ok: false,
      error:
        'Name the project to move the session to: its name as Lee would say it, such as SitRep or Switchboard.',
    })
  }

  expect(checkMove({ project: 'Trey', directory: 'Code/trey' })).toEqual({
    ok: false,
    error: "A project's directory is an absolute path: where the project lives.",
  })
})

test('a move to the project the session is in already is refused; to another, it is the line naming that project', () => {
  const session = fold({})

  expect(checkMoveTo(session, PROJECT.key, PROJECT)).toEqual({
    ok: false,
    error: 'Help desk redesign is in Northwind already.',
  })
  expect(checkMoveTo(session, PROJECT.key, ELSEWHERE)).toEqual({
    ok: true,
    value: { type: 'move', project: ELSEWHERE.key },
  })
})
