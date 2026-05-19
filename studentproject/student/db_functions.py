
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
    # """
    # INSERT a new student and an initial 'Pending' approval record.
    # Both writes happen inside one atomic transaction.
    # Returns the new student id.
    # """
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