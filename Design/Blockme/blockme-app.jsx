// blockme-app.jsx — main interactive component
// All six states live in one component, driven by `mode`:
//   installed | empty | locked | install | error
// `addOpen` controls the add-domain sheet overlay independently.

const { useState, useRef, useEffect, useMemo } = React;

// ─────────────────────────────────────────────────────────────
// Design tokens — slightly warmer than stock macOS so the panel
// reads as crafted rather than templated. Greens lean toward a
// quieter eucalyptus; blues toward indigo. Single source of truth.
// ─────────────────────────────────────────────────────────────
const T = {
  ink:   '#1a1a1f',
  ink2:  '#3a3a40',
  ink3:  '#62626a',
  ink4:  '#9a9aa1',
  hair:  'rgba(0,0,0,0.07)',
  hair2: 'rgba(0,0,0,0.12)',
  surface: '#fdfdfb',
  surface2: '#f5f3ee',
  bg: '#f0ede5',
  green:  '#2f7a52',
  greenL: '#dfeee5',
  blue:   '#2a5fd0',
  blueL:  '#e3eaf8',
  red:    '#c0392f',
  redL:   '#f6e3df',
  amber:  '#a06900',
  amberL: '#f5e9cc',
  font: '"Inter Tight", -apple-system, BlinkMacSystemFont, "SF Pro Display", "SF Pro Text", system-ui, sans-serif',
  mono: '"JetBrains Mono", "SF Mono", ui-monospace, monospace',
};

// ─────────────────────────────────────────────────────────────
// Icons — 1px stroke, currentColor. Slightly more refined than
// the SF-Symbols clones; consistent geometric construction.
// ─────────────────────────────────────────────────────────────
const Icon = {
  shieldFill: ({ size = 18, color = 'currentColor' }) => (
    <svg width={size} height={size} viewBox="0 0 18 18" fill="none">
      <path d="M9 1.6 2.6 3.4v5.2c0 3.4 2.6 6.5 6.4 8 3.8-1.5 6.4-4.6 6.4-8V3.4L9 1.6z" fill={color} fillOpacity="0.14" />
      <path d="M9 1.6 2.6 3.4v5.2c0 3.4 2.6 6.5 6.4 8 3.8-1.5 6.4-4.6 6.4-8V3.4L9 1.6z" stroke={color} strokeWidth="1.2" strokeLinejoin="round" />
      <path d="M5.8 9.2 8 11.4l4.2-4.4" stroke={color} strokeWidth="1.4" strokeLinecap="round" strokeLinejoin="round" />
    </svg>
  ),
  shieldExclaim: ({ size = 18, color = 'currentColor' }) => (
    <svg width={size} height={size} viewBox="0 0 18 18" fill="none">
      <path d="M9 1.6 2.6 3.4v5.2c0 3.4 2.6 6.5 6.4 8 3.8-1.5 6.4-4.6 6.4-8V3.4L9 1.6z" fill={color} fillOpacity="0.14" />
      <path d="M9 1.6 2.6 3.4v5.2c0 3.4 2.6 6.5 6.4 8 3.8-1.5 6.4-4.6 6.4-8V3.4L9 1.6z" stroke={color} strokeWidth="1.2" strokeLinejoin="round" />
      <path d="M9 5.5v4.2M9 11.6v.6" stroke={color} strokeWidth="1.4" strokeLinecap="round" />
    </svg>
  ),
  shieldOutline: ({ size = 18, color = 'currentColor' }) => (
    <svg width={size} height={size} viewBox="0 0 18 18" fill="none" stroke={color} strokeWidth="1.2" strokeLinejoin="round" strokeLinecap="round">
      <path d="M9 1.6 2.6 3.4v5.2c0 3.4 2.6 6.5 6.4 8 3.8-1.5 6.4-4.6 6.4-8V3.4L9 1.6z" />
    </svg>
  ),
  lockClosed: ({ size = 14, color = 'currentColor' }) => (
    <svg width={size} height={size} viewBox="0 0 14 14" fill="none">
      <rect x="2.5" y="6.2" width="9" height="6.6" rx="1.6" fill={color} />
      <path d="M4.4 6.2V4a2.6 2.6 0 0 1 5.2 0v2.2" stroke={color} strokeWidth="1.3" strokeLinecap="round" />
    </svg>
  ),
  lockOpen: ({ size = 14, color = 'currentColor' }) => (
    <svg width={size} height={size} viewBox="0 0 14 14" fill="none">
      <rect x="2.5" y="6.2" width="9" height="6.6" rx="1.6" fill={color} />
      <path d="M4.4 6.2V4a2.6 2.6 0 0 1 4.9-1.2" stroke={color} strokeWidth="1.3" strokeLinecap="round" />
    </svg>
  ),
  plus: ({ size = 11 }) => (
    <svg width={size} height={size} viewBox="0 0 11 11" fill="none" stroke="currentColor" strokeWidth="1.7" strokeLinecap="round">
      <path d="M5.5 1.6v7.8M1.6 5.5h7.8" />
    </svg>
  ),
  minus: ({ size = 11 }) => (
    <svg width={size} height={size} viewBox="0 0 11 11" fill="none" stroke="currentColor" strokeWidth="1.7" strokeLinecap="round">
      <path d="M1.8 5.5h7.4" />
    </svg>
  ),
  check: ({ size = 12, color = 'currentColor' }) => (
    <svg width={size} height={size} viewBox="0 0 12 12" fill="none" stroke={color} strokeWidth="1.7" strokeLinecap="round" strokeLinejoin="round">
      <path d="M2.5 6.2 5 8.6 9.6 3.6" />
    </svg>
  ),
  warn: ({ size = 14, color = 'currentColor' }) => (
    <svg width={size} height={size} viewBox="0 0 14 14" fill={color}>
      <path d="M7 1.2 0.5 12.6h13L7 1.2zm-.6 4.2h1.2v3.6H6.4V5.4zm0 4.6h1.2v1.3H6.4v-1.3z" />
    </svg>
  ),
  arrowRight: ({ size = 11 }) => (
    <svg width={size} height={size} viewBox="0 0 11 11" fill="none" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round">
      <path d="M2 5.5h7M6 2.5l3 3-3 3" />
    </svg>
  ),
};

