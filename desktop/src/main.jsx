import React from 'react';
import { createRoot } from 'react-dom/client';
import App from './App';

// ALAKEYA design system: tokens → animations → components → shell.
import './components/alakeya/tokens.css';
import './components/alakeya/animations.css';
import './styles/components.css';
import './styles/app.css';

createRoot(document.getElementById('root')).render(
  <React.StrictMode>
    <App />
  </React.StrictMode>
);
