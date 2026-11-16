import { expect, test } from './kit'
import { heldReads } from '../cli/held'
import { T0 } from './data'
import { terminal } from './terminal'

const DIR = '/state/sitrep/held'

const put = (t: ReturnType<typeof terminal>, path: string, text: string) =>
  t.files.set(path, { text, mtimeMs: T0 })

test('a file its folder no longer lists is let go: one there again at the same size and time is read anew', async () => {
  const t = terminal()
  const io = heldReads(t.io)
  const path = `${DIR}/a.json`

  put(t, `${DIR}/b.json`, '{}')
  put(t, path, '{"is":1}')
  await io.fs.list(DIR)

  expect(await io.fs.read(path)).toBe('{"is":1}')

  t.files.delete(path)
  await io.fs.list(DIR)
  put(t, path, '{"is":2}')
  await io.fs.list(DIR)

  expect(await io.fs.read(path)).toBe('{"is":2}')
})

test('a folder gone lets go of all under it: a file there again at the same size and time is read anew', async () => {
  const t = terminal()
  const io = heldReads(t.io)
  const path = `${DIR}/inner/a.json`

  put(t, path, '{"is":1}')
  await io.fs.list(DIR)
  await io.fs.list(`${DIR}/inner`)

  expect(await io.fs.read(path)).toBe('{"is":1}')

  t.files.delete(path)
  await io.fs.list(DIR)
  put(t, path, '{"is":2}')
  await io.fs.list(DIR)
  await io.fs.list(`${DIR}/inner`)

  expect(await io.fs.read(path)).toBe('{"is":2}')
})
