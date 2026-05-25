import { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { fetchJson } from '../../api/fetchClient';
import './Leave.css';

const Leave = () => {
  const navigate = useNavigate();
  const [formData, setFormData] = useState({
    employee_name: '',
    leave_type: '',
    start_date: '',
    end_date: '',
    reason: '',
  });
  const [error, setError] = useState('');
  const [submitting, setSubmitting] = useState(false);

  const [showSuccessModal, setShowSuccessModal] = useState(false);

  const handleChange = (event) => {
    const { name, value } = event.target;
    setFormData((prev) => ({ ...prev, [name]: value }));
  };

  const handleSubmit = async (event) => {
    event.preventDefault();
    setError('');

    if (new Date(formData.start_date) > new Date(formData.end_date)) {
      setError('Start date cannot be after end date.');
      return;
    }

    setSubmitting(true);
    try {
      const response = await fetchJson('api/v1/documents/LEAVE_REQ/', {
        method: 'POST',
        body: formData,
      });
      if (response && response.success) {
        setShowSuccessModal(true);
      } else {
        setError(response?.message || 'Failed to submit leave request.');
      }
    } catch (err) {
      console.error(err);
      const msg = err.response?.data?.message || err.response?.data?.error || 'Failed to submit leave request. Please check the dates and try again.';
      setError(msg);
    } finally {
      setSubmitting(false);
    }
  };

  return (
    <div className="leave-page">
      <div className="form-container">
        <div className="form-header">
          <span>✈️</span>
          <h2>Submit New Leave Request</h2>
        </div>

        {error && (
          <div className="alert alert-error" style={{ background: '#fef2f2', border: '1px solid #fca5a5', color: '#b91c1c', padding: 12, borderRadius: 6, marginBottom: 16, fontSize: 14 }}>
            {error}
          </div>
        )}

        <form onSubmit={handleSubmit} className="leave-form">
          <div className="field-group">
            <label>Employee Name</label>
            <input
              type="text"
              name="employee_name"
              value={formData.employee_name}
              onChange={handleChange}
              required
            />
          </div>

          <div className="field-group">
            <label>Leave Type</label>
            <select
              name="leave_type"
              value={formData.leave_type}
              onChange={handleChange}
              required
            >
              <option value="" disabled>
                -- Select Leave Type --
              </option>
              <option value="Casual Leave">Casual Leave</option>
              <option value="Medical Leave">Medical Leave</option>
              <option value="Earned Leave">Earned Leave</option>
              <option value="Maternity Leave">Maternity Leave</option>
            </select>
          </div>

          <div className="date-row">
            <div className="field-group">
              <label>Start Date</label>
              <input
                type="date"
                name="start_date"
                value={formData.start_date}
                onChange={handleChange}
                required
              />
            </div>
            <div className="field-group">
              <label>End Date</label>
              <input
                type="date"
                name="end_date"
                value={formData.end_date}
                onChange={handleChange}
                required
              />
            </div>
          </div>

          <div className="field-group">
            <label>Reason for Leave</label>
            <textarea
              name="reason"
              rows="4"
              value={formData.reason}
              onChange={handleChange}
              required
            />
          </div>

          <div className="button-row">
            <button
              type="button"
              className="cancel-button"
              onClick={() => navigate('/leaves')}
            >
              Cancel
            </button>
            <button type="submit" className="submit-button" disabled={submitting}>
              {submitting ? 'Submitting...' : 'Submit Request'}
            </button>
          </div>
        </form>
      </div>

      {showSuccessModal && (
        <div style={{
          position: 'fixed', top: 0, left: 0, right: 0, bottom: 0,
          backgroundColor: 'rgba(0, 0, 0, 0.5)', display: 'flex',
          alignItems: 'center', justifyContent: 'center', zIndex: 1000
        }}>
          <div style={{
            background: 'white', padding: '24px', borderRadius: '12px',
            width: '90%', maxWidth: '400px', textAlign: 'center',
            boxShadow: '0 10px 25px rgba(0,0,0,0.1)'
          }}>
            <div style={{ fontSize: '48px', marginBottom: '16px' }}>🎉</div>
            <h3 style={{ margin: '0 0 12px 0', color: '#111827' }}>Success!</h3>
            <p style={{ color: '#4b5563', marginBottom: '24px' }}>
              Leave request submitted successfully.
            </p>
            <button
              onClick={() => navigate('/leaves')}
              style={{
                background: '#0d6efd', color: 'white', border: 'none',
                padding: '10px 24px', borderRadius: '6px', fontWeight: 'bold',
                cursor: 'pointer', width: '100%'
              }}
            >
              OK
            </button>
          </div>
        </div>
      )}
    </div>
  );
};

export default Leave;
