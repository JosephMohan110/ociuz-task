import React from 'react';

export default function FormInput({ id, label, type = 'text', value, onChange, placeholder, error, hint, accept, maxLength }) {
  return (
    <div className="form-group">
      <label htmlFor={id}>{label}</label>
      <input
        id={id}
        name={id}
        type={type}
        className={`form-input ${error ? 'error' : value ? 'valid' : ''}`}
        value={type === 'file' ? undefined : value}
        onChange={onChange}
        placeholder={placeholder}
        accept={accept}
        maxLength={maxLength}
      />
      <small className="form-hint">{hint}</small>
      <div className="error-message" id={`${id}-error`}>{error || ''}</div>
    </div>
  );
}
