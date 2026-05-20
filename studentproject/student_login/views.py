from django.shortcuts import render, redirect
from django.contrib.auth import authenticate, login, logout
from django.contrib import messages
from django.views.decorators.cache import never_cache

@never_cache
def login_view(request):
    # Dynamically redirect to dashboard if already authenticated
    if request.user.is_authenticated:
        return redirect('erp_dashboard')

    if request.method == 'POST':
        u = request.POST.get('username')
        p = request.POST.get('password')
        user = authenticate(request, username=u, password=p)
        if user is not None:
            login(request, user)
            messages.success(request, f"Welcome to the ERP System, {user.username}!")
            return redirect('erp_dashboard')
        else:
            messages.error(request, "Invalid username or password.")
            
    return render(request, 'login/login.html')

@never_cache
def logout_view(request):
    # """
    # Securely logs out the user, flushes all session data from the database,
    # and clears the session cookie to prevent session fixation attacks.
    # """
    if request.user.is_authenticated:
        # 1. EXPLICIT FLUSH: Deletes the session data from the DB and regenerates 
        # the session key. Ensures no leftover custom data (like cached workflow roles) remains.
        request.session.flush()

        # 2. Native Logout: Cleans up the request object context
        logout(request)

        messages.info(request, "You have been securely logged out. Session flushed.")
    else:
        messages.info(request, "You were not logged in.")

    # 3. Dynamic Redirect (No hardcoding)
    return redirect('login')