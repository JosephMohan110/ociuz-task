import React, { useEffect, useState } from 'react';
import { useNavigate, useParams, useLocation } from 'react-router-dom';
import { fetchJson } from '../../api/fetchClient';
import './DeleteStudent.css';

export default function DeleteStudent() {
  const { id } = useParams();
  const location = useLocation();
  const navigate = useNavigate();
  const [student, setStudent] = useState(null);
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
        console.error(err);
        setError('Unable to load student details.');
      })
      .finally(() => {
        if (mounted) setLoading(false);
      });

    return () => {
      mounted = false;
    };
  }, [id]);

  async function handleDelete(event) {
    event.preventDefault();
    setError('');

    try {
      await fetchJson(`api/students/${id}/delete/`, {
        method: 'POST',
        body: { page },
      });
      navigate(`/students${page ? `?page=${page}` : ''}`);
    } catch (err) {
      console.error(err);
      setError('Failed to delete student. Please try again.');
    }
  }

  if (loading) {
    return <div className="form-card">Loading student details...</div>;
  }

  return (
    <div className="form-card" style={{ textAlign: 'center' }}>
      <h2 className="delete-title">Confirm Delete</h2>

      <p>Are you sure you want to delete <strong>{student?.name}</strong>?</p>

      <div className="student-summary-box">
        <p><strong>Phone:</strong> {student?.phone}</p>
        <p><strong>Email:</strong> {student?.email}</p>
        <p><strong>Course:</strong> {student?.course}</p>
        <p><strong>Status:</strong> {student?.approval_status?.toUpperCase()}</p>
      </div>

      {error && <div className="error-alert">{error}</div>}

      <form onSubmit={handleDelete} className="delete-form">
        <div className="action-row">
          <button type="submit" className="btn btn-danger">Yes, Delete</button>
          <button type="button" className="btn btn-info" onClick={() => navigate(`/students${page ? `?page=${page}` : ''}`)}>
            Cancel
          </button>
        </div>
      </form>
    </div>
  );
}
