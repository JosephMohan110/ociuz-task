import json
import pandas as pd
from django.shortcuts import render
from django.http import JsonResponse
from django.views.decorators.csrf import csrf_exempt 
from django.views.decorators.http import require_POST, require_GET
from .chat import get_chat_response, file_path, conversation_memory
from django.db import connection


def chat_bot_page(request):
    """Renders the chatbot interface."""
    return render(request, 'chat_bot/chatbot.html')


@csrf_exempt
@require_POST
def chat_api(request):
    """
    Chat API endpoint - handles messages and stores user data
    Returns: JSON response with bot message
    """
    try:
        data = json.loads(request.body)
        user_message = data.get('message', '').strip()

        if not request.session.session_key:
            request.session.create()
        session_id = request.session.session_key

        # Get chatbot response
        bot_response = get_chat_response(session_id, user_message)

        # Get user data from conversation memory
        user_data = conversation_memory.get(session_id, {})

        # Save to database only if user has shared at least name or email
        if (user_data.get('name') or user_data.get('email')) and user_data.get('status') == 'interested':
            try:
                with connection.cursor() as cursor:
                    cursor.execute('''
                        INSERT INTO chatbot_user_details (session_id, name, email, phone, status)
                        VALUES (%s, %s, %s, %s, %s)
                        ON CONFLICT (session_id) DO UPDATE SET
                            name = EXCLUDED.name,
                            email = EXCLUDED.email,
                            phone = EXCLUDED.phone,
                            status = EXCLUDED.status
                    ''', [
                        session_id,
                        user_data.get('name'),
                        user_data.get('email'),
                        user_data.get('phone'),
                        user_data.get('status')
                    ])
            except Exception as db_error:
                print(f"Database error: {str(db_error)}")
                # Continue anyway - chat still works even if DB save fails

        return JsonResponse({
            'success': True,
            'response': bot_response,
            'user_name': user_data.get('name', 'Guest')  # For personalization on frontend
        })

    except json.JSONDecodeError:
        return JsonResponse({
            'success': False,
            'error': 'Invalid JSON'
        }, status=400)
    except Exception as e:
        return JsonResponse({
            'success': False,
            'error': str(e)
        }, status=500)


@require_GET
def chat_stats(request):
    """Returns chatbot statistics"""
    try:
        df = pd.read_csv(file_path)
        total_qa = len(df)
    except Exception:
        total_qa = 0

    # Get count of users who shared their info
    try:
        with connection.cursor() as cursor:
            cursor.execute("SELECT COUNT(*) FROM chatbot_user_details WHERE status='interested'")
            interested_users = cursor.fetchone()[0]
    except Exception:
        interested_users = 0

    return JsonResponse({
        'total_qa': total_qa,
        'interested_users': interested_users,
        'today_chats': len(conversation_memory)  # Active sessions
    })