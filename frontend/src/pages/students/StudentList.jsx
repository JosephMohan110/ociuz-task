import { useEffect, useMemo, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { fetchJson } from '../../api/fetchClient';
import { useAuth } from '../../context/AuthContext';
import './StudentList.css';

const PAGE_SIZE = 5;

// ─── Status display helpers (data-driven from DB color codes) ───────────────
const STATUS_DEFAULTS = {
  DRAFT:    '#6c757d',
  PENDING:  '#ffc107',
  APPROVED: '#198754',
  REJECTED: '#dc3545',
};

function StatusBadge({ code, colorCode }) {
  const upper = (code || '').toUpperCase();
  const label = upper.charAt(0) + upper.slice(1).toLowerCase();
  const bg    = colorCode || STATUS_DEFAULTS[upper] || '#6c757d';
  const textColor = ['PENDING', 'DRAFT', 'CANCELLED'].includes(upper) ? '#333' : '#fff';
  return (
    <span
      className="status-badge"
      style={{ background: bg, color: textColor, fontWeight: 700 }}
      title={`Status: ${label}`}
    >
      {label}
    </span>
  );
}

// ─── Workflow button (uses color from DB) ────────────────────────────────────

function WorkflowBtn({ action, onClick }) {
  const bg = action.color_code || '#0d6efd';
  const textC = action.action_name === 'Reject' ? '#fff' : (bg === '#ffc107' ? '#333' : '#fff');
  return (
    <button
      type="button"
      className="btn workflow-action-btn"
      style={{ background: bg, color: textC, border: 'none' }}
      onClick={() => onClick(action)}
      title={`${action.action_name} → ${action.next_status_code}`}
    >
      {action.action_name}
    </button>
  );
}

function StudentList() {
  const navigate = useNavigate();
  const { user } = useAuth();                  // ← get logged-in username from session

  const [students, setStudents]           = useState([]);
  const [search, setSearch]               = useState('');
  const [currentPage, setCurrentPage]     = useState(1);
  const [workflowActions, setWorkflowActions] = useState({});
  const [modal, setModal] = useState({ open: false, student: null, action: null, error: '', confirming: false });
  const [loading, setLoading]             = useState(false);

  // ── Fetch student list ─────────────────────────────────────────────────────
  const fetchStudents = async (query = '') => {
    setLoading(true);
    try {
      const res = await fetchJson('api/students/', { params: { search: query } });
      setStudents(res.students || []);
      setCurrentPage(1);
    } catch (err) {
      console.error('Failed to load students', err);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => { fetchStudents(); }, []);

  // ── Live search suggestions ───────────────────────────────────────────────
  useEffect(() => {
    const timeout = setTimeout(() => {
      fetchStudents(search.trim());
    }, 250);
    return () => clearTimeout(timeout);
  }, [search]);

  // ── Fetch available workflow actions for each student ─────────────────────
  // Called after students list is loaded.
  // fnGetAvailableActions(doc_code, status_code, role) returns buttons from DB.
  useEffect(() => {
    if (!students.length) { setWorkflowActions({}); return; }

    const fetchActions = async () => {
      const map = {};
      await Promise.all(students.map(async (student) => {
        // approval_status comes from students.status column (e.g., 'DRAFT', 'PENDING')
        const statusCode = (student.approval_status || 'DRAFT').toUpperCase();
        try {
          const res = await fetchJson('api/v1/workflow-config/', {
            params: {
              doc_code: 'STUDENT_ADM',
              status:   statusCode,
              role:     user?.role || 'Manager',
            }
          });
          // Normalize response — API returns { success, data: [...] }
          const raw = res?.data ?? res;
          const arr = Array.isArray(raw) ? raw : (raw ? [raw] : []);
          map[student.id] = arr.filter(Boolean);
        } catch (err) {
          map[student.id] = [];
          console.error('Workflow config fetch failed for student', student.id, err);
        }
      }));
      setWorkflowActions(map);
    };

    fetchActions();
  }, [students]);

  // ── Pagination ─────────────────────────────────────────────────────────────
  const filteredStudents = useMemo(() => students, [students]);
  const totalPages = Math.max(1, Math.ceil(filteredStudents.length / PAGE_SIZE));

  useEffect(() => {
    if (currentPage > totalPages) setCurrentPage(1);
  }, [currentPage, totalPages]);

  const currentRows = useMemo(() => {
    const start = (currentPage - 1) * PAGE_SIZE;
    return filteredStudents.slice(start, start + PAGE_SIZE);
  }, [filteredStudents, currentPage]);

  // ── Search handlers ────────────────────────────────────────────────────────
  const handleSearchSubmit = (e) => {
    e.preventDefault();
    fetchStudents(search.trim());
  };

  const handleClearSearch = () => {
    setSearch('');
    fetchStudents('');
  };

  // ── Workflow modal ─────────────────────────────────────────────────────────
  const openModal  = (student, action) => setModal({ open: true, student, action, error: '', confirming: false });
  const closeModal = () => setModal({ open: false, student: null, action: null, error: '', confirming: false });

  const handleWorkflowConfirm = async () => {
    if (!modal.student || !modal.action) return;
    setModal((prev) => ({ ...prev, error: '', confirming: true }));

    try {
      // username comes from AuthContext (Django session), not hardcoded
      const performedBy = user?.username || 'Admin';

      const res = await fetchJson('api/v1/workflow/process/', {
        method: 'POST',
        body: {
          doc_code:       'STUDENT_ADM',
          record_id:      modal.student.id,
          current_status: (modal.student.approval_status || 'DRAFT').toUpperCase(),
          action_name:    modal.action.action_name,
          role:           user?.role || 'Manager',
          username:       performedBy,
          remarks:        `${modal.action.action_name} via Student List — by ${performedBy}`,
        },
      });

      if (res && res.success) {
        closeModal();
        fetchStudents(search.trim());   // refresh table with new status
      } else {
        setModal((prev) => ({ ...prev, error: res?.message || 'Action rejected.', confirming: false }));
      }
    } catch (err) {
      console.error('Workflow process failed', err);
      const message = err?.message || 'Unable to process the workflow action.';
      setModal((prev) => ({ ...prev, error: message, confirming: false }));
    }
  };

  // ── Page numbers ───────────────────────────────────────────────────────────
  const buildPageNumbers = () => {
    const pages = [];
    for (let n = 1; n <= totalPages; n++) {
      if (n === 1 || n === totalPages || (n >= currentPage - 2 && n <= currentPage + 2)) {
        pages.push(n);
      } else if (pages[pages.length - 1] !== '...') {
        pages.push('...');
      }
    }
    return pages;
  };

  // ── Render ─────────────────────────────────────────────────────────────────
  return (
    <div>
      {/* ── Search Bar ─────────────────────────────────────────────────────── */}
      <div className="search-container">
        <form className="search-box" onSubmit={handleSearchSubmit}>
          <div className="search-input-wrap">
            <input
              type="text"
              placeholder="Search by name, phone, email, course..."
              value={search}
              onChange={(e) => setSearch(e.target.value)}
              className="search-input"
              autoComplete="off"
            />
          </div>
          <button type="submit" className="btn btn-primary">Search</button>
          {search && (
            <button type="button" className="btn btn-info" onClick={handleClearSearch}>Clear</button>
          )}
        </form>
        <div id="resultsInfo" className={`results-info ${students.length > 0 ? 'show' : ''}`}>
          {students.length} result{students.length !== 1 ? 's' : ''} for "{search || 'all'}"
        </div>
      </div>

      {/* ── Student Table ───────────────────────────────────────────────────── */}
      <div className="table-wrap">
        {loading ? (
          <div className="empty-state">Loading students...</div>
        ) : currentRows.length === 0 ? (
          <div className="empty-state">
            No students found.{' '}
            <button className="link-button" onClick={() => navigate('/students/add')}>Add a student</button>
          </div>
        ) : (
          <table className="students-table">
            <thead>
              <tr>
                <th>#</th>
                <th>Photo</th>
                <th>Name</th>
                <th>Phone</th>
                <th>Email</th>
                <th>Course</th>
                <th>Status</th>
                <th>By</th>
                <th>Actions</th>
              </tr>
            </thead>
            <tbody>
              {currentRows.map((student, index) => (
                <tr
                  key={student.id}
                  className="workflow-row"
                  data-doc="STUDENT_ADM"
                  data-status={student.approval_status}
                  data-id={student.id}
                >
                  <td>{(currentPage - 1) * PAGE_SIZE + index + 1}</td>
                  <td>
                    {student.student_image
                      ? <img src={`/media/${student.student_image}`} alt={student.name} className="student-thumb" />
                      : <span className="student-thumb placeholder">No img</span>
                    }
                  </td>
                  <td>
                    <div style={{ fontWeight: 600 }}>{student.name}</div>
                    {student.document_number && (
                      <div style={{ fontSize: 11, color: '#64748b' }}>#{student.document_number}</div>
                    )}
                  </td>
                  <td>{student.phone}</td>
                  <td>{student.email}</td>
                  <td>
                    {student.course || 'Not assigned'}
                    {student.course_code ? ` (${student.course_code})` : ''}
                  </td>
                  <td><StatusBadge code={student.approval_status} colorCode={student.status_color} /></td>
                  <td style={{ fontSize: 12, color: '#64748b' }}>{student.approved_by || '—'}</td>
                  <td>
                    {/* ── Standard row actions ── */}
                    <div className="action-buttons">
                      <button
                        type="button"
                        className="btn btn-primary"
                        onClick={() => navigate(`/students/${student.id}/edit?page=${currentPage}`)}
                      >Edit</button>
                      <button
                        type="button"
                        className="btn btn-danger"
                        onClick={() => navigate(`/students/${student.id}/delete?page=${currentPage}`)}
                      >Delete</button>
                      <button
                        type="button"
                        className="btn btn-info"
                        onClick={() => navigate(`/students/${student.id}/approval-history?page=${currentPage}`)}
                      >History</button>
                    </div>

                    {/* ── Workflow action buttons (from DB, dynamic) ── */}
                    <div className="workflow-actions-container">
                      {(workflowActions[student.id] || []).length > 0 && (
                        workflowActions[student.id].map((action, i) => (
                          <WorkflowBtn
                            key={`${action.action_name}-${i}`}
                            action={action}
                            onClick={(a) => openModal(student, a)}
                          />
                        ))
                      )}
                    </div>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        )}
      </div>

      {/* ── Pagination ─────────────────────────────────────────────────────── */}
      {filteredStudents.length > 0 && (
        <div className="pagination-container">
          <div className="pagination-info">
            Showing <strong>{(currentPage - 1) * PAGE_SIZE + 1}</strong>–<strong>{Math.min(currentPage * PAGE_SIZE, filteredStudents.length)}</strong> of <strong>{filteredStudents.length}</strong> students
          </div>
          <div className="pagination">
            <button className="btn btn-outline" onClick={() => setCurrentPage(1)} disabled={currentPage === 1}>⏮ First</button>
            <button className="btn btn-outline" onClick={() => setCurrentPage((p) => Math.max(p - 1, 1))} disabled={currentPage === 1}>« Prev</button>
            {buildPageNumbers().map((page, idx) => (
              <button
                key={`${page}-${idx}`}
                className={`btn ${page === currentPage ? 'btn-active' : 'btn-outline'}`}
                onClick={() => typeof page === 'number' && setCurrentPage(page)}
                disabled={page === '...'}
              >{page}</button>
            ))}
            <button className="btn btn-outline" onClick={() => setCurrentPage((p) => Math.min(p + 1, totalPages))} disabled={currentPage === totalPages}>Next »</button>
            <button className="btn btn-outline" onClick={() => setCurrentPage(totalPages)} disabled={currentPage === totalPages}>Last ⏭</button>
          </div>
        </div>
      )}

      {/* ── Workflow Confirmation Modal ─────────────────────────────────────── */}
      {modal.open && (
        <div className="custom-modal-overlay" onClick={closeModal}>
          <div
            className="modal-content"
            role="dialog"
            aria-modal="true"
            aria-labelledby="workflowModalTitle"
            onClick={(e) => e.stopPropagation()}
          >
            <h3 id="workflowModalTitle">Confirm Workflow Action</h3>

            {/* Workflow sequence hint */}
            <div className="workflow-sequence-hint">
              <StatusBadge code={modal.student?.approval_status} colorCode={modal.student?.status_color} />
              <span style={{ margin: '0 8px', fontWeight: 700 }}>→</span>
              <span
                className="status-badge"
                style={{ background: modal.action?.color_code || '#0d6efd', color: '#fff', fontWeight: 700 }}
              >
                {modal.action?.next_status_code?.charAt(0)}{modal.action?.next_status_code?.slice(1).toLowerCase()}
              </span>
            </div>

            <p style={{ margin: '14px 0 6px' }}>
              Execute <strong>"{modal.action?.action_name}"</strong> for student <strong>{modal.student?.name}</strong>?
            </p>
            <p style={{ fontSize: 13, color: '#64748b', margin: '0 0 14px' }}>
              Performed by: <strong>{user?.username || 'Admin'}</strong>
            </p>

            {modal.error && <div className="modal-error">{modal.error}</div>}

            <div className="modal-actions">
              <button
                type="button"
                className="btn btn-secondary"
                onClick={closeModal}
                disabled={modal.confirming}
              >Cancel</button>
              <button
                type="button"
                className="btn btn-success"
                onClick={handleWorkflowConfirm}
                disabled={modal.confirming}
              >
                {modal.confirming ? 'Processing…' : `Yes, ${modal.action?.action_name}`}
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}

export default StudentList;
