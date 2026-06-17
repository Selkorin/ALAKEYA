// ============================================================
// Icons.jsx — crisp inline SVG icons for the quick-actions grid
// and panel chrome. Stroke-based, 24×24 viewBox, currentColor so
// they inherit --wai-accent-bright from .wai-quick-icon.
// ============================================================
import React from 'react';

const base = {
  width: 22,
  height: 22,
  viewBox: '0 0 24 24',
  fill: 'none',
  stroke: 'currentColor',
  strokeWidth: 1.7,
  strokeLinecap: 'round',
  strokeLinejoin: 'round',
};

export const IconOpen = (p) => (
  <svg {...base} {...p}>
    <rect x="3" y="3" width="7" height="7" rx="1.5" />
    <rect x="14" y="3" width="7" height="7" rx="1.5" />
    <rect x="3" y="14" width="7" height="7" rx="1.5" />
    <rect x="14" y="14" width="7" height="7" rx="1.5" />
  </svg>
);

export const IconSearch = (p) => (
  <svg {...base} {...p}>
    <circle cx="11" cy="11" r="7" />
    <path d="M21 21l-4.3-4.3" />
  </svg>
);

export const IconSummarize = (p) => (
  <svg {...base} {...p}>
    <path d="M4 6h16" />
    <path d="M4 12h16" />
    <path d="M4 18h10" />
  </svg>
);

export const IconWrite = (p) => (
  <svg {...base} {...p}>
    <path d="M12 20h9" />
    <path d="M16.5 3.5a2.12 2.12 0 0 1 3 3L7 19l-4 1 1-4Z" />
  </svg>
);

export const IconFiles = (p) => (
  <svg {...base} {...p}>
    <path d="M3 7a2 2 0 0 1 2-2h4l2 2h8a2 2 0 0 1 2 2v8a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2Z" />
  </svg>
);

export const IconImage = (p) => (
  <svg {...base} {...p}>
    <rect x="3" y="4" width="18" height="16" rx="2" />
    <circle cx="8.5" cy="9.5" r="1.6" />
    <path d="M21 16l-5-5L5 20" />
  </svg>
);

export const IconTranslate = (p) => (
  <svg {...base} {...p}>
    <path d="M4 5h7" />
    <path d="M7.5 5v1.5c0 3-2 6-4.5 7.5" />
    <path d="M5 9.5c.8 2 2.6 3.7 4.5 4.5" />
    <path d="M12 20l4-9 4 9" />
    <path d="M13.4 17h5.2" />
  </svg>
);

export const IconSettings = (p) => (
  <svg {...base} {...p}>
    <circle cx="12" cy="12" r="3" />
    <path d="M12 2v3M12 19v3M4.2 4.2l2.1 2.1M17.7 17.7l2.1 2.1M2 12h3M19 12h3M4.2 19.8l2.1-2.1M17.7 6.3l2.1-2.1" />
  </svg>
);

export const IconMinus = (p) => (
  <svg {...base} {...p} width="14" height="14">
    <path d="M5 12h14" />
  </svg>
);

export const IconClose = (p) => (
  <svg {...base} {...p} width="14" height="14">
    <path d="M6 6l12 12M18 6L6 18" />
  </svg>
);
