from django.shortcuts import render, redirect
from django.contrib import messages
from django.views.decorators.cache import never_cache
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
            request.session['erp_user_id'] = superuser['id']  #--EX>User ID = 1
            request.session['erp_username'] = superuser['username']  # STORE USER NAME
            request.session['is_erp_superuser'] = True    # MARK CEYUTUM ITU 
            request.session['role'] = superuser.get('role', 'Manager')
            request.session['user_role'] = superuser.get('role', 'Manager') #'Manager' is the default value.

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