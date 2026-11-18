import { expect, test } from './kit'
import {
  checkProject,
  checkStart,
  foldSession,
  isSameName,
  metaText,
  nearestFirst,
  newProjectKey,
  parseProject,
  projectAround,
  projectFrom,
  projectName,
  projectNamed,
  projectText,
  recordedName,
  type Project,
  type ProjectFile,
} from '../core'
import { META, T0, W1 } from './data'

const SITREP: ProjectFile = {
  name: 'SitRep',
  directory: '/Users/me/.config/litware/shared/plugins/sitrep',
  created: T0,
  by: W1,
}

const HELP_DESK = { name: 'Help desk', summary: 'Area by area' }

test("a project's name matches another's ignoring case, spaces and punctuation, never its letters", () => {
  for (const name of ['SitRep', 'sitrep', 'Sit Rep', 'SIT-REP', ' sit_rep! ']) {
    expect(isSameName(name, 'SitRep'), name).toBe(true)
  }

  expect(isSameName('Sitreps', 'SitRep')).toBe(false)
  expect(isSameName('Café', 'Cafe'), 'an accent is a letter of its own').toBe(false)
  expect(isSameName('Café', 'Café'), 'however the accent is spelled').toBe(true)
})

test('the project a name names is the one whose name matches, whatever its folder', () => {
  const projects: Project[] = [
    { key: 'code-1a2b3c4d', name: 'SitRep' },
    { key: 'northwind', name: 'Northwind' },
  ]

  expect(projectNamed(projects, 'sitrep')?.key).toBe('code-1a2b3c4d')
  expect(projectNamed(projects, 'Contoso')).toBeUndefined()
})

test("a new project's key is its name as a slug, numbered on past a folder that has it", () => {
  expect(newProjectKey('SitRep', new Set())).toBe('sitrep')
  expect(newProjectKey('Invoice Ledger & Co.', new Set())).toBe('invoice-ledger-co')
  expect(newProjectKey('Café Ünïcode', new Set())).toBe('cafe-unicode')
  expect(newProjectKey('日本', new Set())).toBe('project')
  expect(newProjectKey('SitRep', new Set(['sitrep', 'sitrep-2']))).toBe('sitrep-3')
  expect(newProjectKey('A'.repeat(40), new Set())).toBe('a'.repeat(32))
})

test("a project's file holds its name, its directory if known, and when and by whom it was made", () => {
  const text = projectText(SITREP)

  expect(JSON.parse(text)).toEqual({ v: 1, ...SITREP })
  expect(text.endsWith('\n')).toBe(true)
  expect(parseProject(text)).toEqual(SITREP)
  expect(parseProject(projectText({ ...SITREP, directory: undefined }))).toEqual({
    name: 'SitRep',
    created: T0,
    by: W1,
  })

  for (const torn of ['', '{"v":1,"name":', '{"v":2,"name":"SitRep","created":1,"by":"x"}']) {
    expect(parseProject(torn), torn).toBeUndefined()
  }
})

test('a folder from before projects were named is named as its sessions recorded it, first letter a capital', () => {
  expect(projectName(undefined, 'code')).toBe('Code')
  expect(projectName(SITREP, 'code')).toBe('SitRep')
  expect(projectFrom('code-1a2b3c4d', undefined, 'code')).toEqual({
    key: 'code-1a2b3c4d',
    name: 'Code',
  })
  expect(projectFrom('code-1a2b3c4d', SITREP, 'code')).toEqual({
    key: 'code-1a2b3c4d',
    name: 'SitRep',
    directory: SITREP.directory,
  })
  expect(projectFrom('empty', undefined, undefined)).toBeUndefined()
})

test('such a folder goes by the name the first of its sessions to read recorded, in the order listed', () => {
  expect(recordedName([undefined, { project: 'code' }, { project: 'other' }])).toBe('code')
  expect(recordedName([undefined])).toBeUndefined()
})

test("a session folds with its project's name as the project's file has it, else as it recorded it", () => {
  const meta = metaText({ ...META, project: 'code' })

  expect(foldSession({ meta, logs: {} }, T0)?.project).toBe('Code')
  expect(foldSession({ meta, project: projectText(SITREP), logs: {} }, T0)?.project).toBe('SitRep')
  expect(foldSession({ meta, project: '{"v":1,', logs: {} }, T0)?.project, 'a torn file').toBe(
    'Code',
  )
})

test('the projects living around a folder come first, the nearest first, the rest as they were', () => {
  const projects = [
    { key: 'northwind' },
    { key: 'code', directory: '/Users/me/Code' },
    { key: 'contoso', directory: '/Users/me/Code/contoso' },
    { key: 'sitrep', directory: '/Users/me/.config/litware/shared/plugins/sitrep' },
    { key: 'litware', directory: '/Users/me/.config/litware' },
  ]
  const keys = (folder: string) => nearestFirst(projects, folder).map(project => project.key)

  expect(keys('/Users/me/.config/litware/shared/plugins/sitrep/hooks')).toEqual([
    'sitrep',
    'litware',
    'northwind',
    'code',
    'contoso',
  ])
  expect(keys('/Users/me/Code/contoso-wt')).toEqual([
    'code',
    'northwind',
    'contoso',
    'sitrep',
    'litware',
  ])
  expect(projectAround(projects, '/Users/me/Code/contoso/')?.key).toBe('contoso')
  expect(projectAround(projects, '/Users/me'), 'a folder above every project').toBeUndefined()
})

test("start takes the project's name, and its directory as an absolute path, the slashes after it dropped", () => {
  expect(checkStart({ ...HELP_DESK, project: '  SitRep\n' })).toEqual({
    ok: true,
    value: { ...HELP_DESK, project: 'SitRep', directory: undefined },
  })
  expect(
    checkStart({ ...HELP_DESK, project: 'SitRep', directory: ' /Users/me/sitrep// ' }),
  ).toEqual({
    ok: true,
    value: { ...HELP_DESK, project: 'SitRep', directory: '/Users/me/sitrep' },
  })
  expect(checkStart({ ...HELP_DESK, project: 'SitRep', directory: '' })).toMatchObject({
    ok: true,
    value: { directory: undefined },
  })
  expect(checkStart({ ...HELP_DESK, project: 'SitRep', directory: '~/sitrep' }).ok).toBe(false)
})

test('the project tool takes a new name, a directory, or both, and refuses neither', () => {
  expect(checkProject({ name: 'SitRep' })).toEqual({
    ok: true,
    value: { name: 'SitRep', directory: undefined },
  })
  expect(checkProject({ directory: '/Users/me/sitrep/' })).toEqual({
    ok: true,
    value: { name: undefined, directory: '/Users/me/sitrep' },
  })
  expect(checkProject({})).toEqual({
    ok: false,
    error: 'Give the project a new name, a directory, or both.',
  })
  expect(checkProject({ name: '...' })).toEqual({
    ok: false,
    error: "A project's name is one line, as the user would say it, with a letter or a digit.",
  })
  expect(checkProject({ name: 'SitRep', directory: 'sitrep' }).ok).toBe(false)
})
