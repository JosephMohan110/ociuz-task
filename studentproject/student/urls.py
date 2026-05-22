# urls.py — Student app URL patterns

from django.urls import path
from django.shortcuts import render  # Required for the config_masters direct render
from . import views

urlpatterns = [
    # ==========================================
    # 1. CORE ADMISSION MODULE
    # ==========================================
    path('', views.student_list, name='student_list'),
    path('add/', views.add_student, name='add_student'),
    path('edit/<int:student_id>/', views.edit_student, name='edit_student'),
    path('delete/<int:student_id>/', views.delete_student, name='delete_student'),
    
    # # Legacy Approval Views (If still used by your student_list.html buttons)
    # path('approve/<int:student_id>/', views.approve_student, name='approve_student'),
    # path('reject/<int:student_id>/', views.reject_student, name='reject_student'),
    path('workflow/<int:student_id>/', views.process_student_workflow, name='process_student_workflow'),


    # ==========================================
    # 2. AUDIT & TRASH ARCHIVES
    # ==========================================
    path('history/<int:student_id>/', views.view_approval_history, name='approval_history'),
    path('audit-history/', views.global_approval_history, name='global_approval_history'),
    path('deleted/', views.deleted_students_list, name='deleted_students_list'),
    path('restore/<int:student_id>/', views.restore_student, name='restore_student'),

    # ==========================================
    # 3. LEAVE REQUEST MODULE (Added from Module 8 & 11)
    # ==========================================
    path('leaves/', views.leave_list, name='leave_list'),
    path('leaves/add/', views.add_leave_request, name='add_leave_request'),

    # ==========================================
    # 4. ERP DASHBOARD & SYSTEM CONFIGS
    # ==========================================
    path('dashboard/', views.dashboard_view, name='dashboard'), # Legacy dashboard
    path('erp-dashboard/', views.erp_dashboard_view, name='erp_dashboard'), # New ERP Dashboard
    
    # Maps directly to the template without needing a separate views.py function
    path('config-masters/', lambda request: render(request, 'student/config_masters.html'), name='config_masters'),

    # ==========================================
    # 5. GENERIC APPROVAL HANDLER (Module 5 Engine)
    # ==========================================
    # CRITICAL: This allows any template to trigger an approval dynamically
    path('workflow/action/<str:module_code>/<str:record_id>/', views.handle_document_approval, name='handle_document_approval'),

    # ==========================================
    # 6. AJAX / UI HELPERS
    # ==========================================
    path('api/search/', views.search_students_api, name='search_api'),
    path('api/courses/', views.get_courses_api, name='courses_api'),

    # ==========================================
    # 7. LEGACY REST APIs
    # ==========================================
    path('api/students/', views.api_get_students, name='api_students'),
    path('api/students/add/', views.api_add_student, name='api_add_student'),
    path('api/students/update/<int:student_id>/', views.api_update_student, name='api_update_student'),
    path('api/students/<int:student_id>/approve/', views.api_approve_student, name='api_approve_student'),
    path('api/students/<int:student_id>/reject/', views.api_reject_student, name='api_reject_student'),


    path('api/v1/document-types/', views.api_v1_get_document_types, name='api_v1_get_document_types'),
    path('api/v1/status-master/', views.api_v1_get_status_master, name='api_v1_get_status_master'),
    
    # CRITICAL FIX: This exact path string fixes your reverse template loop match
    path('api/v1/workflow-config/', views.api_v1_workflow_config, name='api_v1_workflow_config'),
    
    path('api/v1/dashboard-data/', views.api_v1_dashboard_data, name='api_v1_dashboard_data'),
    path('api/v1/workflow/process/', views.api_v1_process_workflow, name='api_v1_process_workflow'),
    path('api/v1/document-history/<str:doc_code>/<str:record_id>/', views.api_v1_document_history, name='api_v1_document_history'),
    path('api/v1/documents/<str:doc_code>/', views.api_v1_dynamic_documents, name='api_v1_dynamic_documents'),
    path('api/v1/documents/<str:doc_code>/<int:record_id>/', views.api_v1_dynamic_document_detail, name='api_v1_dynamic_document_detail'),
    path('api/v1/erp-dashboard/', views.api_v1_erp_dashboard, name='api_v1_erp_dashboard'),
]


