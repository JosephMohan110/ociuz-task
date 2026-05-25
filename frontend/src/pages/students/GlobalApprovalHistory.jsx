import React, { useEffect, useState } from 'react';
import { Link } from 'react-router-dom';
import { fetchJson } from '../../api/fetchClient';
import './GlobalApprovalHistory.css';

export default function GlobalApprovalHistory() {
  const [search, setSearch] = useState('');
  const [action, setAction] = useState('');
  const [dateFrom, setDateFrom] = useState('');
  const [dateTo, setDateTo] = useState('');
  const [logs, setLogs] = useState([]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');

  const fetchLogs = (params = {}) => {
    setLoading(true);
    setError('');
    fetchJson('api/v1/global-approval-history/', { params })
      .then((res) => {
        // Response structure: { success, message, data: [...logs] }
        setLogs(Array.isArray(res?.data) ? res.data : (Array.isArray(res) ? res : []));
      })
      .catch((err) => {
        console.error(err);
        setError('Unable to fetch approval history');
      })
      .finally(() => setLoading(false));
  };

  useEffect(() => {
    // initial load
    fetchLogs({ q: search, action, date_from: dateFrom, date_to: dateTo });
  }, []);

  const handleFilter = (e) => {
    e.preventDefault();
    fetchLogs({ q: search, action, date_from: dateFrom, date_to: dateTo });
  };

  return (
    <div>
      <div className="archive-header">
        <div style={{ display: 'flex', alignItems: 'center', gap: 12 }}>
          <span style={{ fontSize: 26 }}>📋</span>
          <h2 style={{ color: '#0f172a', margin: 0 }}>System Approval History</h2>
        </div>
        <Link to="/students" className="btn btn-info">← Back to Dashboard</Link>
      </div>

      <div className="filter-bar">
        <form onSubmit={handleFilter} className="filter-form">
          <div className="filter-field">
            <label>Search Student</label>
            <input value={search} onChange={(e) => setSearch(e.target.value)} placeholder="Name..." />
          </div>

          <div className="filter-field">
            <label>Action Filter</label>
            <select value={action} onChange={(e) => setAction(e.target.value)}>
              <option value="">All Actions</option>
              <option value="APPROVE">Approve</option>
              <option value="REJECT">Reject</option>
              <option value="STATUS_PENDING">Pending</option>
            </select>
          </div>

          <div className="filter-field">
            <label>Date From</label>
            <input type="date" value={dateFrom} onChange={(e) => setDateFrom(e.target.value)} />
          </div>

          <div className="filter-field">
            <label>Date To</label>
            <input type="date" value={dateTo} onChange={(e) => setDateTo(e.target.value)} />
          </div>

          <div className="filter-actions">
            <button className="btn btn-primary" type="submit">Filter</button>
            <button type="button" className="btn btn-outline" onClick={() => { setSearch(''); setAction(''); setDateFrom(''); setDateTo(''); fetchLogs({}); }}>Clear</button>
          </div>
        </form>
      </div>

      <div className="table-wrap">
        {loading ? (
          <div className="empty-state">Loading...</div>
        ) : error ? (
          <div className="alert alert-error">{error}</div>
        ) : logs.length === 0 ? (
          <div className="empty-state">No Audit Records Found</div>
        ) : (
          <table className="audit-table">
            <thead>
              <tr>
                <th>Date & Time</th>
                <th>Student Name</th>
                <th>Action Taken</th>
                <th>Status Change</th>
                <th>Performed By</th>
                <th>Remarks</th>
              </tr>
            </thead>
            <tbody>
              {logs.map((log, idx) => (
                <tr key={idx}>
                  <td className="muted">{log.performed_date}</td>
                  <td className="strong">{log.student_name}</td>
                  <td><span className={`status-badge status-${(log.action||'').toLowerCase()}`}>{log.action}</span></td>
                  <td className="muted"><span className="strike">{log.old_status}</span> <span className="arrow">→</span> <strong>{log.new_status}</strong></td>
                  <td>{log.performed_by}</td>
                  <td className="remarks" title={log.remarks}>{log.remarks || '—'}</td>
                </tr>
              ))}
            </tbody>
          </table>
        )}
      </div>
    </div>
  );
}
