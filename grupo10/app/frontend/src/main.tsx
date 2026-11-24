/**
 * Disciplinas: DCC060 (Banco de Dados) & DCC061 (Engenharia de Software)
 */
import { StrictMode } from 'react'
import { createRoot } from 'react-dom/client'
import { BrowserRouter } from 'react-router-dom'
import { SessaoUsuarioProvider } from './context/SessaoUsuarioContext'
import { AppRoutes } from './routes/AppRoutes'
import './index.css'

createRoot(document.getElementById('root')!).render(
  <StrictMode>
    <BrowserRouter>
      <SessaoUsuarioProvider>
        <AppRoutes />
      </SessaoUsuarioProvider>
    </BrowserRouter>
  </StrictMode>,
)
