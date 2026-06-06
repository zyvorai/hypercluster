import type { CSSProperties } from 'react'
import zavorLogoUrl from '../assets/brand/zavor-logo.webp'
import appIconUrl from '../assets/brand/app-icon.svg'

export const ZYVOR_URL = 'https://zyvor.dev'
export const ZYVOR_ORANGE = '#f0583a'
export const ZYVOR_ORANGE_LIGHT = '#ff8a3d'
export const ZYVOR_PURPLE = '#a78bfa'

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
        style={{ color: ZYVOR_ORANGE_LIGHT }}
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
    <div className={`flex flex-col gap-3 px-1 py-2 ${className}`.trim()}>
      <div className="flex items-center gap-3">
        <img
          src={appIconUrl}
          alt=""
          className="h-11 w-11 shrink-0 rounded-[22%] shadow-zyvor-glow ring-1 ring-white/10"
          draggable={false}
        />
        <div className="min-w-0">
          <h1 className="truncate text-base font-bold tracking-tight text-white">{product}</h1>
          <p className="text-[10px] font-medium uppercase tracking-[0.22em] text-glass-accent-light">
            Cluster Studio
          </p>
        </div>
      </div>
      <ZyvorLogoMark height={22} />
    </div>
  )
}
