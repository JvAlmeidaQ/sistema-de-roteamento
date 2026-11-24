/**
 * Disciplinas: DCC060 (Banco de Dados) & DCC061 (Engenharia de Software)
 * Feature Flag: VITE_APP_MODE (RNF02)
 */
import { lazy, Suspense } from 'react'
import { Navigate, Route, Routes } from 'react-router-dom'
import { GestaoPedidosPage } from '@/features/comercio/components/GestaoPedidosPage'
import { NavbarComercio } from '@/features/comercio/components/NavbarComercio'
import { NovoPedidoPage } from '@/features/comercio/components/NovoPedidoPage'
import { RelatoriosFinanceirosPage } from '@/features/comercio/components/RelatoriosFinanceirosPage'

const isBd = import.meta.env.VITE_APP_MODE === 'bd'
const PainelLojistaPage = !isBd
  ? lazy(() =>
      import('@/features/catalogo/components/PainelLojistaPage').then((m) => ({
        default: m.PainelLojistaPage,
      })),
    )
  : null
const PainelEntregadorPage = !isBd
  ? lazy(() => import('@/features/logistica/components/PainelEntregadorPage'))
  : null
const RastreioPedido = !isBd
  ? lazy(() => import('@/features/logistica/components/RastreioPedido'))
  : null
// Subdomínio Identidade e Contato (RF01) — exclusivo de ES
const PerfisListaPage = !isBd
  ? lazy(() => import('@/features/identidade/components/PerfisListaPage'))
  : null
const PerfilDetalhePage = !isBd
  ? lazy(() => import('@/features/identidade/components/PerfilDetalhePage'))
  : null
const PerfilFormPage = !isBd
  ? lazy(() => import('@/features/identidade/components/PerfilFormPage'))
  : null
// Subdomínio Auditoria (RF05, RF10) — exclusivo de ES
const AuditoriaRastreioPage = !isBd
  ? lazy(() => import('@/features/auditoria/components/AuditoriaRastreioPage'))
  : null
const AuditoriaSlaPage = !isBd
  ? lazy(() => import('@/features/auditoria/components/AuditoriaSlaPage'))
  : null

export function AppRoutes() {
  return (
    <div className="min-h-screen bg-surface-bg">
      <NavbarComercio />
      <main className="mx-auto max-w-7xl px-4 py-6 sm:px-6">
        <Routes>
          <Route path="/" element={<NovoPedidoPage />} />
          <Route path="/relatorios" element={<RelatoriosFinanceirosPage />} />
          {!isBd && <Route path="/pedidos" element={<GestaoPedidosPage />} />}
          {PainelLojistaPage && (
            <Route
              path="/catalogo"
              element={(
                <Suspense fallback={<p role="status">Carregando painel do lojista…</p>}>
                  <PainelLojistaPage />
                </Suspense>
              )}
            />
          )}
          {PainelEntregadorPage && (
            <Route
              path="/painel-entregador"
              element={(
                <Suspense fallback={<p role="status">Carregando painel do entregador…</p>}>
                  <PainelEntregadorPage />
                </Suspense>
              )}
            />
          )}
          {RastreioPedido && (
            <Route
              path="/rastreio/:id"
              element={(
                <Suspense fallback={<p role="status">Carregando rastreio…</p>}>
                  <RastreioPedido />
                </Suspense>
              )}
            />
          )}
          {PerfisListaPage && PerfilDetalhePage && PerfilFormPage && (
            <>
              <Route
                path="/perfis"
                element={(
                  <Suspense fallback={<p role="status">Carregando perfis…</p>}>
                    <PerfisListaPage />
                  </Suspense>
                )}
              />
              <Route
                path="/perfis/novo"
                element={(
                  <Suspense fallback={<p role="status">Carregando formulário…</p>}>
                    <PerfilFormPage />
                  </Suspense>
                )}
              />
              <Route
                path="/perfis/:id"
                element={(
                  <Suspense fallback={<p role="status">Carregando perfil…</p>}>
                    <PerfilDetalhePage />
                  </Suspense>
                )}
              />
              <Route
                path="/perfis/:id/editar"
                element={(
                  <Suspense fallback={<p role="status">Carregando formulário…</p>}>
                    <PerfilFormPage />
                  </Suspense>
                )}
              />
            </>
          )}
          {AuditoriaRastreioPage && AuditoriaSlaPage && (
            <>
              <Route
                path="/auditoria"
                element={(
                  <Suspense fallback={<p role="status">Carregando rastreamento de auditoria…</p>}>
                    <AuditoriaRastreioPage />
                  </Suspense>
                )}
              />
              <Route
                path="/auditoria/sla"
                element={(
                  <Suspense fallback={<p role="status">Carregando painel de SLA…</p>}>
                    <AuditoriaSlaPage />
                  </Suspense>
                )}
              />
            </>
          )}
          <Route path="*" element={<Navigate to="/" replace />} />
        </Routes>
      </main>
    </div>
  )
}