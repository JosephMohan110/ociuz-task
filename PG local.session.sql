

SELECT * from students;
SELECT * from tblCourse;
SELECT * from studentapproval;
SELECT * from tblStudentCourse;
SELECT * from tblAuditLog;

CREATE TABLE IF NOT EXISTS students (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100),
    age INT,
    phone VARCHAR(15),
    email VARCHAR(100),
    address TEXT,
    dob DATE,
    course_id INT,
    student_image VARCHAR(255),
    status VARCHAR(20),
    created_date TIMESTAMP DEFAULT NOW(),
    updated_date TIMESTAMP DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS tblCourse (
    course_id SERIAL PRIMARY KEY,
    course_name VARCHAR(100) NOT NULL UNIQUE,
    course_code VARCHAR(20) NOT NULL UNIQUE,
    status VARCHAR(20) NOT NULL DEFAULT 'Active'
);

CREATE TABLE IF NOT EXISTS studentapproval (
    id SERIAL PRIMARY KEY,
    student_id INT REFERENCES students(id),
    approval_status VARCHAR(50),
    approved_by VARCHAR(100),
    approved_date TIMESTAMP,
    remarks TEXT,
    created_date TIMESTAMP DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS tblStudentCourse (
    id SERIAL PRIMARY KEY,
    student_id INT REFERENCES students(id) ON DELETE CASCADE,
    course_id INT REFERENCES tblCourse(course_id),
    enrollment_date DATE DEFAULT CURRENT_DATE,
    status VARCHAR(20) DEFAULT 'Active',
    created_date TIMESTAMP DEFAULT NOW(),
    updated_date TIMESTAMP DEFAULT NOW(),
    UNIQUE(student_id)
);


-- ==========================================
-- TABLE: Audit Log
-- ==========================================
CREATE TABLE IF NOT EXISTS tblAuditLog (
    id SERIAL PRIMARY KEY,
    module_name VARCHAR(100) NOT NULL,
    action_type VARCHAR(50) NOT NULL, -- INSERT, UPDATE, DELETE, APPROVE, REJECT
    old_value JSONB,                  -- State before the action
    new_value JSONB,                  -- State after the action
    performed_by VARCHAR(100),
    performed_date TIMESTAMP DEFAULT NOW()
);

SELECT * from tblauditlog
-- Add foreign key constraint to students table (if not exists)
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.table_constraints 
        WHERE constraint_name = 'fk_students_course'
    ) THEN
        ALTER TABLE students
        ADD CONSTRAINT fk_students_course FOREIGN KEY (course_id) REFERENCES tblCourse(course_id);
    END IF;
END;
$$;

-- ==========================================
-- ALTER TABLE - Add columns if not exist
-- ==========================================

ALTER TABLE students
ADD COLUMN IF NOT EXISTS phone VARCHAR(15),
ADD COLUMN IF NOT EXISTS email VARCHAR(100),
ADD COLUMN IF NOT EXISTS address TEXT,
ADD COLUMN IF NOT EXISTS dob DATE,
ADD COLUMN IF NOT EXISTS student_image VARCHAR(255),
ADD COLUMN IF NOT EXISTS status VARCHAR(20),
ADD COLUMN IF NOT EXISTS created_date TIMESTAMP DEFAULT NOW(),
ADD COLUMN IF NOT EXISTS updated_date TIMESTAMP DEFAULT NOW();

-- Migrate existing course data if needed
DO $$
BEGIN
    IF EXISTS (
        SELECT 1
        FROM information_schema.columns
        WHERE table_name = 'students'
          AND column_name = 'course'
    ) THEN
        UPDATE students s
        SET course_id = c.course_id
        FROM tblCourse c
        WHERE s.course = c.course_name
          AND s.course_id IS NULL;

        ALTER TABLE students
        DROP COLUMN IF EXISTS course;
    END IF;
END;
$$;

-- ==========================================
-- INSERT DATA
-- ==========================================

INSERT INTO tblCourse (course_name, course_code, status) VALUES
    ('Computer Science', 'CS101', 'Active'),
    ('Information Technology', 'IT102', 'Active'),
    ('Mechanical Engineering', 'ME103', 'Active'),
    ('Electrical Engineering', 'EE104', 'Active'),
    ('Civil Engineering', 'CE105', 'Active'),
    ('Electronics & Communication', 'EC106', 'Active'),
    ('Biotechnology', 'BT107', 'Active'),
    ('Chemical Engineering', 'CH108', 'Active'),
    ('Architecture', 'AR109', 'Active'),
    ('Business Administration', 'BA110', 'Active')
ON CONFLICT (course_code) DO NOTHING;

INSERT INTO tblCourse (course_name, course_code, status) VALUES
    ('Thrissur Jobs', 'TH222', 'Active')
