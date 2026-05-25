import React, { useState, useEffect } from 'react';
import { useNavigate, Navigate } from 'react-router-dom';
import { useAuth } from '../../context/AuthContext';
import './Login.css';

export default function Login() {
  const [username, setUsername] = useState('');
  const [password, setPassword] = useState('');
  const [error, setError] = useState('');
  const [submitting, setSubmitting] = useState(false);

  const { user, loading, login } = useAuth();
  const navigate = useNavigate();

  // If already authenticated, redirect straight to dashboard
  if (!loading && user) {
    return <Navigate to="/" replace />;
  }

  const handleSubmit = async (e) => {
    e.preventDefault();
    setError('');

    if (!username.trim() || !password.trim()) {
      setError('Both username and password are required.');
      return;
    }

    setSubmitting(true);
    try {
      const result = await login(username.trim(), password.trim());
      if (result.success) {
        navigate('/', { replace: true });
      } else {
        setError(result.error || 'Invalid username or password.');
      }
    } catch (err) {
      setError('Unable to connect. Please try again.');
    } finally {
      setSubmitting(false);
    }
  };

  return (
    <div className="login-page">
      <div className="form-card">
        <h2 className="text-center" style={{ marginBottom: '10px' }}>ERP Login</h2>
        <p className="text-center subtext">Student Management System</p>

        {error && <div className="alert alert-error">{error}</div>}

        <form onSubmit={handleSubmit} noValidate>
          <div className="form-group">
            <label htmlFor="username">Username</label>
            <input
              id="username"
              type="text"
              name="username"
              className="form-input"
              required
              autoComplete="username"
              placeholder="Enter username"
              value={username}
              onChange={(e) => setUsername(e.target.value)}
              disabled={submitting}
            />
          </div>
          <div className="form-group">
            <label htmlFor="password">Password</label>
            <input
              id="password"
              type="password"
              name="password"
              className="form-input"
              required
              placeholder="••••••••"
              value={password}
              onChange={(e) => setPassword(e.target.value)}
              disabled={submitting}
            />
          </div>
          <button
            type="submit"
            className="btn-primary"
            disabled={submitting || loading}
          >
            {submitting ? 'Signing in…' : 'Secure Login'}
          </button>
        </form>
      </div>
    </div>
  );
}
