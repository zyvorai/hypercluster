import { motion } from 'framer-motion'

export function AppBackdrop() {
  return (
    <div className="app-backdrop" aria-hidden>
      <motion.div
        className="backdrop-orb backdrop-orb-orange"
        animate={{ x: [0, 24, -12, 0], y: [0, -18, 8, 0], scale: [1, 1.06, 0.98, 1] }}
        transition={{ duration: 22, repeat: Infinity, ease: 'easeInOut' }}
      />
      <motion.div
        className="backdrop-orb backdrop-orb-purple"
        animate={{ x: [0, -20, 14, 0], y: [0, 16, -10, 0], scale: [1, 0.95, 1.04, 1] }}
        transition={{ duration: 26, repeat: Infinity, ease: 'easeInOut' }}
      />
      <motion.div
        className="backdrop-orb backdrop-orb-indigo"
        animate={{ x: [0, 12, -8, 0], y: [0, 10, -6, 0] }}
        transition={{ duration: 18, repeat: Infinity, ease: 'easeInOut' }}
      />
    </div>
  )
}
