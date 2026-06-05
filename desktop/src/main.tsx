import { StrictMode } from 'react'
import { createRoot } from 'react-dom/client'
import App from './App'
import { EulaGate } from './components/EulaGate'
import './index.css'

createRoot(document.getElementById('root')!).render(
  <StrictMode>
    <EulaGate>
      <App />
    </EulaGate>
  </StrictMode>,
)