// ─────────────────────────────────────────────────────────────
// Status block — the hero element on every "running" state.
// Larger than the original, with a more architectural layout:
// shield medallion at left, two-line title, divider, key/value
// strip beneath. Reads as serious and reassuring.
// ─────────────────────────────────────────────────────────────
function StatusBlock({ tone, title, sub, kvs }) {
  const palette = {
    active:  { fg: T.green, soft: T.greenL, ring: 'rgba(47,122,82,0.22)' },
    locked:  { fg: T.ink2,  soft: '#ececea', ring: 'rgba(0,0,0,0.15)' },
    error:   { fg: T.red,   soft: T.redL,   ring: 'rgba(192,57,47,0.22)' },
    install: { fg: T.blue,  soft: T.blueL,  ring: 'rgba(42,95,208,0.22)' },
  }[tone];

  const ShieldIcon = tone === 'error' ? Icon.shieldExclaim
    : tone === 'install' ? Icon.shieldOutline
    : tone === 'locked' ? Icon.shieldOutline
    : Icon.shieldFill;

  return (
    <div style={{
      margin: '14px 14px 0',
      padding: '14px 14px 12px',
      borderRadius: 12,
      background: T.surface,
      boxShadow: `inset 0 0 0 0.5px ${T.hair2}`,
      position: 'relative', overflow: 'hidden',
    }}>
      {/* soft tinted wash on the left side */}
      <div style={{
        position: 'absolute', top: 0, left: 0, bottom: 0, width: 90,
        background: `linear-gradient(135deg, ${palette.soft} 0%, transparent 90%)`,
        opacity: 0.85, pointerEvents: 'none',
      }} />

      <div style={{ position: 'relative', display: 'flex', alignItems: 'center', gap: 12 }}>
        <div style={{
          width: 38, height: 38, borderRadius: 11,
          background: '#fff',
          boxShadow: `0 0 0 0.5px ${palette.ring}, 0 1px 0 rgba(0,0,0,0.04)`,
          display: 'flex', alignItems: 'center', justifyContent: 'center',
          color: palette.fg, flexShrink: 0,
        }}>
          <ShieldIcon size={20} color={palette.fg} />
        </div>
        <div style={{ flex: 1, minWidth: 0 }}>
          <div style={{
            fontSize: 14, fontWeight: 600, color: T.ink, letterSpacing: -0.25,
            display: 'flex', alignItems: 'center', gap: 7,
          }}>
            {tone === 'active' && <PulseDot color={palette.fg} />}
            {tone === 'error' && <span style={{ width: 7, height: 7, borderRadius: '50%', background: palette.fg }} />}
            {tone === 'locked' && <Icon.lockClosed size={11} color={palette.fg} />}
            {title}
          </div>
          <div style={{ fontSize: 12, color: T.ink3, marginTop: 3, lineHeight: 1.45, letterSpacing: -0.05 }}>
            {sub}
          </div>
        </div>
      </div>

      {kvs && kvs.length > 0 && (
        <div style={{
          marginTop: 12, paddingTop: 10,
          borderTop: `0.5px solid ${T.hair}`,
          display: 'flex', gap: 22, alignItems: 'center',
          fontSize: 11, color: T.ink3, fontVariantNumeric: 'tabular-nums',
          letterSpacing: -0.05,
        }}>
          {kvs.map((kv, i) => (
            <div key={i} style={{ display: 'flex', alignItems: 'center', gap: 6 }}>
              <span style={{ color: T.ink4, textTransform: 'uppercase', fontSize: 9.5, fontWeight: 600, letterSpacing: 0.6 }}>
                {kv.label}
              </span>
              <span style={{ color: T.ink2, fontWeight: 500 }}>{kv.value}</span>
            </div>
          ))}
        </div>
      )}
    </div>
  );
}

// Subtle breathing dot for the "live" state — keyframe in styles below.
function PulseDot({ color = T.green }) {
  return (
    <span style={{ position: 'relative', width: 8, height: 8, display: 'inline-block' }}>
      <span style={{
        position: 'absolute', inset: 0, borderRadius: '50%', background: color,
      }} />
      <span style={{
        position: 'absolute', inset: 0, borderRadius: '50%', background: color,
        opacity: 0.35, animation: 'bm-pulse 2.2s ease-out infinite',
      }} />
    </span>
  );
}

