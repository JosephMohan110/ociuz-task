import React, { useEffect, useState } from 'react';
import { fetchJson } from '../../api/fetchClient';
import './ConfigMasters.css';

export default function ConfigMasters() {
  const [documentTypes, setDocumentTypes] = useState([]);
  const [statusMaster, setStatusMaster] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');

  useEffect(() => {
    let mounted = true;
    setLoading(true);
    setError('');

    Promise.all([fetchJson('api/v1/document-types/'), fetchJson('api/v1/status-master/')])
      .then(([docRes, statusRes]) => {
        if (!mounted) return;
        setDocumentTypes(docRes?.data ?? docRes ?? []);
        setStatusMaster(statusRes?.data ?? statusRes ?? []);
      })
      .catch((err) => {
        if (!mounted) return;
        setError('Unable to load configuration data.');
        console.error(err);
      })
      .finally(() => {
        if (mounted) setLoading(false);
      });

    return () => {
      mounted = false;
    };
  }, []);

  return (
    <div>
      <div className="archive-header">
        <h2>⚙️ System Configurations</h2>
        <p>Data is dynamically fetched from the PostgreSQL configuration engine.</p>
      </div>

      {error && <div className="alert alert-error">{error}</div>}
      {loading && <div className="loading-text">Loading configuration data...</div>}

      <div className="config-grid">
        <div className="form-card config-card">
          <h3>Registered Documents</h3>
          <table id="docTable">
            <thead>
              <tr>
                <th>Doc Name</th>
                <th>Code</th>
                <th>Prefix</th>
              </tr>
            </thead>
            <tbody>
              {documentTypes.length === 0 ? (
                <tr>
                  <td colSpan="3" className="text-center loading-row">Loading from Database API...</td>
                </tr>
              ) : (
                documentTypes.map((doc) => (
                  <tr key={doc.document_code || doc.document_name}>
                    <td style={{ fontWeight: 600 }}>{doc.document_name}</td>
                    <td>
                      <span className="status-badge badge-blue">{doc.document_code}</span>
                    </td>
                    <td>{doc.prefix ? `${doc.prefix}-XXXX` : 'N/A'}</td>
                  </tr>
                ))
              )}
            </tbody>
          </table>
        </div>

        <div className="form-card config-card">
          <h3>Global Status Master</h3>
          <table id="statusTable">
            <thead>
              <tr>
                <th>Seq</th>
                <th>Status Name</th>
                <th>UI Color (DB)</th>
              </tr>
            </thead>
            <tbody>
              {statusMaster.length === 0 ? (
                <tr>
                  <td colSpan="3" className="text-center loading-row">Loading from Database API...</td>
                </tr>
              ) : (
                statusMaster.map((st) => (
                  <tr key={st.sequence_order || st.status_name}>
                    <td>{st.sequence_order}</td>
                    <td style={{ fontWeight: 600 }}>{st.status_name}</td>
                    <td>
                      <span className="status-badge badge-color" style={{ background: st.color_code, borderColor: 'rgba(0,0,0,0.1)' }}>
                        {st.color_code}
                      </span>
                    </td>
                  </tr>
                ))
              )}
            </tbody>
          </table>
        </div>
      </div>
    </div>
  );
}
