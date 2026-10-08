import { expect, test } from 'claude-code/testing'
import {
  COMMON_DIR,
  fnv1a,
  identityOf,
  isWorkId,
  LOG_SUFFIX,
  newItemId,
  newWorkId,
  PRESENCE_SUFFIX,
  projectKeys,
  projectOf,
  rootOf,
  workPaths,
  worksDir,
  writerOf,
} from '../core'
import { scripted, W1 } from './support'

const ROOT = '/Users/lee/.local/state/sitrep'

/** Bytes that map to `k3f9qa` in Crockford's base32: k is 19, 3 is 3, f is 15, 9 is 9, q is 23, a is 10. */
const K3F9QA = [19, 3, 15, 9, 23, 10]

test('the folder is under XDG_STATE_HOME when it names one, else under HOME', () => {
  expect(rootOf({ XDG_STATE_HOME: '/state/', HOME: '/Users/lee' })).toBe('/state/sitrep')
  expect(rootOf({ HOME: '/Users/lee' })).toBe(ROOT)
})

test('an empty or relative XDG_STATE_HOME is ignored, as the XDG spec has it', () => {
  expect(rootOf({ XDG_STATE_HOME: '', HOME: '/Users/lee' })).toBe(ROOT)
  expect(rootOf({ XDG_STATE_HOME: 'state', HOME: '/Users/lee' })).toBe(ROOT)
  expect(() => rootOf({})).toThrow('needs HOME or XDG_STATE_HOME')
})

test("a work's files sit in its folder: work.json, one file per writer, the inbox and the heartbeats", () => {
  const paths = workPaths(ROOT, 'switchboard-1a2b3c4d', 'sr-k3f9qa')
  const dir = `${ROOT}/projects/switchboard-1a2b3c4d/works/sr-k3f9qa`

  expect(worksDir(ROOT, 'switchboard-1a2b3c4d')).toBe(`${ROOT}/projects/switchboard-1a2b3c4d/works`)
  expect([paths.dir, paths.meta, paths.inbox, paths.presence]).toEqual([
    dir,
    `${dir}/work.json`,
    `${dir}/inbox`,
    `${dir}/presence`,
  ])
  expect([paths.log(W1), paths.letters('cli'), paths.heartbeat(W1)]).toEqual([
    `${dir}/${W1}.jsonl`,
    `${dir}/inbox/cli.jsonl`,
    `${dir}/presence/${W1}.json`,
  ])
})

test('a name that could climb out of its folder is refused', () => {
  expect(() => workPaths(ROOT, 'switchboard', '../../etc')).toThrow('Not a name sitrep files under')
  expect(() => workPaths(ROOT, 'switchboard', 'sr-k3f9qa').log('a/b')).toThrow()
  expect(() => worksDir(ROOT, '')).toThrow()
})

test("a listed file gives its writer by its folder's suffix; any other file gives none", () => {
  expect(writerOf(`${W1}.jsonl`, LOG_SUFFIX)).toBe(W1)
  expect(writerOf('cli.jsonl', LOG_SUFFIX)).toBe('cli')
  expect(writerOf('work.json', LOG_SUFFIX)).toBeUndefined()
  expect(writerOf(`${W1}.json`, PRESENCE_SUFFIX)).toBe(W1)
  expect(writerOf('.jsonl', LOG_SUFFIX)).toBeUndefined()
  expect(writerOf('.DS_Store', LOG_SUFFIX)).toBeUndefined()
})

test('the hash is FNV-1a over UTF-8, matching its published values', () => {
  expect(fnv1a('')).toBe(0x811c9dc5)
  expect(fnv1a('a')).toBe(0xe40c292c)
  expect(fnv1a('foobar')).toBe(0xbf9cf968)
  expect(fnv1a('é')).toBe(fnv1a('é'))
})

