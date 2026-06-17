// ============================================================
// Orb.jsx — the floating ALAKEYA / WAI Agent sphere
//
// PROPS
//   state      'idle' | 'listening' | 'thinking' | 'speaking'
//              | 'acting' | 'permission' | 'error'
//   size       px (default 72)
//   onClick    () => void
//   accent     hex string — tints the sphere, halo, particles, glow
//   glow       0..1 — halo / shadow intensity (default 0.68)
//   particles  0..1 — idle spark density / opacity (default 0.5)
//   faceStyle  'minimal' | 'friendly' | 'futuristic'
//
// Appearance props let onboarding + settings preview the orb live,
// instead of only re-styling the surrounding UI.
// ============================================================

import React from 'react';
import styles from './Orb.module.css';

const VALID_STATES = [
  'idle', 'listening', 'thinking', 'speaking',
  'acting', 'permission', 'error',
];

// #RRGGBB → "r, g, b"
function rgb(hex) {
  const h = (hex || '#06B6D4').replace('#', '');
  const n = parseInt(h.length === 3 ? h.split('').map((c) => c + c).join('') : h, 16);
  return `${(n >> 16) & 255}, ${(n >> 8) & 255}, ${n & 255}`;
}
// lighten toward white by t (0..1)
function lighten(hex, t = 0.45) {
  const [r, g, b] = rgb(hex).split(',').map((x) => parseInt(x, 10));
  const mix = (c) => Math.round(c + (255 - c) * t);
  return `rgb(${mix(r)}, ${mix(g)}, ${mix(b)})`;
}

export default function Orb({
  state = 'idle',
  size = 72,
  onClick,
  accent,
  glow = 0.68,
  particles = 0.5,
  faceStyle = 'friendly',
  ariaLabel = 'Alakeya assistant',
}) {
  const safeState = VALID_STATES.includes(state) ? state : 'idle';

  const mouthClass =
    safeState === 'thinking' || safeState === 'acting' ? 'flat'  :
    safeState === 'error'                              ? 'frown' :
    safeState === 'speaking'                           ? 'speak' : '';

  const showVoiceDots = safeState === 'listening';
  const showPulseRings = safeState === 'listening';
  const showOrbitals = safeState === 'thinking';
  const showSparks = safeState === 'idle' && particles > 0.05;

  // Per-instance accent override. Falls back to the global token when no
  // accent prop is supplied, so existing usages keep working.
  const vars = { '--orb-size': `${size}px`, '--orb-glow': glow };
  if (accent) {
    const bright = lighten(accent, 0.45);
    const triple = rgb(accent);
    vars['--wai-accent'] = accent;
    vars['--wai-accent-bright'] = bright;
    vars['--wai-accent-glow'] = `rgba(${triple}, ${0.35 + glow * 0.4})`;
    vars['--wai-accent-pale'] = lighten(accent, 0.7);
    vars['--wai-orb-core'] =
      `radial-gradient(circle at 35% 30%, ${lighten(accent, 0.75)} 0%, ${accent} 38%, #1e1b4b 76%, #050216 100%)`;
    vars['--wai-shadow-orb'] =
      `0 0 ${20 + glow * 28}px rgba(${triple}, ${0.4 + glow * 0.45}), ` +
      `inset -4px -4px 12px rgba(0,0,0,0.5), inset 4px 4px 12px rgba(${triple}, 0.45)`;
    vars['--wai-shadow-orb-bright'] = `0 0 ${36 + glow * 30}px rgba(${triple}, 0.9)`;
  }

  return (
    <button
      type="button"
      className={`${styles.orbRoot} ${styles[`face-${faceStyle}`] || ''}`}
      style={vars}
      onClick={onClick}
      aria-label={ariaLabel}
    >
      <div className={styles.halo} />

      {showPulseRings && (
        <>
          <div className={styles.pulseRing} />
          <div className={styles.pulseRing} />
          <div className={styles.pulseRing} />
        </>
      )}

      {showOrbitals && (
        <div className={styles.orbitWrap}>
          <div className={styles.orbit1}>
            <span className={styles.particle} style={{ top: 0, left: '50%' }} />
            <span className={styles.particle} style={{ bottom: 0, left: '50%' }} />
          </div>
          <div className={styles.orbit2}>
            <span className={styles.particle} style={{ top: '10%', right: '15%', width: 3, height: 3 }} />
            <span className={styles.particle} style={{ bottom: '10%', left: '15%', width: 2, height: 2 }} />
          </div>
        </div>
      )}

      <div className={`${styles.sphere} ${styles[safeState]}`}>
        <div className={`${styles.eye} ${styles.eyeLeft}`} />
        <div className={`${styles.eye} ${styles.eyeRight}`} />

        {showVoiceDots ? (
          <div className={styles.voiceDots}>
            <span /><span /><span />
          </div>
        ) : (
          <div className={`${styles.mouth} ${mouthClass ? styles[mouthClass] : ''}`} />
        )}
      </div>

      {showSparks && (
        <div style={{ opacity: 0.4 + particles * 0.6 }}>
          <span className={styles.spark} style={{ top: '-10%', left: '30%', '--dx': '8px', '--dy': '-14px' }} />
          <span className={styles.spark} style={{ bottom: '5%', right: '-6%', animationDelay: '0.6s', '--dx': '12px', '--dy': '6px' }} />
          <span className={styles.spark} style={{ top: '15%', right: '-10%', animationDelay: '1.2s', '--dx': '14px', '--dy': '-8px' }} />
        </div>
      )}
    </button>
  );
}
