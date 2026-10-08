import { expect, test } from 'claude-code/testing'
import {
  allProjects,
  foldWork,
  metaText,
  projectLog,
  summarise,
  summariseProject,
  type ProjectSummary,
  type Work,
  type WorkFiles,
} from '../core'
import { ask, file, META, MIN, note, park, seen, status, T0, W1, W2 } from './support'

const NOW = T0 + 60 * MIN

/** A work of `project`, folded at NOW from its own meta and files. */
const workOf = (id: string, project: string, files: Partial<WorkFiles>, created = T0): Work => {
  const work = foldWork(
    { meta: metaText({ ...META, id, project, created }), logs: {}, ...files },
    NOW,
  )

  if (work === undefined) {
    throw new Error('the work did not fold')
  }

  return work
}

/** A project summary with these counts, the rest empty. */
const project = (key: string, counts: Partial<ProjectSummary> = {}): ProjectSummary => ({
  key,
  name: key,
  works: [],
  open: 0,
  waiting: 0,
  parked: 0,
  updatedAt: T0,
  ...counts,
})

const keys = (projects: readonly ProjectSummary[]) => projects.map(each => each.key)

test('a work in brief: what it is doing, whether a window has it, and what it holds for Lee', () => {
  const work = workOf('sr-aaaaaa', 'switchboard', {
    logs: {
      [W1]: file(
        [T0 + MIN, status(['Drawing Usage, round 2'], { next: 'Usage, round 3' })],
        [T0 + 2 * MIN, ask('k1', 'review', 'Review round 1')],
        [T0 + 3 * MIN, ask('k2', 'do', 'Run the apply')],
        [T0 + 4 * MIN, park('p1', 'Later')],
      ),
    },
    presence: { [W1]: seen(W1, NOW) },
  })

  expect(summarise(work)).toEqual({
    id: 'sr-aaaaaa',
    name: 'Dashboard redesign',
    summary: 'Redesign the dashboard, area by area in Paper',
    now: ['Drawing Usage, round 2'],
    next: 'Usage, round 3',
    isOpen: true,
    waiting: 2,
    parked: 1,
    updatedAt: T0 + 4 * MIN,
  })
})

test('a project adds up its works, those with a window first, then the most recently updated', () => {
  const quiet = workOf('sr-aaaaaa', 'switchboard', {
    logs: { [W1]: file([T0 + 50 * MIN, ask('k1', 'try', 'Try it')]) },
  })
  const open = workOf('sr-bbbbbb', 'switchboard', {
    logs: { [W2]: file([T0 + 10 * MIN, park('p1', 'Later')]) },
    presence: { [W2]: seen(W2, NOW) },
  })
  const older = workOf('sr-cccccc', 'switchboard', { logs: {} })

  expect(summariseProject('switchboard-1a2b3c4d', [older, quiet, open])).toMatchObject({
    key: 'switchboard-1a2b3c4d',
    name: 'switchboard',
    works: [{ id: 'sr-bbbbbb' }, { id: 'sr-aaaaaa' }, { id: 'sr-cccccc' }],
    open: 1,
    waiting: 1,
    parked: 1,
    updatedAt: T0 + 50 * MIN,
  })
})

test('All projects: this project first, then the busiest, by waiting, then windows, then parked', () => {
  const view = allProjects(
    [
      project('parked', { parked: 3 }),
      project('here'),
      project('open', { open: 2 }),
      project('waiting-1', { waiting: 1, open: 3 }),
      project('waiting-2', { waiting: 2 }),
    ],
    'here',
  )

  expect(keys(view.projects)).toEqual(['here', 'waiting-2', 'waiting-1', 'open', 'parked'])
})

test('a project with nothing open, waiting or parked folds into one line, the most recent first', () => {
  const view = allProjects(
    [
      project('busy', { waiting: 1 }),
      project('idle-old', { updatedAt: T0 }),
      project('idle-new', { updatedAt: T0 + MIN }),
    ],
    'busy',
  )

  expect(keys(view.projects)).toEqual(['busy'])
  expect(keys(view.folded)).toEqual(['idle-new', 'idle-old'])
})

test('this project is never folded away, however quiet', () => {
  const view = allProjects([project('elsewhere', { open: 1 }), project('here')], 'here')

  expect(keys(view.projects)).toEqual(['here', 'elsewhere'])
  expect(view.folded).toEqual([])
})

test('equally busy projects order by their latest update, then by name', () => {
  const view = allProjects([
    project('b', { waiting: 1, updatedAt: T0 }),
    project('a', { waiting: 1, updatedAt: T0 }),
    project('c', { waiting: 1, updatedAt: T0 + MIN }),
  ])

  expect(keys(view.projects)).toEqual(['c', 'a', 'b'])
})

test("a project's log holds every work's lines, newest first, each naming its work", () => {
  const first = workOf('sr-aaaaaa', 'switchboard', {
    logs: { [W1]: file([T0 + 1 * MIN, note('n1', 'one')], [T0 + 4 * MIN, note('n4', 'four')]) },
  })
  const second = workOf('sr-bbbbbb', 'switchboard', {
    logs: { [W2]: file([T0 + 2 * MIN, note('n2', 'two')], [T0 + 3 * MIN, status(['Drawing'])]) },
  })

  expect(projectLog([first, second]).map(line => [line.work, line.text])).toEqual([
    ['sr-aaaaaa', 'four'],
    ['sr-bbbbbb', 'Status: now drawing'],
    ['sr-bbbbbb', 'two'],
    ['sr-aaaaaa', 'one'],
  ])
})
