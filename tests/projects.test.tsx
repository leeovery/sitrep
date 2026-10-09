import { expect, test, tier, type Engine } from 'claude-code/testing'
import {
  parseMeta,
  parseProject,
  projectPaths,
  workPaths,
  type ProjectFile,
  type WorkMeta,
} from '../core'
import { ask, META, MIN, note, T0, W1, W2, W3 } from './support'
import { DASHBOARD, HOME, PROJECT, REPO, ROOT, SESSION, startedId, world } from './world'

tier('user')

type World = ReturnType<typeof world>

/** Where SitRep lives: not where any session here starts. */
const SITREP_HOME = '/Users/lee/.config/kit/shared/plugins/sitrep'

/** A project folder from before projects were named, keyed from the folder a session started in. */
const LEGACY = 'code-84dbac88'

const BOARD = { name: 'sitrep', summary: "Lee's board inside Claude Code", project: 'SitRep' }

const meta = (id: string, name: string, project: string, by = W2): WorkMeta => ({
  ...META,
  id,
  name,
  project,
  by,
})

/** A project's file, as it stands. */
const fileIn = (w: World, key: string) => parseProject(w.text(projectPaths(ROOT, key).file))

/** The project files on the board, by key. */
const projectKeys = (w: World) =>
  [...w.files.keys()].flatMap(path => {
    const key = path.match(/\/projects\/([^/]+)\/project\.json$/)?.[1]

    return key === undefined ? [] : [key]
  })

/** The board's project tab, as the board draws it. */
const projectTab = async (w: World) => {
  const ui = await w.pane()
  const tab = await ui.find({ key: 'tab:project' })

  await ui.unmount()

  return tab?.text
}

/** The session's first message's sitrep block. */
const firstMessage = async ($: Engine) =>
  (await $.prompt.context({ blocks: [] })).blocks.find(block => block.name === 'sitrep')?.text

test('start makes a new project of the name given, keyed by its slug, whatever folder the session started in', async ($, on) => {
  const w = world($, on)

  w.become({ cwd: HOME })
  await $.session.start(SESSION)

  const answer = await w.call('start', BOARD)
  const id = startedId(answer)

  expect(answer.result).toBe(
    `Started sitrep as ${id}, in a new project, SitRep. Record ${id} wherever the project tracks this work, so a later window can join it.`,
  )
  expect(fileIn(w, 'sitrep')).toEqual({ name: 'SitRep', created: T0, by: W1 })
  expect(parseMeta(w.text(workPaths(ROOT, 'sitrep', id).meta))).toMatchObject({
    project: 'SitRep',
    root: HOME,
  })
  expect(w.state.attachment).toMatchObject({ project: 'sitrep', work: id })
  expect(w.state.board?.project).toBe('SitRep')
})

test('start puts the work in the project its name matches, case, spaces and punctuation aside, and the project keeps its name', async ($, on) => {
  const w = world($, on)

  await $.session.start(SESSION)
  await w.call('start', BOARD)

  for (const name of ['sitrep', 'Sit Rep', ' SIT-REP! ']) {
    const answer = await w.call('start', { ...BOARD, name: `Work on ${name}`, project: name })

    expect(String(answer.result), name).toContain(', in the existing project SitRep. Record ')
    expect(w.state.attachment?.project, name).toBe('sitrep')
    expect(w.state.board?.project, name).toBe('SitRep')
  }

  expect(projectKeys(w)).toEqual(['sitrep'])
  expect(fileIn(w, 'sitrep')?.name).toBe('SitRep')
})

test("a directory given is the project's: a new one keeps it, one with none takes it, and one with its own keeps that", async ($, on) => {
  const w = world($, on)

  await $.session.start(SESSION)
  await w.call('start', { ...BOARD, directory: `${SITREP_HOME}/` })
  await w.call('start', DASHBOARD)

  expect(fileIn(w, 'sitrep')?.directory).toBe(SITREP_HOME)
  expect(fileIn(w, PROJECT.key)?.directory).toBeUndefined()

  const given = await w.call('start', { ...DASHBOARD, name: 'Lobby', directory: REPO })

  expect(String(given.result)).toContain(', in the existing project Switchboard. Record ')
  expect(fileIn(w, PROJECT.key)).toEqual({
    name: 'Switchboard',
    directory: REPO,
    created: T0,
    by: W1,
  })

  const other = await w.call('start', { ...BOARD, name: 'Themes', directory: '/Users/lee/other' })

  expect(String(other.result)).toContain(
    `, in the existing project SitRep, which lives in ${SITREP_HOME}; the project tool changes that. Record `,
  )
  expect(fileIn(w, 'sitrep')?.directory).toBe(SITREP_HOME)
})

