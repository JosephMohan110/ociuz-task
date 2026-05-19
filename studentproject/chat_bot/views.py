import json
import pandas as pd
from django.shortcuts import render
from django.http import JsonResponse
from django.views.decorators.csrf import csrf_exempt # Used for standalone testing if needed
from django.views.decorators.http import require_POST, require_GET
from .chat import get_chat_response, file_path  # Importing your engine structures




def chat_bot_page(request):
    """Renders a page containing the chatbot if needed."""
    return render(request, 'chat_bot/chatbot.html')

@csrf_exempt
@require_POST
def chat_api(request):
    """Main communication endpoint for user questions."""
    try:
        # Front-end send cheyyunna JSON data receive cheyyunnu
        #from frontend data recives as a json format and we convert it to python dict using json.loads() method
        data = json.loads(request.body)
        user_message = data.get('message', '').strip()
        
        if not user_message:
            return JsonResponse({
                'success': False,
                'error': 'Message content is empty.'
            })
            
        # ChatBot engine logic call cheyyunnu
        # after ceckin messae and we call the main cat bot enigine
        bot_response = get_chat_response(user_message)
        
        return JsonResponse({
            'success': True,
            'response': bot_response   # best answer will get here..and sent to front end
        })
        
    except Exception as e:
        return JsonResponse({
            'success': False,
            'error': str(e)
        })

@require_GET
def chat_stats(request):
    """Returns dynamic counter statistics for the top widget bar."""
    try:
        # Dynamically read the shape of the dataset for the answer metric
        df = pd.read_csv(file_path)
        total_qa = len(df)
    except Exception:
        total_qa = 0  # Fallback if file read fails temporarily

    return JsonResponse({
        'total_qa': total_qa,
        'today_chats': 12 # Static placeholder or implement counter if database log exists
    })