// ─────────────────────────────────────────────────────────────
// Section header above the list
// ─────────────────────────────────────────────────────────────
function ListHeader({ count, locked, onAdd, onLock }) {
  return (
    <div style={{
      display: 'flex', alignItems: 'center', justifyContent: 'space-between',
      padding: '14px 16px 8px',
    }}>
      <div style={{ display: 'flex', alignItems: 'baseline', gap: 8 }}>
        <span style={{ fontSize: 10, fontWeight: 600, textTransform: 'uppercase', letterSpacing: 0.9, color: T.ink4 }}>
          Blocklist
        </span>
        <span style={{ fontSize: 11, color: T.ink4, fontVariantNumeric: 'tabular-nums', letterSpacing: -0.05 }}>
          {count} {count === 1 ? 'domain' : 'domains'}
        </span>
      </div>
      {locked ? (
        <button onClick={onLock} style={pillBtn('ghost')}>
          <Icon.lockClosed size={11} />
          <span>Unlock to edit</span>
        </button>
      ) : (
        <button onClick={onAdd} style={pillBtn('primary')} disabled={!onAdd}>
          <Icon.plus />
          <span>Add Domain</span>
        </button>
      )}
    </div>
  );
}

function pillBtn(kind) {
  const base = {
    display: 'inline-flex', alignItems: 'center', gap: 6,
    height: 24, padding: '0 11px', borderRadius: 7,
    fontSize: 12, fontWeight: 500, letterSpacing: -0.1,
    border: 'none', cursor: 'pointer', fontFamily: 'inherit',
    transition: 'background .12s, opacity .12s, transform .12s',
  };
  if (kind === 'primary') return {
    ...base, background: T.ink, color: '#fff',
    boxShadow: `inset 0 0.5px 0 rgba(255,255,255,0.18), 0 0.5px 1.5px rgba(0,0,0,0.18)`,
  };
  if (kind === 'danger')  return { ...base, background: T.red, color: '#fff' };
  return { ...base, background: 'rgba(0,0,0,0.05)', color: T.ink };
}

// ─────────────────────────────────────────────────────────────
// Domain row — letter chip, monospace domain, hover-revealed remove.
// The chip color is hashed off the domain so it's stable per row.
// ─────────────────────────────────────────────────────────────
const CHIP_PALETTE = [
  { fg: '#2f7a52', bg: '#dfeee5' },
  { fg: '#2a5fd0', bg: '#e3eaf8' },
  { fg: '#a04a8a', bg: '#f1e3ee' },
  { fg: '#a06900', bg: '#f5e9cc' },
  { fg: '#6a4ca8', bg: '#e8e3f5' },
  { fg: '#3b6e8a', bg: '#dce8f0' },
  { fg: '#a04330', bg: '#f3e0d9' },
];
function chipColor(domain) {
  let h = 0; for (let i = 0; i < domain.length; i++) h = (h * 31 + domain.charCodeAt(i)) >>> 0;
  return CHIP_PALETTE[h % CHIP_PALETTE.length];
}

function DomainRow({ domain, locked, onRemove, confirmingRemove, onConfirmRemove, onCancelRemove, last }) {
  const [hover, setHover] = useState(false);
  const c = useMemo(() => chipColor(domain), [domain]);
  const initial = domain[0]?.toUpperCase() || '?';

  return (
    <div
      onMouseEnter={() => setHover(true)}
      onMouseLeave={() => { setHover(false); if (confirmingRemove) onCancelRemove(); }}
      style={{
        display: 'flex', alignItems: 'center', gap: 10,
        padding: '9px 12px 9px 12px',
        borderBottom: last ? 'none' : `0.5px solid ${T.hair}`,
        background: hover && !locked ? 'rgba(42,95,208,0.04)' : 'transparent',
        opacity: locked ? 0.65 : 1,
        transition: 'background .12s',
      }}
    >
      <div style={{
        width: 24, height: 24, borderRadius: 6, flexShrink: 0,
        background: c.bg, color: c.fg,
        display: 'flex', alignItems: 'center', justifyContent: 'center',
        fontSize: 11, fontWeight: 600, letterSpacing: -0.2,
        boxShadow: `inset 0 0 0 0.5px ${c.fg}22`,
      }}>
        {initial}
      </div>
      <div style={{
        flex: 1, fontFamily: T.mono,
        fontSize: 12.5, color: T.ink, letterSpacing: -0.1,
        overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap',
        fontVariationSettings: '"wght" 450',
      }}>
        {domain}
      </div>
      <span style={{
        fontSize: 9.5, color: T.ink4, fontWeight: 600,
        textTransform: 'uppercase', letterSpacing: 0.7,
        opacity: hover && !locked ? 0 : 0.9, transition: 'opacity .1s',
      }}>
        Blocked
      </span>
      {!locked && confirmingRemove && (
        <div style={{ display: 'flex', gap: 4 }}>
          <button onClick={onCancelRemove} style={{ ...pillBtn('ghost'), height: 22, fontSize: 11.5 }}>Cancel</button>
          <button onClick={onConfirmRemove} style={{ ...pillBtn('danger'), height: 22, fontSize: 11.5 }}>Remove</button>
        </div>
      )}
      {!locked && !confirmingRemove && (
        <button
          onClick={onRemove}
          style={{
            width: 22, height: 22, borderRadius: 6,
            border: 'none', background: hover ? 'rgba(0,0,0,0.06)' : 'transparent',
            cursor: 'pointer', display: 'flex', alignItems: 'center', justifyContent: 'center',
            color: T.ink2, opacity: hover ? 1 : 0, transition: 'opacity .12s, background .12s',
          }}
          title="Remove"
        >
          <Icon.minus />
        </button>
      )}
    </div>
  );
}