test('a project folder with no project.json is named as its works recorded it, and a start by that name goes into it', async ($, on) => {
  const w = world($, on)

  w.elsewhere(meta('sr-wdsqvn', 'sitrep', 'code'), LEGACY)
  await $.session.start(SESSION)

  const answer = await w.call('start', { ...BOARD, name: 'Lobby', project: 'Code' })

  expect(String(answer.result)).toContain(', in the existing project Code. Record ')
  expect(w.state.attachment?.project).toBe(LEGACY)
  expect(projectKeys(w), 'nothing written to name it').toEqual([])
  expect(await projectTab(w)).toBe('Code')
})

test('a project.json written into a folder from before relabels it, moving nothing', async ($, on) => {
  const w = world($, on)
  const legacy = w.elsewhere(meta('sr-wdsqvn', 'sitrep', 'code'), LEGACY)
  const before = [...w.files.keys()]

  w.project(LEGACY, { name: 'SitRep', directory: SITREP_HOME, created: T0, by: W2 })
  await $.session.start(SESSION)
  await w.call('join', { work: 'sr-wdsqvn' })

  expect(w.state.board?.project).toBe('SitRep')
  expect(await projectTab(w)).toBe('SitRep')

  await w.call('start', { ...BOARD, name: 'Lobby', project: 'Sitrep' })

  expect(w.state.attachment?.project).toBe(LEGACY)
  expect(before.every(path => w.files.has(path))).toBe(true)
  expect(w.files.has(legacy.paths.meta)).toBe(true)

  const code = await w.call('start', { ...BOARD, name: 'Themes', project: 'Code' })

  expect(String(code.result), 'the old name names it no more').toContain('in a new project, Code')
  expect(w.state.attachment?.project).toBe('code')
})

test("the board's project tab is the held work's project, whatever folder the session started in", async ($, on) => {
  const w = world($, on)

  w.project(PROJECT.key, { name: PROJECT.name, directory: REPO, created: T0, by: W2 })
  w.elsewhere(meta('sr-v1pwm9', 'Milestone 7 stage 1', 'Switchboard')).beat()
  await $.session.start(SESSION)
  await w.call('start', BOARD)

  expect(await projectTab(w)).toBe('SitRep')

  await w.call('join', { work: 'sr-v1pwm9' })

  expect(await projectTab(w)).toBe('Switchboard')
})

test('the project tool renames the held work’s project and sets where it lives, the work staying where it is filed', async ($, on) => {
  const w = world($, on)

  await $.session.start(SESSION)

  const id = startedId(await w.call('start', { ...BOARD, project: 'Sitrep' }))

  await w.clock.advance(MIN)

  expect((await w.call('project', { name: 'SitRep' })).result).toBe(
    'Renamed the project Sitrep to SitRep.',
  )
  expect(fileIn(w, 'sitrep')).toEqual({ name: 'SitRep', created: T0, by: W1 })
  expect(w.state.board?.project).toBe('SitRep')
  expect(await projectTab(w)).toBe('SitRep')

  expect((await w.call('project', { directory: SITREP_HOME })).result).toBe(
    `SitRep lives in ${SITREP_HOME}.`,
  )
  expect(fileIn(w, 'sitrep')).toEqual({
    name: 'SitRep',
    directory: SITREP_HOME,
    created: T0,
    by: W1,
  })
  expect(w.state.attachment).toMatchObject({ project: 'sitrep', work: id })
  expect(w.files.has(workPaths(ROOT, 'sitrep', id).meta)).toBe(true)
})

