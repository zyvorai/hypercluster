import type { CSSProperties } from 'react'
import zavorLogoUrl from '../assets/brand/zavor-logo.webp'

export const ZYVOR_URL = 'https://zyvor.dev'
export const ZYVOR_ORANGE = '#f97316'

type BrandProps = {
  className?: string
  style?: CSSProperties
  includeCopyright?: boolean
}

export function ZyvorLogoMark({
  className = '',
  height = 28,
}: {
  className?: string
  height?: number
}) {
  return (
    <a
      href={ZYVOR_URL}
      target="_blank"
      rel="noopener noreferrer"
      title="zyvor.dev"
      className={`inline-flex shrink-0 items-center ${className}`.trim()}
    >
      <img
        src={zavorLogoUrl}
        alt="Zyvor"
        className="w-auto object-contain"
        style={{ height, maxWidth: height * 4.2 }}
        draggable={false}
      />
    </a>
  )
}

export function ZyvorInline({
  className = '',
  style,
  includeCopyright = true,
}: BrandProps) {
  return (
    <span
      className={`whitespace-normal text-xs leading-relaxed text-glass-muted ${className}`.trim()}
      style={style}
    >
      <a
        href={ZYVOR_URL}
        target="_blank"
        rel="noopener noreferrer"
        className="font-semibold transition hover:brightness-110"
        style={{ color: ZYVOR_ORANGE }}
      >
        zyvor.dev
      </a>
      {includeCopyright ? (
        <>
          <span aria-hidden> · </span>
          <span style={{ color: ZYVOR_ORANGE, fontWeight: 500 }}>© 2026</span>
        </>
      ) : null}
    </span>
  )
}

export function ZyvorFooter({ className = '' }: { className?: string }) {
  return (
    <footer className={`shrink-0 py-2 text-center ${className}`.trim()} role="contentinfo">
      <ZyvorInline />
    </footer>
  )
}

export function AppBrandHeader({
  product = 'Hypercluster',
  className = '',
}: {
  product?: string
  className?: string
}) {
  return (
    <div className={`flex flex-col gap-2 px-2 py-3 ${className}`.trim()}>
      <ZyvorLogoMark height={26} />
      <div>
        <h1 className="text-lg font-bold tracking-tight text-white">{product}</h1>
        <p className="text-[10px] uppercase tracking-widest text-glass-muted">Cluster Studio</p>
      </div>
    </div>
  )
}