// ─────────────────────────────────────────────────────────────
// Empty state inside the list
// ─────────────────────────────────────────────────────────────
function EmptyList({ locked, onAdd }) {
  return (
    <div style={{
      padding: '44px 24px 40px', textAlign: 'center',
      display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 12,
    }}>
      <div style={{
        width: 56, height: 56, borderRadius: 16,
        background: T.surface2,
        display: 'flex', alignItems: 'center', justifyContent: 'center',
        color: T.ink4, position: 'relative',
      }}>
        <div style={{
          position: 'absolute', inset: 0, borderRadius: 16,
          background: 'radial-gradient(circle at 30% 25%, rgba(255,255,255,0.9), transparent 60%)',
          pointerEvents: 'none',
        }} />
        <Icon.shieldOutline size={26} color={T.ink3} />
      </div>
      <div style={{ fontSize: 13.5, fontWeight: 600, color: T.ink, letterSpacing: -0.2 }}>
        Your blocklist is empty
      </div>
      <div style={{ fontSize: 12, color: T.ink3, maxWidth: 290, lineHeight: 1.5, letterSpacing: -0.05 }}>
        Protection is active and watching. Add a domain to start enforcing.
      </div>
      {!locked && onAdd && (
        <button onClick={onAdd} style={{ ...pillBtn('primary'), height: 26, marginTop: 6 }}>
          <Icon.plus />
          <span>Add your first domain</span>
        </button>
      )}
    </div>
  );
}

// ─────────────────────────────────────────────────────────────
// Footer status strip
// ─────────────────────────────────────────────────────────────
function Footer({ children }) {
  return (
    <div style={{
      height: 30, flexShrink: 0,
      borderTop: `0.5px solid ${T.hair2}`,
      background: T.surface2,
      display: 'flex', alignItems: 'center', padding: '0 14px',
      fontSize: 10.5, color: T.ink3, gap: 10,
      fontVariantNumeric: 'tabular-nums', letterSpacing: -0.05,
    }}>
      {children}
    </div>
  );
}

// ─────────────────────────────────────────────────────────────
// Inline banner (success / error)
// ─────────────────────────────────────────────────────────────
function Banner({ tone = 'success', children, onDismiss }) {
  const tones = {
    success: { bg: T.greenL, fg: T.green, dot: '#34a06a' },
    error:   { bg: T.redL,   fg: T.red,   dot: T.red },
  }[tone];
  return (
    <div style={{
      margin: '10px 14px 0', padding: '8px 10px 8px 12px', borderRadius: 8,
      background: tones.bg, color: tones.fg, fontSize: 12, fontWeight: 500,
      display: 'flex', alignItems: 'center', gap: 8, letterSpacing: -0.05,
      boxShadow: `inset 0 0 0 0.5px ${tones.fg}22`,
    }}>
      {tone === 'success' ? <Icon.check color={tones.dot} /> : <Icon.warn color={tones.dot} />}
      <span style={{ flex: 1 }}>{children}</span>
      {onDismiss && (
        <button onClick={onDismiss} style={{
          border: 'none', background: 'transparent', color: tones.fg, opacity: 0.55,
          cursor: 'pointer', fontSize: 14, lineHeight: 1, padding: 0,
        }}>×</button>
      )}
    </div>
  );
}

