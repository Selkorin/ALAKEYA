// ============================================================
// snap.js — magnetic corner snapping for the overlay (HANDOFF §5.4).
// ============================================================
const { screen } = require('electron');

const SNAP_RADIUS = 80;

function attachSnap(win, { width, height }) {
  win.on('moved', () => {
    if (win.isDestroyed()) return;
    const [x, y] = win.getPosition();
    const { width: sw, height: sh } = screen.getPrimaryDisplay().workAreaSize;
    const corners = [
      [0, 0], [sw - width, 0],
      [0, sh - height], [sw - width, sh - height],
    ];
    const nearest = corners.reduce(
      (best, [cx, cy]) => {
        const d = Math.hypot(x - cx, y - cy);
        return d < best.d ? { d, cx, cy } : best;
      },
      { d: Infinity, cx: x, cy: y }
    );
    if (nearest.d < SNAP_RADIUS) win.setPosition(nearest.cx, nearest.cy, true);
  });
}

module.exports = { attachSnap };
