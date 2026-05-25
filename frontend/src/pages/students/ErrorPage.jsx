import React from 'react';
import { useLocation, useNavigate } from 'react-router-dom';
import './ErrorPage.css';

export default function ErrorPage() {
  const loc = useLocation();
  const navigate = useNavigate();
  // Accept an error message passed via location.state or query params
  const message = loc.state?.message || new URLSearchParams(loc.search).get('message') || 'An unexpected error occurred.';
  const code = loc.state?.code || new URLSearchParams(loc.search).get('code') || '';

  return (
    <div className="error-page">
      <div className="error-card">
        <div className="error-code">{code ? `Error ${code}` : 'Error'}</div>
        <div className="error-message">{message}</div>
        <div className="error-actions">
          <button className="btn-primary" onClick={() => navigate(-1)}>Go Back</button>
          <button className="btn-secondary" onClick={() => navigate('/erp-dashboard')}>Dashboard</button>
        </div>
      </div>
    </div>
  );
}
