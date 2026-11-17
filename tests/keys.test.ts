/**
 * The two kinds of key a session is named by, held apart by the compiler
 * (see "A session moves to another project at Lee's word" in DESIGN.md): a
 * ref a view drew names the project it showed the session in, and is
 * refused wherever a ref the window keeps, naming the folder its files are
 * in, goes. What is pinned here is pinned by the type-check, which fails on
 * any `@ts-expect-error` no longer refused.
 */
import { expect, test } from './kit'
import {
  folderKey,
  sessionPaths,
  type FolderKey as Folder,
  type ProjectKey as Project,
} from '../core'
import type { Host } from '../hooks/host'
import { writeOwnFile, type Into } from '../hooks/into'
import { attachTo } from '../hooks/window'
import type { FolderKey, ProjectKey, SitrepSessionRef } from '../types'

/** Whether two types are each assignable to the other. */
type Same<A, B> = [A] extends [B] ? ([B] extends [A] ? true : false) : false

test("the plugin's types brand the two keys as core does, each assignable to the other's", () => {
  const same: [Same<FolderKey, Folder>, Same<ProjectKey, Project>] = [true, true]

  expect(same).toEqual([true, true])
})

test('a drawn ref is refused where a kept one goes: a write into a session, the queue, the attachment; and no folder or path to one is made of a project', () => {
  const drawn: SitrepSessionRef<ProjectKey> = {
    project: 'contoso' as ProjectKey,
    session: 'sr-0sh1ft',
  }
  const none = () => []
  const posted = async () => undefined
  const misuses = (host: Host) => [
    // @ts-expect-error a write goes by a kept ref
    ((into: Into) => into)({ ...drawn, writer: 'w' }),
    // @ts-expect-error through the hold, or beside it
    writeOwnFile(host, { ...drawn, writer: 'w' }, none, posted),
    // @ts-expect-error Ready to send keeps the folder
    host.state.queue.write([{ ...drawn, item: 'p1', verdict: 'pickup' }]),
    // @ts-expect-error as the attachment does
    host.state.attachment.write({ ...drawn, writer: 'w', attachedAt: 0 }),
    // @ts-expect-error and the hold
    attachTo(host, '/root', { ...drawn, writer: 'w', attachedAt: 0 }),
    // @ts-expect-error a project's key is never a folder's
    folderKey(drawn.project),
    // @ts-expect-error nor names the path to a session's files
    sessionPaths('/root', drawn.project, drawn.session),
  ]

  expect(misuses).toBeInstanceOf(Function)
})
