# views.py
# ─────────────────────────────────────────────────────────────
# All HTTP request handling for the Student app.
# No ORM / database code here — every DB call goes through db_functions.py.
# ─────────────────────────────────────────────────────────────

import imghdr
import os
import re
import uuid
from pathlib import Path

from django.conf import settings
from django.shortcuts import render, redirect
from django.urls import reverse
from django.contrib import messages
from django.core.paginator import Paginator
from django.http import JsonResponse

from .db_functions import (
    db_get_all_students,
    db_get_student_by_id,
    db_email_exists,
    db_add_student,
    db_update_student,
    db_delete_student,
    db_restore_student,
    db_get_deleted_students,
    # db_approve_student,
    # db_reject_student,
    db_process_student_approval,
    db_get_approval_history,
    db_get_courses,
    db_course_exists,
    db_get_dashboard_stats,
    db_get_global_approval_history,
)


# CONSTANTS

ALLOWED_IMAGE_EXTENSIONS = {'jpg', 'jpeg', 'png', 'gif'}
ALLOWED_IMAGE_CONTENT_TYPES = {
    'image/jpeg',
    'image/png',
    'image/gif',
}
MAX_IMAGE_SIZE = 2 * 1024 * 1024  # 2 MB


# SHARED VALIDATION HELPERS

