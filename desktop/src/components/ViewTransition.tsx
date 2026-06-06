import { AnimatePresence, motion } from 'framer-motion'
import type { ReactNode } from 'react'

export function ViewTransition({ viewKey, children }: { viewKey: string; children: ReactNode }) {
  return (
    <AnimatePresence mode="wait">
      <motion.div
        key={viewKey}
        initial={{ opacity: 0, y: 10 }}
        animate={{ opacity: 1, y: 0 }}
        exit={{ opacity: 0, y: -6 }}
        transition={{ duration: 0.22, ease: [0.22, 1, 0.36, 1] }}
        className="view-transition-root"
      >
        {children}
      </motion.div>
    </AnimatePresence>
  )
}
