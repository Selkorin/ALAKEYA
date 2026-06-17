// ============================================================
// Orb.jsx — the floating ALAKEYA / WAI Agent sphere
//
// PROPS
//   state    'idle' | 'listening' | 'thinking' | 'speaking'
//            | 'acting' | 'permission' | 'error'
//            (drive this from your existing agent status)
//   size     px (default 72)  — 64/72/96 are the three sizes
//   onClick  () => void       — usually toggles the panel
//
// USAGE
//   <Orb state={agentStatus} onClick={() => setPanelOpen(o => !o)} />
//
// State → visual mapping is defined in Orb.module.css.
// ============================================================

import React from 'react';
import styles from './Orb.module.css';

const VALID_STATES = [
  'idle', 'listening', 'thinking', 'speaking',
  'acting', 'permission', 'error',
];

export default function Orb({
  state = 'idle',
  size = 72,
  onClick,
  ariaLabel = 'Alakeya assistant',
}) {
  const safeState = VALID_STATES.includes(state) ? state : 'idle';

  // mouth variant per state
  const mouthClass =
    safeState === 'thinking' || safeState === 'acting' ? 'flat'  :
    safeState === 'error'                              ? 'frown' :
    safeState === 'speaking'                           ? 'speak' : '';

  const showVoiceDots = safeState === 'listening';
  const showPulseRings = safeState === 'listening';
  const showOrbitals = safeState === 'thinking';
  const showSparks = safeState === 'idle';

  return (
    <button
      type="button"
      className={styles.orbRoot}
      style={{ '--orb-size': `${size}px` }}
      onClick={onClick}
      aria-label={ariaLabel}
    >
      {/* outer pulsing halo */}
      <div className={styles.halo} />

      {/* listening rings */}
      {showPulseRings && (
        <>
          <div className={styles.pulseRing} />
          <div className={styles.pulseRing} />
          <div className={styles.pulseRing} />
        </>
      )}

      {/* thinking orbital particles */}
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

      {/* the sphere */}
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

      {/* idle sparks */}
      {showSparks && (
        <>
          <span className={styles.spark} style={{ top: '-10%', left: '30%', '--dx': '8px', '--dy': '-14px' }} />
          <span className={styles.spark} style={{ bottom: '5%', right: '-6%', animationDelay: '0.6s', '--dx': '12px', '--dy': '6px' }} />
          <span className={styles.spark} style={{ top: '15%', right: '-10%', animationDelay: '1.2s', '--dx': '14px', '--dy': '-8px' }} />
        </>
      )}
    </button>
  );
}
