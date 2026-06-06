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
    return (
      <div className="space-y-2">
        <div className="skeleton h-4 w-32" />
        <div className="skeleton h-8 w-full" />
        <div className="skeleton h-8 w-full" />
      </div>
    )
  }
  if (error) {
    return <p className="text-sm text-red-300">{error}</p>
  }
  if (!results) {
    return <p className="text-sm text-glass-muted">No test results yet. Run test to refresh.</p>
  }

  const total = results.pass + results.fail
  const passRate = total > 0 ? Math.round((results.pass / total) * 100) : 0

  return (
    <div>
      <div className="mb-3 flex flex-wrap items-center justify-between gap-2">
        <p className="text-sm">
          <span className="text-emerald-300">{results.pass} passed</span>
          {results.fail > 0 && <span className="ml-2 text-red-300">{results.fail} failed</span>}
        </p>
        <span
          className={`text-xs font-medium ${passRate === 100 ? 'text-emerald-300' : results.fail > 0 ? 'text-amber-200' : 'text-glass-muted'}`}
        >
          {passRate}% pass rate
        </span>
      </div>
      <div className="stat-bar mb-4 h-2">
        <div
          className="stat-bar-fill h-full"
          style={{ width: `${passRate}%` }}
        />
      </div>
      <ul className="max-h-64 space-y-1 overflow-y-auto text-sm">
        {results.checks.map((c) => (
          <li
            key={c.name}
            className={`flex items-center justify-between rounded-lg border px-2.5 py-1.5 ${
              c.passed
                ? 'border-emerald-500/20 bg-emerald-500/8'
                : 'border-red-500/25 bg-red-500/10'
            }`}
          >
            <span className="truncate pr-2">{c.name}</span>
            <span
              className={`shrink-0 text-[10px] font-medium uppercase tracking-wide ${c.passed ? 'text-emerald-300' : 'text-red-300'}`}
            >
              {c.passed ? '✓ pass' : '✗ fail'}
            </span>
          </li>
        ))}
      </ul>
    </div>
  )
}