def _validate_form(request, name, phone, email, course, exclude_id=None, api_mode=False):
    # """
    # Validate student form fields.
    # If api_mode=True, returns (has_error, error_list).
    # If api_mode=False, adds Django messages and returns has_error.
    # """
    errors = []
    has_error = False

    # Name
    if not name:
        error_msg = 'Name is required.'
        if api_mode:
            errors.append(error_msg)
        else:
            messages.error(request, error_msg)
        has_error = True
    elif not re.match(r'^[A-Za-z\s]+$', name):
        error_msg = 'Name must contain only letters and spaces.'
        if api_mode:
            errors.append(error_msg)
        else:
            messages.error(request, error_msg)
        has_error = True

    # Phone
    if not phone:
        error_msg = 'Phone number is required.'
        if api_mode:
            errors.append(error_msg)
        else:
            messages.error(request, error_msg)
        has_error = True
    elif not phone.isdigit() or len(phone) != 10:
        error_msg = 'Phone number must be exactly 10 digits.'
        if api_mode:
            errors.append(error_msg)
        else:
            messages.error(request, error_msg)
        has_error = True
    elif phone[0] not in '6789':
        error_msg = 'Phone number must start with 6, 7, 8 or 9.'
        if api_mode:
            errors.append(error_msg)
        else:
            messages.error(request, error_msg)
        has_error = True

    # Email
    if not email:
        error_msg = 'Email is required.'
        if api_mode:
            errors.append(error_msg)
        else:
            messages.error(request, error_msg)
        has_error = True
    elif not re.match(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$', email):
        error_msg = 'Enter a valid email address.'
        if api_mode:
            errors.append(error_msg)
        else:
            messages.error(request, error_msg)
        has_error = True
    elif db_email_exists(email, exclude_id=exclude_id):
        error_msg = 'This email is already registered.'
        if api_mode:
            errors.append(error_msg)
        else:
            messages.error(request, error_msg)
        has_error = True

    # Course
    if not course:
        error_msg = 'Course is required.'
        if api_mode:
            errors.append(error_msg)
        else:
            messages.error(request, error_msg)
        has_error = True
    else:
        try:
            selected_course_id = int(course)
        except (TypeError, ValueError):
            selected_course_id = None

        if selected_course_id is None or not db_course_exists(selected_course_id):
            error_msg = 'Selected course is not available in the course master list.'
            if api_mode:
                errors.append(error_msg)
            else:
                messages.error(request, error_msg)
            has_error = True

    if api_mode:
        return has_error, errors
    return has_error


def _validate_student_image(request, image_file, api_mode=False):
    # """
    # Validate student image file.
    # If api_mode=True, returns (has_error, error_message).
    # If api_mode=False, adds Django messages and returns has_error.
    # """
    if not image_file:
        return False

    if image_file.size > MAX_IMAGE_SIZE:
        error_msg = 'Image must be 2MB or smaller.'
        if api_mode:
            return True, error_msg
        messages.error(request, error_msg)
        return True

    if image_file.content_type not in ALLOWED_IMAGE_CONTENT_TYPES:
        error_msg = 'Only JPG, PNG, and GIF image files are allowed.'
        if api_mode:
            return True, error_msg
        messages.error(request, error_msg)
        return True

    header = image_file.read(512)
    image_file.seek(0)
    image_type = imghdr.what(None, header)
    if image_type not in ALLOWED_IMAGE_EXTENSIONS:
        error_msg = 'Uploaded file is not a valid image.'
        if api_mode:
            return True, error_msg
        messages.error(request, error_msg)
        return True

    ext = os.path.splitext(image_file.name)[1].lower()
    if ext and ext.lstrip('.') not in ALLOWED_IMAGE_EXTENSIONS:
        error_msg = 'Image file extension must be JPG, PNG, or GIF.'
        if api_mode:
            return True, error_msg
        messages.error(request, error_msg)
        return True

    return False


def _save_student_image(image_file):
    # """
    # Save uploaded student image and return the relative path.
    # """
    uploads_dir = Path(settings.MEDIA_ROOT) / 'student_images'
    uploads_dir.mkdir(parents=True, exist_ok=True)

    extension = os.path.splitext(image_file.name)[1].lower()
    if not extension:
        extension = '.' + (imghdr.what(None, image_file.read(512)) or 'jpg')
        image_file.seek(0)

    filename = f"{uuid.uuid4().hex}{extension}"
    save_path = uploads_dir / filename

    with open(save_path, 'wb') as destination:
        for chunk in image_file.chunks():
            destination.write(chunk)

    return f'student_images/{filename}'


# WEB VIEWS (CRUD OPERATIONS)

def student_list(request):
    # """
    # Display all students with their current approval status.
    # Supports search (name / phone / email / course) and pagination (5 per page).
    # """
    search_keyword = request.GET.get('search', '').strip()
    all_students = db_get_all_students(search_keyword=search_keyword)

    paginator = Paginator(all_students, 5)
    page_obj = paginator.get_page(request.GET.get('page'))

    return render(request, 'student/student_list.html', {
        'students': page_obj,
        'page_obj': page_obj,
        'paginator': paginator,
        'search_keyword': search_keyword,
    })


def add_student(request):
    # """
    # GET: blank form.
    # POST: validate → INSERT student + Pending approval → redirect to list.
    # """
    form_data = {'name': '', 'phone': '', 'email': '', 'course': ''}
    courses = db_get_courses()

    if request.method == 'POST':
        name = request.POST.get('name', '').strip()
        phone = request.POST.get('phone', '').strip()
        email = request.POST.get('email', '').strip()
        course = request.POST.get('course', '').strip()
        image_file = request.FILES.get('student_image')

        form_data = {'name': name, 'phone': phone, 'email': email, 'course': course}

        image_has_error = _validate_student_image(request, image_file)
        if not _validate_form(request, name, phone, email, course) and not image_has_error:
            image_path = _save_student_image(image_file) if image_file else None
            db_add_student(name, phone, email, int(course), image_path)
            messages.success(request, f'Student "{name}" added successfully.')
            return redirect('student_list')

    return render(request, 'student/add_student.html', {
        'form_data': form_data,
        'courses': courses,
    })


def edit_student(request, student_id):
    # """
    # GET: form pre-filled with current student data.
    # POST: validate → UPDATE student → redirect to list.
    # ANY edit automatically resets status to Pending for re-approval.
    # """
    student = db_get_student_by_id(student_id)
    if not student:
        messages.error(request, 'Student not found.')
        return redirect('student_list')

    page = request.GET.get('page', '').strip() if request.method == 'GET' else request.POST.get('page', '').strip()
    courses = db_get_courses()
    form_data = {
        'name': student['name'],
        'phone': student['phone'],
        'email': student['email'],
        'course': '' if student['course_id'] is None else str(student['course_id']),
    }

    if request.method == 'POST':
        name = request.POST.get('name', '').strip()
        phone = request.POST.get('phone', '').strip()
        email = request.POST.get('email', '').strip()
        course = request.POST.get('course', '').strip()
        image_file = request.FILES.get('student_image')

        form_data = {'name': name, 'phone': phone, 'email': email, 'course': course}

        image_has_error = _validate_student_image(request, image_file)
        if not _validate_form(request, name, phone, email, course, exclude_id=student_id) and not image_has_error:
            image_path = _save_student_image(image_file) if image_file else None
            db_update_student(student_id, name, phone, email, int(course), image_path)

            messages.info(request,
                f'"{name}" updated successfully. Status reset to Pending for re-approval.')

            if page:
                return redirect(f'{reverse("student_list")}?page={page}')
            return redirect('student_list')

    return render(request, 'student/edit_student.html', {
        'student': student,
        'form_data': form_data,
        'courses': courses,
        'page': page,
    })



# old code of delete....
#update code is below ...
# def delete_student(request, student_id):
#     # """
#     # GET: confirmation page.
#     # POST: DELETE student (and all approval records) → redirect.
#     # """
#     student = db_get_student_by_id(student_id)
#     if not student:
#         messages.error(request, 'Student not found.')
#         return redirect('student_list')

#     page = request.GET.get('page', '').strip()

#     if request.method == 'POST':
#         page = request.POST.get('page', page).strip()  # Use POST page if available, fallback to GET
#         db_delete_student(student_id)
#         messages.success(request, f'Student "{student["name"]}" deleted.')
#         if page:
#             return redirect(f'{reverse("student_list")}?page={page}')
#         return redirect('student_list')

#     return render(request, 'student/delete_student.html', {'student': student, 'page': page})




# new code of delete and restore....
def delete_student(request, student_id):
    student = db_get_student_by_id(student_id)
    if not student:
        messages.error(request, 'Student not found.')
        return redirect('student_list')

    page = request.GET.get('page', '').strip()

    if request.method == 'POST':
        page = request.POST.get('page', page).strip()
        # Pass 'Admin' or request.user.username if using auth
        db_delete_student(student_id, deleted_by='Admin') 
        messages.success(request, f'Student "{student["name"]}" moved to trash.')
        if page:
            return redirect(f'{reverse("student_list")}?page={page}')
        return redirect('student_list')

    return render(request, 'student/delete_student.html', {'student': student, 'page': page})

# ADD THESE TWO NEW VIEWS
def deleted_students_list(request):
    """ Shows the trash bin / archive of deleted students """
    deleted_students = db_get_deleted_students()
    return render(request, 'student/deleted_list.html', {
        'deleted_students': deleted_students
    })

def restore_student(request, student_id):
    """ Action to restore a student from the trash """
    if request.method == 'POST':
        success = db_restore_student(student_id, restored_by='Admin')
        if success:
            messages.success(request, 'Student restored successfully and requires re-approval.')
        else:
            messages.error(request, 'Failed to restore student.')
    return redirect('deleted_students_list')




# THIS CODE IS NW REPLACE BY ITS BELOW CODE...
# def approve_student(request, student_id):
#     # """
#     # GET: confirmation page with optional remarks.
#     # POST: INSERT Approved record → redirect.
#     # Only Pending students can be approved.
#     # """
#     student = db_get_student_by_id(student_id)
#     if not student:
#         messages.error(request, 'Student not found.')
#         return redirect('student_list')

#     if student['approval_status'] != 'Pending':
#         messages.warning(request,
#             f'"{student["name"]}" is already {student["approval_status"]}.')
#         return redirect('student_list')

#     page = request.GET.get('page', '').strip()

#     if request.method == 'POST':
#         remarks = request.POST.get('remarks', '').strip()
#         page = request.POST.get('page', page).strip()  # Use POST page if available, fallback to GET
#         db_approve_student(student_id, approved_by='Admin', remarks=remarks)
#         messages.success(request, f'"{student["name"]}" approved successfully.')
#         if page:
#             return redirect(f'{reverse("student_list")}?page={page}')
#         return redirect('student_list')

#     return render(request, 'student/approve_student.html', {
#         'student': student,
#         'remarks': '',
#         'page': page,
#     })


# def reject_student(request, student_id):
#     # """
#     # GET: confirmation page with optional remarks.
#     # POST: INSERT Rejected record → redirect.
#     # Only Pending students can be rejected.
#     # """
#     student = db_get_student_by_id(student_id)
#     if not student:
#         messages.error(request, 'Student not found.')
#         return redirect('student_list')

#     if student['approval_status'] != 'Pending':
#         messages.warning(request,
#             f'"{student["name"]}" is already {student["approval_status"]}.')
#         return redirect('student_list')

#     page = request.GET.get('page', '').strip()

#     if request.method == 'POST':
#         remarks = request.POST.get('remarks', '').strip()
#         page = request.POST.get('page', page).strip()  # Use POST page if available, fallback to GET
#         db_reject_student(student_id, approved_by='Admin', remarks=remarks)
#         messages.success(request, f'"{student["name"]}" rejected.')
#         if page:
#             return redirect(f'{reverse("student_list")}?page={page}')
#         return redirect('student_list')

#     return render(request, 'student/reject_student.html', {
#         'student': student,
#         'remarks': '',
#         'page': page,
#     })


# NEW CODE FOR APPROVAL AND REJECT..

def approve_student(request, student_id):
    student = db_get_student_by_id(student_id)
    if not student:
        messages.error(request, 'Student not found.')
        return redirect('student_list')

    page = request.GET.get('page', '').strip()

    if request.method == 'POST':
        remarks = request.POST.get('remarks', '').strip()
        page = request.POST.get('page', page).strip()
        
        # 1. Call the new DB Procedure
        result = db_process_student_approval(student_id, 'APPROVE', 'Admin', remarks)
        
        # 2. Handle the response dynamically based on Status Code
        if result['status_code'] == 200:
            messages.success(request, result['message'])
        elif result['status_code'] == 409:
            messages.info(request, result['message']) # Already approved
        else:
            messages.warning(request, result['message']) # 400 or 500 errors

        if page:
            return redirect(f'{reverse("student_list")}?page={page}')
        return redirect('student_list')

    return render(request, 'student/approve_student.html', {
        'student': student, 'remarks': '', 'page': page,
    })


def reject_student(request, student_id):
    student = db_get_student_by_id(student_id)
    if not student:
        messages.error(request, 'Student not found.')
        return redirect('student_list')

    page = request.GET.get('page', '').strip()

    if request.method == 'POST':
        remarks = request.POST.get('remarks', '').strip()
        page = request.POST.get('page', page).strip()
        
        # 1. Call the new DB Procedure
        result = db_process_student_approval(student_id, 'REJECT', 'Admin', remarks)
        
        # 2. Handle the response dynamically based on Status Code
        if result['status_code'] == 200:
            messages.success(request, result['message'])
        elif result['status_code'] == 409:
            messages.info(request, result['message']) # Already rejected
        else:
            messages.warning(request, result['message']) # 400 or 500 errors

        if page:
            return redirect(f'{reverse("student_list")}?page={page}')
        return redirect('student_list')

    return render(request, 'student/reject_student.html', {
        'student': student, 'remarks': '', 'page': page,
    })





def view_approval_history(request, student_id):
    # """
    # GET: display full approval/rejection history for a student.
    # Shows every event (Pending → Approved/Rejected) with timestamps and remarks.
    # """
    student = db_get_student_by_id(student_id)
    if not student:
        messages.error(request, 'Student not found.')
        return redirect('student_list')

    history = db_get_approval_history(student_id)
    page = request.GET.get('page', '').strip()

    return render(request, 'student/approval_history.html', {
        'student': student,
        'history': history,
        'page': page,
    })


# AJAX ENDPOINTS

def search_students_api(request):
    # """
    # AJAX endpoint for real-time search.
    # Returns JSON with matching students.
    # GET parameter: ?q=search_keyword
    # """
    search_keyword = request.GET.get('q', '').strip()

    # Require minimum 1 character
    if len(search_keyword) < 1:
        return JsonResponse({'results': []})

    # Get matching students
    all_students = db_get_all_students(search_keyword=search_keyword)

    # Limit to first 20 results for performance
    results = []
    for student in all_students[:20]:
        results.append({
            'id': student['id'],
            'name': student['name'],
            'email': student['email'],
            'phone': student['phone'],
            'course': student['course'],
            'approval_status': student['approval_status'],
            'approved_by': student['approved_by'],
        })

    return JsonResponse({'results': results})


def get_courses_api(request):
    # """
    # AJAX endpoint to fetch all active courses.
    # Returns JSON array with all courses.
    # """
    courses = db_get_courses()

    results = []
    for course in courses:
        results.append({
            'course_id': course['course_id'],
            'course_name': course['course_name'],
            'course_code': course['course_code'],
            'status': course['status'],
        })

    return JsonResponse({'courses': results})


# API ENDPOINTS

def api_add_student(request):
    # """
    # API endpoint to add a new student.
    # Accepts multipart/form-data: name, phone, email, course (course_id), student_image.
    # Returns JSON with success/error.
    # """
    if request.method != 'POST':
        return JsonResponse({'error': 'Method not allowed'}, status=405)

    name = request.POST.get('name', '').strip()
    phone = request.POST.get('phone', '').strip()
    email = request.POST.get('email', '').strip()
    course = request.POST.get('course', '').strip()
    image_file = request.FILES.get('student_image')

    # Validate form
    has_error, errors = _validate_form(request, name, phone, email, course, api_mode=True)
    if has_error:
        return JsonResponse({'error': 'Validation failed', 'details': errors}, status=400)

    # Validate image
    image_error, image_msg = _validate_student_image(request, image_file, api_mode=True)
    if image_error:
        return JsonResponse({'error': image_msg}, status=400)

    # Save image if provided
    image_path = _save_student_image(image_file) if image_file else None

    # Add student
    try:
        student_id = db_add_student(name, phone, email, int(course), image_path)
        student = db_get_student_by_id(student_id)
        return JsonResponse({
            'success': True,
            'message': f'Student "{name}" added successfully.',
            'student': {
                'id': student['id'],
                'name': student['name'],
                'phone': student['phone'],
                'email': student['email'],
                'course_id': student['course_id'],
                'course': student['course'],
                'course_code': student['course_code'],
                'student_image': student['student_image'],
                'approval_status': student['approval_status'],
            }
        })
    except Exception as e:
        return JsonResponse({'error': 'Failed to add student', 'details': str(e)}, status=500)


def api_update_student(request, student_id):
    # """
    # API endpoint to update an existing student.
    # Accepts multipart/form-data: name, phone, email, course (course_id), student_image.
    # Returns JSON with success/error.
    # """
    if request.method != 'POST':
        return JsonResponse({'error': 'Method not allowed'}, status=405)

    # Check if student exists
    student = db_get_student_by_id(student_id)
    if not student:
        return JsonResponse({'error': 'Student not found'}, status=404)

    name = request.POST.get('name', '').strip()
    phone = request.POST.get('phone', '').strip()
    email = request.POST.get('email', '').strip()
    course = request.POST.get('course', '').strip()
    image_file = request.FILES.get('student_image')

    # Validate form
    has_error, errors = _validate_form(request, name, phone, email, course, exclude_id=student_id, api_mode=True)
    if has_error:
        return JsonResponse({'error': 'Validation failed', 'details': errors}, status=400)

    # Validate image
    image_error, image_msg = _validate_student_image(request, image_file, api_mode=True)
    if image_error:
        return JsonResponse({'error': image_msg}, status=400)

    # Save image if provided
    image_path = _save_student_image(image_file) if image_file else None

    # Update student
    try:
        success = db_update_student(student_id, name, phone, email, int(course), image_path)
        if success:
            updated_student = db_get_student_by_id(student_id)
            return JsonResponse({
                'success': True,
                'message': f'Student "{name}" updated successfully.',
                'student': {
                    'id': updated_student['id'],
                    'name': updated_student['name'],
                    'phone': updated_student['phone'],
                    'email': updated_student['email'],
                    'course_id': updated_student['course_id'],
                    'course': updated_student['course'],
                    'course_code': updated_student['course_code'],
                    'student_image': updated_student['student_image'],
                    'approval_status': updated_student['approval_status'],
                }
            })
        else:
            return JsonResponse({'error': 'Failed to update student'}, status=500)
    except Exception as e:
        return JsonResponse({'error': 'Failed to update student', 'details': str(e)}, status=500)


def api_approve_student(request, student_id):
    # """
    # API endpoint to approve a student.
    # Accepts POST with optional remarks and approved_by.
    # """
    if request.method != 'POST':
        return JsonResponse({'error': 'Method not allowed'}, status=405)

    student = db_get_student_by_id(student_id)
    if not student:
        return JsonResponse({'error': 'Student not found'}, status=404)

    if student['approval_status'] != 'Pending':
        return JsonResponse({'error': f'Student is already {student["approval_status"]}.'}, status=400)

    remarks = request.POST.get('remarks', '').strip()
    approved_by = request.POST.get('approved_by', '').strip() or 'Admin'

    try:
        db_approve_student(student_id, approved_by=approved_by, remarks=remarks)
        updated_student = db_get_student_by_id(student_id)
        return JsonResponse({
            'success': True,
            'message': f'Student "{updated_student["name"]}" approved successfully.',
            'student': {
                'id': updated_student['id'],
                'approval_status': updated_student['approval_status'],
                'approved_by': updated_student['approved_by'],
                'remarks': updated_student['remarks'],
                'approved_date': updated_student['approved_date'].isoformat() if updated_student['approved_date'] else None,
            }
        })
    except Exception as e:
        return JsonResponse({'error': 'Failed to approve student', 'details': str(e)}, status=500)


def api_reject_student(request, student_id):
    # """
    # API endpoint to reject a student.
    # Accepts POST with optional remarks and approved_by.
    # """
    if request.method != 'POST':
        return JsonResponse({'error': 'Method not allowed'}, status=405)

    student = db_get_student_by_id(student_id)
    if not student:
        return JsonResponse({'error': 'Student not found'}, status=404)

    if student['approval_status'] != 'Pending':
        return JsonResponse({'error': f'Student is already {student["approval_status"]}.'}, status=400)

    remarks = request.POST.get('remarks', '').strip()
    approved_by = request.POST.get('approved_by', '').strip() or 'Admin'

    try:
        db_reject_student(student_id, approved_by=approved_by, remarks=remarks)
        updated_student = db_get_student_by_id(student_id)
        return JsonResponse({
            'success': True,
            'message': f'Student "{updated_student["name"]}" rejected successfully.',
            'student': {
                'id': updated_student['id'],
                'approval_status': updated_student['approval_status'],
                'approved_by': updated_student['approved_by'],
                'remarks': updated_student['remarks'],
                'approved_date': updated_student['approved_date'].isoformat() if updated_student['approved_date'] else None,
            }
        })
    except Exception as e:
        return JsonResponse({'error': 'Failed to reject student', 'details': str(e)}, status=500)


def api_get_students(request):
    # """
    # API endpoint to get student list.
    # Supports query param: search (optional).
    # Returns JSON array of students.
    # """
    search_keyword = request.GET.get('search', '').strip()
    all_students = db_get_all_students(search_keyword=search_keyword)

    results = []
    for student in all_students:
        results.append({
            'id': student['id'],
            'name': student['name'],
            'phone': student['phone'],
            'email': student['email'],
            'course_id': student['course_id'],
            'course': student['course'],
            'course_code': student['course_code'],
            'student_image': student['student_image'],
            'created_date': student['created_date'].isoformat() if student['created_date'] else None,
            'updated_date': student['updated_date'].isoformat() if student['updated_date'] else None,
            'approval_status': student['approval_status'],
            'approved_by': student['approved_by'],
            'remarks': student['remarks'],
            'approved_date': student['approved_date'].isoformat() if student['approved_date'] else None,
        })

    return JsonResponse({'students': results})






def dashboard_view(request):
    # """
    # Renders the analytics dashboard.
    # """
    stats = db_get_dashboard_stats()
    
    # Separate the data so the template is easy to build
    grand_total_row = stats[-1] if stats else None  # The last row is our Grand Total
    course_wise_rows = stats[:-1] if stats else []  # Everything else is course-wise
    
    return render(request, 'student/dashboard.html', {
        'grand_total': grand_total_row,
        'course_stats': course_wise_rows
    })






def global_approval_history(request):
    # Capture filters from the URL (e.g., ?q=John&action=APPROVE)
    search = request.GET.get('q', '').strip()
    action = request.GET.get('action', '').strip()
    date_from = request.GET.get('date_from', '').strip()
    date_to = request.GET.get('date_to', '').strip()

    # Fetch the filtered data from the database
    history_logs = db_get_global_approval_history(search, action, date_from, date_to)

    return render(request, 'student/global_approval_history.html', {
        'history_logs': history_logs,
        'search': search,
        'action': action,
        'date_from': date_from,
        'date_to': date_to,
    })