test('the project tool never takes the name of another project, nor changes nothing', async ($, on) => {
  const w = world($, on)

  await w.begin()
  await w.call('start', BOARD)

  expect((await w.call('project', { name: 'switch board' })).deny).toBe(
    "Another project is already named Switchboard. This renames the attached work's project; it moves no work to another.",
  )
  expect((await w.call('project', {})).deny).toBe(
    'Give the project a new name, a directory, or both.',
  )
  expect((await w.call('project', { name: 'Sit Rep' })).result, 'its own name, respelled').toBe(
    'Renamed the project SitRep to Sit Rep.',
  )
  expect(fileIn(w, PROJECT.key)?.name).toBe('Switchboard')
})

test('the project tool gives a folder from before projects were named its first project.json', async ($, on) => {
  const w = world($, on)

  w.elsewhere(meta('sr-wdsqvn', 'sitrep', 'code'), LEGACY)
  await w.clock.advance(MIN)
  await $.session.start(SESSION)
  await w.call('join', { work: 'sr-wdsqvn' })

  expect((await w.call('project', { name: 'SitRep' })).result).toBe(
    'Renamed the project Code to SitRep.',
  )
  expect(fileIn(w, LEGACY)).toEqual({ name: 'SitRep', created: T0 + MIN, by: W1 })
  expect(w.state.attachment?.project).toBe(LEGACY)
  expect(await projectTab(w)).toBe('SitRep')
})

/** Three projects with current works: SitRep and Switchboard each living somewhere, and Goosemates from before. */
const threeProjects = (w: World) => {
  const sitrep: ProjectFile = { name: 'SitRep', directory: SITREP_HOME, created: T0, by: W2 }
  const switchboard: ProjectFile = { name: 'Switchboard', directory: REPO, created: T0, by: W3 }

  w.project('sitrep', sitrep)
  w.project(PROJECT.key, switchboard)
  w.elsewhere(meta('sr-wdsqvn', 'sitrep', 'SitRep'), 'sitrep').write(
    ask('k1', 'review', 'Review the plan'),
    ask('k2', 'do', 'Try the board'),
  )
  w.elsewhere(meta('sr-v1pwm9', 'Milestone 7 stage 1', 'Switchboard', W3)).beat()
  w.elsewhere(meta('sr-eeeeee', 'Onboarding', 'goosemates'), 'goosemates-1a2b3c4d').write(
    note('n1', 'Drew the flow'),
  )
}

const SITREP_LINE = '- SitRep: sr-wdsqvn "sitrep", 2 waiting on Lee'
const SWITCHBOARD_LINE = '- Switchboard: sr-v1pwm9 "Milestone 7 stage 1"'
const GOOSEMATES_LINE = '- Goosemates: sr-eeeeee "Onboarding"'

test("the first message lists every project's current works, those living around the session's folder first", async ($, on) => {
  const w = world($, on)

  threeProjects(w)
  w.become({ cwd: `${SITREP_HOME}/hooks` })

  expect(await firstMessage($)).toContain(
    ['On the board:', SITREP_LINE, SWITCHBOARD_LINE, GOOSEMATES_LINE].join('\n'),
  )

  w.become({ cwd: REPO })

  expect(await firstMessage($)).toContain(
    ['On the board:', SWITCHBOARD_LINE, SITREP_LINE, GOOSEMATES_LINE].join('\n'),
  )
})

test('a session resumed in any folder takes up the work it was last seen in, whichever project files it', async ($, on) => {
  const w = world($, on, { now: T0 + 10 * MIN })

  threeProjects(w)
  w.beat('sr-wdsqvn', { writer: W1, attachedAt: T0, seenAt: T0 + MIN, leftAt: T0 + MIN }, 'sitrep')
  w.beat(
    'sr-eeeeee',
    { writer: W1, attachedAt: T0, seenAt: T0 + 5 * MIN, leftAt: T0 + 5 * MIN },
    'goosemates-1a2b3c4d',
  )
  w.become({ cwd: HOME })

  const listing = await firstMessage($)

  expect(w.state.attachment).toMatchObject({ project: 'goosemates-1a2b3c4d', work: 'sr-eeeeee' })
  expect(listing).toContain('This window already holds sr-eeeeee (Onboarding)')
})
