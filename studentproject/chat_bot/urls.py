from django.urls import path
from . import views

urlpatterns = [
    # Optional: If you want a standalone page for the chatbot
    path('', views.chat_bot_page, name='chat_bot_page'), 
    
    # API endpoints matched exactly with your HTML widget script
    path('api/send/', views.chat_api, name='chat_api'),
    path('api/stats/', views.chat_stats, name='chat_stats'),
]