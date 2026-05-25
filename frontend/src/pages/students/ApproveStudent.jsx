import React, { useEffect, useState } from 'react';
import { useNavigate, useParams, useLocation } from 'react-router-dom';
import { fetchJson } from '../../api/fetchClient';
import './ApproveStudent.css';

export default function ApproveStudent() {
  const { id } = useParams();
  const location = useLocation();
  const navigate = useNavigate();
  const [student, setStudent] = useState(null);
  const [remarks, setRemarks] = useState('');
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');

  const page = new URLSearchParams(location.search).get('page');

  useEffect(() => {
    let mounted = true;
    setLoading(true);
    fetchJson(`api/students/${id}/`)
      .then((res) => {
        if (!mounted) return;
        setStudent(res.student || res);
      })
      .catch((err) => {
        if (!mounted) return;
        setError('Unable to load student details.');
        console.error(err);
      })
      .finally(() => {
        if (mounted) setLoading(false);
      });

    return () => {
      mounted = false;
    };
  }, [id]);

  async function handleSubmit(event) {
    event.preventDefault();
    setError('');

    try {
      await fetchJson(`api/students/${id}/approve/`, {
        method: 'POST',
        body: { remarks, page },
      });
      navigate(`/students${page ? `?page=${page}` : ''}`);
    } catch (err) {
      console.error(err);
      setError('Failed to approve student. Please try again.');
    }
  }

  if (loading) {
    return <div className="form-card">Loading student details...</div>;
  }

  return (
    <div className="form-card" style={{ textAlign: 'center' }}>
      <h2 className="approve-title">Confirm Approval</h2>

      <p>
        Are you sure you want to <strong>APPROVE</strong> <strong>{student?.name}</strong>?
      </p>

      <div className="student-summary-box">
        <p><strong>Phone:</strong> {student?.phone}</p>
        <p><strong>Email:</strong> {student?.email}</p>
        <p><strong>Course:</strong> {student?.course}</p>
        <p><strong>Current Status:</strong> {student?.approval_status?.toUpperCase()}</p>
      </div>

      <form onSubmit={handleSubmit} className="approve-form">
        <div className="form-group">
          <label htmlFor="remarks">
            <strong>Approval Remarks</strong> (optional)
          </label>
          <textarea
            id="remarks"
            name="remarks"
            rows="3"
            className="form-control"
            placeholder="Add a note for this approval..."
            value={remarks}
            onChange={(e) => setRemarks(e.target.value)}
          />
        </div>

        {error && <div className="error-alert">{error}</div>}

        <div className="action-row">
          <button type="submit" className="btn btn-success">
            Yes, Approve
          </button>
          <button
            type="button"
            className="btn btn-info"
            onClick={() => navigate(`/students${page ? `?page=${page}` : ''}`)}
          >
            Cancel
          </button>
        </div>
      </form>
    </div>
  );
}
