import json
from django.shortcuts import render, redirect
from django.contrib import messages
from django.views.decorators.cache import never_cache
from django.views.decorators.csrf import csrf_exempt
from django.http import JsonResponse
# Import connection helpers from your student workspace app 
from student.db_functions import db_verify_erp_superuser

@never_cache
def login_view(request):
    # 1. Custom session parameter block check
    if request.session.get('is_erp_superuser'):
        return redirect('erp_dashboard')

    if request.method == 'POST':
        u = request.POST.get('username', '').strip()
        p = request.POST.get('password', '').strip()

        if not u or not p:
            messages.error(request, "Both username and password are required.")
            return render(request, 'login/login.html')

        # 2. Fire the custom PostgreSQL function wrapper
        superuser = db_verify_erp_superuser(u, p)

        if superuser is not None:
            # 3. Manually serialize custom context parameters to the Session cookie
            request.session['erp_user_id'] = superuser['id']
            request.session['erp_username'] = superuser['username']
            request.session['is_erp_superuser'] = True
            request.session['role'] = superuser.get('role', 'Manager')
            request.session['user_role'] = superuser.get('role', 'Manager')

            messages.success(request, f"Welcome to the ERP System Master Dashboard, {superuser['username']}!")
            return redirect('erp_dashboard')
        else:
            messages.error(request, "Invalid username or password.")
            
    return render(request, 'login/login.html')

@never_cache
def logout_view(request):
    # Completely flushes the custom cookie data from the session store
    request.session.flush()
    messages.info(request, "You have been securely logged out. Session flushed.")
    return redirect('login')


# ─────────────────────────────────────────────────────────────────────────────
# JSON API endpoints — used by the React SPA frontend
# ─────────────────────────────────────────────────────────────────────────────

@csrf_exempt
@never_cache
def api_login_view(request):
    """
    POST /api/auth/login/
    Body: { "username": "...", "password": "..." }
    Returns JSON: { "success": true/false, "username": "...", "role": "..." }
    Used by the React Login page instead of the HTML form POST.
    """
    if request.method != 'POST':
        return JsonResponse({'success': False, 'error': 'Method not allowed'}, status=405)

    # Support both JSON body and form data
    try:
        if request.content_type and 'application/json' in request.content_type:
            body = json.loads(request.body)
            username = body.get('username', '').strip()
            password = body.get('password', '').strip()
        else:
            username = request.POST.get('username', '').strip()
            password = request.POST.get('password', '').strip()
    except (json.JSONDecodeError, Exception):
        return JsonResponse({'success': False, 'error': 'Invalid request body'}, status=400)

    if not username or not password:
        return JsonResponse({'success': False, 'error': 'Username and password are required'}, status=400)

    superuser = db_verify_erp_superuser(username, password)

    if superuser is not None:
        # Set all session values (same as the HTML login view)
        request.session['erp_user_id'] = superuser['id']
        request.session['erp_username'] = superuser['username']
        request.session['is_erp_superuser'] = True
        request.session['role'] = superuser.get('role', 'Manager')
        request.session['user_role'] = superuser.get('role', 'Manager')
        return JsonResponse({
            'success': True,
            'username': superuser['username'],
            'role': superuser.get('role', 'Manager'),
        })
    else:
        return JsonResponse({'success': False, 'error': 'Invalid username or password'}, status=401)


@csrf_exempt
@never_cache
def api_logout_view(request):
    """
    POST /api/auth/logout/
    Clears the Django session and returns JSON confirmation.
    Used by the React app's logout flow.
    """
    request.session.flush()
    return JsonResponse({'success': True, 'message': 'Logged out successfully'})