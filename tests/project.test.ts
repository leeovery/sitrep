import { expect, test } from 'claude-code/testing'
import {
  checkProject,
  checkStart,
  foldWork,
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
  type Project,
  type ProjectFile,
} from '../core'
import { META, T0, W1 } from './support'

const SITREP: ProjectFile = {
  name: 'SitRep',
  directory: '/Users/lee/.config/kit/shared/plugins/sitrep',
  created: T0,
  by: W1,
}

const DASHBOARD = { name: 'Dashboard', summary: 'Area by area' }

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
    { key: 'code-84dbac88', name: 'SitRep' },
    { key: 'switchboard', name: 'Switchboard' },
  ]

  expect(projectNamed(projects, 'sitrep')?.key).toBe('code-84dbac88')
  expect(projectNamed(projects, 'Goosemates')).toBeUndefined()
})

test("a new project's key is its name as a slug, numbered on past a folder that has it", () => {
  expect(newProjectKey('SitRep', new Set())).toBe('sitrep')
  expect(newProjectKey('Request Ledger & Co.', new Set())).toBe('request-ledger-co')
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

test('a folder from before projects were named is named as its works recorded it, first letter a capital', () => {
  expect(projectName(undefined, 'code')).toBe('Code')
  expect(projectName(SITREP, 'code')).toBe('SitRep')
  expect(projectFrom('code-84dbac88', undefined, 'code')).toEqual({
    key: 'code-84dbac88',
    name: 'Code',
  })
  expect(projectFrom('code-84dbac88', SITREP, 'code')).toEqual({
    key: 'code-84dbac88',
    name: 'SitRep',
    directory: SITREP.directory,
  })
  expect(projectFrom('empty', undefined, undefined)).toBeUndefined()
})

test("a work folds with its project's name as the project's file has it, else as it recorded it", () => {
  const meta = metaText({ ...META, project: 'code' })

  expect(foldWork({ meta, logs: {} }, T0)?.project).toBe('Code')
  expect(foldWork({ meta, project: projectText(SITREP), logs: {} }, T0)?.project).toBe('SitRep')
  expect(foldWork({ meta, project: '{"v":1,', logs: {} }, T0)?.project, 'a torn file').toBe('Code')
})

test('the projects living around a folder come first, the nearest first, the rest as they were', () => {
  const projects = [
    { key: 'switchboard' },
    { key: 'code', directory: '/Users/lee/Code' },
    { key: 'goosemates', directory: '/Users/lee/Code/goosemates' },
    { key: 'sitrep', directory: '/Users/lee/.config/kit/shared/plugins/sitrep' },
    { key: 'kit', directory: '/Users/lee/.config/kit' },
  ]
  const keys = (folder: string) => nearestFirst(projects, folder).map(project => project.key)

  expect(keys('/Users/lee/.config/kit/shared/plugins/sitrep/hooks')).toEqual([
    'sitrep',
    'kit',
    'switchboard',
    'code',
    'goosemates',
  ])
  expect(keys('/Users/lee/Code/goosemates-wt')).toEqual([
    'code',
    'switchboard',
    'goosemates',
    'sitrep',
    'kit',
  ])
  expect(projectAround(projects, '/Users/lee/Code/goosemates/')?.key).toBe('goosemates')
  expect(projectAround(projects, '/Users/lee'), 'a folder above every project').toBeUndefined()
})

test("start takes the project's name, and its directory as an absolute path, the slashes after it dropped", () => {
  expect(checkStart({ ...DASHBOARD, project: '  SitRep\n' })).toEqual({
    ok: true,
    value: { ...DASHBOARD, project: 'SitRep', directory: undefined },
  })
  expect(
    checkStart({ ...DASHBOARD, project: 'SitRep', directory: ' /Users/lee/sitrep// ' }),
  ).toEqual({
    ok: true,
    value: { ...DASHBOARD, project: 'SitRep', directory: '/Users/lee/sitrep' },
  })
  expect(checkStart({ ...DASHBOARD, project: 'SitRep', directory: '' })).toMatchObject({
    ok: true,
    value: { directory: undefined },
  })
  expect(checkStart({ ...DASHBOARD, project: 'SitRep', directory: '~/sitrep' }).ok).toBe(false)
})

test('the project tool takes a new name, a directory, or both, and refuses neither', () => {
  expect(checkProject({ name: 'SitRep' })).toEqual({
    ok: true,
    value: { name: 'SitRep', directory: undefined },
  })
  expect(checkProject({ directory: '/Users/lee/sitrep/' })).toEqual({
    ok: true,
    value: { name: undefined, directory: '/Users/lee/sitrep' },
  })
  expect(checkProject({})).toEqual({
    ok: false,
    error: 'Give the project a new name, a directory, or both.',
  })
  expect(checkProject({ name: '...' })).toEqual({
    ok: false,
    error: "A project's name is one line, as Lee would say it, with a letter or a digit.",
  })
  expect(checkProject({ name: 'SitRep', directory: 'sitrep' }).ok).toBe(false)
})
