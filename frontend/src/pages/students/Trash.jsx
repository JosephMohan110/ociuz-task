import React, { useEffect, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { fetchJson } from '../../api/fetchClient';
import './Trash.css';

export default function Trash() {
  const navigate = useNavigate();
  const [deletedStudents, setDeletedStudents] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const [restoreTarget, setRestoreTarget] = useState(null);
  const [restoring, setRestoring] = useState(false);

  useEffect(() => {
    let mounted = true;
    setLoading(true);
    setError('');

    fetchJson('api/students/deleted/')
      .then((res) => {
        if (!mounted) return;
        setDeletedStudents(res?.data ?? res ?? []);
      })
      .catch((err) => {
        if (!mounted) return;
        console.error(err);
        setError('Unable to load deleted students.');
      })
      .finally(() => {
        if (mounted) setLoading(false);
      });

    return () => {
      mounted = false;
    };
  }, []);

  async function handleRestore() {
    if (!restoreTarget) return;
    setRestoring(true);
    setError('');

    try {
      const response = await fetchJson(`api/students/${restoreTarget.id}/restore/`, {
        method: 'POST',
      });
      if (response && response.success) {
        setDeletedStudents((current) => current.filter((item) => item.id !== restoreTarget.id));
        setRestoreTarget(null);
      } else {
        setError(response.data?.message || 'Failed to restore student.');
      }
    } catch (err) {
      console.error(err);
      setError('Failed to restore student. Please try again.');
    } finally {
      setRestoring(false);
    }
  }

  return (
    <div className="trash-page">
      <div className="archive-header">
        <div>
          <h2>🗑️ Deleted Students Archive</h2>
          <p className="archive-subtitle">
            Records shown here are soft-deleted and can be restored back to the active list.
          </p>
        </div>
        <button type="button" className="btn btn-info" onClick={() => navigate('/students')}>
          ← Back to Active List
        </button>
      </div>

      <div className="alert alert-warning">
        <strong>Note:</strong> Deleted records are kept for recovery and audit, then can be restored.
      </div>

      {error && <div className="alert alert-error">{error}</div>}

      {loading ? (
        <div className="loading-text">Loading deleted students...</div>
      ) : deletedStudents.length === 0 ? (
        <div className="empty-state">
          <span className="empty-icon">📂</span>
          <h3>No Deleted Students</h3>
          <p>The trash is currently empty.</p>
        </div>
      ) : (
        <div className="table-wrapper">
          <table className="deleted-table">
            <thead>
              <tr>
                <th>ID</th>
                <th>Name</th>
                <th>Email</th>
                <th>Deleted By</th>
                <th>Deleted Date</th>
                <th>Actions</th>
              </tr>
            </thead>
            <tbody>
              {deletedStudents.map((student) => (
                <tr key={student.id}>
                  <td>{student.id}</td>
                  <td className="student-name">{student.name}</td>
                  <td>{student.email}</td>
                  <td>{student.deleted_by || '—'}</td>
                  <td>{student.deleted_date ? new Date(student.deleted_date).toLocaleString() : '—'}</td>
                  <td>
                    <button type="button" className="btn btn-success" onClick={() => setRestoreTarget(student)}>
                      ↻ Restore
                    </button>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}

      <div className={`modal-overlay ${restoreTarget ? 'show' : ''}`} onClick={() => setRestoreTarget(null)}>
        <div className="modal-card" onClick={(event) => event.stopPropagation()}>
          <div className="modal-icon">♻️</div>
          <h3>Confirm Restore</h3>
          <p>
            Are you sure you want to restore <strong>{restoreTarget?.name}</strong>?
          </p>
          <div className="modal-note">
            This student will be moved out of the trash and back to the active list.
          </div>
          <div className="modal-actions">
            <button type="button" className="btn btn-info" onClick={() => setRestoreTarget(null)}>
              Cancel
            </button>
            <button type="button" className="btn btn-success" onClick={handleRestore} disabled={restoring}>
              {restoring ? 'Restoring…' : 'Yes, Restore'}
            </button>
          </div>
        </div>
      </div>
    </div>
  );
}
