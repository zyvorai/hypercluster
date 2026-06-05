import type { TestJson } from '../lib/types'

export function TestResultsPanel({
  results,
  loading,
  error,
}: {
  results: TestJson | null
  loading?: boolean
  error?: string
}) {
  if (loading) {
    return <p className="text-sm text-glass-muted">Running platform smoke tests…</p>
  }
  if (error) {
    return <p className="text-sm text-red-300">{error}</p>
  }
  if (!results) {
    return <p className="text-sm text-glass-muted">No test results yet. Run test to refresh.</p>
  }
  return (
    <div>
      <p className="mb-3 text-sm">
        <span className="text-emerald-300">{results.pass} passed</span>
        {results.fail > 0 && (
          <span className="ml-2 text-red-300">{results.fail} failed</span>
        )}
      </p>
      <ul className="max-h-64 space-y-1 overflow-y-auto text-sm">
        {results.checks.map((c) => (
          <li
            key={c.name}
            className={`flex items-center justify-between rounded-lg px-2 py-1 ${
              c.passed ? 'bg-emerald-500/10' : 'bg-red-500/10'
            }`}
          >
            <span>{c.name}</span>
            <span className={c.passed ? 'text-emerald-300' : 'text-red-300'}>
              {c.passed ? 'PASS' : 'FAIL'}
            </span>
          </li>
        ))}
      </ul>
    </div>
  )
}
