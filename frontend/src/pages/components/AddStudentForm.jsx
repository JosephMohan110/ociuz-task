import React, { useState, useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import { apiUrl, fetchJson, getCsrfToken } from '../../api/fetchClient';
import '../students/AddStudent.css';
import FormInput from './FormInput';
import CourseSelect from './CourseSelect';
import ImagePreview from './ImagePreview';

export default function AddStudentForm() {
  const navigate = useNavigate();
  const [form, setForm] = useState({ name: '', phone: '', email: '', course: '' });
  const [errors, setErrors] = useState({});
  const [imageFile, setImageFile] = useState(null);
  const [imageSrc, setImageSrc] = useState('');
  const [courses, setCourses] = useState([]);
  const [submitting, setSubmitting] = useState(false);
  const [successMessage, setSuccessMessage] = useState('');
  const [apiError, setApiError] = useState('');

  useEffect(() => {
    fetchJson('api/courses')
      .then((res) => setCourses(res?.courses || []))
      .catch(() => setCourses([]));
  }, []);

  const validators = {
    name: (v) => {
      if (!v.trim()) return 'Name is required.';
      if (!/^[A-Za-z\s]+$/.test(v)) return 'Name must contain only letters and spaces.';
      return '';
    },
    phone: (v) => {
      if (!v.trim()) return 'Phone number is required.';
      if (!/^[6-9]\d{9}$/.test(v)) return 'Phone must be a valid 10-digit mobile number.';
      return '';
    },
    email: (v) => {
      if (!v.trim()) return 'Email is required.';
      if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(v)) return 'Enter a valid email address.';
      return '';
    },
    course: (v) => (!v ? 'Course selection is required.' : ''),
  };

  function handleChange(e) {
    const { name, value, files } = e.target;
    if (name === 'studentImage' && files && files[0]) {
      handleImage(files[0]);
      return;
    }
    setForm((s) => ({ ...s, [name]: value }));
    setErrors((s) => ({ ...s, [name]: validators[name] ? validators[name](value) : '' }));
  }

  function handleImage(file) {
    const allowed = ['image/jpeg', 'image/png', 'image/gif'];
    if (!allowed.includes(file.type)) {
      setErrors((s) => ({ ...s, studentImage: 'Only JPG, PNG, or GIF images are allowed.' }));
      setImageFile(null);
      setImageSrc('');
      return;
    }
    if (file.size > 2 * 1024 * 1024) {
      setErrors((s) => ({ ...s, studentImage: 'Image size must be 2MB or less.' }));
      setImageFile(null);
      setImageSrc('');
      return;
    }
    setErrors((s) => ({ ...s, studentImage: '' }));
    setImageFile(file);
    const reader = new FileReader();
    reader.onload = (ev) => setImageSrc(ev.target.result);
    reader.readAsDataURL(file);
  }

  function validateAll() {
    const next = {};
    Object.keys(validators).forEach((k) => (next[k] = validators[k](form[k] || '')));
    setErrors((s) => ({ ...s, ...next }));
    return !Object.values(next).some(Boolean) && !errors.studentImage;
  }

  async function handleSubmit(e) {
    e.preventDefault();
    setApiError('');
    setSuccessMessage('');
    if (!validateAll()) return;

    const fd = new FormData();
    fd.append('name', form.name);
    fd.append('phone', form.phone);
    fd.append('email', form.email);
    fd.append('course', form.course);
    if (imageFile) fd.append('student_image', imageFile);

    setSubmitting(true);
    try {
      const res = await fetch(apiUrl('api/students/add/'), {
        method: 'POST',
        credentials: 'include',
        headers: { 'X-CSRFToken': getCsrfToken() },
        body: fd,
      });

      if (!res.ok) {
        const data = await res.json().catch(() => ({}));
        const details = Array.isArray(data.details)
          ? data.details.join(' ')
          : (data.error || 'Failed to save student.');
        setApiError(details);
        return;
      }

      // Success — navigate to student list
      navigate('/students');
    } catch (err) {
      console.error(err);
      setApiError('Network error — please check your connection and try again.');
    } finally {
      setSubmitting(false);
    }
  }

  return (
    <div className="form-card">
      <h2 className="text-center">Add New Student</h2>

      {apiError && <div className="alert alert-error" style={{ marginBottom: 16 }}>{apiError}</div>}
      {successMessage && <div className="alert alert-success" style={{ marginBottom: 16 }}>{successMessage}</div>}

      <form id="studentForm" onSubmit={handleSubmit} encType="multipart/form-data" noValidate>
        <FormInput id="name" label="Student Name *" value={form.name} onChange={handleChange} placeholder="e.g., John Doe" error={errors.name} hint="Enter full name using only letters and spaces" />
        <FormInput id="phone" label="Phone Number *" type="tel" value={form.phone} onChange={handleChange} placeholder="e.g., 9876543210" error={errors.phone} maxLength={10} hint="Enter 10-digit mobile number starting with 6, 7, 8, or 9" />
        <FormInput id="email" label="Email *" type="email" value={form.email} onChange={handleChange} placeholder="e.g., john.doe@example.com" error={errors.email} hint="Enter a valid email address (e.g., name@domain.com)" />

        <CourseSelect
          value={form.course}
          onChange={(e) => {
            setForm((s) => ({ ...s, course: e.target.value }));
            setErrors((s) => ({ ...s, course: validators.course(e.target.value) }));
          }}
          options={courses}
          error={errors.course}
        />

        <div className="form-group">
          <label>Student Image</label>
          <input
            id="studentImage"
            name="studentImage"
            type="file"
            className={`form-input ${errors.studentImage ? 'error' : ''}`}
            accept="image/png,image/jpeg,image/gif"
            onChange={(e) => handleChange(e)}
          />
          <small className="form-hint">Upload a JPG, PNG, or GIF image. Max size 2MB.</small>
          <div className="image-preview-wrapper">
            <ImagePreview src={imageSrc} alt="Image preview" />
          </div>
          <div className="error-message" id="studentImage-error">{errors.studentImage || ''}</div>
        </div>

        <div className="text-center">
          <button type="submit" className="btn btn-success" id="submitBtn" disabled={submitting}>
            {submitting ? 'Saving…' : 'Save Student'}
          </button>
          <button
            type="button"
            className="btn btn-info"
            onClick={() => navigate('/students')}
            disabled={submitting}
          >
            Cancel
          </button>
        </div>
      </form>
    </div>
  );
}
