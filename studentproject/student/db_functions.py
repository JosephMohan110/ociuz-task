
from django.db import connection, transaction


# PRIVATE HELPERS

def _fetchall(cursor):
    # """Convert cursor result-set to a list of dicts."""
    cols = [c[0] for c in cursor.description]
    return [dict(zip(cols, row)) for row in cursor.fetchall()]


def _fetchone(cursor):
    # """Convert a single cursor row to a dict, or return None."""
    row = cursor.fetchone()
    if row is None:
        return None
    cols = [c[0] for c in cursor.description]
    return dict(zip(cols, row))


# READ — list & detail

def db_get_all_students(search_keyword=''):
    # """
    # Return every student joined with their latest approval status.
    # When search_keyword is given, filters across name / phone / email / course.
    # Returns a list of dicts ordered by id DESC (newest first).
    # """
    with connection.cursor() as cur:
        cur.execute(
            "SELECT * FROM fnGetStudentsWithCurrentCourse(%s)",
            [search_keyword or None]
        )
        return _fetchall(cur)


def db_get_student_by_id(student_id):
    # """
    # Return one student (with latest approval status and image path) or None.
    # """
    with connection.cursor() as cur:
        cur.execute(
            "SELECT * FROM fnGetStudentById(%s)",
            [student_id]
        )
        return _fetchone(cur)


# READ — email uniqueness check

def db_email_exists(email, exclude_id=None):
    # """
    # Return True if email is already taken.
    # Pass exclude_id when editing so the student's own email is not flagged.
    # """
    with connection.cursor() as cur:
        if exclude_id:
            cur.execute(
                "SELECT COUNT(*) FROM students WHERE email = %s AND id != %s",
                [email, exclude_id]
            )
        else:
            cur.execute(
                "SELECT COUNT(*) FROM students WHERE email = %s",
                [email]
            )
        return cur.fetchone()[0] > 0


# CREATE

def db_add_student(name, phone, email, course_id, student_image_path=None):
    with transaction.atomic():
        with connection.cursor() as cur:
            cur.execute(
                "SELECT fnAddStudent(%s, %s, %s, %s, %s)",
                [name, phone, email, course_id, student_image_path]
            )
            return cur.fetchone()[0]
        


# UPDATE

def db_update_student(student_id, name, phone, email, course_id, student_image_path=None):
    # """
    # UPDATE core student fields.
    # ANY edit automatically resets the student to 'Pending' status
    # so they go back into the approval queue for re-review.
    # Returns True if the student row was updated, False otherwise.
    # """
    with transaction.atomic():
        with connection.cursor() as cur:
            cur.execute(
                "SELECT fnEditStudent(%s, %s, %s, %s, %s, %s, NULL, NULL, NULL)",
                [student_id, name, phone, email, course_id, student_image_path]
            )
            return cur.fetchone()[0]





# delete new code...
def db_delete_student(student_id, deleted_by='Admin'):
    # """
    # SOFT DELETE a student. Keeps history intact.
    # Returns True if the student row was updated.
    # """
    with connection.cursor() as cur:
        cur.execute(
            "SELECT fnDeleteStudent(%s, %s)",
            [student_id, deleted_by]
        )
        return cur.fetchone()[0]


def db_restore_student(student_id, restored_by='Admin'):
    # """
    # Restores a softly deleted student back to the active list.
    # """
    with connection.cursor() as cur:
        cur.execute(
            "SELECT fnRestoreStudent(%s, %s)",
            [student_id, restored_by]
        )
        return cur.fetchone()[0]

def db_get_deleted_students():
    # """
    # Fetch all students currently marked as deleted.
    # """
    with connection.cursor() as cur:
        cur.execute("SELECT * FROM fnGetDeletedStudents()")
        return _fetchall(cur)




# new code for eject and approve with new procedure

def db_process_student_approval(student_id, action, performed_by='Admin', remarks=''):
    # """
    # Calls the spProcessStudentApproval stored procedure.
    # :param action: Must be 'APPROVE' or 'REJECT'
    # :returns: Dictionary with 'status_code' and 'message'
    # """
    with connection.cursor() as cur:
        # We query it just like a table because of the OUT parameters
        cur.execute(
            "SELECT o_status_code, o_message FROM spProcessStudentApproval(%s, %s, %s, %s)",
            [student_id, action, performed_by, remarks]
        )
        row = cur.fetchone()
        
        return {
            'status_code': row[0],
            'message': row[1]
        }




# APPROVAL HISTORY  (full audit trail)

