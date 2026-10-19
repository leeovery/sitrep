/**
 * All projects: this project first, then the busiest, each with its open
 * sessions hung from it as a tree. Those with nothing open, waiting or
 * parked fold into one line at the bottom.
 */
import type { ProjectSummary, SessionSummary } from '../../core'
import { C, counted, GLYPH } from '../look'
import { everyProject, hereFirst, projectPlace } from '../places'
import { context, heading, spaced, waitingWords, type Block, type Drawing } from './kit'

const total = (projects: readonly ProjectSummary[], count: (project: ProjectSummary) => number) =>
  projects.reduce((sum, project) => sum + count(project), 0)

const drawSession = (d: Drawing, project: string, session: SessionSummary) => {
  const { Box, Text, Button } = d.els

  return (
    <Box key={`allsess:${session.id}`} flexDirection="row" gap={1}>
      <Box flexGrow={1} flexShrink={1} flexDirection="row" gap={1}>
        <Button
          key={`go:${session.id}`}
          plain
          label={session.name}
          onPress={() => d.act.go({ level: 'session', project, session: session.id })}
        />
        {session.id === d.scene.session.id && <Text color={C.now}>{GLYPH.home}</Text>}
      </Box>
      {session.waiting > 0 && <Text color={C.ask}>{session.waiting} waiting</Text>}
    </Box>
  )
}

/** What hangs from a project: its open sessions, or a line saying none is. */
const branchesOf = (d: Drawing, project: ProjectSummary) => {
  const { Text } = d.els
  const open = hereFirst(
    d.scene,
    project.sessions.filter(session => session.isOpen),
  )
  const parked = project.parked > 0 ? ` · ${GLYPH.parked} ${project.parked} parked` : ''

  return open.length > 0
    ? open.map(session => drawSession(d, project.key, session))
    : [
        <Text key={`allnone:${project.key}`} color={C.soft}>
          no sessions open{parked}
        </Text>,
      ]
}

const drawProject = (d: Drawing, project: ProjectSummary) => {
  const { Box, Text, Button } = d.els
  const branches = branchesOf(d, project)

  return (
    <Box key={`allproj:${project.key}`} flexDirection="column">
      <Box flexDirection="row" gap={1}>
        <Box flexGrow={1} flexShrink={1}>
          <Button
            key={`proj:${project.key}`}
            plain
            label={project.name}
            onPress={() => d.act.go(projectPlace(project.key))}
          />
        </Box>
        {project.waiting > 0 && <Text color={C.ask}>{project.waiting} waiting</Text>}
      </Box>
      {branches.map((branch, i) => (
        <Box key={`alltree:${project.key}:${i}`} flexDirection="row" gap={1}>
          <Text color={C.faint}>{i === branches.length - 1 ? GLYPH.last : GLYPH.branch}</Text>
          <Box flexGrow={1} flexShrink={1}>
            {branch}
          </Box>
        </Box>
      ))}
    </Box>
  )
}

/** The quiet projects in one line. */
const foldedLine = (folded: readonly ProjectSummary[]) =>
  `${folded.length} more, with nothing going on: ${folded.map(project => project.name).join(', ')}`

/** PROJECTS' heading, then each project, a blank row between each and the next. */
const drawProjects = (d: Drawing, projects: readonly ProjectSummary[]): Block[] => {
  const open = total(projects, project => project.open)

  return [
    {
      key: 'projects',
      element: heading(d, 'PROJECTS', C.parked, `${counted(open, 'session', 'sessions')} open`),
    },
    ...spaced(
      ...projects.map(project => [
        { key: `allproj:${project.key}`, element: drawProject(d, project) },
      ]),
    ),
  ]
}

/** The quiet projects' line; none while every project has something going on. */
const drawFolded = (d: Drawing, folded: readonly ProjectSummary[]): Block[] => {
  const { Text } = d.els

  return folded.length === 0
    ? []
    : [
        {
          key: 'folded',
          element: (
            <Text color={C.faint} wrap="wrap">
              {foldedLine(folded)}
            </Text>
          ),
        },
      ]
}

/** The view's sections, a blank row between each and the next. */
export const drawAllView = (d: Drawing): Block[] => {
  const { projects, folded } = everyProject(d.scene)
  const waiting = waitingWords(total(projects, project => project.waiting))

  return spaced(
    [{ key: 'context', element: context(d, 'All projects', waiting) }],
    drawProjects(d, projects),
    drawFolded(d, folded),
  )
}
