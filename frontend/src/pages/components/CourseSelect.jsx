import React from 'react';

export default function CourseSelect({ id = 'course', value, onChange, options = [], error }) {
  return (
    <div className="form-group">
      <label htmlFor={id}>Course *</label>
      <select id={id} name={id} className={`form-input ${error ? 'error' : value ? 'valid' : ''}`} value={value} onChange={onChange}>
        <option value="">Select a course</option>
        {options.map((c) => (
          <option key={c.course_id || c.id} value={c.course_id ?? c.id}>{`${c.course_name ?? c.name} (${c.course_code ?? c.code ?? ''})`}</option>
        ))}
      </select>
      <small className="form-hint">Choose a course from the master list.</small>
      <div className="error-message" id={`${id}-error`}>{error || ''}</div>
    </div>
  );
}