def db_get_approval_history(student_id):
    # """
    # Return every approval/rejection event for a student, newest first.
    # Each dict: id, approval_status, approved_by, remarks, approved_date.
    # """
    with connection.cursor() as cur:
        cur.execute(
            "SELECT * FROM fnGetApprovalHistory(%s)",
            [student_id]
        )
        return _fetchall(cur)


# COURSES

def db_get_courses():
    # """
    # Return all active courses.
    # Each dict: course_id, course_name, course_code, status.
    # """
    with connection.cursor() as cur:
        cur.execute(
            "SELECT * FROM fnGetCourses()"
        )
        return _fetchall(cur)


def db_course_exists(course_id):
    # """
    # Return True if an active course exists for the given course_id.
    # """
    with connection.cursor() as cur:
        cur.execute(
            "SELECT COUNT(*) FROM tblCourse WHERE course_id = %s AND status = 'Active'",
            [course_id]
        )
        return cur.fetchone()[0] > 0




# ==========================================
# DASHBOARD / REPORTING
# ==========================================
def db_get_dashboard_stats():
    # """
    # Fetches the pre-calculated dashboard statistics from vwStudentDashboard.
    # Returns a list of dicts. The last dict in the list is always 'Grand Total'.
    # """
    with connection.cursor() as cur:
        cur.execute("SELECT * FROM vwStudentDashboard")
        return _fetchall(cur)
    




# ==========================================
# AUDIT & HISTORY LOGS
# ==========================================
def db_get_global_approval_history(search='', action='', date_from='', date_to=''):
    # """
    # Fetch global approval history with optional filters.
    # """
    with connection.cursor() as cur:
        cur.execute(
            "SELECT * FROM fnGetGlobalApprovalHistory(%s, %s, %s, %s)",
            [search or None, action or None, date_from or None, date_to or None]
        )
        return _fetchall(cur)
    







# ==========================================
# MODULE 1: ERP DOCUMENT MASTER
# ==========================================

def db_get_all_documents():
    # """
    # Fetch all active ERP Document Configurations dynamically.
    # Returns a list of dicts.
    # """
    with connection.cursor() as cur:
        cur.execute("SELECT * FROM fnGetDocumentMasters()")
        return _fetchall(cur)

def db_generate_document_number(document_code):
    # """
    # Dynamically generates the next sequence number for a module (e.g., ADM-0001).
    # Runs inside a transaction to ensure database row-locking works correctly.
    # """
    with transaction.atomic():
        with connection.cursor() as cur:
            cur.execute("SELECT fnGenerateNextDocumentNumber(%s)", [document_code])
            return cur.fetchone()[0]

def db_check_approval_required(document_code):
    # """
    # Dynamically checks if a specific module requires workflow approval.
    # Calls the database function to avoid raw table queries in Python.
    # """
    with connection.cursor() as cur:
        cur.execute("SELECT fnCheckApprovalRequired(%s)", [document_code])
        row = cur.fetchone()
        return row[0] if row else True



# ==========================================
# MODULE 2: ERP STATUS MANAGEMENT
# ==========================================

def db_get_all_statuses():
    # """
    # Fetch all active workflow statuses.
    # Used by frontend to build dynamic dropdowns or filter tabs.
    # """
    with connection.cursor() as cur:
        cur.execute("SELECT * FROM fnGetAllStatuses()")
        return _fetchall(cur)


def db_get_initial_status():
    # """
    # Returns the starting status code for any newly created record.
    # Hardcoded string removed; the DB function determines the lowest sequence.
    # """
    with connection.cursor() as cur:
        cur.execute("SELECT fnGetInitialStatus()")
        row = cur.fetchone()
        return row[0] if row else None


def db_get_next_status(current_status_code):
    # """
    # Queries the dynamic workflow engine to find the next sequential status.
    # Eliminates hardcoded `if status == 'Pending' -> 'Approved'` logic.
    # """
    with connection.cursor() as cur:
        cur.execute("SELECT fnGetNextWorkflowStatus(%s)", [current_status_code])
        row = cur.fetchone()
        return row[0] if row else None
    




# ==========================================
# MODULE 3: ERP WORKFLOW CONFIGURATION
# ==========================================

def db_get_available_actions(doc_code, current_status_code, role_name):
    # """
    # Returns a list of valid actions (buttons) a user can perform.
    # Each dict contains: action_name, next_status_code, color_code.
    # """
    with connection.cursor() as cur:
        cur.execute(
            "SELECT * FROM fnGetAvailableActions(%s, %s, %s)",
            [doc_code, current_status_code, role_name]
        )
        return _fetchall(cur)

