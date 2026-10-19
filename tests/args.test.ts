import { expect, test } from 'claude-code/testing'
import { parseWords, wantsHelp, type Grammar } from '../cli/args'
import type { Checked } from '../core'

/** A command shaped as ask is: two arguments, a value, a list and a switch. */
const GRAMMAR: Grammar = {
  args: [
    { field: 'kind', about: 'a kind' },
    { field: 'title', about: 'a title' },
  ],
  flags: {
    where: { field: 'where', form: 'one', value: '<words>', about: 'where' },
    option: { field: 'options', form: 'many', value: '<choice>', about: 'a choice' },
    json: { field: 'json', form: 'switch', about: 'JSON' },
  },
}

const FLAGS_ONLY: Grammar = { args: [], flags: GRAMMAR.flags }

const value = <T>(checked: Checked<T>) => (checked.ok ? checked.value : undefined)
const refusal = <T>(checked: Checked<T>) => (checked.ok ? undefined : checked.error)

test('the arguments go in order, the last taking every word left, so a title needs no quotes', () => {
  expect(value(parseWords(GRAMMAR, ['review', 'Review', 'round', '3']))).toEqual({
    kind: 'review',
    title: 'Review round 3',
  })
  expect(value(parseWords(GRAMMAR, ['review', 'Review round 3']))).toEqual({
    kind: 'review',
    title: 'Review round 3',
  })
})

test('an argument not given is left out, for the check to say it is needed', () => {
  expect(value(parseWords(GRAMMAR, ['review']))).toEqual({ kind: 'review' })
  expect(value(parseWords(GRAMMAR, []))).toEqual({})
})

test('a flag takes its value from the next word or after an =, a list one value each time', () => {
  expect(
    value(
      parseWords(GRAMMAR, [
        'decide',
        '--where',
        'In Paper',
        'Keep it?',
        '--option=Keep it',
        '--option',
        'Drop it',
        '--json',
      ]),
    ),
  ).toEqual({
    kind: 'decide',
    title: 'Keep it?',
    where: 'In Paper',
    options: ['Keep it', 'Drop it'],
    json: true,
  })
})

test('an empty value is a value: it is how a status clears what it names', () => {
  expect(value(parseWords(GRAMMAR, ['--where', '', '--option=']))).toEqual({
    where: '',
    options: [''],
  })
})

test('after --, every word is an argument, however it starts', () => {
  expect(value(parseWords(GRAMMAR, ['do', '--', '--json', 'is', 'a', 'word']))).toEqual({
    kind: 'do',
    title: '--json is a word',
  })
})

test('a lone dash, or a dash before a number, is a word', () => {
  expect(value(parseWords(GRAMMAR, ['do', '-', '-5%', 'on', 'load']))).toEqual({
    kind: 'do',
    title: '- -5% on load',
  })
})

test('a flag the command has not, or given wrong, is refused, naming it', () => {
  expect(refusal(parseWords(GRAMMAR, ['--colour', 'red']))).toBe('There is no --colour.')
  expect(refusal(parseWords(GRAMMAR, ['do', 'It', '--where']))).toBe(
    '--where needs a value: <words>.',
  )
  expect(refusal(parseWords(GRAMMAR, ['--where', 'here', '--where=there']))).toBe(
    'Give --where once.',
  )
  expect(refusal(parseWords(GRAMMAR, ['--json=yes']))).toBe('--json takes no value.')
})

test('a command of flags only refuses any other word', () => {
  expect(refusal(parseWords(FLAGS_ONLY, ['now', '--json']))).toBe('It takes flags only, not "now".')
  expect(value(parseWords(FLAGS_ONLY, ['--json']))).toEqual({ json: true })
})

test('a command taking no words at all refuses any, as taking nothing', () => {
  const none: Grammar = { args: [], flags: {} }

  expect(refusal(parseWords(none, ['now']))).toBe('It takes nothing, not "now".')
  expect(refusal(parseWords(none, ['--json']))).toBe('There is no --json.')
  expect(value(parseWords(none, []))).toEqual({})
})

test('help is asked for by --help or -h among the flags, never after --', () => {
  expect(wantsHelp(['review', '--help'])).toBe(true)
  expect(wantsHelp(['-h'])).toBe(true)
  expect(wantsHelp(['do', '--', '--help'])).toBe(false)
  expect(wantsHelp(['do', 'help'])).toBe(false)
})
