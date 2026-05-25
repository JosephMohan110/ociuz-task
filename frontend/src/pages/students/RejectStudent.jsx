import React, { useEffect, useState } from 'react';
import { useNavigate, useParams, useLocation } from 'react-router-dom';
import { fetchJson } from '../../api/fetchClient';
import './RejectStudent.css';

export default function RejectStudent(){
  const { id } = useParams();
  const navigate = useNavigate();
  const loc = useLocation();
  const [student, setStudent] = useState(null);
  const [remarks, setRemarks] = useState(loc.state?.remarks || '');
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');

  // preserve optional page query param
  const query = new URLSearchParams(loc.search);
  const page = query.get('page') || '';

  useEffect(() => {
    let mounted = true;
    setLoading(true);
    fetchJson(`api/students/${id}/`)
      .then(res => { if(!mounted) return; setStudent(res.student ?? res.data ?? res ?? null); })
      .catch(err => { console.error(err); if(!mounted) return; setError('Failed to load student'); })
      .finally(() => mounted && setLoading(false));
    return () => { mounted = false; };
  }, [id]);

  const handleReject = (e) => {
    e.preventDefault();
    setLoading(true);
    setError('');
    fetchJson(`api/students/${id}/reject/`, {
      method: 'POST',
      body: { remarks, page },
    })
      .then(() => {
        // navigate back to list; preserve page if present
        const target = page ? `/students?page=${page}` : '/students';
        navigate(target, { replace: true });
      })
      .catch(err => { console.error(err); setError('Reject action failed'); })
      .finally(() => setLoading(false));
  };

  if(loading && !student) return <div className="empty-state">Loading...</div>;
  if(error && !student) return <div className="alert alert-error">{error}</div>;

  return (
    <div className="form-card" style={{ textAlign: 'center' }}>
      <h2 style={{ color: '#dc3545' }}>Confirm Rejection</h2>

      <p>Are you sure you want to <strong>REJECT</strong> <strong>{student?.name}</strong>?</p>

      <div className="student-summary">
        <p><strong>Phone:</strong> {student?.phone}</p>
        <p><strong>Email:</strong> {student?.email}</p>
        <p><strong>Course:</strong> {student?.course_name ?? student?.course}</p>
        <p><strong>Current Status:</strong> {(student?.approval_status || '').toUpperCase()}</p>
      </div>

      <form onSubmit={handleReject} style={{ textAlign: 'left', maxWidth: 640, margin: '18px auto 0' }}>
        <div className="form-group">
          <label htmlFor="remarks"><strong>Rejection Remarks</strong> (optional)</label>
          <textarea id="remarks" name="remarks" rows={3} className="form-control" placeholder="Add a note for this rejection..." value={remarks} onChange={(e) => setRemarks(e.target.value)} />
        </div>

        <div className="actions">
          <button type="submit" className="btn btn-warning">{loading ? 'Rejecting…' : 'Yes, Reject'}</button>
          <button type="button" className="btn btn-info" onClick={() => navigate(page ? `/students?page=${page}` : '/students')}>Cancel</button>
        </div>

        {error && <div className="alert alert-error" style={{ marginTop: 12 }}>{error}</div>}
      </form>
    </div>
  );
}
