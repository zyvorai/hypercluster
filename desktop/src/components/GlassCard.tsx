import { motion } from 'framer-motion'
import type { ReactNode } from 'react'

export function GlassCard({
  children,
  className = '',
  onClick,
  interactive = false,
}: {
  children: ReactNode
  className?: string
  onClick?: () => void
  interactive?: boolean
}) {
  const Tag = interactive || onClick ? motion.div : 'div'
  const motionProps =
    interactive || onClick
      ? {
          whileHover: { y: -2 },
          transition: { duration: 0.2 },
        }
      : {}

  return (
    <Tag
      className={`glass-panel p-5 ${className}`}
      onClick={onClick}
      onKeyDown={onClick ? (e) => e.key === 'Enter' && onClick() : undefined}
      role={onClick ? 'button' : undefined}
      tabIndex={onClick ? 0 : undefined}
      {...motionProps}
    >
      {children}
    </Tag>
  )
}
