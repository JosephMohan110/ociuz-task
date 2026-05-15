# urls.py — Student app URL patterns

from django.urls import path
from . import views

urlpatterns = [
    path('',views.student_list,name='student_list'),
    path('add/',views.add_student,name='add_student'),
    path('edit/<int:student_id>/',views.edit_student,name='edit_student'),
    path('delete/<int:student_id>/',views.delete_student,name='delete_student'),
    path('approve/<int:student_id>/',views.approve_student,name='approve_student'),
    path('reject/<int:student_id>/',views.reject_student,name='reject_student'),
    path('history/<int:student_id>/',views.view_approval_history,name='approval_history'),
    path('api/search/',views.search_students_api,name='search_api'),
    path('api/courses/',views.get_courses_api,name='courses_api'),
    path('api/students/',views.api_get_students,name='api_students'),
    path('api/students/add/',views.api_add_student,name='api_add_student'),
    path('api/students/update/<int:student_id>/',views.api_update_student,name='api_update_student'),
    path('api/students/<int:student_id>/approve/',views.api_approve_student,name='api_approve_student'),
    path('api/students/<int:student_id>/reject/',views.api_reject_student,name='api_reject_student'),
    path('deleted/', views.deleted_students_list, name='deleted_students_list'),
    path('restore/<int:student_id>/', views.restore_student, name='restore_student'),
]