// ─────────────────────────────────────────────────────────────
// Add-domain sheet — the moment of design care most users notice
// ─────────────────────────────────────────────────────────────
function AddSheet({ onAdd, onCancel, existing = [] }) {
  const [value, setValue] = useState('');
  const [error, setError] = useState('');
  const [focused, setFocused] = useState(false);
  const inputRef = useRef(null);

  useEffect(() => { inputRef.current?.focus(); }, []);

  const validate = (raw) => {
    let v = raw.trim().toLowerCase();
    if (!v) return { error: 'Enter a domain.' };
    try { if (v.includes('://')) v = new URL(v).hostname; } catch {}
    v = v.replace(/^www\./, '').replace(/\/.*$/, '');
    if (!/^[a-z0-9.-]+\.[a-z]{2,}$/.test(v)) return { error: 'That doesn\u2019t look like a valid domain.' };
    if (existing.includes(v)) return { error: `${v} is already in your blocklist.` };
    return { value: v };
  };

  const submit = (e) => {
    e.preventDefault();
    const r = validate(value);
    if (r.error) { setError(r.error); return; }
    onAdd(r.value);
  };

  // Live preview of the parsed hostname
  const preview = useMemo(() => {
    if (!value.trim()) return null;
    let v = value.trim().toLowerCase();
    try { if (v.includes('://')) v = new URL(v).hostname; } catch {}
    v = v.replace(/^www\./, '').replace(/\/.*$/, '');
    if (v && v !== value.trim().toLowerCase() && /^[a-z0-9.-]+\.[a-z]{2,}$/.test(v)) return v;
    return null;
  }, [value]);

  return (
    <div onClick={onCancel} style={{
      position: 'absolute', inset: 0, zIndex: 30,
      display: 'flex', alignItems: 'flex-start', justifyContent: 'center',
      background: 'rgba(20,20,22,0.22)', backdropFilter: 'blur(3px)',
      animation: 'bm-fade .18s ease-out',
    }}>
      <form onClick={(e) => e.stopPropagation()} onSubmit={submit} style={{
        marginTop: 64, width: 380,
        background: T.surface, borderRadius: 14,
        boxShadow: '0 0 0 0.5px rgba(0,0,0,0.18), 0 24px 60px rgba(0,0,0,0.32), 0 6px 16px rgba(0,0,0,0.16)',
        overflow: 'hidden',
        animation: 'bm-sheet .22s cubic-bezier(.2,.8,.2,1)',
      }}>
        <div style={{ padding: '20px 22px 16px' }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: 10, marginBottom: 12 }}>
            <div style={{
              width: 28, height: 28, borderRadius: 8, background: T.redL, color: T.red,
              display: 'flex', alignItems: 'center', justifyContent: 'center',
            }}>
              <Icon.shieldOutline size={15} color={T.red} />
            </div>
            <div>
              <div style={{ fontSize: 13.5, fontWeight: 600, color: T.ink, letterSpacing: -0.2 }}>
                Add domain to blocklist
              </div>
              <div style={{ fontSize: 11.5, color: T.ink3, marginTop: 1, letterSpacing: -0.05 }}>
                Takes effect immediately, system-wide.
              </div>
            </div>
          </div>

          <div style={{
            position: 'relative',
            background: '#fff',
            borderRadius: 8,
            boxShadow: error
              ? `inset 0 0 0 1.5px ${T.red}, 0 0 0 4px rgba(192,57,47,0.14)`
              : focused
              ? `inset 0 0 0 1.5px ${T.blue}, 0 0 0 4px rgba(42,95,208,0.16)`
              : `inset 0 0 0 0.5px ${T.hair2}`,
            transition: 'box-shadow .12s',
            padding: '0 12px',
            display: 'flex', alignItems: 'center', gap: 8,
            height: 36,
          }}>
            <span style={{ color: T.ink4, fontFamily: T.mono, fontSize: 12.5 }}>https://</span>
            <input
              ref={inputRef}
              value={value}
              onChange={(e) => { setValue(e.target.value); if (error) setError(''); }}
              onFocus={() => setFocused(true)}
              onBlur={() => setFocused(false)}
              placeholder="instagram.com"
              spellCheck={false}
              autoCapitalize="off"
              autoCorrect="off"
              style={{
                flex: 1, height: '100%', border: 'none', background: 'transparent',
                fontFamily: T.mono, fontSize: 13, color: T.ink, outline: 'none',
                letterSpacing: -0.1,
              }}
            />
            {preview && (
              <span style={{
                fontSize: 10.5, color: T.ink4, fontFamily: T.mono,
                display: 'inline-flex', alignItems: 'center', gap: 4,
              }}>
                <Icon.arrowRight size={9} />
                {preview}
              </span>
            )}
          </div>

          <div style={{
            marginTop: 8, fontSize: 11.5, color: error ? T.red : T.ink3,
            minHeight: 16, lineHeight: 1.4, letterSpacing: -0.05,
            display: 'flex', alignItems: 'center', gap: 6,
          }}>
            {error && <Icon.warn size={11} color={T.red} />}
            <span>
              {error || 'Enter a domain such as instagram.com. Subdomains are blocked automatically.'}
            </span>
          </div>
        </div>
        <div style={{
          display: 'flex', justifyContent: 'flex-end', gap: 8,
          padding: '12px 16px', background: T.surface2,
          borderTop: `0.5px solid ${T.hair}`,
        }}>
          <button type="button" onClick={onCancel} style={sheetBtn('secondary')}>Cancel</button>
          <button type="submit" style={sheetBtn('primary')}>Add to blocklist</button>
        </div>
      </form>
    </div>
  );
}

function sheetBtn(kind) {
  const base = {
    height: 28, padding: '0 16px', borderRadius: 8,
    fontSize: 12.5, fontWeight: 500, letterSpacing: -0.1,
    border: 'none', cursor: 'pointer', fontFamily: 'inherit',
    transition: 'background .12s, transform .12s',
  };
  if (kind === 'primary') return {
    ...base, background: T.ink, color: '#fff',
    boxShadow: 'inset 0 0.5px 0 rgba(255,255,255,0.16), 0 1px 2px rgba(0,0,0,0.16)',
  };
  return {
    ...base, background: '#fff', color: T.ink,
    boxShadow: `inset 0 0 0 0.5px ${T.hair2}, 0 0.5px 1px rgba(0,0,0,0.05)`,
  };
}

