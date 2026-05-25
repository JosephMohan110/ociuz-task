import React, { useEffect, useState } from 'react';
import { fetchJson } from '../../api/fetchClient';
import './ErpDashboard.css';

export default function ErpDashboard() {
  const [data, setData] = useState(null);
  const [recentActivities, setRecentActivities] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');

  useEffect(() => {
    let mounted = true;
    setLoading(true);
    fetchJson('api/v1/erp-dashboard/')
      .then((res) => {
        if (!mounted) return;
        const payload = res?.data ?? res ?? {};
        setData(payload.metrics ?? payload);
        setRecentActivities(payload.recent_activities || []);
      })
      .catch((err) => {
        console.error(err);
        if (!mounted) return;
        setError('Unable to load dashboard data.');
      })
      .finally(() => { if (mounted) setLoading(false); });

    return () => { mounted = false; };
  }, []);

  if (loading) return (
    <div className="erp-loading">
      <div className="spinner"></div>
      <p>Loading dashboard...</p>
    </div>
  );
  if (error) return <div className="alert alert-error">{error}</div>;

  const metrics = typeof data === 'object' && data !== null ? data : {};
  const leaves = metrics.leaves || {};
  const admissions = metrics.admissions || {};
  const courseWise = metrics.course_wise || [];
  const approvals30d = metrics.approvals_30d || {};

  const getStatusColor = (status) => {
    if (!status) return '#94a3b8';
    const s = status.toUpperCase();
    if (s.includes('APPROVE')) return '#10b981';
    if (s.includes('REJECT')) return '#ef4444';
    if (s.includes('PENDING')) return '#f59e0b';
    if (s.includes('DRAFT')) return '#6366f1';
    return '#94a3b8';
  };

  const getModuleIcon = (module) => {
    if (!module) return '📋';
    const m = module.toLowerCase();
    if (m.includes('leave')) return '✈️';
    if (m.includes('admission') || m.includes('student')) return '🎓';
    if (m.includes('document')) return '📄';
    return '📋';
  };

  const calculatePercentage = (value, total) => {
    return total > 0 ? Math.round((value / total) * 100) : 0;
  };

  const leavePercentage = calculatePercentage(leaves.approved_leaves || 0, leaves.total_leaves || 1);
  const admissionPercentage = calculatePercentage(admissions.approved_requests || 0, admissions.total_admissions || 1);
  const approvalsPercentage = calculatePercentage(approvals30d.approvals || 0, approvals30d.total_actions || 1);

  return (
    <div className="erp-dashboard">
      <div className="dashboard-header">
        <div>
          <h1 className="dashboard-title">📊 ERP Dashboard</h1>
          <p className="dashboard-subtitle">Real-time system metrics and recent activities</p>
        </div>
        <div className="header-badge">
          <span className="status-dot"></span>
          <span className="status-text">Live</span>
        </div>
      </div>

      <div className="metrics-container">
        <div className="metric-card metric-card-leaves">
          <div className="metric-header">
            <div className="metric-icon">✈️</div>
            <div className="metric-info">
              <span className="metric-label">Total Leaves</span>
              <span className="metric-value">{leaves.total_leaves ?? 0}</span>
            </div>
          </div>
          <div className="metric-progress">
            <div className="progress-bar">
              <div className="progress-fill" style={{ width: leavePercentage + '%' }}></div>
            </div>
            <div className="metric-stats">
              <span className="stat-approved"> {leaves.approved_leaves ?? 0} Approved</span>
              <span className="stat-rejected"> {leaves.rejected_leaves ?? 0} Rejected</span>
            </div>
          </div>
        </div>

        <div className="metric-card metric-card-admissions">
          <div className="metric-header">
            <div className="metric-icon">🎓</div>
            <div className="metric-info">
              <span className="metric-label">Admissions</span>
              <span className="metric-value">{admissions.total_admissions ?? 0}</span>
            </div>
          </div>
          <div className="metric-progress">
            <div className="progress-bar">
              <div className="progress-fill" style={{ width: admissionPercentage + '%' }}></div>
            </div>
            <div className="metric-stats">
              <span className="stat-approved"> {admissions.approved_requests ?? 0} Approved</span>
              <span className="stat-pending"> {admissions.pending_approvals ?? 0} Pending</span>
            </div>
          </div>
        </div>

        <div className="metric-card metric-card-actions">
          <div className="metric-header">
            <div className="metric-icon">⚙️</div>
            <div className="metric-info">
              <span className="metric-label">Last 30 Days</span>
              <span className="metric-value">{approvals30d.total_actions ?? 0}</span>
            </div>
          </div>
          <div className="metric-progress">
            <div className="progress-bar">
              <div className="progress-fill" style={{ width: approvalsPercentage + '%' }}></div>
            </div>
            <div className="metric-stats">
              <span className="stat-approved"> {approvals30d.approvals ?? 0} Approvals</span>
              <span className="stat-rejected"> {approvals30d.rejections ?? 0} Rejections</span>
            </div>
          </div>
        </div>
      </div>

      <div className="dashboard-content">
        <div className="content-section">
          <div className="section-header">
            <h2 className="section-title">📚 Course-wise Distribution</h2>
          </div>
            {courseWise.length === 0 ? (
              <div className="empty-state">No course data available.</div>
            ) : (
              <div className="courses-table-wrap">
                <table className="course-table">
                  <thead>
                    <tr>
                      <th>Course</th>
                      <th>Student Count</th>
                      <th></th>
                    </tr>
                  </thead>
                  <tbody>
                    {courseWise.map((course) => (
                      <tr key={course.course_name}>
                        <td className="ct-name">{course.course_name}</td>
                        <td className="ct-count">{course.student_count}</td>
                        <td className="ct-label">Students</td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            )}
        </div>

        <div className="content-section">
          <div className="section-header">
            <h2 className="section-title">🔔 Recent Activities</h2>
          </div>
          {recentActivities.length === 0 ? (
            <div className="empty-state">No recent activity available.</div>
          ) : (
            <div className="timeline">
              {recentActivities.map((activity, idx) => {
                const [oldStatus, newStatus] = (activity.status_change || ' -> ').split('->').map(s => s.trim());
                return (
                  <div key={activity.history_id || idx} className="timeline-item">
                    <div className="timeline-marker" style={{ background: getStatusColor(activity.action) }}></div>
                    <div className="timeline-content">
                      <div className="activity-module">
                        <span className="module-icon">{getModuleIcon(activity.module)}</span>
                        <span className="module-name">{activity.module || 'System'}</span>
                        <span className="activity-action-badge">{activity.action}</span>
                      </div>
                      <div className="activity-timestamp">
                        {new Date(activity.date).toLocaleString('en-US', { 
                          month: 'short', 
                          day: 'numeric', 
                          year: 'numeric',
                          hour: '2-digit',
                          minute: '2-digit'
                        })}
                      </div>
                      <div className="activity-status">
                        <span className="status-badge old">{oldStatus}</span>
                        <span className="status-arrow">→</span>
                        <span className="status-badge new">{newStatus}</span>
                      </div>
                      <div className="activity-performer">👤 {activity.performed_by}</div>
                    </div>
                  </div>
                );
              })}
            </div>
          )}
        </div>
      </div>
    </div>
  );
}