ON CONFLICT (course_code) DO NOTHING;

INSERT INTO tblStudentCourse (student_id, course_id, enrollment_date, status, created_date, updated_date)
SELECT id, course_id, CURRENT_DATE, 'Active', NOW(), NOW()
FROM students
WHERE course_id IS NOT NULL
ON CONFLICT (student_id) DO NOTHING;

-- ==========================================
-- DELETE DATA (Keep tblCourse, delete others)
-- ==========================================

-- Delete from dependent tables first (due to foreign key constraints)
DELETE FROM studentapproval;
DELETE FROM tblStudentCourse;
DELETE FROM students;

-- ==========================================
-- FUNCTIONS
-- ==========================================

DROP FUNCTION IF EXISTS fnGetCourses();
CREATE OR REPLACE FUNCTION fnGetCourses()
RETURNS TABLE(
    course_id INT,
    course_name VARCHAR,
    course_code VARCHAR,
    status VARCHAR
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        tblCourse.course_id AS course_id,
        tblCourse.course_name AS course_name,
        tblCourse.course_code AS course_code,
        tblCourse.status AS status
    FROM tblCourse
    WHERE tblCourse.status = 'Active'
    ORDER BY tblCourse.course_name;
END;
$$ LANGUAGE plpgsql;

-- ==========================================
-- FUNCTION: Approve Student
-- ==========================================
DROP FUNCTION IF EXISTS fnApproveStudent(INT, VARCHAR, TEXT);
CREATE OR REPLACE FUNCTION fnApproveStudent(
    p_student_id INT,
    p_approved_by VARCHAR,
    p_remarks TEXT DEFAULT NULL
)
RETURNS BOOLEAN AS $$
BEGIN
    INSERT INTO studentapproval (
        student_id, approval_status, approved_by,
        approved_date, remarks, created_date
    )
    VALUES (
        p_student_id, 'Approved', p_approved_by,
        NOW(), COALESCE(p_remarks, ''), NOW()
    );

    UPDATE students
    SET updated_date = NOW()
    WHERE id = p_student_id;

    RETURN TRUE;
END;
$$ LANGUAGE plpgsql;

-- ==========================================
-- FUNCTION: Get Approved Students
-- ==========================================
DROP FUNCTION IF EXISTS fnGetApprovedStudents();
CREATE OR REPLACE FUNCTION fnGetApprovedStudents()
RETURNS TABLE(
    student_id INT,
    student_name VARCHAR,
    course_name VARCHAR,
    phone_number VARCHAR,
    email_address VARCHAR,
    approval_status VARCHAR,
    approved_by VARCHAR
) AS $$  
BEGIN
    RETURN QUERY
    SELECT 
        s.id,
        s.name,
        COALESCE(c.course_name, 'Unknown'),
        s.phone,
        s.email,
        a.approval_status,
        a.approved_by
    FROM students s
    LEFT JOIN tblStudentCourse sc ON s.id = sc.student_id AND sc.status = 'Active'
    LEFT JOIN tblCourse c ON sc.course_id = c.course_id
    LEFT JOIN LATERAL (
        SELECT sa.approval_status, sa.approved_by
        FROM studentapproval sa
        WHERE sa.student_id = s.id
        ORDER BY sa.id DESC
        LIMIT 1
    ) a ON TRUE;
END;
$$ LANGUAGE plpgsql;

-- ==========================================
-- FUNCTION: Update Student Course
-- ==========================================
DROP FUNCTION IF EXISTS fnUpdateStudentCourse(INT, INT);
CREATE OR REPLACE FUNCTION fnUpdateStudentCourse(
    p_student_id INT,
    p_course_id INT
)
RETURNS BOOLEAN AS $$
BEGIN
    UPDATE tblStudentCourse
    SET course_id = p_course_id, updated_date = NOW()
    WHERE student_id = p_student_id;
    
    IF NOT FOUND THEN
        INSERT INTO tblStudentCourse (student_id, course_id, status, created_date, updated_date)
        VALUES (p_student_id, p_course_id, 'Active', NOW(), NOW());
    END IF;
    
    RETURN TRUE;
END;
$$ LANGUAGE plpgsql;

-- ==========================================
-- FUNCTION: Edit Student
-- ==========================================
DROP FUNCTION IF EXISTS fnEditStudent(INT, VARCHAR, VARCHAR, VARCHAR, INT, INT, TEXT, DATE);
CREATE OR REPLACE FUNCTION fnEditStudent(
    p_student_id INT,
    p_name VARCHAR,
    p_phone VARCHAR,
    p_email VARCHAR,
    p_course_id INT,
    p_student_image VARCHAR DEFAULT NULL,
    p_age INT DEFAULT NULL,
    p_address TEXT DEFAULT NULL,
    p_dob DATE DEFAULT NULL
)
RETURNS BOOLEAN AS $$
DECLARE
    v_rows_affected INT;
BEGIN
    UPDATE students 
    SET 
        name = COALESCE(p_name, name),
        age = COALESCE(p_age, age),
        phone = COALESCE(p_phone, phone),
        email = COALESCE(p_email, email),
        address = COALESCE(p_address, address),
        dob = COALESCE(p_dob, dob),
        student_image = COALESCE(p_student_image, student_image),
        updated_date = NOW()
    WHERE id = p_student_id;
    
    GET DIAGNOSTICS v_rows_affected = ROW_COUNT;
    
    -- Update course enrollment if course_id provided
    IF p_course_id IS NOT NULL THEN
        PERFORM fnUpdateStudentCourse(p_student_id, p_course_id);
    END IF;
    
    IF v_rows_affected > 0 THEN
        INSERT INTO studentapproval (
            student_id, approval_status, approved_by, remarks, approved_date, created_date
        ) VALUES (
            p_student_id, 'Pending', 'System', 'Updated - Pending re-approval', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP
        );
    END IF;
    
    RETURN v_rows_affected > 0;
END;
$$ LANGUAGE plpgsql;

-- ==========================================
-- FUNCTION: Delete Student
-- ==========================================
DROP FUNCTION IF EXISTS fnDeleteStudent(INT);
CREATE OR REPLACE FUNCTION fnDeleteStudent(
    p_student_id INT
)
RETURNS BOOLEAN AS $$
DECLARE
    v_student_name VARCHAR;
    v_rows_affected INT;
BEGIN
    SELECT name INTO v_student_name 
    FROM students 
    WHERE id = p_student_id;
    
    IF v_student_name IS NULL THEN
        RETURN FALSE;
    END IF;
    
    DELETE FROM studentapproval 
    WHERE student_id = p_student_id;
    
    DELETE FROM students 
    WHERE id = p_student_id;
    
    GET DIAGNOSTICS v_rows_affected = ROW_COUNT;
    
    RETURN v_rows_affected > 0;
END;
$$ LANGUAGE plpgsql;

-- ==========================================
-- FUNCTION: Get Students with Current Course
-- ==========================================
DROP FUNCTION IF EXISTS fnGetStudentsWithCurrentCourse(VARCHAR);
CREATE OR REPLACE FUNCTION fnGetStudentsWithCurrentCourse(
    p_search VARCHAR DEFAULT NULL
)
RETURNS TABLE(
    id INT,
    name VARCHAR,
    phone VARCHAR,
    email VARCHAR,
    course_id INT,
    course VARCHAR,
    course_code VARCHAR,
    student_image VARCHAR,
    created_date TIMESTAMP,
    updated_date TIMESTAMP,
    approval_status VARCHAR,
    approved_by VARCHAR,
    remarks TEXT,
    approved_date TIMESTAMP
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        s.id,
        s.name,
        s.phone,
        s.email,
        sc.course_id,
        COALESCE(c.course_name, 'Not assigned'),
        COALESCE(c.course_code, ''),
        s.student_image,
        s.created_date,
        s.updated_date,
        COALESCE(a.approval_status, 'Pending'),
        COALESCE(a.approved_by, 'System'),
        COALESCE(a.remarks, ''),
        a.approved_date::timestamp without time zone
    FROM students s
    LEFT JOIN tblStudentCourse sc ON s.id = sc.student_id AND sc.status = 'Active'
    LEFT JOIN tblCourse c ON sc.course_id = c.course_id
    LEFT JOIN LATERAL (
        SELECT sa.approval_status, sa.approved_by, sa.remarks, sa.approved_date
        FROM studentapproval sa
        WHERE sa.student_id = s.id
        ORDER BY sa.id DESC
        LIMIT 1
    ) a ON TRUE
    WHERE p_search IS NULL
       OR s.name ILIKE '%' || p_search || '%'
       OR s.phone ILIKE '%' || p_search || '%'
       OR s.email ILIKE '%' || p_search || '%'
       OR c.course_name ILIKE '%' || p_search || '%'
    ORDER BY s.id DESC;
END;
$$ LANGUAGE plpgsql;

-- ==========================================
-- FUNCTION: Get Student by ID
-- ==========================================
DROP FUNCTION IF EXISTS fnGetStudentById(INT);
CREATE OR REPLACE FUNCTION fnGetStudentById(
    p_student_id INT
)
RETURNS TABLE(
    id INT,
    name VARCHAR,
    phone VARCHAR,
    email VARCHAR,
    course_id INT,
    course VARCHAR,
    course_code VARCHAR,
    student_image VARCHAR,
    created_date TIMESTAMP,
    updated_date TIMESTAMP,
    approval_status VARCHAR,
    approved_by VARCHAR,
    remarks TEXT,
    approved_date TIMESTAMP
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        s.id,
        s.name,
        s.phone,
        s.email,
        sc.course_id,
        COALESCE(c.course_name, 'Not assigned'),
        COALESCE(c.course_code, ''),
        s.student_image,
        s.created_date,
        s.updated_date,
        COALESCE(a.approval_status, 'Pending'),
        COALESCE(a.approved_by, 'System'),
        COALESCE(a.remarks, ''),
        a.approved_date::timestamp without time zone
    FROM students s
    LEFT JOIN tblStudentCourse sc ON s.id = sc.student_id AND sc.status = 'Active'
    LEFT JOIN tblCourse c ON sc.course_id = c.course_id
    LEFT JOIN LATERAL (
        SELECT sa.approval_status, sa.approved_by, sa.remarks, sa.approved_date
        FROM studentapproval sa
        WHERE sa.student_id = s.id
        ORDER BY sa.id DESC
        LIMIT 1
    ) a ON TRUE
    WHERE s.id = p_student_id
    ORDER BY s.id DESC
    LIMIT 1;
END;
$$ LANGUAGE plpgsql;

==========================================
VIEW TABLE DATA (Uncomment to use)
==========================================

SELECT * FROM students;
SELECT * FROM tblCourse;
SELECT * FROM studentapproval;
SELECT * FROM tblStudentCourse;

SELECT * FROM fnGetCourses();
SELECT * FROM fnGetApprovedStudents();
SELECT * FROM fnGetStudentsWithCurrentCourse(NULL);
SELECT * FROM fnGetStudentById(1);



CREATE OR REPLACE FUNCTION fnAddStudent(
    p_name VARCHAR,
    p_phone VARCHAR,
    p_email VARCHAR,
    p_course_id INT,
    p_student_image VARCHAR DEFAULT NULL
)
RETURNS INT AS $$
DECLARE
    new_student_id INT;
BEGIN
    INSERT INTO students (
        name,
        phone,
        email,
        course_id,
        student_image,
        created_date,
        updated_date
    )
    VALUES (
        p_name,
        p_phone,
        p_email,
        p_course_id,
        p_student_image,
        NOW(),
        NOW()
    )
    RETURNING id INTO new_student_id;

    INSERT INTO tblStudentCourse (
        student_id,
        course_id,
        enrollment_date,
        status,
        created_date,
        updated_date
    )
    VALUES (
        new_student_id,
        p_course_id,
        CURRENT_DATE,
        'Active',
        NOW(),
        NOW()
    );

    INSERT INTO studentapproval (
        student_id,
        approval_status,
        approved_by,
        approved_date,
        remarks,
        created_date
    )
    VALUES (
        new_student_id,
        'Pending',
        'System',
        NOW(),
        'New student added',
        NOW()
    );

    RETURN new_student_id;
END;
$$ LANGUAGE plpgsql;



-- ==========================================
-- TRIGGER FUNCTION: Student Core Operations
-- ==========================================
CREATE OR REPLACE FUNCTION fn_audit_students()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        INSERT INTO tblAuditLog (module_name, action_type, old_value, new_value, performed_by)
        VALUES ('Student Module', 'INSERT', NULL, row_to_json(NEW)::jsonb, 'System');
        RETURN NEW;
        
    ELSIF TG_OP = 'UPDATE' THEN
        INSERT INTO tblAuditLog (module_name, action_type, old_value, new_value, performed_by)
        VALUES ('Student Module', 'UPDATE', row_to_json(OLD)::jsonb, row_to_json(NEW)::jsonb, 'System');
        RETURN NEW;
        
    ELSIF TG_OP = 'DELETE' THEN
        INSERT INTO tblAuditLog (module_name, action_type, old_value, new_value, performed_by)
        VALUES ('Student Module', 'DELETE', row_to_json(OLD)::jsonb, NULL, 'System');
        RETURN OLD;
    END IF;
    
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

-- Attach trigger to students table
DROP TRIGGER IF EXISTS trg_audit_students ON students;
CREATE TRIGGER trg_audit_students
AFTER INSERT OR UPDATE OR DELETE ON students
FOR EACH ROW EXECUTE FUNCTION fn_audit_students();






-- ==========================================
-- TRIGGER FUNCTION: Approval Workflow
-- ==========================================
CREATE OR REPLACE FUNCTION fn_audit_approvals()
RETURNS TRIGGER AS $$
DECLARE
    v_action_type VARCHAR(50);
BEGIN
    -- We only care about tracking when new approval statuses are generated
    IF TG_OP = 'INSERT' THEN
        
        -- Map the table's status to the required Action Type
        IF NEW.approval_status = 'Approved' THEN
            v_action_type := 'APPROVE';
        ELSIF NEW.approval_status = 'Rejected' THEN
            v_action_type := 'REJECT';
        ELSIF NEW.approval_status = 'Pending' THEN
            v_action_type := 'STATUS_PENDING';
        ELSE
            v_action_type := UPPER(NEW.approval_status);
        END IF;

        INSERT INTO tblAuditLog (module_name, action_type, old_value, new_value, performed_by)
        VALUES (
            'Approval Module', 
            v_action_type, 
            NULL, 
            row_to_json(NEW)::jsonb, 
            COALESCE(NEW.approved_by, 'System') -- Captures who actually performed it
        );
        RETURN NEW;
        
    ELSIF TG_OP = 'DELETE' THEN
        -- When a student is deleted, their approval history is cascade-deleted. Track this too.
        INSERT INTO tblAuditLog (module_name, action_type, old_value, new_value, performed_by)
        VALUES ('Approval Module', 'DELETE_HISTORY', row_to_json(OLD)::jsonb, NULL, 'System');
        RETURN OLD;
    END IF;

    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

-- Attach trigger to studentapproval table
DROP TRIGGER IF EXISTS trg_audit_approvals ON studentapproval;
CREATE TRIGGER trg_audit_approvals
AFTER INSERT OR DELETE ON studentapproval
FOR EACH ROW EXECUTE FUNCTION fn_audit_approvals();











-- ==========================================
-- 1. ALTER TABLE: Add Soft Delete Columns
-- ==========================================
ALTER TABLE students
ADD COLUMN IF NOT EXISTS is_deleted BOOLEAN DEFAULT FALSE,
ADD COLUMN IF NOT EXISTS deleted_by VARCHAR(100),
ADD COLUMN IF NOT EXISTS deleted_date TIMESTAMP;


-- ==========================================
-- 2.  Soft Delete Student
-- ==========================================
-- Replaces the old hard delete function. Notice we no longer delete 
-- from studentapproval or tblStudentCourse. We keep the history intact!
DROP FUNCTION IF EXISTS fnDeleteStudent(INT);
CREATE OR REPLACE FUNCTION fnDeleteStudent(
    p_student_id INT,
    p_deleted_by VARCHAR DEFAULT 'Admin'
)
RETURNS BOOLEAN AS $$
DECLARE
    v_rows_affected INT;
BEGIN
    UPDATE students 
    SET 
        is_deleted = TRUE,
        deleted_by = p_deleted_by,
        deleted_date = NOW(),
        updated_date = NOW()
    WHERE id = p_student_id AND is_deleted = FALSE;
    
    GET DIAGNOSTICS v_rows_affected = ROW_COUNT;
    
    -- Optional: Log a "Pending" status indicating the soft delete in approval history
    IF v_rows_affected > 0 THEN
        INSERT INTO studentapproval (
            student_id, approval_status, approved_by, remarks, approved_date, created_date
        ) VALUES (
            p_student_id, 'Deleted', p_deleted_by, 'Student softly deleted from system', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP
        );
    END IF;

    RETURN v_rows_affected > 0;
END;
$$ LANGUAGE plpgsql;


-- ==========================================
-- 3. NEW FUNCTION: Restore Student
-- ==========================================
DROP FUNCTION IF EXISTS fnRestoreStudent(INT, VARCHAR);
CREATE OR REPLACE FUNCTION fnRestoreStudent(
    p_student_id INT,
    p_restored_by VARCHAR DEFAULT 'Admin'
)
RETURNS BOOLEAN AS $$
DECLARE
    v_rows_affected INT;
BEGIN
    UPDATE students 
    SET 
        is_deleted = FALSE,
        deleted_by = NULL,
        deleted_date = NULL,
        updated_date = NOW()
    WHERE id = p_student_id AND is_deleted = TRUE;
    
    GET DIAGNOSTICS v_rows_affected = ROW_COUNT;

    -- Push them back into the Pending queue for re-approval upon restoration
    IF v_rows_affected > 0 THEN
        INSERT INTO studentapproval (
            student_id, approval_status, approved_by, remarks, approved_date, created_date
        ) VALUES (
            p_student_id, 'Pending', p_restored_by, 'Student restored. Pending re-approval.', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP
        );
    END IF;

    RETURN v_rows_affected > 0;
END;
$$ LANGUAGE plpgsql;


-- ==========================================
-- 4. UPDATE LISTING FUNCTIONS: Hide Deleted Records
-- ==========================================
-- Update fnGetStudentsWithCurrentCourse to exclude is_deleted = TRUE
CREATE OR REPLACE FUNCTION fnGetStudentsWithCurrentCourse(
    p_search VARCHAR DEFAULT NULL
)
RETURNS TABLE(
    id INT, name VARCHAR, phone VARCHAR, email VARCHAR, 
    course_id INT, course VARCHAR, course_code VARCHAR, 
    student_image VARCHAR, created_date TIMESTAMP, updated_date TIMESTAMP, 
    approval_status VARCHAR, approved_by VARCHAR, remarks TEXT, approved_date TIMESTAMP
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        s.id, s.name, s.phone, s.email, sc.course_id,
        COALESCE(c.course_name, 'Not assigned'), COALESCE(c.course_code, ''),
        s.student_image, s.created_date, s.updated_date,
        COALESCE(a.approval_status, 'Pending'), COALESCE(a.approved_by, 'System'),
        COALESCE(a.remarks, ''), a.approved_date::timestamp without time zone
    FROM students s
    LEFT JOIN tblStudentCourse sc ON s.id = sc.student_id AND sc.status = 'Active'
    LEFT JOIN tblCourse c ON sc.course_id = c.course_id
    LEFT JOIN LATERAL (
        SELECT sa.approval_status, sa.approved_by, sa.remarks, sa.approved_date
        FROM studentapproval sa
        WHERE sa.student_id = s.id
        ORDER BY sa.id DESC LIMIT 1
    ) a ON TRUE
    WHERE s.is_deleted = FALSE -- <--- CRITICAL ADDITION
      AND (p_search IS NULL
       OR s.name ILIKE '%' || p_search || '%'
       OR s.phone ILIKE '%' || p_search || '%'
       OR s.email ILIKE '%' || p_search || '%'
       OR c.course_name ILIKE '%' || p_search || '%')
    ORDER BY s.id DESC;
END;
$$ LANGUAGE plpgsql;


-- ==========================================
-- 5. NEW FUNCTION: Get Deleted Students (For Restore UI)
-- ==========================================
CREATE OR REPLACE FUNCTION fnGetDeletedStudents()
RETURNS TABLE(
    id INT, name VARCHAR, email VARCHAR, deleted_by VARCHAR, deleted_date TIMESTAMP
) AS $$
BEGIN
    RETURN QUERY
    SELECT s.id, s.name, s.email, s.deleted_by, s.deleted_date
    FROM students s
    WHERE s.is_deleted = TRUE
    ORDER BY s.deleted_date DESC;
END;
$$ LANGUAGE plpgsql;





-- ==========================================
-- TASK 3: Process Student Approval Procedure
-- ==========================================
DROP FUNCTION IF EXISTS spProcessStudentApproval(INT, VARCHAR, VARCHAR, TEXT);

CREATE OR REPLACE FUNCTION spProcessStudentApproval(
    p_student_id INT,
    p_action VARCHAR,             -- Expected: 'APPROVE' or 'REJECT'
    p_performed_by VARCHAR DEFAULT 'Admin',
    p_remarks TEXT DEFAULT NULL,
    OUT o_status_code INT,        -- Returns HTTP-style status codes (200, 400, 404, 409)
    OUT o_message VARCHAR         -- Returns standard success/failure message
) AS $$
DECLARE
    v_current_status VARCHAR;  -- store current status
    v_is_deleted BOOLEAN;
    v_new_status VARCHAR;
BEGIN
    -- 1. Validate the Action Parameter (No hardcoding bad inputs)
    IF UPPER(p_action) NOT IN ('APPROVE', 'REJECT') THEN
        o_status_code := 400;
        o_message := 'Invalid action. Must be APPROVE or REJECT.';
        RETURN;
    END IF;

    -- 2. Check if student exists and is not soft-deleted
    SELECT is_deleted INTO v_is_deleted
    FROM students 
    WHERE id = p_student_id;

    IF NOT FOUND THEN
        o_status_code := 404;
        o_message := 'Student not found in the database.';
        RETURN;
    END IF;
--If student already deleted.
    IF v_is_deleted THEN
        o_status_code := 400;
        o_message := 'Action denied. Cannot process approval for a deleted student.';
        RETURN;
    END IF;

    -- 3. Fetch the most recent approval status for this student
    SELECT approval_status INTO v_current_status
    FROM studentapproval
    WHERE student_id = p_student_id
    ORDER BY id DESC
    LIMIT 1;

    -- Default to 'Pending' if they somehow have no history
    v_current_status := COALESCE(v_current_status, 'Pending');

    -- Map the action to the final status text
    IF UPPER(p_action) = 'APPROVE' THEN
        v_new_status := 'Approved';
    ELSE
        v_new_status := 'Rejected';
    END IF;

    -- 4. VALIDATION: Prevent duplicate processing
    IF v_current_status = v_new_status THEN
        o_status_code := 409; -- 409 Conflict
        o_message := 'Student is already marked as ' || v_new_status || '.';
        RETURN;
    END IF;

    -- 5. VALIDATION: Ensure only 'Pending' records can be approved/rejected
    IF v_current_status != 'Pending' THEN
        o_status_code := 400; -- 400 Bad Request
        o_message := 'Action denied. Current status is ' || v_current_status || '. Only Pending students can be processed.';
        RETURN;
    END IF;

    -- 6. EXECUTE PROCESS: Insert the new status
    -- (NOTE: This INSERT automatically fires the Task 1 trg_audit_approvals trigger!)
    INSERT INTO studentapproval (
        student_id, approval_status, approved_by, 
        approved_date, remarks, created_date
    ) VALUES (
        p_student_id, v_new_status, p_performed_by, 
        NOW(), COALESCE(p_remarks, ''), NOW()
    );

    -- Touch the updated_date on the parent table
    UPDATE students
    SET updated_date = NOW()
    WHERE id = p_student_id;

    -- 7. Return Success
    o_status_code := 200;
    o_message := 'Student successfully ' || LOWER(v_new_status) || '.';
    RETURN;

EXCEPTION WHEN OTHERS THEN
    -- Safety net: Catch any unexpected DB constraints or errors
    o_status_code := 500;
    o_message := 'Database error occurred: ' || SQLERRM;
    RETURN;
END;
$$ LANGUAGE plpgsql;





SELECT * FROM vwStudentDashboard;


-- ==========================================
-- TASK 4: Student Dashboard Reporting View
-- ==========================================
DROP VIEW IF EXISTS vwStudentDashboard;

CREATE OR REPLACE VIEW vwStudentDashboard AS

-- 1. CTE to efficiently get ONLY the latest approval status per student
WITH LatestApproval AS (
    SELECT DISTINCT ON (student_id) student_id, approval_status
    FROM studentapproval
    ORDER BY student_id, id DESC
)

-- 2. Main Aggregation Query
SELECT 
    -- If ROLLUP generates the grand total row, name it 'Grand Total'
    -- Otherwise, show the course name (or 'Unassigned' if they have no course)
    CASE 
        WHEN GROUPING(c.course_name) = 1 THEN 'Grand Total'
        ELSE COALESCE(c.course_name, 'Unassigned')
    END AS category_name,
    
    -- Count Total Students (Both active and deleted)
    COUNT(s.id) AS total_students,
    
    -- Use Postgres FILTER for blazing fast conditional counting
    COUNT(s.id) FILTER (WHERE s.is_deleted = FALSE AND COALESCE(la.approval_status, 'Pending') = 'Approved') AS approved_count,
    COUNT(s.id) FILTER (WHERE s.is_deleted = FALSE AND COALESCE(la.approval_status, 'Pending') = 'Rejected') AS rejected_count,
    COUNT(s.id) FILTER (WHERE s.is_deleted = FALSE AND COALESCE(la.approval_status, 'Pending') = 'Pending')  AS pending_count,
    
    -- Count Soft Deleted Students
    COUNT(s.id) FILTER (WHERE s.is_deleted = TRUE) AS deleted_count

FROM students s
LEFT JOIN tblCourse c ON s.course_id = c.course_id
LEFT JOIN LatestApproval la ON s.id = la.student_id

-- 3. ROLLUP automatically calculates course-wise counts AND a grand total in one pass!
GROUP BY ROLLUP(c.course_name)

-- Sort so courses are alphabetical, and the 'Grand Total' row stays exactly at the bottom
ORDER BY 
    CASE WHEN GROUPING(c.course_name) = 1 THEN 1 ELSE 0 END, 
    c.course_name;







-- ==========================================
-- TASK 5: Get Filtered Global Approval History
-- ==========================================
-- Drop the old version first
DROP FUNCTION IF EXISTS fnGetGlobalApprovalHistory(VARCHAR, VARCHAR, DATE, DATE);

-- Create the bulletproof version
CREATE OR REPLACE FUNCTION fnGetGlobalApprovalHistory(
    p_search VARCHAR DEFAULT NULL,
    p_action VARCHAR DEFAULT NULL,
    p_date_from DATE DEFAULT NULL,
    p_date_to DATE DEFAULT NULL
)
RETURNS TABLE (
    audit_id INT,
    student_name VARCHAR,
    action VARCHAR,
    old_status VARCHAR,
    new_status VARCHAR,
    performed_by VARCHAR,
    performed_date TIMESTAMP,
    remarks TEXT
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        al.id,
        --tblAuditLog alias tblAuditLog.id
        -- Using CAST() instead of :: to ensure the parser understands
        -- cast is used for convert te datatype .. data want as varcar
        CAST(COALESCE(s.name, 'Unknown/Deleted') AS VARCHAR) AS student_name,
        CAST(al.action_type AS VARCHAR) AS action,
        --coalese if first value empty, use second value.
        -- Extract the status from the JSONB snapshots safely
        CAST(COALESCE(al.old_value->>'approval_status', 'None') AS VARCHAR) AS old_status,
        CAST(COALESCE(al.new_value->>'approval_status', 'None') AS VARCHAR) AS new_status,
        
        CAST(al.performed_by AS VARCHAR) AS performed_by,
        al.performed_date,
        COALESCE(al.new_value->>'remarks', '') AS remarks
        
    FROM tblAuditLog al
    
    -- Using CAST() for the JSON ID extraction
    LEFT JOIN students s ON s.id = CAST(COALESCE(al.new_value->>'student_id', al.old_value->>'student_id') AS INT)
    
    WHERE al.module_name = 'Approval Module'
      -- Apply the Search Filter
      AND (p_search IS NULL OR p_search = '' OR s.name ILIKE '%' || p_search || '%')
      -- Apply the Action Filter
      AND (p_action IS NULL OR p_action = '' OR al.action_type = UPPER(p_action))
      -- Apply the Date Filters safely using CAST
      AND (p_date_from IS NULL OR al.performed_date >= CAST(p_date_from AS TIMESTAMP))
      AND (p_date_to IS NULL OR al.performed_date < CAST(p_date_to + interval '1 day' AS TIMESTAMP))
      
    ORDER BY al.performed_date DESC;
END;
$$ LANGUAGE plpgsql;







DROP FUNCTION IF EXISTS fnGetApprovalHistory(INT);
CREATE OR REPLACE FUNCTION fnGetApprovalHistory(p_student_id INT)
RETURNS TABLE(
    id INT,
    approval_status VARCHAR,
    approved_by VARCHAR,
    remarks TEXT,
    approved_date TIMESTAMP
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        sa.id,
        sa.approval_status,
        sa.approved_by,
        sa.remarks,
        sa.approved_date
    FROM studentapproval sa
    WHERE sa.student_id = p_student_id
    ORDER BY sa.id DESC;
END;
$$ LANGUAGE plpgsql;







-- ==========================================
-- SIMPLE CHATBOT TABLES FOR POSTGRESQL
-- ==========================================

-- -- Drop existing tables if they exist
-- DROP TABLE IF EXISTS tblChatbotQA CASCADE;
-- DROP TABLE IF EXISTS tblChatHistory CASCADE;
-- DROP TABLE IF EXISTS tblChatFeedback CASCADE;

-- -- Simple table for storing Q&A pairs (only question and answer)
-- CREATE TABLE IF NOT EXISTS tblChatbotQA (
--     id SERIAL PRIMARY KEY,
--     question TEXT NOT NULL UNIQUE,
--     answer TEXT NOT NULL,
--     usage_count INTEGER DEFAULT 0,
--     is_active BOOLEAN DEFAULT TRUE,
--     created_date TIMESTAMP DEFAULT NOW(),
--     updated_date TIMESTAMP DEFAULT NOW()
-- );

-- -- Table for storing chat history
-- CREATE TABLE IF NOT EXISTS tblChatHistory (
--     id SERIAL PRIMARY KEY,
--     session_id VARCHAR(100) NOT NULL,
--     user_message TEXT NOT NULL,
--     bot_response TEXT NOT NULL,
--     created_date TIMESTAMP DEFAULT NOW()
-- );

-- -- Simple feedback table
-- CREATE TABLE IF NOT EXISTS tblChatFeedback (
--     id SERIAL PRIMARY KEY,
--     chat_history_id INTEGER REFERENCES tblChatHistory(id) ON DELETE CASCADE,
--     is_helpful BOOLEAN,
--     created_date TIMESTAMP DEFAULT NOW()
-- );

-- -- Create indexes
-- CREATE INDEX IF NOT EXISTS idx_question ON tblChatbotQA(question);
-- CREATE INDEX IF NOT EXISTS idx_session ON tblChatHistory(session_id);

-- -- Function to update updated_date
-- CREATE OR REPLACE FUNCTION update_updated_date_column()
-- RETURNS TRIGGER AS $$
-- BEGIN
--     NEW.updated_date = NOW();
--     RETURN NEW;
-- END;
-- $$ language 'plpgsql';

-- -- Trigger for updated_date
-- DROP TRIGGER IF EXISTS update_chatbot_qa_updated_date ON tblChatbotQA;
-- CREATE TRIGGER update_chatbot_qa_updated_date 
--     BEFORE UPDATE ON tblChatbotQA 
--     FOR EACH ROW 
--     EXECUTE FUNCTION update_updated_date_column();