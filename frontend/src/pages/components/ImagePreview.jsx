import React from 'react';

export default function ImagePreview({ src, alt }) {
  if (!src) return null;
  return <img className="image-preview" src={src} alt={alt || 'Preview'} />;
}
