import { expect, test } from './kit'
import {
  isSessionId,
  LOG_SUFFIX,
  newItemId,
  newSessionId,
  PRESENCE_SUFFIX,
  projectPaths,
  rootOf,
  sessionPaths,
  sessionsDir,
  writerOf,
  type SessionPaths,
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

/** A session's folder's paths, its meta named `meta`. */
const folderAt = (sessions: string, meta: string) => {
  const dir = `${sessions}/sr-k3f9qa`

  return {
    places: [sessions, dir, `${dir}/${meta}`, `${dir}/inbox`, `${dir}/presence`],
    files: [`${dir}/${W1}.jsonl`, `${dir}/inbox/cli.jsonl`, `${dir}/presence/${W1}.json`],
  }
}

const placesOf = (folder: SessionPaths) => ({
  places: [folder.sessions, folder.dir, folder.meta, folder.inbox, folder.presence],
  files: [folder.log(W1), folder.letters('cli'), folder.heartbeat(W1)],
})

test("a session's files sit in its folder under sessions/: session.json, one file per writer, the inbox and the heartbeats", () => {
  const paths = sessionPaths(ROOT, 'switchboard-1a2b3c4d', 'sr-k3f9qa')
  const project = `${ROOT}/projects/switchboard-1a2b3c4d`

  expect(sessionsDir(ROOT, 'switchboard-1a2b3c4d')).toBe(`${project}/sessions`)
  expect(paths.project).toEqual(projectPaths(ROOT, 'switchboard-1a2b3c4d'))
  expect(paths.project).toEqual({ dir: project, file: `${project}/project.json` })
  expect(placesOf(paths)).toEqual(folderAt(`${project}/sessions`, 'session.json'))
})

test('a name that could climb out of its folder is refused', () => {
  expect(() => sessionPaths(ROOT, 'switchboard', '../../etc')).toThrow(
    'Not a name sitrep files under',
  )
  expect(() => projectPaths(ROOT, '..')).toThrow('Not a name sitrep files under')
  expect(() => sessionPaths(ROOT, 'switchboard', 'sr-k3f9qa').log('a/b')).toThrow()
  expect(() => sessionsDir(ROOT, '')).toThrow()
})

test("a listed file gives its writer by its folder's suffix; any other file gives none", () => {
  expect(writerOf(`${W1}.jsonl`, LOG_SUFFIX)).toBe(W1)
  expect(writerOf('cli.jsonl', LOG_SUFFIX)).toBe('cli')
  expect(writerOf('session.json', LOG_SUFFIX)).toBeUndefined()
  expect(writerOf(`${W1}.json`, PRESENCE_SUFFIX)).toBe(W1)
  expect(writerOf('.jsonl', LOG_SUFFIX)).toBeUndefined()
  expect(writerOf('.DS_Store', LOG_SUFFIX)).toBeUndefined()
})

test('a session id is sr- and six characters of base32, drawn from the bytes given', () => {
  const id = newSessionId(scripted(K3F9QA), new Set())

  expect(id).toBe('sr-k3f9qa')
  expect(isSessionId(id)).toBe(true)
  expect(newSessionId(scripted(K3F9QA.map(byte => byte + 32)), new Set())).toBe('sr-k3f9qa')
})

test('an id already taken is drawn again', () => {
  const id = newSessionId(scripted(K3F9QA, [0, 1, 2, 3, 4, 5]), new Set(['sr-k3f9qa']))

  expect(id).toBe('sr-012345')
})

test('an item id is four characters, unlike any id the session already uses', () => {
  expect(newItemId(scripted([19, 3, 15, 9], [1, 1, 1, 1]), new Set(['k3f9']))).toBe('1111')
})

test('where every draw at one length is taken, the id grows a character rather than loop', () => {
  expect(newItemId(scripted([0]), new Set(['0000']))).toBe('00000')
})

test('only an id of the right shape is a session id', () => {
  for (const notId of ['k3f9qa', 'sr-k3f9', 'sr-K3F9QA', 'sr-k3f9qi', '../sr-k3f9qa', 7]) {
    expect(isSessionId(notId), String(notId)).toBe(false)
  }
})
