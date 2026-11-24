/**
 * Disciplina: DCC061 (Engenharia de Software)
 * Roteamento principal com guardas por sessão autenticada e papel ativo.
 */
import { lazy, Suspense, type ReactNode } from 'react'
import { Navigate, Route, Routes } from 'react-router-dom'
import {
  rotaInicialPorPapel,
  useSessaoUsuario,
  type PapelAtivo,
} from '@/context/SessaoUsuarioContext'
import { GestaoPedidosPage } from '@/features/comercio/components/GestaoPedidosPage'
import { NavbarComercio } from '@/features/comercio/components/NavbarComercio'
import { NovoPedidoPage } from '@/features/comercio/components/NovoPedidoPage'
import { RelatoriosFinanceirosPage } from '@/features/comercio/components/RelatoriosFinanceirosPage'

const PainelLojistaPage = lazy(() =>
  import('@/features/catalogo/components/PainelLojistaPage').then((m) => ({
    default: m.PainelLojistaPage,
  })),
)
const PainelEntregadorPage = lazy(() => import('@/features/logistica/components/PainelEntregadorPage'))
const RastreioPedido = lazy(() => import('@/features/logistica/components/RastreioPedido'))
const EntrarPage = lazy(() => import('@/features/identidade/components/EntrarPage'))
const PerfisListaPage = lazy(() => import('@/features/identidade/components/PerfisListaPage'))
const PerfilDetalhePage = lazy(() => import('@/features/identidade/components/PerfilDetalhePage'))
const PerfilFormPage = lazy(() => import('@/features/identidade/components/PerfilFormPage'))
const AuditoriaRastreioPage = lazy(() => import('@/features/auditoria/components/AuditoriaRastreioPage'))
const AuditoriaSlaPage = lazy(() => import('@/features/auditoria/components/AuditoriaSlaPage'))

function RotaProtegida({
  papeisPermitidos,
  children,
}: {
  papeisPermitidos: PapelAtivo[]
  children: ReactNode
}) {
  const { usuarioAtual, papelAtivo, carregandoUsuarios } = useSessaoUsuario()

  if (carregandoUsuarios) {
    return (
      <div role="status" className="rounded-2xl border border-surface-bg bg-surface p-8 text-center text-sm text-text-default">
        Carregando sessão...
      </div>
    )
  }

  if (!usuarioAtual || !papelAtivo) {
    return <Navigate to="/entrar" replace />
  }

  if (!papeisPermitidos.includes(papelAtivo)) {
    return <Navigate to={rotaInicialPorPapel(papelAtivo)} replace />
  }

  return <>{children}</>
}

export function AppRoutes() {
  const { usuarioAtual, papelAtivo } = useSessaoUsuario()

  return (
    <div className="min-h-screen bg-surface-bg">
      <NavbarComercio />
      <main className="mx-auto max-w-7xl px-4 py-6 sm:px-6">
        <Routes>
          <Route
            path="/entrar"
            element={(
              <Suspense fallback={<p role="status">Carregando...</p>}>
                {usuarioAtual && papelAtivo ? (
                  <Navigate to={rotaInicialPorPapel(papelAtivo)} replace />
                ) : (
                  <EntrarPage />
                )}
              </Suspense>
            )}
          />
          <Route
            path="/cadastro"
            element={(
              <Suspense fallback={<p role="status">Carregando formulário...</p>}>
                <PerfilFormPage />
              </Suspense>
            )}
          />

          <Route
            path="/"
            element={(
              <RotaProtegida papeisPermitidos={['cliente']}>
                <NovoPedidoPage />
              </RotaProtegida>
            )}
          />
          <Route
            path="/pedidos"
            element={(
              <RotaProtegida papeisPermitidos={['cliente', 'lojista']}>
                <GestaoPedidosPage />
              </RotaProtegida>
            )}
          />
          <Route
            path="/catalogo"
            element={(
              <RotaProtegida papeisPermitidos={['lojista']}>
                <Suspense fallback={<p role="status">Carregando painel da loja...</p>}>
                  <PainelLojistaPage />
                </Suspense>
              </RotaProtegida>
            )}
          />
          <Route
            path="/relatorios"
            element={(
              <RotaProtegida papeisPermitidos={['lojista', 'admin']}>
                <RelatoriosFinanceirosPage />
              </RotaProtegida>
            )}
          />
          <Route
            path="/painel-entregador"
            element={(
              <RotaProtegida papeisPermitidos={['entregador']}>
                <Suspense fallback={<p role="status">Carregando painel de entregas...</p>}>
                  <PainelEntregadorPage />
                </Suspense>
              </RotaProtegida>
            )}
          />
          <Route
            path="/rastreio/:id"
            element={(
              <RotaProtegida papeisPermitidos={['cliente', 'lojista', 'entregador', 'admin']}>
                <Suspense fallback={<p role="status">Carregando rastreio...</p>}>
                  <RastreioPedido />
                </Suspense>
              </RotaProtegida>
            )}
          />
          <Route
            path="/auditoria"
            element={(
              <RotaProtegida papeisPermitidos={['cliente', 'lojista', 'entregador', 'admin']}>
                <Suspense fallback={<p role="status">Carregando histórico de auditoria...</p>}>
                  <AuditoriaRastreioPage />
                </Suspense>
              </RotaProtegida>
            )}
          />
          <Route
            path="/auditoria/sla"
            element={(
              <RotaProtegida papeisPermitidos={['lojista', 'entregador', 'admin']}>
                <Suspense fallback={<p role="status">Carregando painel de SLA...</p>}>
                  <AuditoriaSlaPage />
                </Suspense>
              </RotaProtegida>
            )}
          />
          <Route
            path="/perfis"
            element={(
              <RotaProtegida papeisPermitidos={['admin']}>
                <Suspense fallback={<p role="status">Carregando perfis...</p>}>
                  <PerfisListaPage />
                </Suspense>
              </RotaProtegida>
            )}
          />
          <Route
            path="/perfis/:id"
            element={(
              <RotaProtegida papeisPermitidos={['cliente', 'lojista', 'entregador', 'admin']}>
                <Suspense fallback={<p role="status">Carregando perfil...</p>}>
                  <PerfilDetalhePage />
                </Suspense>
              </RotaProtegida>
            )}
          />
          <Route
            path="/perfis/:id/editar"
            element={(
              <RotaProtegida papeisPermitidos={['cliente', 'lojista', 'entregador', 'admin']}>
                <Suspense fallback={<p role="status">Carregando formulário...</p>}>
                  <PerfilFormPage />
                </Suspense>
              </RotaProtegida>
            )}
          />
          <Route
            path="*"
            element={<Navigate to={usuarioAtual && papelAtivo ? rotaInicialPorPapel(papelAtivo) : '/entrar'} replace />}
          />
        </Routes>
      </main>
    </div>
  )
}