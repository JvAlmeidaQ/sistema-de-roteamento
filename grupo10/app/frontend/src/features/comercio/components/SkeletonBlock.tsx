/**
 * Disciplinas: DCC060 (Banco de Dados) & DCC061 (Engenharia de Software)
 * Subdomínio: Comércio e Finanças
 */

interface SkeletonBlockProps {
  linhas?: number
  label?: string
}

export function SkeletonBlock({ linhas = 4, label = 'Carregando dados...' }: SkeletonBlockProps) {
  return (
    <div className="space-y-3 py-2" aria-busy="true" aria-label={label}>
      {Array.from({ length: linhas }).map((_, idx) => (
        <div key={idx} className="h-11 animate-pulse rounded-2xl bg-surface-bg/80" />
      ))}
    </div>
  )
}