// Auth sheet
function AuthSheet({ onUnlock, onCancel }) {
  const [pw, setPw] = useState('');
  const ref = useRef(null);
  useEffect(() => { ref.current?.focus(); }, []);
  return (
    <div onClick={onCancel} style={{
      position: 'absolute', inset: 0, zIndex: 30,
      display: 'flex', alignItems: 'flex-start', justifyContent: 'center',
      background: 'rgba(20,20,22,0.22)', backdropFilter: 'blur(3px)',
      animation: 'bm-fade .18s ease-out',
    }}>
      <form onClick={(e) => e.stopPropagation()} onSubmit={(e) => { e.preventDefault(); onUnlock(); }} style={{
        marginTop: 64, width: 380,
        background: T.surface, borderRadius: 14,
        boxShadow: '0 0 0 0.5px rgba(0,0,0,0.18), 0 24px 60px rgba(0,0,0,0.32), 0 6px 16px rgba(0,0,0,0.16)',
        overflow: 'hidden',
        animation: 'bm-sheet .22s cubic-bezier(.2,.8,.2,1)',
      }}>
        <div style={{ padding: '20px 22px 16px', display: 'flex', gap: 14 }}>
          <div style={{
            width: 44, height: 44, borderRadius: 11, flexShrink: 0,
            background: T.surface2, color: T.ink2,
            boxShadow: `inset 0 0 0 0.5px ${T.hair2}`,
            display: 'flex', alignItems: 'center', justifyContent: 'center',
          }}>
            <Icon.lockClosed size={22} />
          </div>
          <div style={{ flex: 1 }}>
            <div style={{ fontSize: 13.5, fontWeight: 600, color: T.ink, letterSpacing: -0.2 }}>
              Authenticate to make changes
            </div>
            <div style={{ fontSize: 11.5, color: T.ink3, marginTop: 4, lineHeight: 1.5, letterSpacing: -0.05 }}>
              Enter your administrator password. Edits will stay unlocked until you close the window.
            </div>
            <input
              ref={ref}
              type="password"
              value={pw}
              onChange={(e) => setPw(e.target.value)}
              placeholder="Password"
              style={{
                marginTop: 12, width: '100%', height: 30, padding: '0 10px',
                borderRadius: 7, border: 'none',
                background: '#fff',
                boxShadow: `inset 0 0 0 0.5px ${T.hair2}`,
                fontSize: 13, color: T.ink, outline: 'none',
                boxSizing: 'border-box', fontFamily: 'inherit', letterSpacing: -0.05,
              }}
            />
          </div>
        </div>
        <div style={{
          display: 'flex', justifyContent: 'flex-end', gap: 8,
          padding: '12px 16px', background: T.surface2,
          borderTop: `0.5px solid ${T.hair}`,
        }}>
          <button type="button" onClick={onCancel} style={sheetBtn('secondary')}>Cancel</button>
          <button type="submit" style={sheetBtn('primary')}>Unlock</button>
        </div>
      </form>
    </div>
  );
}

// ─────────────────────────────────────────────────────────────
// Install / setup state — full-bleed, hero shield, considered copy
// ─────────────────────────────────────────────────────────────
function InstallState({ onInstall, installing }) {
  return (
    <div style={{
      height: '100%', display: 'flex', flexDirection: 'column',
      alignItems: 'center', justifyContent: 'center',
      padding: '32px 36px', textAlign: 'center', gap: 16,
      background: `radial-gradient(ellipse at top, ${T.blueL} 0%, transparent 55%)`,
    }}>
      <div style={{
        width: 76, height: 76, borderRadius: 22,
        background: '#fff',
        boxShadow: `0 0 0 0.5px rgba(42,95,208,0.18), 0 18px 30px -10px rgba(42,95,208,0.28), 0 1px 0 rgba(0,0,0,0.04)`,
        display: 'flex', alignItems: 'center', justifyContent: 'center',
        color: T.blue, position: 'relative',
      }}>
        <div style={{
          position: 'absolute', inset: 0, borderRadius: 22,
          background: 'radial-gradient(circle at 30% 22%, rgba(255,255,255,0.95), transparent 65%)',
        }} />
        <Icon.shieldOutline size={36} color={T.blue} />
      </div>
      <div>
        <div style={{ fontSize: 17, fontWeight: 600, color: T.ink, letterSpacing: -0.4 }}>
          Install background protection
        </div>
        <div style={{ fontSize: 12.5, color: T.ink3, marginTop: 8, lineHeight: 1.55, maxWidth: 320, letterSpacing: -0.05 }}>
          Blockme installs a small system service that enforces your blocklist
          even when this window is closed. You\u2019ll be asked for administrator
          approval once.
        </div>
      </div>
      <button onClick={onInstall} disabled={installing} style={{
        ...sheetBtn('primary'), height: 32, padding: '0 22px', marginTop: 4,
        opacity: installing ? 0.65 : 1, cursor: installing ? 'wait' : 'pointer',
        display: 'inline-flex', alignItems: 'center', gap: 8,
      }}>
        {installing && <Spinner />}
        {installing ? 'Installing\u2026' : 'Install Protection'}
      </button>
      <div style={{
        fontSize: 10.5, color: T.ink4, marginTop: 6,
        textTransform: 'uppercase', letterSpacing: 0.7, fontWeight: 500,
      }}>
        Requires admin authentication \u00b7 macOS 13 or later
      </div>
    </div>
  );
}

