/**
 * All projects: this project first, then the busiest, each with its open
 * sessions hung from it as a tree. Those with nothing open, waiting or
 * parked fold into one line at the bottom.
 */
import type { ProjectSummary, WorkSummary } from '../../core'
import { C, counted, GLYPH, titled } from '../look'
import { everyProject, hereFirst, projectPlace } from '../places'
import { context, heading, waitingWords, type Drawing } from './kit'

const total = (projects: readonly ProjectSummary[], count: (project: ProjectSummary) => number) =>
  projects.reduce((sum, project) => sum + count(project), 0)

const drawSession = (d: Drawing, project: string, work: WorkSummary) => {
  const { Box, Text, Button } = d.els

  return (
    <Box key={`allsess:${work.id}`} flexDirection="row" gap={1}>
      <Box flexGrow={1} flexShrink={1} flexDirection="row" gap={1}>
        <Button
          key={`go:${work.id}`}
          plain
          label={work.name}
          onPress={() => d.act.go({ level: 'session', project, work: work.id })}
        />
        {work.id === d.scene.work.id && <Text color={C.now}>{GLYPH.home}</Text>}
      </Box>
      {work.waiting > 0 && <Text color={C.ask}>{work.waiting} waiting</Text>}
    </Box>
  )
}

/** What hangs from a project: its open sessions, or a line saying none is. */
const branchesOf = (d: Drawing, project: ProjectSummary) => {
  const { Text } = d.els
  const open = hereFirst(
    d.scene,
    project.works.filter(work => work.isOpen),
  )
  const parked = project.parked > 0 ? ` · ${GLYPH.parked} ${project.parked} parked` : ''

  return open.length > 0
    ? open.map(work => drawSession(d, project.key, work))
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
            label={titled(project.name)}
            onPress={() => d.act.go(projectPlace(project.key))}
          />
        </Box>
        {project.waiting > 0 && <Text color={C.ask}>{project.waiting} waiting</Text>}
      </Box>
      {branches.map((branch, i) => (
        <Box key={`alltree:${project.key}:${i}`} flexDirection="row" gap={1}>
          <Text color={C.rule}>{i === branches.length - 1 ? GLYPH.last : GLYPH.branch}</Text>
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
  `${folded.length} more, with nothing going on: ${folded.map(project => titled(project.name)).join(', ')}`

export const drawAllView = (d: Drawing) => {
  const { Box, Text } = d.els
  const { projects, folded } = everyProject(d.scene)
  const open = total(projects, project => project.open)

  return (
    <Box flexDirection="column" gap={1}>
      {context(d, 'All projects', waitingWords(total(projects, project => project.waiting)))}
      <Box flexDirection="column">
        {heading(d, 'PROJECTS', C.parked, `${counted(open, 'session', 'sessions')} open`)}
        <Box flexDirection="column" rowGap={1}>
          {projects.map(project => drawProject(d, project))}
        </Box>
      </Box>
      {folded.length > 0 && (
        <Text color={C.faint} wrap="wrap">
          {foldedLine(folded)}
        </Text>
      )}
    </Box>
  )
}
