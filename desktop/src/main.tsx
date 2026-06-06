import { StrictMode } from 'react'
import { createRoot } from 'react-dom/client'
import App from './App'
import { AppBackdrop } from './components/AppBackdrop'
import { EulaGate } from './components/EulaGate'
import './styles/glass.css'
import './index.css'

createRoot(document.getElementById('root')!).render(
  <StrictMode>
    <AppBackdrop />
    <EulaGate>
      <App />
    </EulaGate>
  </StrictMode>,
)