function Spinner() {
  return (
    <span style={{
      width: 12, height: 12, borderRadius: '50%',
      border: '1.5px solid rgba(255,255,255,0.3)',
      borderTopColor: '#fff',
      animation: 'bm-spin .7s linear infinite',
      display: 'inline-block',
    }} />
  );
}

// ─────────────────────────────────────────────────────────────
// Error / degraded state
// ─────────────────────────────────────────────────────────────
function ErrorState({ onRetry, onReinstall, retrying }) {
  return (
    <div style={{
      height: '100%', display: 'flex', flexDirection: 'column',
      alignItems: 'center', justifyContent: 'center',
      padding: '28px 36px', textAlign: 'center', gap: 14,
      background: `radial-gradient(ellipse at top, ${T.redL} 0%, transparent 55%)`,
    }}>
      <div style={{
        width: 70, height: 70, borderRadius: 20,
        background: '#fff',
        boxShadow: `0 0 0 0.5px rgba(192,57,47,0.18), 0 16px 28px -10px rgba(192,57,47,0.3)`,
        display: 'flex', alignItems: 'center', justifyContent: 'center',
        color: T.red, position: 'relative',
      }}>
        <div style={{
          position: 'absolute', inset: 0, borderRadius: 20,
          background: 'radial-gradient(circle at 30% 22%, rgba(255,255,255,0.95), transparent 65%)',
        }} />
        <Icon.shieldExclaim size={32} color={T.red} />
      </div>
      <div>
        <div style={{ fontSize: 16, fontWeight: 600, color: T.ink, letterSpacing: -0.3 }}>
          Protection is not running
        </div>
        <div style={{ fontSize: 12.5, color: T.ink3, marginTop: 6, lineHeight: 1.55, maxWidth: 320, letterSpacing: -0.05 }}>
          The background service stopped responding. Your blocklist is preserved,
          but domains are not currently being enforced.
        </div>
      </div>
      <div style={{ display: 'flex', gap: 8, marginTop: 4 }}>
        <button onClick={onReinstall} style={{ ...sheetBtn('secondary'), height: 30 }}>
          Reinstall service
        </button>
        <button onClick={onRetry} disabled={retrying} style={{
          ...sheetBtn('primary'), height: 30,
          opacity: retrying ? 0.65 : 1, cursor: retrying ? 'wait' : 'pointer',
          display: 'inline-flex', alignItems: 'center', gap: 8,
        }}>
          {retrying && <Spinner />}
          {retrying ? 'Retrying\u2026' : 'Retry connection'}
        </button>
      </div>
      <div style={{
        marginTop: 10, fontSize: 10.5, color: T.red,
        fontFamily: T.mono, opacity: 0.85, letterSpacing: -0.05,
      }}>
        Last contact 47s ago \u00b7 SIGPIPE on control socket
      </div>
    </div>
  );
}

