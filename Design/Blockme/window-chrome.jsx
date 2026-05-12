// window-chrome.jsx — refined macOS utility window
// Softer titlebar, slightly larger corner radius, layered shadow.

const SYS_FONT = '"Inter Tight", -apple-system, BlinkMacSystemFont, "SF Pro Display", "SF Pro Text", system-ui, sans-serif';

function TrafficLights({ disabled = false }) {
  const dot = (bg, ring) => (
    <div style={{
      width: 12, height: 12, borderRadius: '50%',
      background: disabled ? '#d4d4d2' : bg,
      boxShadow: disabled
        ? 'inset 0 0 0 0.5px rgba(0,0,0,0.08)'
        : `inset 0 0 0 0.5px ${ring}, inset 0 0.5px 0 rgba(255,255,255,0.35)`,
    }} />
  );
  return (
    <div style={{ display: 'flex', gap: 8, alignItems: 'center' }}>
      {dot('#ff5f57', 'rgba(0,0,0,0.18)')}
      {dot('#febc2e', 'rgba(0,0,0,0.18)')}
      {dot('#28c840', 'rgba(0,0,0,0.18)')}
    </div>
  );
}

function UtilWindow({ width = 480, height = 600, title = 'Blockme', children, accent }) {
  return (
    <div style={{
      width, height, borderRadius: 12, overflow: 'hidden',
      background: '#f6f4ee',
      boxShadow: [
        '0 0 0 0.5px rgba(0,0,0,0.18)',
        '0 28px 64px -12px rgba(20,18,12,0.28)',
        '0 8px 20px -6px rgba(20,18,12,0.18)',
        '0 1px 0 rgba(255,255,255,0.4) inset',
      ].join(','),
      display: 'flex', flexDirection: 'column',
      fontFamily: SYS_FONT,
      color: '#1a1a1f',
    }}>
      <div style={{
        height: 38, flexShrink: 0,
        display: 'grid', gridTemplateColumns: '1fr auto 1fr', alignItems: 'center',
        padding: '0 12px',
        background: 'linear-gradient(180deg, #f9f7f1 0%, #efece4 100%)',
        borderBottom: '0.5px solid rgba(0,0,0,0.12)',
        position: 'relative',
      }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
          <TrafficLights />
        </div>
        <div style={{
          fontSize: 12.5, fontWeight: 600, color: '#3a3a40',
          letterSpacing: -0.15, textAlign: 'center',
          display: 'flex', alignItems: 'center', gap: 7, justifyContent: 'center',
        }}>
          {accent && <span style={{
            width: 7, height: 7, borderRadius: '50%', background: accent,
            boxShadow: `0 0 0 2.5px ${accent}22`,
          }} />}
          {title}
        </div>
        <div />
      </div>
      <div style={{ flex: 1, overflow: 'hidden' }}>
        {children}
      </div>
    </div>
  );
}

Object.assign(window, { UtilWindow, TrafficLights, SYS_FONT });
