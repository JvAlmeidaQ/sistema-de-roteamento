/**
 * Disciplinas: DCC060 (Banco de Dados) & DCC061 (Engenharia de Software)
 * Feature Flag: VITE_APP_MODE (RNF02)
 */
import { Navigate, Route, Routes } from 'react-router-dom'
import { GestaoPedidosPage } from '@/features/comercio/components/GestaoPedidosPage'
import { NavbarComercio } from '@/features/comercio/components/NavbarComercio'
import { NovoPedidoPage } from '@/features/comercio/components/NovoPedidoPage'
import { RelatoriosFinanceirosPage } from '@/features/comercio/components/RelatoriosFinanceirosPage'
import { PainelLojistaPage } from '@/features/catalogo/components/PainelLojistaPage'

const isBd = import.meta.env.VITE_APP_MODE === 'bd'

export function AppRoutes() {
  return (
    <div className="min-h-screen bg-surface-bg">
      <NavbarComercio />
      <main className="mx-auto max-w-7xl px-4 py-6 sm:px-6">
        <Routes>
          <Route path="/" element={<NovoPedidoPage />} />
          <Route path="/relatorios" element={<RelatoriosFinanceirosPage />} />
          {!isBd && (
            <>
              <Route path="/pedidos" element={<GestaoPedidosPage />} />
              <Route path="/catalogo" element={<PainelLojistaPage />} />
            </>
          )}
          <Route path="*" element={<Navigate to="/" replace />} />
        </Routes>
      </main>
    </div>
  )
}
