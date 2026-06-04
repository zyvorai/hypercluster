import type { ReactNode } from 'react'

export function GlassCard({
  children,
  className = '',
}: {
  children: ReactNode
  className?: string
}) {
  return (
    <div className={`glass-panel p-5 ${className}`}>{children}</div>
  )
}
