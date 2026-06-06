import { AnimatePresence, motion } from 'framer-motion'
import type { ReactNode } from 'react'
import type { CockpitSection } from '../lib/types'

export function CockpitSectionTabs({
  sections,
  active,
  onChange,
}: {
  sections: { id: CockpitSection; label: string }[]
  active: CockpitSection
  onChange: (id: CockpitSection) => void
}) {
  return (
    <div className="cockpit-tabs flex flex-wrap gap-1.5">
      {sections.map((s) => (
        <button
          key={s.id}
          type="button"
          className={`cockpit-tab ${active === s.id ? 'cockpit-tab-active' : ''}`}
          onClick={() => onChange(s.id)}
        >
          {s.label}
        </button>
      ))}
    </div>
  )
}

export function CockpitSectionBody({
  sectionKey,
  children,
}: {
  sectionKey: string
  children: ReactNode
}) {
  return (
    <AnimatePresence mode="wait">
      <motion.div
        key={sectionKey}
        initial={{ opacity: 0, y: 8 }}
        animate={{ opacity: 1, y: 0 }}
        exit={{ opacity: 0, y: -4 }}
        transition={{ duration: 0.18, ease: [0.22, 1, 0.36, 1] }}
        className="space-y-4"
      >
        {children}
      </motion.div>
    </AnimatePresence>
  )
}
