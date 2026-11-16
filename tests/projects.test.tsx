import { expect, test, tier, type Engine } from './kit'
import {
  parseMeta,
  parseProject,
  projectPaths,
  sessionPaths,
  type ProjectFile,
  type SessionMeta,
} from '../core'
import { HELP_DESK, HOME, META, MIN, PROJECT, REPO, ROOT, T0, W1, W2, W3 } from './data'
import { note, yesAsk } from './lines'
import { CONVERSATION, startedId, world } from './world'

tier('user')

type World = ReturnType<typeof world>

/** Where SitRep lives: not where any window here starts. */
const SITREP_HOME = '/Users/me/.claude/plugins/sitrep'

/** Where Fabrikam lives: apart from Northwind, so a window in either is around that one alone. */
const FABRIKAM_HOME = '/Users/me/Work/fabrikam'

/** A project folder from before projects were named, keyed from the folder a window started in. */
const LEGACY = 'code-1a2b3c4d'

const BOARD = { name: 'sitrep', summary: "Lee's board inside Claude Code", project: 'SitRep' }

const meta = (id: string, name: string, project: string, by = W2): SessionMeta => ({
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

/** The board's own project, as All projects names it first. */
const boardProject = async (w: World) => {
  const ui = await w.pane()

  await ui.press({ key: 'tab:all' })

  const [first] = (await ui.findAll({ type: 'Button' })).filter(each =>
    each.key?.startsWith('proj:'),
  )

  await ui.unmount()

  return first?.text
}

/** The conversation's first message's sitrep block. */
const firstMessage = async ($: Engine) =>
  (await $.prompt.context({ blocks: [] })).blocks.find(block => block.name === 'sitrep')?.text

test('start makes a new project of the name given, keyed by its slug, whatever folder the window started in', async ($, on) => {
  const w = world($, on)

  w.become({ cwd: HOME })
  await $.session.start(CONVERSATION)

  const answer = await w.call('start', BOARD)
  const id = startedId(answer)

  expect(answer.result).toBe(
    `Started sitrep as ${id}, in a new project, SitRep. Record ${id} wherever the project tracks this work, so a later window can join it.`,
  )
  expect(fileIn(w, 'sitrep')).toEqual({ name: 'SitRep', created: T0, by: W1 })
  expect(parseMeta(w.text(sessionPaths(ROOT, 'sitrep', id).meta))).toMatchObject({
    project: 'SitRep',
    root: HOME,
  })
  expect(w.state.attachment).toMatchObject({ project: 'sitrep', session: id })
  expect(w.state.board?.project).toBe('SitRep')
})

test('start puts the session in the project its name matches, case, spaces and punctuation aside, and the project keeps its name', async ($, on) => {
  const w = world($, on)

  await $.session.start(CONVERSATION)
  await w.call('start', BOARD)

  for (const name of ['sitrep', 'Sit Rep', ' SIT-REP! ']) {
    const answer = await w.call('start', { ...BOARD, name: `Session on ${name}`, project: name })

    expect(String(answer.result), name).toContain(', in the existing project SitRep. Record ')
    expect(w.state.attachment?.project, name).toBe('sitrep')
    expect(w.state.board?.project, name).toBe('SitRep')
  }

  expect(projectKeys(w)).toEqual(['sitrep'])
  expect(fileIn(w, 'sitrep')?.name).toBe('SitRep')
})

test("a directory given is the project's: a new one keeps it, one with none takes it, and one with its own keeps that", async ($, on) => {
  const w = world($, on)

  await $.session.start(CONVERSATION)
  await w.call('start', { ...BOARD, directory: `${SITREP_HOME}/` })
  await w.call('start', HELP_DESK)

  expect(fileIn(w, 'sitrep')?.directory).toBe(SITREP_HOME)
  expect(fileIn(w, PROJECT.key)?.directory).toBeUndefined()

  const given = await w.call('start', { ...HELP_DESK, name: 'Lobby', directory: REPO })

  expect(String(given.result)).toContain(', in the existing project Northwind. Record ')
  expect(fileIn(w, PROJECT.key)).toEqual({
    name: 'Northwind',
    directory: REPO,
    created: T0,
    by: W1,
  })

  const other = await w.call('start', { ...BOARD, name: 'Themes', directory: '/Users/me/other' })

  expect(String(other.result)).toContain(
    `, in the existing project SitRep, which lives in ${SITREP_HOME}; the project tool changes that. Record `,
  )
  expect(fileIn(w, 'sitrep')?.directory).toBe(SITREP_HOME)
})

test('a project folder with no project.json is named as its sessions recorded it, and a start by that name goes into it', async ($, on) => {
  const w = world($, on)

  w.elsewhere(meta('sr-1egacy', 'Early days', 'code'), LEGACY)
  await $.session.start(CONVERSATION)

  const answer = await w.call('start', { ...BOARD, name: 'Lobby', project: 'Code' })

  expect(String(answer.result)).toContain(', in the existing project Code. Record ')
  expect(w.state.attachment?.project).toBe(LEGACY)
  expect(projectKeys(w), 'nothing written to name it').toEqual([])
  expect(await boardProject(w)).toBe('Code')
})

test('a project.json written into a folder from before relabels it, moving nothing', async ($, on) => {
  const w = world($, on)
  const legacy = w.elsewhere(meta('sr-1egacy', 'Early days', 'code'), LEGACY)
  const before = [...w.files.keys()]

  w.project(LEGACY, { name: 'SitRep', directory: SITREP_HOME, created: T0, by: W2 })
  await $.session.start(CONVERSATION)
  await w.call('join', { session: 'sr-1egacy' })

  expect(w.state.board?.project).toBe('SitRep')
  expect(await boardProject(w)).toBe('SitRep')

  await w.call('start', { ...BOARD, name: 'Lobby', project: 'Sitrep' })

  expect(w.state.attachment?.project).toBe(LEGACY)
  expect(before.every(path => w.files.has(path))).toBe(true)
  expect(w.files.has(legacy.paths.meta)).toBe(true)

  const code = await w.call('start', { ...BOARD, name: 'Themes', project: 'Code' })

  expect(String(code.result), 'the old name names it no more').toContain('in a new project, Code')
  expect(w.state.attachment?.project).toBe('code')
})

test("the board's own project is the held session's, whatever folder the window started in", async ($, on) => {
  const w = world($, on)

  w.project(PROJECT.key, { name: PROJECT.name, directory: REPO, created: T0, by: W2 })
  w.elsewhere(meta('sr-pr1ce5', 'Pricing page, stage 1', 'Northwind')).beat()
  await $.session.start(CONVERSATION)
  await w.call('start', BOARD)

  expect(await boardProject(w)).toBe('SitRep')

  await w.call('join', { session: 'sr-pr1ce5' })

  expect(await boardProject(w)).toBe('Northwind')
})

test('the project tool renames the held session’s project and sets where it lives, the session staying where it is filed', async ($, on) => {
  const w = world($, on)

  await $.session.start(CONVERSATION)

  const id = startedId(await w.call('start', { ...BOARD, project: 'Sitrep' }))

  await w.clock.advance(MIN)

  expect((await w.call('project', { name: 'SitRep' })).result).toBe(
    'Renamed the project Sitrep to SitRep.',
  )
  expect(fileIn(w, 'sitrep')).toEqual({ name: 'SitRep', created: T0, by: W1 })
  expect(w.state.board?.project).toBe('SitRep')
  expect(await boardProject(w)).toBe('SitRep')

  expect((await w.call('project', { directory: SITREP_HOME })).result).toBe(
    `SitRep lives in ${SITREP_HOME}.`,
  )
  expect(fileIn(w, 'sitrep')).toEqual({
    name: 'SitRep',
    directory: SITREP_HOME,
    created: T0,
    by: W1,
  })
  expect(w.state.attachment).toMatchObject({ project: 'sitrep', session: id })
  expect(w.files.has(sessionPaths(ROOT, 'sitrep', id).meta)).toBe(true)
})

test('the project tool never takes the name of another project, nor changes nothing', async ($, on) => {
  const w = world($, on)

  await w.begin()
  await w.call('start', BOARD)

  expect((await w.call('project', { name: 'north wind' })).deny).toBe(
    "Another project is already named Northwind. This renames the attached session's project; it moves no session to another.",
  )
  expect((await w.call('project', {})).deny).toBe(
    'Give the project a new name, a directory, or both.',
  )
  expect((await w.call('project', { name: 'Sit Rep' })).result, 'its own name, respelled').toBe(
    'Renamed the project SitRep to Sit Rep.',
  )
  expect(fileIn(w, PROJECT.key)?.name).toBe('Northwind')
})

test('the project tool gives a folder from before projects were named its first project.json', async ($, on) => {
  const w = world($, on)

  w.elsewhere(meta('sr-1egacy', 'Early days', 'code'), LEGACY)
  await w.clock.advance(MIN)
  await $.session.start(CONVERSATION)
  await w.call('join', { session: 'sr-1egacy' })

  expect((await w.call('project', { name: 'SitRep' })).result).toBe(
    'Renamed the project Code to SitRep.',
  )
  expect(fileIn(w, LEGACY)).toEqual({ name: 'SitRep', created: T0 + MIN, by: W1 })
  expect(w.state.attachment?.project).toBe(LEGACY)
  expect(await boardProject(w)).toBe('SitRep')
})

/** Three projects with current sessions: Fabrikam and Northwind each living somewhere, and Contoso from before. */
const threeProjects = (w: World) => {
  const fabrikam: ProjectFile = {
    name: 'Fabrikam',
    directory: FABRIKAM_HOME,
    created: T0,
    by: W2,
  }
  const northwind: ProjectFile = { name: 'Northwind', directory: REPO, created: T0, by: W3 }

  w.project('fabrikam', fabrikam)
  w.project(PROJECT.key, northwind)
  w.elsewhere(meta('sr-fabr1k', 'Price list', 'Fabrikam'), 'fabrikam').write(
    yesAsk('k1', 'Review the plan'),
    yesAsk('k2', 'Try the board', 'Done'),
  )
  w.elsewhere(meta('sr-pr1ce5', 'Pricing page, stage 1', 'Northwind', W3)).beat()
  w.elsewhere(meta('sr-eeeeee', 'Onboarding', 'contoso'), 'contoso-1a2b3c4d').write(
    note('n1', 'Drew the flow'),
  )
}

const FABRIKAM_LINE = '- Fabrikam: sr-fabr1k "Price list", 2 waiting on Lee'
const NORTHWIND_LINE = '- Northwind: sr-pr1ce5 "Pricing page, stage 1"'
const CONTOSO_LINE = '- Contoso: sr-eeeeee "Onboarding"'

test("the first message lists every project's current sessions, those living around the window's folder first", async ($, on) => {
  const w = world($, on)

  threeProjects(w)
  w.become({ cwd: `${FABRIKAM_HOME}/hooks` })

  expect(await firstMessage($)).toContain(
    ['On the board:', FABRIKAM_LINE, NORTHWIND_LINE, CONTOSO_LINE].join('\n'),
  )

  w.become({ cwd: REPO })

  expect(await firstMessage($)).toContain(
    ['On the board:', NORTHWIND_LINE, FABRIKAM_LINE, CONTOSO_LINE].join('\n'),
  )
})

test('a conversation resumed in any folder takes up the session it was last seen in, whichever project files it', async ($, on) => {
  const w = world($, on, { now: T0 + 10 * MIN })

  threeProjects(w)
  w.beat(
    'sr-fabr1k',
    { writer: W1, attachedAt: T0, seenAt: T0 + MIN, leftAt: T0 + MIN },
    'fabrikam',
  )
  w.beat(
    'sr-eeeeee',
    { writer: W1, attachedAt: T0, seenAt: T0 + 5 * MIN, leftAt: T0 + 5 * MIN },
    'contoso-1a2b3c4d',
  )
  w.become({ cwd: HOME })

  const listing = await firstMessage($)

  expect(w.state.attachment).toMatchObject({ project: 'contoso-1a2b3c4d', session: 'sr-eeeeee' })
  expect(listing).toContain('This window already holds sr-eeeeee (Onboarding)')
})
