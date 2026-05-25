import React, { useEffect, useState } from 'react';
import { useNavigate, useParams, useLocation } from 'react-router-dom';
import { apiUrl, fetchJson, getCsrfToken } from '../../api/fetchClient';
import '../students/AddStudent.css';
import FormInput from '../components/FormInput';
import CourseSelect from '../components/CourseSelect';
import ImagePreview from '../components/ImagePreview';

function buildImageUrl(path) {
  if (!path) return '';
  if (path.startsWith('http') || path.startsWith('/')) return path;
  return `/media/${path}`;
}

export default function EditStudent() {
  const { id } = useParams();
  const location = useLocation();
  const navigate = useNavigate();
  const [form, setForm] = useState({ name: '', phone: '', email: '', course: '' });
  const [currentImage, setCurrentImage] = useState('');
  const [courses, setCourses] = useState([]);
  const [errors, setErrors] = useState({});
  const [imageFile, setImageFile] = useState(null);
  const [imageSrc, setImageSrc] = useState('');
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const [submitting, setSubmitting] = useState(false);

  const page = new URLSearchParams(location.search).get('page');

  useEffect(() => {
    let mounted = true;
    setLoading(true);
    setError('');

    Promise.all([
      fetchJson(`api/students/${id}/`),
      fetchJson('api/courses'),
    ])
      .then(([studentRes, courseRes]) => {
        if (!mounted) return;
        // Support multiple API shapes: { student: {...} } or { data: { student: {...} } }
        const student = (studentRes && (studentRes.student || (studentRes.data && studentRes.data.student))) || studentRes || null;
        if (!student) {
          setError('Student data not found.');
          return;
        }

        setForm({
          name: student.name || '',
          phone: student.phone || '',
          email: student.email || '',
          course: student.course_id ? String(student.course_id) : '',
        });
        setCurrentImage(student.student_image ? buildImageUrl(student.student_image) : '');

        const coursesList = (courseRes && (courseRes.courses || (courseRes.data && courseRes.data.courses))) || [];
        setCourses(coursesList || []);
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

  const validators = {
    name: (value) => {
      if (!value.trim()) return 'Name is required.';
      if (!/^[A-Za-z\s]+$/.test(value)) return 'Name must contain only letters and spaces.';
      return '';
    },
    phone: (value) => {
      if (!value.trim()) return 'Phone number is required.';
      if (!/^[6-9]\d{9}$/.test(value)) return 'Phone must be a valid 10-digit mobile number.';
      return '';
    },
    email: (value) => {
      if (!value.trim()) return 'Email is required.';
      if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(value)) return 'Enter a valid email address.';
      return '';
    },
    course: (value) => (!value ? 'Course selection is required.' : ''),
  };

  function handleChange(e) {
    const { name, value, files } = e.target;
    if (name === 'studentImage' && files && files[0]) {
      handleImage(files[0]);
      return;
    }
    setForm((prev) => ({ ...prev, [name]: value }));
    setErrors((prev) => ({ ...prev, [name]: validators[name] ? validators[name](value) : '' }));
  }

  function handleImage(file) {
    const allowed = ['image/jpeg', 'image/png', 'image/gif'];
    if (!allowed.includes(file.type)) {
      setErrors((prev) => ({ ...prev, studentImage: 'Only JPG, PNG, or GIF images are allowed.' }));
      setImageFile(null);
      setImageSrc('');
      return;
    }
    if (file.size > 2 * 1024 * 1024) {
      setErrors((prev) => ({ ...prev, studentImage: 'Image size must be 2MB or less.' }));
      setImageFile(null);
      setImageSrc('');
      return;
    }
    setErrors((prev) => ({ ...prev, studentImage: '' }));
    setImageFile(file);
    const reader = new FileReader();
    reader.onload = (ev) => setImageSrc(ev.target.result);
    reader.readAsDataURL(file);
  }

  function validateAll() {
    const next = {};
    Object.keys(validators).forEach((key) => {
      next[key] = validators[key](form[key] || '');
    });
    setErrors((prev) => ({ ...prev, ...next }));
    return !Object.values(next).some(Boolean) && !errors.studentImage;
  }

  async function handleSubmit(event) {
    event.preventDefault();
    setError('');
    if (!validateAll()) return;

    const formData = new FormData();
    formData.append('name', form.name);
    formData.append('phone', form.phone);
    formData.append('email', form.email);
    formData.append('course', form.course);
    if (imageFile) formData.append('student_image', imageFile);

    setSubmitting(true);
    try {
      const res = await fetch(apiUrl(`api/students/update/${id}/`), {
        method: 'POST',
        credentials: 'include',
        headers: {
          'X-CSRFToken': getCsrfToken(),
        },
        body: formData,
      });

      if (!res.ok) {
        // Parse the error message from Django's JSON response
        const data = await res.json().catch(() => ({}));
        const details = Array.isArray(data.details)
          ? data.details.join(' ')
          : (data.error || `Server error (${res.status}). Please try again.`);
        setError(details);
        return;
      }

      // Success — go back to student list (preserving page number if present)
      navigate(`/students${page ? `?page=${page}` : ''}`);
    } catch (err) {
      console.error(err);
      setError('Network error — please check your connection and try again.');
    } finally {
      setSubmitting(false);
    }
  }


  if (loading) {
    return <div className="form-card">Loading student details...</div>;
  }

  return (
    <div className="form-card">
      <h2 className="text-center">Edit Student</h2>

      <div className="alert alert-warning" style={{ marginBottom: 20, padding: '12px 14px', background: 'linear-gradient(135deg, #fff3cd 0%, #fffbf0 100%)', color: '#856404', border: '2px solid #ffc107', borderRadius: 8, boxShadow: '0 2px 8px rgba(255, 193, 7, 0.15)' }}>
        <div style={{ display: 'flex', alignItems: 'start', gap: 12 }}>
          <span style={{ fontSize: 20, flexShrink: 0 }}>⚠️</span>
          <div>
            <strong>Important Notice:</strong><br />
            Any changes to this student's information will reset their approval status to <strong>"Pending"</strong> for re-approval. The admin must review and re-approve the changes.
          </div>
        </div>
      </div>

      {error && <div className="error-message" style={{ marginBottom: 18 }}>{error}</div>}

      <form id="studentForm" onSubmit={handleSubmit} encType="multipart/form-data" noValidate>
        <FormInput id="name" label="Student Name *" value={form.name} onChange={handleChange} placeholder="e.g., John Doe" error={errors.name} hint="Enter full name using only letters and spaces" />
        <FormInput id="phone" label="Phone Number *" type="tel" value={form.phone} onChange={handleChange} placeholder="e.g., 9876543210" error={errors.phone} maxLength={10} hint="Enter 10-digit mobile number starting with 6, 7, 8, or 9" />
        <FormInput id="email" label="Email *" type="email" value={form.email} onChange={handleChange} placeholder="e.g., john.doe@example.com" error={errors.email} hint="Enter a valid email address (e.g., name@domain.com)" />

        <CourseSelect value={form.course} onChange={(e) => { handleChange(e); }} options={courses} error={errors.course} />

        {currentImage && !imageSrc ? (
          <div className="form-group">
            <label>Current Image</label>
            <div className="current-image-preview">
              <img src={currentImage} alt={form.name || 'Current image'} className="image-preview" />
            </div>
          </div>
        ) : null}

        <div className="form-group">
          <label>Update Student Image</label>
          <input id="studentImage" name="studentImage" type="file" className={`form-input ${errors.studentImage ? 'error' : ''}`} accept="image/png,image/jpeg,image/gif" onChange={handleChange} />
          <small className="form-hint">Upload a JPG, PNG, or GIF image. Max size 2MB.</small>
          <div className="image-preview-wrapper">
            <ImagePreview src={imageSrc} alt="Image preview" />
          </div>
          <div className="error-message" id="studentImage-error">{errors.studentImage || ''}</div>
        </div>

        <div className="text-center">
          <button type="submit" className="btn btn-success" disabled={submitting}>{submitting ? 'Updating…' : 'Update Student'}</button>
          <button type="button" className="btn btn-info" onClick={() => navigate(`/students${page ? `?page=${page}` : ''}`)}>
            Cancel
          </button>
        </div>
      </form>
    </div>
  );
}
