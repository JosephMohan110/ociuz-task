import React, { useState, useEffect } from 'react';
import './ChatBotLeads.css';

export default function ChatBotLeads() {
  const [leads, setLeads] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);

  useEffect(() => {
    // Initial fetch
    fetchLeads(true);
  }, []);

  const fetchLeads = async (isInitial = false) => {
    try {
      if (isInitial) setLoading(true);
      const response = await fetch('/student/api/v1/chatbot-users/');
      const data = await response.json();
      
      if (data.success) {
        setLeads(data.data || []);
      } else {
        if (isInitial) setError(data.message || 'Failed to fetch leads');
      }
    } catch (err) {
      if (isInitial) setError('Network error or server unavailable');
    } finally {
      if (isInitial) setLoading(false);
    }
  };

  return (
    <div className="chatbot-leads-page">
      <div className="simple-header">
        <div className="header-content">
          <div>
            <h2 className="title-simple">Chatbot User Details</h2>
            <p className="subtitle" style={{color: '#6c757d'}}>Manual Sync Active</p>
          </div>
          <button className="btn-simple-primary" onClick={() => fetchLeads(true)}>
            Refresh Data
          </button>
        </div>
      </div>

      <div className="leads-content">
        {loading ? (
          <div className="simple-state">Loading data...</div>
        ) : error ? (
          <div className="simple-error">{error}</div>
        ) : leads.length === 0 ? (
          <div className="simple-state">No users available in the table. Start chatting to see data here instantly!</div>
        ) : (
          <div className="simple-table-wrapper">
            <table className="simple-table">
              <thead>
                <tr>
                  <th>ID</th>
                  <th>Session ID</th>
                  <th>Name</th>
                  <th>Email</th>
                  <th>Phone</th>
                  <th>Status</th>
                  <th>Created At</th>
                </tr>
              </thead>
              <tbody>
                {leads.map((lead) => (
                  <tr key={lead.id}>
                    <td>{lead.id}</td>
                    <td>{lead.session_id}</td>
                    <td>{lead.name}</td>
                    <td>{lead.email}</td>
                    <td>{lead.phone}</td>
                    <td>{lead.status}</td>
                    <td>{lead.created_at ? new Date(lead.created_at).toLocaleString() : '-'}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </div>
    </div>
  );
}
