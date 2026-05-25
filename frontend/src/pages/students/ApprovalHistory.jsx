import React, { useEffect, useState } from 'react';
import { useParams, useLocation, Link } from 'react-router-dom';
import { fetchJson } from '../../api/fetchClient';
import './ApprovalHistory.css';

function ApprovalTimelineItem({ event }) {
  if (!event) return null;

  const status = (event.approval_status || '').toLowerCase();
  const borderColor = status === 'approved' ? '#28a745' : status === 'rejected' ? '#dc3545' : '#ffc107';

  return (
    <div
      className="timeline-item"
      style={{
        marginBottom: 20,
        padding: 16,
        background: 'white',
        border: '1px solid #e5e7eb',
        borderRadius: 10,
        borderLeft: `4px solid ${borderColor}`
      }}
    >
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'start', marginBottom: 12 }}>
        <div>
          <h4 style={{ margin: '0 0 4px 0', color: '#0f172a' }}>
            <span className={`status-badge status-${status}`} style={{ padding: '4px 8px', fontSize: 11 }}>
              {(event.approval_status || '').toUpperCase()}
            </span>
          </h4>
          <p style={{ margin: '4px 0', color: '#6b7280', fontSize: 13 }}>
            <strong>Approved By:</strong> {event.approved_by}
          </p>
        </div>
        <div style={{ textAlign: 'right', color: '#6b7280', fontSize: 13 }}>
          {event.approved_date}
        </div>
      </div>

      {event.remarks ? (
        <div style={{ background: '#f3f4f6', padding: 10, borderRadius: 6, marginTop: 10 }}>
          <p style={{ margin: 0, color: '#374151', fontSize: 13, lineHeight: 1.5 }}>
            <strong>Remarks:</strong> {event.remarks}
          </p>
        </div>
      ) : null}
    </div>
  );
}

export default function ApprovalHistory() {
  const { id } = useParams();
  const location = useLocation();
  const [student, setStudent] = useState(null);
  const [history, setHistory] = useState([]);
  const [loading, setLoading] = useState(true);
  const page = new URLSearchParams(location.search).get('page');

  useEffect(() => {
    let mounted = true;
    setLoading(true);

    const studentUrl = `api/students/${id}/`;
    const historyUrl = `api/students/${id}/history/`;

    Promise.allSettled([fetchJson(studentUrl), fetchJson(historyUrl)])
      .then((results) => {
        if (!mounted) return;
        const [studentRes, historyRes] = results;
        if (studentRes.status === 'fulfilled') {
          const studentData = studentRes.value.student || studentRes.value;
          setStudent(studentData);
          if (!historyRes || historyRes.status !== 'fulfilled') {
            const maybeHistory = studentData.history || studentData.approval_history || [];
            setHistory(maybeHistory);
          }
        }
        if (historyRes && historyRes.status === 'fulfilled') {
          setHistory(historyRes.value);
        }
      })
      .catch((e) => {
        console.error(e);
      })
      .finally(() => {
        if (mounted) setLoading(false);
      });

    return () => {
      mounted = false;
    };
  }, [id]);

  if (loading) {
    return <div className="history-container">Loading...</div>;
  }

  const statusClass = (student?.approval_status || '').toLowerCase();

  return (
    <div className="history-container">
      <h2 style={{ marginBottom: 20, color: '#0f172a' }}>Approval History for {student?.name || 'Student'}</h2>

      <div style={{ background: '#f8f9fa', padding: 16, marginBottom: 24, borderRadius: 10, border: '1px solid #e9ecef' }}>
        <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 16 }}>
          <div>
            <p style={{ margin: '4px 0', fontSize: 13, color: '#6b7280' }}><strong>Email:</strong></p>
            <p style={{ margin: '8px 0', color: '#0f172a' }}>{student?.email}</p>
          </div>
          <div>
            <p style={{ margin: '4px 0', fontSize: 13, color: '#6b7280' }}><strong>Phone:</strong></p>
            <p style={{ margin: '8px 0', color: '#0f172a' }}>{student?.phone}</p>
          </div>
          <div>
            <p style={{ margin: '4px 0', fontSize: 13, color: '#6b7280' }}><strong>Course:</strong></p>
            <p style={{ margin: '8px 0', color: '#0f172a' }}>{student?.course}</p>
          </div>
          <div>
            <p style={{ margin: '4px 0', fontSize: 13, color: '#6b7280' }}><strong>Current Status:</strong></p>
            <p style={{ margin: '8px 0' }}>
              <span className={`status-badge status-${statusClass}`}>{(student?.approval_status || '').toUpperCase()}</span>
            </p>
          </div>
        </div>
      </div>

      {history && history.length > 0 ? (
        <div className="timeline">
          {history.map((event) => (
            <ApprovalTimelineItem key={event.id || event.approved_date || Math.random()} event={event} />
          ))}
        </div>
      ) : (
        <div style={{ background: '#fef3c7', border: '1px solid #fcd34d', color: '#92400e', padding: 16, borderRadius: 10, textAlign: 'center' }}>
          <p>No approval history available for this student.</p>
        </div>
      )}

      <div style={{ marginTop: 24, display: 'flex', gap: 10, justifyContent: 'center' }}>
        <Link to={`/students/${student?.id ?? id}/edit${page ? `?page=${page}` : ''}`} className="btn btn-primary">Edit Student</Link>
        <Link to={`/students${page ? `?page=${page}` : ''}`} className="btn btn-info">Back to List</Link>
      </div>
    </div>
  );
}
