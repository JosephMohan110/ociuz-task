import { useEffect, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { fetchJson } from '../../api/fetchClient';
import { useAuth } from '../../context/AuthContext';
import './LeaveList.css';

const LeaveList = () => {
  const { user } = useAuth();
  const [leaves, setLeaves] = useState([]);
  const [workflowActions, setWorkflowActions] = useState({});
  const [selectedAction, setSelectedAction] = useState(null);
  const [workflowError, setWorkflowError] = useState('');
  const [modalOpen, setModalOpen] = useState(false);
  const [loading, setLoading] = useState(true);
  const [actionLoading, setActionLoading] = useState(false);
  const navigate = useNavigate();

  const fetchLeaves = async () => {
    setLoading(true);
    try {
      const response = await fetchJson('api/v1/documents/LEAVE_REQ/');
      // The generic API returns data as a JSON string — parse it
      let raw = response?.data ?? response ?? [];
      if (typeof raw === 'string') {
        try { raw = JSON.parse(raw); } catch { raw = []; }
      }
      setLeaves(Array.isArray(raw) ? raw : []);
    } catch (error) {
      console.error('Failed to fetch leave requests', error);
      setLeaves([]);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchLeaves();
  }, []);

  useEffect(() => {
    if (!leaves.length) {
      setWorkflowActions({});
      return;
    }

    const fetchActions = async () => {
      const map = {};
      await Promise.all(
        leaves.map(async (leave) => {
          try {
            const res = await fetchJson('api/v1/workflow-config/', {
              params: {
                doc_code: 'LEAVE_REQ',
                status: leave.status || 'DRAFT',
                role: user?.role || 'Manager',
              },
            });
            const normalizeToArray = (val) => {
              if (!val && val !== 0) return [];
              if (Array.isArray(val)) return val;
              if (typeof val === 'string') {
                try {
                  const parsed = JSON.parse(val);
                  return Array.isArray(parsed) ? parsed : [parsed];
                } catch (_) {
                  return [val];
                }
              }
              if (typeof val === 'object') return Object.values(val).length ? Object.values(val) : [val];
              return [val];
            };

            const workflowData = normalizeToArray(res?.data ?? res);
            map[leave.id] = workflowData.filter(Boolean);
          } catch (err) {
            map[leave.id] = [];
            console.error('Workflow config fetch failed for leave', leave.id, err);
          }
        })
      );
      setWorkflowActions(map);
    };

    fetchActions();
  }, [leaves]);

  const openModal = (leave, action) => {
    setSelectedAction({ leave, action });
    setWorkflowError('');
    setModalOpen(true);
  };

  const closeModal = () => {
    setModalOpen(false);
    setSelectedAction(null);
  };

  const submitAction = async () => {
    if (!selectedAction) return;
    setActionLoading(true);
    setWorkflowError('');

    try {
      const response = await fetchJson('api/v1/workflow/process/', {
        method: 'POST',
        body: {
          doc_code: 'LEAVE_REQ',
          record_id: selectedAction.leave.id,
          current_status: selectedAction.leave.status,
          action_name: selectedAction.action.action_name,
          role: user?.role || 'Manager',
          username: user?.username || 'AdminUser',
          remarks: 'Processed via frontend leave list',
        },
      });
      const result = response;
      if (result.success) {
        closeModal();
        fetchLeaves();
      } else {
        setWorkflowError(result.message || 'Action rejected by workflow engine.');
      }
    } catch (error) {
      console.error(error);
      const msg = error.response?.data?.message || error.response?.data?.error || 'Unable to process the request. Please try again.';
      setWorkflowError(msg);
    } finally {
      setActionLoading(false);
    }
  };

  return (
    <div className="leave-list-page">
      <div className="archive-header">
        <div className="archive-title">
          <span>✈️</span>
          <h2>Leave Requests</h2>
        </div>
        <button className="btn btn-success" onClick={() => navigate('/leaves/new')}>
          + New Request
        </button>
      </div>

      <div className="table-wrapper">
        {loading ? (
          <div className="empty-state">Loading leave requests...</div>
        ) : (
          <table>
            <thead>
              <tr>
                <th>Doc #</th>
                <th>Employee Name</th>
                <th>Leave Type</th>
                <th>Duration</th>
                <th>Status</th>
                <th>Actions</th>
              </tr>
            </thead>
            <tbody>
              {leaves.length === 0 ? (
                <tr>
                  <td colSpan="6" className="empty-state">
                    No leave requests found.
                  </td>
                </tr>
              ) : (
                leaves.map((leave) => (
                  <tr key={leave.id} className="workflow-row">
                    <td className="doc-number">{leave.document_number}</td>
                    <td>{leave.employee_name}</td>
                    <td>{leave.leave_type}</td>
                    <td className="duration-text">
                      {new Date(leave.start_date).toLocaleDateString('en-US', {
                        month: 'short',
                        day: '2-digit',
                        year: 'numeric',
                      })}{' '}
                      to{' '}
                      {new Date(leave.end_date).toLocaleDateString('en-US', {
                        month: 'short',
                        day: '2-digit',
                        year: 'numeric',
                      })}
                    </td>
                    <td>
                      <span className="status-badge" style={{ backgroundColor: leave.status_color || '#6c757d', color: ['PENDING', 'DRAFT', 'CANCELLED'].includes((leave.status || '').toUpperCase()) ? '#333' : '#fff' }}>
                        {(leave.status || '').toUpperCase()}
                      </span>
                    </td>
                    <td className="dynamic-actions-container" style={{ display: 'flex', gap: '5px' }}>
                      {(workflowActions[leave.id] || []).length > 0 ? (
                        workflowActions[leave.id].map((action, i) => (
                          <button
                            key={`${action.action_name}-${i}`}
                            type="button"
                            className="btn workflow-action-btn"
                            style={{
                              backgroundColor: action.color_code || '#3b82f6',
                              color: 'white',
                              border: 'none',
                              padding: '6px 12px',
                              borderRadius: '4px',
                              cursor: 'pointer',
                              fontSize: '12px',
                              fontWeight: '600',
                            }}
                            onClick={() => openModal(leave, action)}
                          >
                            {action.action_name}
                          </button>
                        ))
                      ) : (
                        <span className="no-actions" style={{ color: '#64748b', fontSize: '12px', fontStyle: 'italic' }}>
                          No actions (Locked)
                        </span>
                      )}
                    </td>
                  </tr>
                ))
              )}
            </tbody>
          </table>
        )}
      </div>

      {modalOpen && selectedAction && (
        <div className="custom-modal-overlay" role="dialog" aria-modal="true" aria-labelledby="workflowModalTitle" onClick={closeModal}>
          <div className="modal-content" onClick={(e) => e.stopPropagation()}>
            <h3 id="workflowModalTitle">Confirm Workflow Action</h3>
            <p>
              Are you sure you want to execute action: "{selectedAction.action.action_name}" for document {selectedAction.leave.document_number}?
            </p>
            {workflowError && <div className="modal-error" style={{ color: '#dc3545', margin: '10px 0', fontSize: '14px' }}>{workflowError}</div>}
            <div className="modal-controls">
              <button type="button" className="btn btn-secondary" onClick={closeModal}>
                Cancel
              </button>
              <button type="button" className="btn btn-success" onClick={submitAction} disabled={actionLoading}>
                {actionLoading ? 'Processing...' : 'Yes, Continue'}
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
};

export default LeaveList;