def db_validate_workflow_transition(doc_code, current_status_code, action_name, role_name):
    # """
    # Validates if an action is allowed and returns the new status code.
    # Throws a database error if the transition is illegal.
    # """
    with connection.cursor() as cur:
        cur.execute(
            "SELECT fnProcessWorkflowAction(%s, %s, %s, %s)",
            [doc_code, current_status_code, action_name, role_name]
        )
        row = cur.fetchone()
        return row[0] if row else None
    




# ==========================================
# MODULE 4: DYNAMIC DOCUMENT GENERATION
# ==========================================

def db_generate_document_number(document_code):
    # """
    # Calls spGenerateDocumentNumber to safely generate a unique, sequential ID.
    # CRITICAL: This MUST be wrapped in transaction.atomic(). 
    # The 'FOR UPDATE' lock in Postgres only releases when the Django transaction commits.
    # """
    with transaction.atomic():
        with connection.cursor() as cur:
            cur.execute("SELECT spGenerateDocumentNumber(%s)", [document_code])
            row = cur.fetchone()
            return row[0] if row else None
        






# ==========================================
# MODULE 5: GENERIC APPROVAL ENGINE
# ==========================================

def db_process_document_action(doc_code, record_id, current_status, action_name, role_name, performed_by, remarks=''):
    # """
    # The universal function for transitioning ANY document in the ERP.
    # Returns the 'new_status_code' if successful.
    # Raises an Exception if the workflow rules forbid the action.
    # """
    with transaction.atomic():  # Wrapped in atomic to ensure the history insert is tied to the parent update
        with connection.cursor() as cur:
            try:
                cur.execute(
                    "SELECT spProcessDocumentAction(%s, %s, %s, %s, %s, %s, %s)",
                    [doc_code, str(record_id), current_status, action_name, role_name, performed_by, remarks]
                )
                row = cur.fetchone()
                return row[0] if row else None
            except Exception as e:
                # Catch Postgres RAISE EXCEPTION errors and pass them to Django
                raise Exception(str(e).split('\n')[0]) # Cleans up the Postgres error string
            







# ==========================================
# MODULE 6: ERP AUDIT & HISTORY TRACKING
# ==========================================

def get_client_ip(request):
    # """Utility to extract the user's IP Address from the Django request"""
    x_forwarded_for = request.META.get('HTTP_X_FORWARDED_FOR')
    if x_forwarded_for:
        ip = x_forwarded_for.split(',')[0]
    else:
        ip = request.META.get('REMOTE_ADDR')
    return ip



def db_set_audit_context(cursor, user_name, ip_address):
    # """
    # Passes the Django User and IP to PostgreSQL for the trigger to use.
    # This bridges the gap between Web Requests and Database Triggers.
    # """
    cursor.execute("SET LOCAL erp.current_user = %s", [user_name])
    cursor.execute("SET LOCAL erp.current_ip = %s", [ip_address])



def db_get_document_history(document_code, record_id):
    # """
    # Fetches the complete lifecycle audit trail of any specific record.
    # Delegates the query to PostgreSQL to maintain pure ERP architecture.
    # """
    with connection.cursor() as cur:
        cur.execute("SELECT * FROM fnGetDocumentHistory(%s, %s)", [document_code, str(record_id)])
        return _fetchall(cur)





# ==========================================
# MODULE 8: LEAVE REQUEST MODULE
# ==========================================

def db_create_leave_request(employee_name, leave_type, start_date, end_date, reason, created_by='System'):
    # """
    # Creates a new leave request. Document numbering and initial status 
    # are handled entirely by PostgreSQL dynamically.
    # """
    with transaction.atomic():
        with connection.cursor() as cur:
            cur.execute(
                "SELECT fnCreateLeaveRequest(%s, %s, %s, %s, %s, %s)",
                [employee_name, leave_type, start_date, end_date, reason, created_by]
            )
            return cur.fetchone()[0]

def db_edit_leave_request(leave_id, employee_name, leave_type, start_date, end_date, reason, edited_by='System'):
    # """
    # Edits a leave request. Resets the workflow status automatically via DB logic.
    # """
    with transaction.atomic():
        with connection.cursor() as cur:
            cur.execute(
                "SELECT fnEditLeaveRequest(%s, %s, %s, %s, %s, %s, %s)",
                [leave_id, employee_name, leave_type, start_date, end_date, reason, edited_by]
            )
            return cur.fetchone()[0]

def db_get_leave_requests(search_keyword=''):
    # """
    # Fetches all active leave requests with their dynamic history tracking.
    # """
    with connection.cursor() as cur:
        cur.execute("SELECT * FROM fnGetLeaveRequests(%s)", [search_keyword or None])
        return _fetchall(cur)