test("a repository is named by its folder, whether its common dir, a bare repository's, or a plain folder", () => {
  expect(projectOf('/Users/lee/Code/switchboard/.git').name).toBe('switchboard')
  expect(projectOf('/Users/lee/Code/switchboard/.git/').name).toBe('switchboard')
  expect(projectOf('/srv/git/switchboard.git').name).toBe('switchboard')
  expect(projectOf('/Users/lee/notes').name).toBe('notes')
})

test('every worktree of a repository is the one project: they share the common dir, so they share the key', () => {
  const main = projectOf('/Users/lee/Code/switchboard/.git')

  expect(projectOf('/Users/lee/Code/switchboard/.git/')).toEqual(main)
  expect(main.key).toBe(
    `switchboard-${fnv1a('/Users/lee/Code/switchboard/.git').toString(16).padStart(8, '0')}`,
  )
})

test('two repositories of one name are two projects, and every key is folder-safe', () => {
  const api = projectOf('/Users/lee/Code/api/.git')
  const other = projectOf('/Users/lee/Clients/api/.git')
  const odd = projectOf('/Users/lee/Code/Ünïcode Things & Co./.git')

  expect(api.name).toBe(other.name)
  expect(api.key).not.toBe(other.key)
  expect(odd.name).toBe('Ünïcode Things & Co.')
  expect(odd.key).toMatch(/^n-code-things-co-[0-9a-f]{8}$/)
  expect(projectOf('/Users/lee/Code/!!!/.git').key).toMatch(/^project-[0-9a-f]{8}$/)
})

test("a folder's project is known by git's common dir there, else by the folder itself", () => {
  const repo = '/Users/lee/Code/switchboard'

  expect(COMMON_DIR).toEqual(['git', 'rev-parse', '--path-format=absolute', '--git-common-dir'])
  expect(identityOf(`${repo}-wt`, { exitCode: 0, stdout: `${repo}/.git\n` })).toBe(`${repo}/.git`)
  expect(identityOf('/Users/lee/notes', { exitCode: 128, stdout: '' })).toBe('/Users/lee/notes')
  expect(identityOf('/Users/lee/notes', { exitCode: 0, stdout: '\n' })).toBe('/Users/lee/notes')
  expect(identityOf('/Users/lee/notes'), 'git could not run').toBe('/Users/lee/notes')
})

test('the projects a work is looked up in: here first, listed or not, then every other folder-safe one', () => {
  expect(projectKeys('here-1', ['other-2', 'here-1', '.DS_Store', 'more-3'])).toEqual([
    'here-1',
    'other-2',
    'more-3',
  ])
  expect(projectKeys('here-1', [])).toEqual(['here-1'])
})

test('a work id is sr- and six characters of base32, drawn from the bytes given', () => {
  const id = newWorkId(scripted(K3F9QA), new Set())

  expect(id).toBe('sr-k3f9qa')
  expect(isWorkId(id)).toBe(true)
  expect(newWorkId(scripted(K3F9QA.map(byte => byte + 32)), new Set())).toBe('sr-k3f9qa')
})

test('an id already taken is drawn again', () => {
  const id = newWorkId(scripted(K3F9QA, [0, 1, 2, 3, 4, 5]), new Set(['sr-k3f9qa']))

  expect(id).toBe('sr-012345')
})

test('an item id is four characters, unlike any id the work already uses', () => {
  expect(newItemId(scripted([19, 3, 15, 9], [1, 1, 1, 1]), new Set(['k3f9']))).toBe('1111')
})

test('where every draw at one length is taken, the id grows a character rather than loop', () => {
  expect(newItemId(scripted([0]), new Set(['0000']))).toBe('00000')
})

test('only an id of the right shape is a work id', () => {
  for (const notId of ['k3f9qa', 'sr-k3f9', 'sr-K3F9QA', 'sr-k3f9qi', '../sr-k3f9qa', 7]) {
    expect(isWorkId(notId), String(notId)).toBe(false)
  }
})