// ─────────────────────────────────────────────────────────────
// Main app
// ─────────────────────────────────────────────────────────────
function BlockmeApp({
  initialMode = 'installed',
  initialDomains = ['instagram.com', 'twitter.com', 'reddit.com', 'tiktok.com', 'news.ycombinator.com', 'youtube.com'],
  initialBanner = null,
  forceAddOpen = false,
  forceAuthOpen = false,
  interactive = true,
}) {
  const [mode, setMode] = useState(initialMode);
  const [domains, setDomains] = useState(initialMode === 'empty' ? [] : initialDomains);
  const [addOpen, setAddOpen] = useState(forceAddOpen);
  const [authOpen, setAuthOpen] = useState(forceAuthOpen);
  const [confirmingId, setConfirmingId] = useState(null);
  const [banner, setBanner] = useState(initialBanner);
  const [installing, setInstalling] = useState(false);
  const [retrying, setRetrying] = useState(false);

  useEffect(() => {
    if (!banner || !interactive) return;
    const t = setTimeout(() => setBanner(null), 3500);
    return () => clearTimeout(t);
  }, [banner, interactive]);

  const isLocked = mode === 'locked';
  const isFullState = mode === 'install' || mode === 'error';

  const showBanner = (b) => setBanner(b);

  const handleAdd = (d) => {
    setDomains((cur) => [d, ...cur]);
    setAddOpen(false);
    if (mode === 'empty') setMode('installed');
    showBanner({ tone: 'success', text: `Added ${d}. Blocking is now in effect.` });
  };

  const handleRemove = (d) => {
    setDomains((cur) => cur.filter((x) => x !== d));
    setConfirmingId(null);
    if (domains.length === 1) setMode('empty');
    showBanner({ tone: 'success', text: `Removed ${d} from the blocklist.` });
  };

  const handleInstall = () => {
    if (!interactive) return;
    setInstalling(true);
    setTimeout(() => {
      setInstalling(false);
      setMode(domains.length ? 'installed' : 'empty');
      showBanner({ tone: 'success', text: 'Protection installed and active.' });
    }, 1100);
  };

  const handleRetry = () => {
    if (!interactive) return;
    setRetrying(true);
    setTimeout(() => {
      setRetrying(false);
      setMode(domains.length ? 'installed' : 'empty');
      showBanner({ tone: 'success', text: 'Reconnected to background service.' });
    }, 900);
  };

  // ── Header ──
  let header;
  if (mode === 'locked') {
    header = <StatusBlock
      tone="locked"
      title="Protection Active \u00b7 Locked"
      sub="Enforced in the background even when this window is closed. Edits require admin authentication."
      kvs={[
        { label: 'Service', value: 'Running' },
        { label: 'Last sync', value: '2s ago' },
      ]}
    />;
  } else {
    header = <StatusBlock
      tone="active"
      title="Protection is active"
      sub="Enforced in the background. Continues even when this window is closed."
      kvs={[
        { label: 'Service', value: 'Running' },
        { label: 'Last sync', value: '2s ago' },
        { label: 'Blocked', value: `${domains.length}` },
      ]}
    />;
  }

  return (
    <div style={{
      height: '100%', display: 'flex', flexDirection: 'column', position: 'relative',
      background: T.bg,
      fontFamily: T.font,
      color: T.ink,
    }}>
      {!isFullState && header}

      <div style={{ flex: 1, overflow: 'hidden', display: 'flex', flexDirection: 'column' }}>
        {mode === 'install' && <InstallState onInstall={handleInstall} installing={installing} />}
        {mode === 'error' && <ErrorState onRetry={handleRetry} retrying={retrying} onReinstall={() => interactive && setMode('install')} />}

        {(mode === 'installed' || mode === 'empty' || mode === 'locked') && (
          <>
            {banner && (
              <Banner tone={banner.tone} onDismiss={() => setBanner(null)}>
                {banner.text}
              </Banner>
            )}

            <ListHeader
              count={domains.length}
              locked={isLocked}
              onAdd={interactive ? () => setAddOpen(true) : null}
              onLock={interactive ? () => setAuthOpen(true) : null}
            />

            <div style={{
              flex: 1, overflow: 'auto', margin: '0 14px 14px',
              background: T.surface, borderRadius: 12,
              boxShadow: `inset 0 0 0 0.5px ${T.hair2}`,
            }}>
              {domains.length === 0 ? (
                <EmptyList locked={isLocked} onAdd={interactive ? () => setAddOpen(true) : null} />
              ) : (
                domains.map((d, i) => (
                  <DomainRow
                    key={d}
                    domain={d}
                    locked={isLocked}
                    last={i === domains.length - 1}
                    onRemove={interactive ? () => setConfirmingId(d) : null}
                    confirmingRemove={confirmingId === d}
                    onConfirmRemove={() => handleRemove(d)}
                    onCancelRemove={() => setConfirmingId(null)}
                  />
                ))
              )}
            </div>
          </>
        )}
      </div>

      <Footer>
        {mode === 'install' ? (
          <span style={{ display: 'inline-flex', alignItems: 'center', gap: 6, color: T.ink4 }}>
            <span style={{ width: 6, height: 6, borderRadius: 3, background: T.ink4 }} /> Service not installed
          </span>
        ) : mode === 'error' ? (
          <>
            <span style={{ display: 'inline-flex', alignItems: 'center', gap: 6, color: T.red }}>
              <span style={{ width: 6, height: 6, borderRadius: 3, background: T.red }} /> Disconnected
            </span>
            <span style={{ flex: 1 }} />
            <span style={{ color: T.ink4 }}>Build 4.2.1 (1118)</span>
          </>
        ) : (
          <>
            <span style={{ display: 'inline-flex', alignItems: 'center', gap: 7, color: T.green }}>
              <PulseDot color={T.green} /> Service running
            </span>
            <span style={{ color: T.ink4 }}>\u00b7</span>
            <span>Last sync 2s ago</span>
            <span style={{ flex: 1 }} />
            {isLocked ? (
              <span style={{ display: 'inline-flex', alignItems: 'center', gap: 5 }}>
                <Icon.lockClosed size={10} color={T.ink3} /> Locked
              </span>
            ) : (
              <span style={{ display: 'inline-flex', alignItems: 'center', gap: 5 }}>
                <Icon.lockOpen size={10} color={T.ink3} /> Unlocked
              </span>
            )}
          </>
        )}
      </Footer>

      {addOpen && (
        <AddSheet
          existing={domains}
          onAdd={handleAdd}
          onCancel={() => setAddOpen(false)}
        />
      )}
      {authOpen && (
        <AuthSheet
          onUnlock={() => { setAuthOpen(false); setMode('installed'); showBanner({ tone: 'success', text: 'Edits unlocked for this session.' }); }}
          onCancel={() => setAuthOpen(false)}
        />
      )}
    </div>
  );
}

// One-time keyframes injection
if (typeof document !== 'undefined' && !document.getElementById('bm-keyframes')) {
  const s = document.createElement('style');
  s.id = 'bm-keyframes';
  s.textContent = `
    @keyframes bm-pulse { 0% { transform: scale(1); opacity: .35; } 70% { transform: scale(2.2); opacity: 0; } 100% { opacity: 0; } }
    @keyframes bm-spin { to { transform: rotate(360deg); } }
    @keyframes bm-fade { from { opacity: 0; } to { opacity: 1; } }
    @keyframes bm-sheet { from { opacity: 0; transform: translateY(-8px) scale(0.98); } to { opacity: 1; transform: translateY(0) scale(1); } }
  `;
  document.head.appendChild(s);
}

Object.assign(window, { BlockmeApp, Icon, pillBtn, sheetBtn, T });
