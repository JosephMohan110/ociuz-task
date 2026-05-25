/**
 * AuthContext.jsx
 * ─────────────────────────────────────────────────────────────
 * Provides authentication state to the entire React application.
 *
 * How it works:
 *  1. On every app load / page refresh, calls GET /student/api/v1/auth/me/
 *     If Django session is still valid → user is restored automatically.
 *     If session is gone / expired   → user stays null → ProtectedRoute redirects to /login.
 *
 *  2. login(username, password) → POST /api/auth/login/ (JSON)
 *     Django sets the session cookie. React stores { username, role } in state.
 *
 *  3. logout() → POST /api/auth/logout/
 *     Django flushes the session cookie. React clears user state.
 * ─────────────────────────────────────────────────────────────
 */

import React, { createContext, useContext, useEffect, useState, useCallback } from 'react';
import { getCsrfToken } from '../api/fetchClient';

const AuthContext = createContext(null);

export function AuthProvider({ children }) {
  // null  = not logged in
  // object = { username: '...', role: '...' }
  const [user, setUser] = useState(null);

  // true while we're checking the session with the backend on first load
  const [loading, setLoading] = useState(true);

  // ── Step 1: Restore session on page load / refresh ──────────────────────
  useEffect(() => {
    let mounted = true;
    fetch('/student/api/v1/auth/me/', {
      method: 'GET',
      credentials: 'include',
    })
      .then(async (res) => {
        if (!mounted) return;
        if (res.ok) {
          const data = await res.json();
          if (data.authenticated) {
            setUser({ username: data.username, role: data.role });
          } else {
            setUser(null);
          }
        } else {
          // 401 = not authenticated
          setUser(null);
        }
      })
      .catch(() => {
        if (mounted) setUser(null);
      })
      .finally(() => {
        if (mounted) setLoading(false);
      });

    return () => { mounted = false; };
  }, []);

  // ── Step 2: login() ─────────────────────────────────────────────────────
  const login = useCallback(async (username, password) => {
    const res = await fetch('/api/auth/login/', {
      method: 'POST',
      credentials: 'include',
      headers: {
        'Content-Type': 'application/json',
        'X-CSRFToken': getCsrfToken(),
      },
      body: JSON.stringify({ username, password }),
    });

    const data = await res.json();

    if (res.ok && data.success) {
      setUser({ username: data.username, role: data.role });
      return { success: true };
    }

    return { success: false, error: data.error || 'Login failed' };
  }, []);

  // ── Step 3: logout() ────────────────────────────────────────────────────
  const logout = useCallback(async () => {
    try {
      await fetch('/api/auth/logout/', {
        method: 'POST',
        credentials: 'include',
        headers: {
          'Content-Type': 'application/json',
          'X-CSRFToken': getCsrfToken(),
        },
      });
    } catch (_) {
      // Even if the request fails, clear the local state
    }
    setUser(null);
  }, []);

  return (
    <AuthContext.Provider value={{ user, loading, login, logout }}>
      {children}
    </AuthContext.Provider>
  );
}

/** Hook to consume auth context from any component */
export function useAuth() {
  const ctx = useContext(AuthContext);
  if (!ctx) throw new Error('useAuth must be used inside <AuthProvider>');
  return ctx;
}
