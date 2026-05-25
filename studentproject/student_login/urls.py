from django.urls import path
from . import views

urlpatterns = [
    path('login/', views.login_view, name='login'),
    path('logout/', views.logout_view, name='logout'),
    # JSON API endpoints for React SPA
    path('api/auth/login/', views.api_login_view, name='api_login'),
    path('api/auth/logout/', views.api_logout_view, name='api_logout'),
]