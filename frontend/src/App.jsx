import React, { useEffect } from 'react';
import { BrowserRouter, Routes, Route, NavLink, Outlet, useNavigate, Navigate } from 'react-router-dom';
import './App.css';
import { AuthProvider, useAuth } from './context/AuthContext';
import AddStudent from './pages/students/AddStudent';
import ApprovalHistory from './pages/students/ApprovalHistory';
import ApproveStudent from './pages/students/ApproveStudent';
import ConfigMasters from './pages/students/ConfigMasters';
import DeleteStudent from './pages/students/DeleteStudent';
import EditStudent from './pages/students/EditStudent';
import ErpDashboard from './pages/students/ErpDashboard';
import ErrorPage from './pages/students/ErrorPage';
import GlobalApprovalHistory from './pages/students/GlobalApprovalHistory';
import RejectStudent from './pages/students/RejectStudent';
import StudentList from './pages/students/StudentList';
import Trash from './pages/students/Trash';
import Login from './pages/login/Login';
import ChatBot from './pages/chat_bot/ChatBot';
import ChatBotLeads from './pages/chat_bot/ChatBotLeads';
import Leave from './pages/leave/Leave';
import LeaveList from './pages/leave/LeaveList';

// ─────────────────────────────────────────────────────────────────────────────
// ProtectedRoute — redirects to /login if the user is not authenticated.
// Shows a loading screen while we are checking the session on first load.
// ─────────────────────────────────────────────────────────────────────────────
function ProtectedRoute({ children }) {
  const { user, loading } = useAuth();

  if (loading) {
    return (
      <div style={{
        display: 'flex', alignItems: 'center', justifyContent: 'center',
        minHeight: '100vh', flexDirection: 'column', gap: 12,
        background: 'var(--bg-primary, #0f172a)', color: 'var(--text-primary, #e2e8f0)',
      }}>
        <div style={{
          width: 40, height: 40, border: '4px solid rgba(99,102,241,0.3)',
          borderTopColor: '#6366f1', borderRadius: '50%', animation: 'spin 0.8s linear infinite',
        }} />
        <p style={{ margin: 0, fontSize: 14, opacity: 0.7 }}>Checking session…</p>
      </div>
    );
  }

  if (!user) {
    return <Navigate to="/login" replace />;
  }

  return children;
}

// ─────────────────────────────────────────────────────────────────────────────
// Layout — the shared nav header shown on all protected pages
// ─────────────────────────────────────────────────────────────────────────────
function Layout() {
  const { user } = useAuth();

  const navItems = [
    { to: '/', label: ' Dashboard' },
    { to: '/students', label: ' Admissions' },
    { to: '/students/add', label: 'Add Student' },
    { to: '/leaves', label: ' Leaves' },
    { to: '/chatbot-leads', label: ' Chatbot Leads' },
    { to: '/global-approval-history', label: ' Audit History' },
    { to: '/trash', label: ' Trash', className: 'btn-trash' },
  ];

  return (
    <div className="app-body">
      <div className="container">
        <div className="header">
          <div className="header-top">
            <h1>Student Management System</h1>
            <div className="header-actions">
              <span className="user-badge">👤 {user?.username || 'Manager'}</span>
              <NavLink to="/config" className="btn-small btn-trash"> Config Masters</NavLink>
              <NavLink to="/logout" className="btn-small btn-trash"> Logout</NavLink>
            </div>
          </div>
          <div className="nav">
            <div className="button-set">
              {navItems.map((item) => (
                <NavLink
                  key={item.to}
                  to={item.to}
                  className={({ isActive }) => `btn ${item.className || ''} ${isActive ? 'btn-active' : ''}`}
                >
                  {item.label}
                </NavLink>
              ))}
            </div>
          </div>
        </div>

        <div className="content">
          <Outlet />
        </div>
      </div>

      {/* Floating Chatbot Widget loaded globally on all pages */}
      <ChatBot />
    </div>
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Logout — clears the Django session via AuthContext, then navigates to /login
// ─────────────────────────────────────────────────────────────────────────────
function Logout() {
  const navigate = useNavigate();
  const { logout } = useAuth();

  useEffect(() => {
    logout().then(() => navigate('/login', { replace: true }));
  }, [logout, navigate]);

  return <div className="empty-state">Logging out…</div>;
}

function NotFound() {
  return <div className="empty-state">Page not found.</div>;
}

// ─────────────────────────────────────────────────────────────────────────────
// App — root component with BrowserRouter + AuthProvider
// ─────────────────────────────────────────────────────────────────────────────
export default function App() {
  return (
    <BrowserRouter>
      <AuthProvider>
        <Routes>
          {/* Public route — accessible without login */}
          <Route path="/login" element={<Login />} />

          {/* All protected routes require a valid session */}
          <Route
            path="/"
            element={
              <ProtectedRoute>
                <Layout />
              </ProtectedRoute>
            }
          >
            <Route index element={<ErpDashboard />} />
            <Route path="students" element={<StudentList />} />
            <Route path="students/add" element={<AddStudent />} />
            <Route path="students/:id/edit" element={<EditStudent />} />
            <Route path="students/edit/:id" element={<EditStudent />} />
            <Route path="students/:id/approval-history" element={<ApprovalHistory />} />
            <Route path="students/:id/approve" element={<ApproveStudent />} />
            <Route path="students/:id/delete" element={<DeleteStudent />} />
            <Route path="students/:id/reject" element={<RejectStudent />} />
            <Route path="leaves" element={<LeaveList />} />
            <Route path="leaves/new" element={<Leave />} />
            <Route path="chatbot-leads" element={<ChatBotLeads />} />
            <Route path="trash" element={<Trash />} />
            <Route path="global-approval-history" element={<GlobalApprovalHistory />} />
            <Route path="error" element={<ErrorPage />} />
            <Route path="config" element={<ConfigMasters />} />
            <Route path="logout" element={<Logout />} />
            <Route path="*" element={<NotFound />} />
          </Route>
        </Routes>
      </AuthProvider>
    </BrowserRouter>
  );
}
