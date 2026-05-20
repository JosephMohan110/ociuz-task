

-- SELECT * from students;
-- SELECT * from tblCourse;
-- SELECT * from studentapproval;
-- SELECT * from tblStudentCourse;
-- SELECT * from tblAuditLog;

-- CREATE TABLE IF NOT EXISTS students (
--     id SERIAL PRIMARY KEY,
--     name VARCHAR(100),
--     age INT,
--     phone VARCHAR(15),
--     email VARCHAR(100),
--     address TEXT,
--     dob DATE,
--     course_id INT,
--     student_image VARCHAR(255),
--     status VARCHAR(20),
--     created_date TIMESTAMP DEFAULT NOW(),
--     updated_date TIMESTAMP DEFAULT NOW()
-- );

-- CREATE TABLE IF NOT EXISTS tblCourse (
--     course_id SERIAL PRIMARY KEY,
--     course_name VARCHAR(100) NOT NULL UNIQUE,
--     course_code VARCHAR(20) NOT NULL UNIQUE,
--     status VARCHAR(20) NOT NULL DEFAULT 'Active'
-- );

-- CREATE TABLE IF NOT EXISTS studentapproval (
--     id SERIAL PRIMARY KEY,
--     student_id INT REFERENCES students(id),
--     approval_status VARCHAR(50),
--     approved_by VARCHAR(100),
--     approved_date TIMESTAMP,
--     remarks TEXT,
--     created_date TIMESTAMP DEFAULT NOW()
-- );

-- CREATE TABLE IF NOT EXISTS tblStudentCourse (
--     id SERIAL PRIMARY KEY,
--     student_id INT REFERENCES students(id) ON DELETE CASCADE,
--     course_id INT REFERENCES tblCourse(course_id),
--     enrollment_date DATE DEFAULT CURRENT_DATE,
--     status VARCHAR(20) DEFAULT 'Active',
--     created_date TIMESTAMP DEFAULT NOW(),
--     updated_date TIMESTAMP DEFAULT NOW(),
--     UNIQUE(student_id)
-- );


-- -- ==========================================
-- -- TABLE: Audit Log
-- -- ==========================================
-- CREATE TABLE IF NOT EXISTS tblAuditLog (
--     id SERIAL PRIMARY KEY,
--     module_name VARCHAR(100) NOT NULL,
--     action_type VARCHAR(50) NOT NULL, -- INSERT, UPDATE, DELETE, APPROVE, REJECT
--     old_value JSONB,                  -- State before the action
--     new_value JSONB,                  -- State after the action
--     performed_by VARCHAR(100),
--     performed_date TIMESTAMP DEFAULT NOW()
-- );

-- SELECT * from tblauditlog
-- -- Add foreign key constraint to students table (if not exists)
-- DO $$
-- BEGIN
--     IF NOT EXISTS (
--         SELECT 1 FROM information_schema.table_constraints 
--         WHERE constraint_name = 'fk_students_course'
--     ) THEN
--         ALTER TABLE students
--         ADD CONSTRAINT fk_students_course FOREIGN KEY (course_id) REFERENCES tblCourse(course_id);
--     END IF;
-- END;
-- $$;

-- -- ==========================================
-- -- ALTER TABLE - Add columns if not exist
-- -- ==========================================

-- ALTER TABLE students
-- ADD COLUMN IF NOT EXISTS phone VARCHAR(15),
-- ADD COLUMN IF NOT EXISTS email VARCHAR(100),
-- ADD COLUMN IF NOT EXISTS address TEXT,
-- ADD COLUMN IF NOT EXISTS dob DATE,
-- ADD COLUMN IF NOT EXISTS student_image VARCHAR(255),
-- ADD COLUMN IF NOT EXISTS status VARCHAR(20),
-- ADD COLUMN IF NOT EXISTS created_date TIMESTAMP DEFAULT NOW(),
-- ADD COLUMN IF NOT EXISTS updated_date TIMESTAMP DEFAULT NOW();

-- -- Migrate existing course data if needed
-- DO $$
-- BEGIN
--     IF EXISTS (
--         SELECT 1
--         FROM information_schema.columns
--         WHERE table_name = 'students'
--           AND column_name = 'course'
--     ) THEN
--         UPDATE students s
--         SET course_id = c.course_id
--         FROM tblCourse c
--         WHERE s.course = c.course_name
--           AND s.course_id IS NULL;

--         ALTER TABLE students
--         DROP COLUMN IF EXISTS course;
--     END IF;
-- END;
-- $$;

-- -- ==========================================
-- -- INSERT DATA
-- -- ==========================================

-- INSERT INTO tblCourse (course_name, course_code, status) VALUES
--     ('Computer Science', 'CS101', 'Active'),
--     ('Information Technology', 'IT102', 'Active'),
--     ('Mechanical Engineering', 'ME103', 'Active'),
--     ('Electrical Engineering', 'EE104', 'Active'),
--     ('Civil Engineering', 'CE105', 'Active'),
--     ('Electronics & Communication', 'EC106', 'Active'),
--     ('Biotechnology', 'BT107', 'Active'),
--     ('Chemical Engineering', 'CH108', 'Active'),
--     ('Architecture', 'AR109', 'Active'),
--     ('Business Administration', 'BA110', 'Active')
-- ON CONFLICT (course_code) DO NOTHING;

-- INSERT INTO tblCourse (course_name, course_code, status) VALUES
--     ('Thrissur Jobs', 'TH222', 'Active')
-- ON CONFLICT (course_code) DO NOTHING;

-- INSERT INTO tblStudentCourse (student_id, course_id, enrollment_date, status, created_date, updated_date)
-- SELECT id, course_id, CURRENT_DATE, 'Active', NOW(), NOW()
-- FROM students
-- WHERE course_id IS NOT NULL
-- ON CONFLICT (student_id) DO NOTHING;

-- -- ==========================================
-- -- DELETE DATA (Keep tblCourse, delete others)
-- -- ==========================================

-- -- Delete from dependent tables first (due to foreign key constraints)
-- DELETE FROM studentapproval;
-- DELETE FROM tblStudentCourse;
-- DELETE FROM students;

-- -- ==========================================
-- -- FUNCTIONS
-- -- ==========================================

-- DROP FUNCTION IF EXISTS fnGetCourses();
-- CREATE OR REPLACE FUNCTION fnGetCourses()
-- RETURNS TABLE(
--     course_id INT,
--     course_name VARCHAR,
--     course_code VARCHAR,
--     status VARCHAR
-- ) AS $$
-- BEGIN
--     RETURN QUERY
--     SELECT
--         tblCourse.course_id AS course_id,
--         tblCourse.course_name AS course_name,
--         tblCourse.course_code AS course_code,
--         tblCourse.status AS status
--     FROM tblCourse
--     WHERE tblCourse.status = 'Active'
--     ORDER BY tblCourse.course_name;
-- END;
-- $$ LANGUAGE plpgsql;

-- -- ==========================================
-- -- FUNCTION: Approve Student
-- -- ==========================================
-- DROP FUNCTION IF EXISTS fnApproveStudent(INT, VARCHAR, TEXT);
-- CREATE OR REPLACE FUNCTION fnApproveStudent(
--     p_student_id INT,
--     p_approved_by VARCHAR,
--     p_remarks TEXT DEFAULT NULL
-- )
-- RETURNS BOOLEAN AS $$
-- BEGIN
--     INSERT INTO studentapproval (
--         student_id, approval_status, approved_by,
--         approved_date, remarks, created_date
--     )
--     VALUES (
--         p_student_id, 'Approved', p_approved_by,
--         NOW(), COALESCE(p_remarks, ''), NOW()
--     );

--     UPDATE students
--     SET updated_date = NOW()
--     WHERE id = p_student_id;

--     RETURN TRUE;
-- END;
-- $$ LANGUAGE plpgsql;

-- -- ==========================================
-- -- FUNCTION: Get Approved Students
-- -- ==========================================
-- DROP FUNCTION IF EXISTS fnGetApprovedStudents();
-- CREATE OR REPLACE FUNCTION fnGetApprovedStudents()
-- RETURNS TABLE(
--     student_id INT,
--     student_name VARCHAR,
--     course_name VARCHAR,
--     phone_number VARCHAR,
--     email_address VARCHAR,
--     approval_status VARCHAR,
--     approved_by VARCHAR
-- ) AS $$  
-- BEGIN
--     RETURN QUERY
--     SELECT 
--         s.id,
--         s.name,
--         COALESCE(c.course_name, 'Unknown'),
--         s.phone,
--         s.email,
--         a.approval_status,
--         a.approved_by
--     FROM students s
--     LEFT JOIN tblStudentCourse sc ON s.id = sc.student_id AND sc.status = 'Active'
--     LEFT JOIN tblCourse c ON sc.course_id = c.course_id
--     LEFT JOIN LATERAL (
--         SELECT sa.approval_status, sa.approved_by
--         FROM studentapproval sa
--         WHERE sa.student_id = s.id
--         ORDER BY sa.id DESC
--         LIMIT 1
--     ) a ON TRUE;
-- END;
-- $$ LANGUAGE plpgsql;

-- -- ==========================================
-- -- FUNCTION: Update Student Course
-- -- ==========================================
-- DROP FUNCTION IF EXISTS fnUpdateStudentCourse(INT, INT);
-- CREATE OR REPLACE FUNCTION fnUpdateStudentCourse(
--     p_student_id INT,
--     p_course_id INT
-- )
-- RETURNS BOOLEAN AS $$
-- BEGIN
--     UPDATE tblStudentCourse
--     SET course_id = p_course_id, updated_date = NOW()
--     WHERE student_id = p_student_id;
    
--     IF NOT FOUND THEN
--         INSERT INTO tblStudentCourse (student_id, course_id, status, created_date, updated_date)
--         VALUES (p_student_id, p_course_id, 'Active', NOW(), NOW());
--     END IF;
    
--     RETURN TRUE;
-- END;
-- $$ LANGUAGE plpgsql;

-- -- ==========================================
-- -- FUNCTION: Edit Student
-- -- ==========================================
-- DROP FUNCTION IF EXISTS fnEditStudent(INT, VARCHAR, VARCHAR, VARCHAR, INT, INT, TEXT, DATE);
-- CREATE OR REPLACE FUNCTION fnEditStudent(
--     p_student_id INT,
--     p_name VARCHAR,
--     p_phone VARCHAR,
--     p_email VARCHAR,
--     p_course_id INT,
--     p_student_image VARCHAR DEFAULT NULL,
--     p_age INT DEFAULT NULL,
--     p_address TEXT DEFAULT NULL,
--     p_dob DATE DEFAULT NULL
-- )
-- RETURNS BOOLEAN AS $$
-- DECLARE
--     v_rows_affected INT;
-- BEGIN
--     UPDATE students 
--     SET 
--         name = COALESCE(p_name, name),
--         age = COALESCE(p_age, age),
--         phone = COALESCE(p_phone, phone),
--         email = COALESCE(p_email, email),
--         address = COALESCE(p_address, address),
--         dob = COALESCE(p_dob, dob),
--         student_image = COALESCE(p_student_image, student_image),
--         updated_date = NOW()
--     WHERE id = p_student_id;
    
--     GET DIAGNOSTICS v_rows_affected = ROW_COUNT;
    
--     -- Update course enrollment if course_id provided
--     IF p_course_id IS NOT NULL THEN
--         PERFORM fnUpdateStudentCourse(p_student_id, p_course_id);
--     END IF;
    
--     IF v_rows_affected > 0 THEN
--         INSERT INTO studentapproval (
--             student_id, approval_status, approved_by, remarks, approved_date, created_date
--         ) VALUES (
--             p_student_id, 'Pending', 'System', 'Updated - Pending re-approval', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP
--         );
--     END IF;
    
--     RETURN v_rows_affected > 0;
-- END;
-- $$ LANGUAGE plpgsql;

-- -- ==========================================
-- -- FUNCTION: Delete Student
-- -- ==========================================
-- DROP FUNCTION IF EXISTS fnDeleteStudent(INT);
-- CREATE OR REPLACE FUNCTION fnDeleteStudent(
--     p_student_id INT
-- )
-- RETURNS BOOLEAN AS $$
-- DECLARE
--     v_student_name VARCHAR;
--     v_rows_affected INT;
-- BEGIN
--     SELECT name INTO v_student_name 
--     FROM students 
--     WHERE id = p_student_id;
    
--     IF v_student_name IS NULL THEN
--         RETURN FALSE;
--     END IF;
    
--     DELETE FROM studentapproval 
--     WHERE student_id = p_student_id;
    
--     DELETE FROM students 
--     WHERE id = p_student_id;
    
--     GET DIAGNOSTICS v_rows_affected = ROW_COUNT;
    
--     RETURN v_rows_affected > 0;
-- END;
-- $$ LANGUAGE plpgsql;

-- -- ==========================================
-- -- FUNCTION: Get Students with Current Course
-- -- ==========================================
-- DROP FUNCTION IF EXISTS fnGetStudentsWithCurrentCourse(VARCHAR);
-- CREATE OR REPLACE FUNCTION fnGetStudentsWithCurrentCourse(
--     p_search VARCHAR DEFAULT NULL
-- )
-- RETURNS TABLE(
--     id INT,
--     name VARCHAR,
--     phone VARCHAR,
--     email VARCHAR,
--     course_id INT,
--     course VARCHAR,
--     course_code VARCHAR,
--     student_image VARCHAR,
--     created_date TIMESTAMP,
--     updated_date TIMESTAMP,
--     approval_status VARCHAR,
--     approved_by VARCHAR,
--     remarks TEXT,
--     approved_date TIMESTAMP
-- ) AS $$
-- BEGIN
--     RETURN QUERY
--     SELECT
--         s.id,
--         s.name,
--         s.phone,
--         s.email,
--         sc.course_id,
--         COALESCE(c.course_name, 'Not assigned'),
--         COALESCE(c.course_code, ''),
--         s.student_image,
--         s.created_date,
--         s.updated_date,
--         COALESCE(a.approval_status, 'Pending'),
--         COALESCE(a.approved_by, 'System'),
--         COALESCE(a.remarks, ''),
--         a.approved_date::timestamp without time zone
--     FROM students s
--     LEFT JOIN tblStudentCourse sc ON s.id = sc.student_id AND sc.status = 'Active'
--     LEFT JOIN tblCourse c ON sc.course_id = c.course_id
--     LEFT JOIN LATERAL (
--         SELECT sa.approval_status, sa.approved_by, sa.remarks, sa.approved_date
--         FROM studentapproval sa
--         WHERE sa.student_id = s.id
--         ORDER BY sa.id DESC
--         LIMIT 1
--     ) a ON TRUE
--     WHERE p_search IS NULL
--        OR s.name ILIKE '%' || p_search || '%'
--        OR s.phone ILIKE '%' || p_search || '%'
--        OR s.email ILIKE '%' || p_search || '%'
--        OR c.course_name ILIKE '%' || p_search || '%'
--     ORDER BY s.id DESC;
-- END;
-- $$ LANGUAGE plpgsql;

-- -- ==========================================
-- -- FUNCTION: Get Student by ID
-- -- ==========================================
-- DROP FUNCTION IF EXISTS fnGetStudentById(INT);
-- CREATE OR REPLACE FUNCTION fnGetStudentById(
--     p_student_id INT
-- )
-- RETURNS TABLE(
--     id INT,
--     name VARCHAR,
--     phone VARCHAR,
--     email VARCHAR,
--     course_id INT,
--     course VARCHAR,
--     course_code VARCHAR,
--     student_image VARCHAR,
--     created_date TIMESTAMP,
--     updated_date TIMESTAMP,
--     approval_status VARCHAR,
--     approved_by VARCHAR,
--     remarks TEXT,
--     approved_date TIMESTAMP
-- ) AS $$
-- BEGIN
--     RETURN QUERY
--     SELECT
--         s.id,
--         s.name,
--         s.phone,
--         s.email,
--         sc.course_id,
--         COALESCE(c.course_name, 'Not assigned'),
--         COALESCE(c.course_code, ''),
--         s.student_image,
--         s.created_date,
--         s.updated_date,
--         COALESCE(a.approval_status, 'Pending'),
--         COALESCE(a.approved_by, 'System'),
--         COALESCE(a.remarks, ''),
--         a.approved_date::timestamp without time zone
--     FROM students s
--     LEFT JOIN tblStudentCourse sc ON s.id = sc.student_id AND sc.status = 'Active'
--     LEFT JOIN tblCourse c ON sc.course_id = c.course_id
--     LEFT JOIN LATERAL (
--         SELECT sa.approval_status, sa.approved_by, sa.remarks, sa.approved_date
--         FROM studentapproval sa
--         WHERE sa.student_id = s.id
--         ORDER BY sa.id DESC
--         LIMIT 1
--     ) a ON TRUE
--     WHERE s.id = p_student_id
--     ORDER BY s.id DESC
--     LIMIT 1;
-- END;
-- $$ LANGUAGE plpgsql;

-- -- ==========================================
-- -- VIEW TABLE DATA (Uncomment to use)
-- -- ==========================================

-- SELECT * FROM students;
-- SELECT * FROM tblCourse;
-- SELECT * FROM studentapproval;
-- SELECT * FROM tblStudentCourse;

-- SELECT * FROM fnGetCourses();
-- SELECT * FROM fnGetApprovedStudents();
-- SELECT * FROM fnGetStudentsWithCurrentCourse(NULL);
-- SELECT * FROM fnGetStudentById(1);



-- CREATE OR REPLACE FUNCTION fnAddStudent(
--     p_name VARCHAR,
--     p_phone VARCHAR,
--     p_email VARCHAR,
--     p_course_id INT,
--     p_student_image VARCHAR DEFAULT NULL
-- )
-- RETURNS INT AS $$
-- DECLARE
--     new_student_id INT;
-- BEGIN
--     INSERT INTO students (
--         name,
--         phone,
--         email,
--         course_id,
--         student_image,
--         created_date,
--         updated_date
--     )
--     VALUES (
--         p_name,
--         p_phone,
--         p_email,
--         p_course_id,
--         p_student_image,
--         NOW(),
--         NOW()
--     )
--     RETURNING id INTO new_student_id;

--     INSERT INTO tblStudentCourse (
--         student_id,
--         course_id,
--         enrollment_date,
--         status,
--         created_date,
--         updated_date
--     )
--     VALUES (
--         new_student_id,
--         p_course_id,
--         CURRENT_DATE,
--         'Active',
--         NOW(),
--         NOW()
--     );

--     INSERT INTO studentapproval (
--         student_id,
--         approval_status,
--         approved_by,
--         approved_date,
--         remarks,
--         created_date
--     )
--     VALUES (
--         new_student_id,
--         'Pending',
--         'System',
--         NOW(),
--         'New student added',
--         NOW()
--     );

--     RETURN new_student_id;
-- END;
-- $$ LANGUAGE plpgsql;



-- -- ==========================================
-- -- TRIGGER FUNCTION: Student Core Operations
-- -- ==========================================
-- CREATE OR REPLACE FUNCTION fn_audit_students()
-- RETURNS TRIGGER AS $$
-- BEGIN
--     IF TG_OP = 'INSERT' THEN
--         INSERT INTO tblAuditLog (module_name, action_type, old_value, new_value, performed_by)
--         VALUES ('Student Module', 'INSERT', NULL, row_to_json(NEW)::jsonb, 'System');
--         RETURN NEW;
        
--     ELSIF TG_OP = 'UPDATE' THEN
--         INSERT INTO tblAuditLog (module_name, action_type, old_value, new_value, performed_by)
--         VALUES ('Student Module', 'UPDATE', row_to_json(OLD)::jsonb, row_to_json(NEW)::jsonb, 'System');
--         RETURN NEW;
        
--     ELSIF TG_OP = 'DELETE' THEN
--         INSERT INTO tblAuditLog (module_name, action_type, old_value, new_value, performed_by)
--         VALUES ('Student Module', 'DELETE', row_to_json(OLD)::jsonb, NULL, 'System');
--         RETURN OLD;
--     END IF;
    
--     RETURN NULL;
-- END;
-- $$ LANGUAGE plpgsql;

-- -- Attach trigger to students table
-- DROP TRIGGER IF EXISTS trg_audit_students ON students;
-- CREATE TRIGGER trg_audit_students
-- AFTER INSERT OR UPDATE OR DELETE ON students
-- FOR EACH ROW EXECUTE FUNCTION fn_audit_students();






-- -- ==========================================
-- -- TRIGGER FUNCTION: Approval Workflow
-- -- ==========================================
-- CREATE OR REPLACE FUNCTION fn_audit_approvals()
-- RETURNS TRIGGER AS $$
-- DECLARE
--     v_action_type VARCHAR(50);
-- BEGIN
--     -- We only care about tracking when new approval statuses are generated
--     IF TG_OP = 'INSERT' THEN
        
--         -- Map the table's status to the required Action Type
--         IF NEW.approval_status = 'Approved' THEN
--             v_action_type := 'APPROVE';
--         ELSIF NEW.approval_status = 'Rejected' THEN
--             v_action_type := 'REJECT';
--         ELSIF NEW.approval_status = 'Pending' THEN
--             v_action_type := 'STATUS_PENDING';
--         ELSE
--             v_action_type := UPPER(NEW.approval_status);
--         END IF;

--         INSERT INTO tblAuditLog (module_name, action_type, old_value, new_value, performed_by)
--         VALUES (
--             'Approval Module', 
--             v_action_type, 
--             NULL, 
--             row_to_json(NEW)::jsonb, 
--             COALESCE(NEW.approved_by, 'System') -- Captures who actually performed it
--         );
--         RETURN NEW;
        
--     ELSIF TG_OP = 'DELETE' THEN
--         -- When a student is deleted, their approval history is cascade-deleted. Track this too.
--         INSERT INTO tblAuditLog (module_name, action_type, old_value, new_value, performed_by)
--         VALUES ('Approval Module', 'DELETE_HISTORY', row_to_json(OLD)::jsonb, NULL, 'System');
--         RETURN OLD;
--     END IF;

--     RETURN NULL;
-- END;
-- $$ LANGUAGE plpgsql;

-- -- Attach trigger to studentapproval table
-- DROP TRIGGER IF EXISTS trg_audit_approvals ON studentapproval;
-- CREATE TRIGGER trg_audit_approvals
-- AFTER INSERT OR DELETE ON studentapproval
-- FOR EACH ROW EXECUTE FUNCTION fn_audit_approvals();











-- -- ==========================================
-- -- 1. ALTER TABLE: Add Soft Delete Columns
-- -- ==========================================
-- ALTER TABLE students
-- ADD COLUMN IF NOT EXISTS is_deleted BOOLEAN DEFAULT FALSE,
-- ADD COLUMN IF NOT EXISTS deleted_by VARCHAR(100),
-- ADD COLUMN IF NOT EXISTS deleted_date TIMESTAMP;


-- -- ==========================================
-- -- 2.  Soft Delete Student
-- -- ==========================================
-- -- Replaces the old hard delete function. Notice we no longer delete 
-- -- from studentapproval or tblStudentCourse. We keep the history intact!
-- DROP FUNCTION IF EXISTS fnDeleteStudent(INT);
-- CREATE OR REPLACE FUNCTION fnDeleteStudent(
--     p_student_id INT,
--     p_deleted_by VARCHAR DEFAULT 'Admin'
-- )
-- RETURNS BOOLEAN AS $$
-- DECLARE
--     v_rows_affected INT;
-- BEGIN
--     UPDATE students 
--     SET 
--         is_deleted = TRUE,
--         deleted_by = p_deleted_by,
--         deleted_date = NOW(),
--         updated_date = NOW()
--     WHERE id = p_student_id AND is_deleted = FALSE;
    
--     GET DIAGNOSTICS v_rows_affected = ROW_COUNT;
    
--     -- Optional: Log a "Pending" status indicating the soft delete in approval history
--     IF v_rows_affected > 0 THEN
--         INSERT INTO studentapproval (
--             student_id, approval_status, approved_by, remarks, approved_date, created_date
--         ) VALUES (
--             p_student_id, 'Deleted', p_deleted_by, 'Student softly deleted from system', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP
--         );
--     END IF;

--     RETURN v_rows_affected > 0;
-- END;
-- $$ LANGUAGE plpgsql;


-- -- ==========================================
-- -- 3. NEW FUNCTION: Restore Student
-- -- ==========================================
-- DROP FUNCTION IF EXISTS fnRestoreStudent(INT, VARCHAR);
-- CREATE OR REPLACE FUNCTION fnRestoreStudent(
--     p_student_id INT,
--     p_restored_by VARCHAR DEFAULT 'Admin'
-- )
-- RETURNS BOOLEAN AS $$
-- DECLARE
--     v_rows_affected INT;
-- BEGIN
--     UPDATE students 
--     SET 
--         is_deleted = FALSE,
--         deleted_by = NULL,
--         deleted_date = NULL,
--         updated_date = NOW()
--     WHERE id = p_student_id AND is_deleted = TRUE;
    
--     GET DIAGNOSTICS v_rows_affected = ROW_COUNT;

--     -- Push them back into the Pending queue for re-approval upon restoration
--     IF v_rows_affected > 0 THEN
--         INSERT INTO studentapproval (
--             student_id, approval_status, approved_by, remarks, approved_date, created_date
--         ) VALUES (
--             p_student_id, 'Pending', p_restored_by, 'Student restored. Pending re-approval.', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP
--         );
--     END IF;

--     RETURN v_rows_affected > 0;
-- END;
-- $$ LANGUAGE plpgsql;



-- -- ==========================================
-- -- 4. UPDATE LISTING FUNCTIONS: Hide Deleted Records
-- -- ==========================================
-- DROP FUNCTION IF EXISTS fnGetStudentsWithCurrentCourse(VARCHAR);

-- CREATE OR REPLACE FUNCTION fnGetStudentsWithCurrentCourse(
--      p_search VARCHAR DEFAULT NULL
-- )
-- RETURNS TABLE(
--      id INT, name VARCHAR, phone VARCHAR, email VARCHAR, 
--      course_id INT, course VARCHAR, course_code VARCHAR, 
--      student_image VARCHAR, created_date TIMESTAMP, updated_date TIMESTAMP, 
--      approval_status VARCHAR, approved_by VARCHAR, remarks TEXT, approved_date TIMESTAMP
-- ) AS $$
-- BEGIN
--      RETURN QUERY
--      SELECT
--          s.id, s.name, s.phone, s.email, sc.course_id,
--          COALESCE(c.course_name, 'Not assigned'), COALESCE(c.course_code, ''),
--          s.student_image, s.created_date, s.updated_date,
--          COALESCE(a.approval_status, 'Pending'), COALESCE(a.approved_by, 'System'),
--          COALESCE(a.remarks, ''), a.approved_date::timestamp without time zone
--      FROM students s
--      LEFT JOIN tblStudentCourse sc ON s.id = sc.student_id AND sc.status = 'Active'
--      LEFT JOIN tblCourse c ON sc.course_id = c.course_id
--      LEFT JOIN LATERAL (
--          -- FIX: Explicitly using sa.remarks to avoid ambiguity
--          SELECT sa.approval_status, sa.approved_by, sa.remarks, sa.approved_date
--          FROM studentapproval sa
--          WHERE sa.student_id = s.id
--          ORDER BY sa.id DESC LIMIT 1
--      ) a ON TRUE
--      WHERE s.is_deleted = FALSE 
--        AND (p_search IS NULL
--         OR s.name ILIKE '%' || p_search || '%'
--         OR s.phone ILIKE '%' || p_search || '%'
--         OR s.email ILIKE '%' || p_search || '%'
--         OR c.course_name ILIKE '%' || p_search || '%')
--      ORDER BY s.id DESC;
-- END;
-- $$ LANGUAGE plpgsql;


-- -- ==========================================
-- -- 5. NEW FUNCTION: Get Deleted Students (For Restore UI)
-- -- ==========================================
-- CREATE OR REPLACE FUNCTION fnGetDeletedStudents()
-- RETURNS TABLE(
--     id INT, name VARCHAR, email VARCHAR, deleted_by VARCHAR, deleted_date TIMESTAMP
-- ) AS $$
-- BEGIN
--     RETURN QUERY
--     SELECT s.id, s.name, s.email, s.deleted_by, s.deleted_date
--     FROM students s
--     WHERE s.is_deleted = TRUE
--     ORDER BY s.deleted_date DESC;
-- END;
-- $$ LANGUAGE plpgsql;





-- -- ==========================================
-- -- TASK 3: Process Student Approval Procedure
-- -- ==========================================
-- DROP FUNCTION IF EXISTS spProcessStudentApproval(INT, VARCHAR, VARCHAR, TEXT);

-- CREATE OR REPLACE FUNCTION spProcessStudentApproval(
--     p_student_id INT,
--     p_action VARCHAR,             -- Expected: 'APPROVE' or 'REJECT'
--     p_performed_by VARCHAR DEFAULT 'Admin',
--     p_remarks TEXT DEFAULT NULL,
--     OUT o_status_code INT,        -- Returns HTTP-style status codes (200, 400, 404, 409)
--     OUT o_message VARCHAR         -- Returns standard success/failure message
-- ) AS $$
-- DECLARE
--     v_current_status VARCHAR;  -- store current status
--     v_is_deleted BOOLEAN;
--     v_new_status VARCHAR;
-- BEGIN
--     -- 1. Validate the Action Parameter (No hardcoding bad inputs)
--     IF UPPER(p_action) NOT IN ('APPROVE', 'REJECT') THEN
--         o_status_code := 400;
--         o_message := 'Invalid action. Must be APPROVE or REJECT.';
--         RETURN;
--     END IF;

--     -- 2. Check if student exists and is not soft-deleted
--     SELECT is_deleted INTO v_is_deleted
--     FROM students 
--     WHERE id = p_student_id;

--     IF NOT FOUND THEN
--         o_status_code := 404;
--         o_message := 'Student not found in the database.';
--         RETURN;
--     END IF;
-- --If student already deleted.
--     IF v_is_deleted THEN
--         o_status_code := 400;
--         o_message := 'Action denied. Cannot process approval for a deleted student.';
--         RETURN;
--     END IF;

--     -- 3. Fetch the most recent approval status for this student
--     SELECT approval_status INTO v_current_status
--     FROM studentapproval
--     WHERE student_id = p_student_id
--     ORDER BY id DESC
--     LIMIT 1;

--     -- Default to 'Pending' if they somehow have no history
--     v_current_status := COALESCE(v_current_status, 'Pending');

--     -- Map the action to the final status text
--     IF UPPER(p_action) = 'APPROVE' THEN
--         v_new_status := 'Approved';
--     ELSE
--         v_new_status := 'Rejected';
--     END IF;

--     -- 4. VALIDATION: Prevent duplicate processing
--     IF v_current_status = v_new_status THEN
--         o_status_code := 409; -- 409 Conflict
--         o_message := 'Student is already marked as ' || v_new_status || '.';
--         RETURN;
--     END IF;

--     -- 5. VALIDATION: Ensure only 'Pending' records can be approved/rejected
--     IF v_current_status != 'Pending' THEN
--         o_status_code := 400; -- 400 Bad Request
--         o_message := 'Action denied. Current status is ' || v_current_status || '. Only Pending students can be processed.';
--         RETURN;
--     END IF;

--     -- 6. EXECUTE PROCESS: Insert the new status
--     -- (NOTE: This INSERT automatically fires the Task 1 trg_audit_approvals trigger!)
--     INSERT INTO studentapproval (
--         student_id, approval_status, approved_by, 
--         approved_date, remarks, created_date
--     ) VALUES (
--         p_student_id, v_new_status, p_performed_by, 
--         NOW(), COALESCE(p_remarks, ''), NOW()
--     );

--     -- Touch the updated_date on the parent table
--     UPDATE students
--     SET updated_date = NOW()
--     WHERE id = p_student_id;

--     -- 7. Return Success
--     o_status_code := 200;
--     o_message := 'Student successfully ' || LOWER(v_new_status) || '.';
--     RETURN;

-- EXCEPTION WHEN OTHERS THEN
--     -- Safety net: Catch any unexpected DB constraints or errors
--     o_status_code := 500;
--     o_message := 'Database error occurred: ' || SQLERRM;
--     RETURN;
-- END;
-- $$ LANGUAGE plpgsql;





-- SELECT * FROM vwStudentDashboard;


-- -- ==========================================
-- -- TASK 4: Student Dashboard Reporting View
-- -- ==========================================
-- DROP VIEW IF EXISTS vwStudentDashboard;

-- CREATE OR REPLACE VIEW vwStudentDashboard AS

-- -- 1. CTE to efficiently get ONLY the latest approval status per student
-- WITH LatestApproval AS (
--     SELECT DISTINCT ON (student_id) student_id, approval_status
--     FROM studentapproval
--     ORDER BY student_id, id DESC
-- )

-- -- 2. Main Aggregation Query
-- SELECT 
--     -- If ROLLUP generates the grand total row, name it 'Grand Total'
--     -- Otherwise, show the course name (or 'Unassigned' if they have no course)
--     CASE 
--         WHEN GROUPING(c.course_name) = 1 THEN 'Grand Total'
--         ELSE COALESCE(c.course_name, 'Unassigned')
--     END AS category_name,
    
--     -- Count Total Students (Both active and deleted)
--     COUNT(s.id) AS total_students,
    
--     -- Use Postgres FILTER for blazing fast conditional counting
--     COUNT(s.id) FILTER (WHERE s.is_deleted = FALSE AND COALESCE(la.approval_status, 'Pending') = 'Approved') AS approved_count,
--     COUNT(s.id) FILTER (WHERE s.is_deleted = FALSE AND COALESCE(la.approval_status, 'Pending') = 'Rejected') AS rejected_count,
--     COUNT(s.id) FILTER (WHERE s.is_deleted = FALSE AND COALESCE(la.approval_status, 'Pending') = 'Pending')  AS pending_count,
    
--     -- Count Soft Deleted Students
--     COUNT(s.id) FILTER (WHERE s.is_deleted = TRUE) AS deleted_count

-- FROM students s
-- LEFT JOIN tblCourse c ON s.course_id = c.course_id
-- LEFT JOIN LatestApproval la ON s.id = la.student_id

-- -- 3. ROLLUP automatically calculates course-wise counts AND a grand total in one pass!
-- GROUP BY ROLLUP(c.course_name)

-- -- Sort so courses are alphabetical, and the 'Grand Total' row stays exactly at the bottom
-- ORDER BY 
--     CASE WHEN GROUPING(c.course_name) = 1 THEN 1 ELSE 0 END, 
--     c.course_name;







-- -- ==========================================
-- -- TASK 5: Get Filtered Global Approval History
-- -- ==========================================
-- -- Drop the old version first
-- DROP FUNCTION IF EXISTS fnGetGlobalApprovalHistory(VARCHAR, VARCHAR, DATE, DATE);

-- -- Create the bulletproof version
-- CREATE OR REPLACE FUNCTION fnGetGlobalApprovalHistory(
--     p_search VARCHAR DEFAULT NULL,
--     p_action VARCHAR DEFAULT NULL,
--     p_date_from DATE DEFAULT NULL,
--     p_date_to DATE DEFAULT NULL
-- )
-- RETURNS TABLE (
--     audit_id INT,
--     student_name VARCHAR,
--     action VARCHAR,
--     old_status VARCHAR,
--     new_status VARCHAR,
--     performed_by VARCHAR,
--     performed_date TIMESTAMP,
--     remarks TEXT
-- ) AS $$
-- BEGIN
--     RETURN QUERY
--     SELECT
--         al.id,
--         --tblAuditLog alias tblAuditLog.id
--         -- Using CAST() instead of :: to ensure the parser understands
--         -- cast is used for convert te datatype .. data want as varcar
--         CAST(COALESCE(s.name, 'Unknown/Deleted') AS VARCHAR) AS student_name,
--         CAST(al.action_type AS VARCHAR) AS action,
--         --coalese if first value empty, use second value.
--         -- Extract the status from the JSONB snapshots safely
--         CAST(COALESCE(al.old_value->>'approval_status', 'None') AS VARCHAR) AS old_status,
--         CAST(COALESCE(al.new_value->>'approval_status', 'None') AS VARCHAR) AS new_status,
        
--         CAST(al.performed_by AS VARCHAR) AS performed_by,
--         al.performed_date,
--         COALESCE(al.new_value->>'remarks', '') AS remarks
        
--     FROM tblAuditLog al
    
--     -- Using CAST() for the JSON ID extraction
--     LEFT JOIN students s ON s.id = CAST(COALESCE(al.new_value->>'student_id', al.old_value->>'student_id') AS INT)
    
--     WHERE al.module_name = 'Approval Module'
--       -- Apply the Search Filter
--       AND (p_search IS NULL OR p_search = '' OR s.name ILIKE '%' || p_search || '%')
--       -- Apply the Action Filter
--       AND (p_action IS NULL OR p_action = '' OR al.action_type = UPPER(p_action))
--       -- Apply the Date Filters safely using CAST
--       AND (p_date_from IS NULL OR al.performed_date >= CAST(p_date_from AS TIMESTAMP))
--       AND (p_date_to IS NULL OR al.performed_date < CAST(p_date_to + interval '1 day' AS TIMESTAMP))
      
--     ORDER BY al.performed_date DESC;
-- END;
-- $$ LANGUAGE plpgsql;







-- DROP FUNCTION IF EXISTS fnGetApprovalHistory(INT);
-- CREATE OR REPLACE FUNCTION fnGetApprovalHistory(p_student_id INT)
-- RETURNS TABLE(
--     id INT,
--     approval_status VARCHAR,
--     approved_by VARCHAR,
--     remarks TEXT,
--     approved_date TIMESTAMP
-- ) AS $$
-- BEGIN
--     RETURN QUERY
--     SELECT 
--         sa.id,
--         sa.approval_status,
--         sa.approved_by,
--         sa.remarks,
--         sa.approved_date
--     FROM studentapproval sa
--     WHERE sa.student_id = p_student_id
--     ORDER BY sa.id DESC;
-- END;
-- $$ LANGUAGE plpgsql;







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










-- -- ==========================================
-- -- MODULE 1: ERP DOCUMENT MASTER 
-- -- ==========================================

-- -- 1. Create the Centralized Document Master Table
-- CREATE TABLE IF NOT EXISTS tblDocumentMaster (
--     DocumentId SERIAL PRIMARY KEY,
--     DocumentName VARCHAR(100) NOT NULL UNIQUE,
--     DocumentCode VARCHAR(50) NOT NULL UNIQUE,
--     Prefix VARCHAR(10) NOT NULL,
--     RunningNumber INT DEFAULT 0,
--     ApprovalRequired BOOLEAN DEFAULT TRUE,
--     IsActive BOOLEAN DEFAULT TRUE,
--     CreatedBy VARCHAR(100) DEFAULT 'System',
--     CreatedDate TIMESTAMP DEFAULT NOW(),
--     UpdatedDate TIMESTAMP DEFAULT NOW()
-- );



-- -- 2. Insert Base ERP Modules dynamically (ON CONFLICT prevents duplication on re-runs)
-- INSERT INTO tblDocumentMaster (DocumentName, DocumentCode, Prefix, RunningNumber, ApprovalRequired)
-- VALUES 
--     ('Student Admission', 'STUDENT_ADM', 'ADM', 0, TRUE),
--     ('Leave Request', 'LEAVE_REQ', 'LEV', 0, TRUE),
--     ('Fee Approval', 'FEE_APP', 'FEE', 0, TRUE),
--     ('Purchase Request', 'PURCHASE_REQ', 'PUR', 0, TRUE),
--     ('Expense Claim', 'EXPENSE_CLAIM', 'EXP', 0, TRUE)
-- ON CONFLICT (DocumentCode) DO NOTHING;




-- -- 3. FUNCTION: Fetch all active document configurations
-- DROP FUNCTION IF EXISTS fnGetDocumentMasters();
-- CREATE OR REPLACE FUNCTION fnGetDocumentMasters()
-- RETURNS TABLE(
--     document_id INT, 
--     document_name VARCHAR, 
--     document_code VARCHAR, 
--     prefix VARCHAR, 
--     running_number INT, 
--     approval_required BOOLEAN
-- ) AS $$
-- BEGIN
--     RETURN QUERY 
--     SELECT 
--         DocumentId, DocumentName, DocumentCode, Prefix, RunningNumber, ApprovalRequired
--     FROM tblDocumentMaster 
--     WHERE IsActive = TRUE 
--     ORDER BY DocumentId;
-- END;
-- $$ LANGUAGE plpgsql;




-- -- 4. FUNCTION: Generate Next Document Number safely (e.g., ADM-0001)
-- -- CRITICAL: Uses 'FOR UPDATE' to lock the row. This prevents race conditions if 
-- -- two users try to generate a number at the exact same time.
-- DROP FUNCTION IF EXISTS fnGenerateNextDocumentNumber(VARCHAR);
-- CREATE OR REPLACE FUNCTION fnGenerateNextDocumentNumber(
--     p_doc_code VARCHAR
-- )
-- RETURNS VARCHAR AS $$
-- DECLARE
--     v_prefix VARCHAR;
--     v_next_number INT;
--     v_generated_number VARCHAR;
-- BEGIN
--     -- Lock the specific document row for updating
--     SELECT Prefix, RunningNumber + 1 
--     INTO v_prefix, v_next_number
--     FROM tblDocumentMaster
--     WHERE DocumentCode = p_doc_code AND IsActive = TRUE
--     FOR UPDATE;

--     IF NOT FOUND THEN
--         RAISE EXCEPTION 'ERP Configuration Error: Document Code % not found or is inactive.', p_doc_code;
--     END IF;

--     -- Update the running number in the master table
--     UPDATE tblDocumentMaster
--     SET RunningNumber = v_next_number, 
--         UpdatedDate = NOW()
--     WHERE DocumentCode = p_doc_code;

--     -- Format the output standard ERP style: PREFIX-0000 (e.g., ADM-0001, LEV-0012)
--     v_generated_number := v_prefix || '-' || LPAD(v_next_number::TEXT, 4, '0');

--     RETURN v_generated_number;
-- END;
-- $$ LANGUAGE plpgsql;




-- -- ==========================================
-- -- MODULE 1:  FUNCTION (Removes raw query from Python)
-- -- ==========================================
-- DROP FUNCTION IF EXISTS fnCheckApprovalRequired(VARCHAR);

-- CREATE OR REPLACE FUNCTION fnCheckApprovalRequired(p_document_code VARCHAR)
-- RETURNS BOOLEAN AS $$
-- DECLARE
--     v_is_required BOOLEAN;
-- BEGIN
--     SELECT ApprovalRequired INTO v_is_required
--     FROM tblDocumentMaster 
--     WHERE DocumentCode = p_document_code AND IsActive = TRUE;
    
--     -- Default to TRUE for safety if the document code is not found
--     RETURN COALESCE(v_is_required, TRUE);
-- END;
-- $$ LANGUAGE plpgsql;




-- ==========================================
-- MODULE 2: ERP STATUS MANAGEMENT MASTER
-- ==========================================

-- -- 1. Create the Centralized Status Master Table
-- CREATE TABLE IF NOT EXISTS tblDocumentStatusMaster (
--     StatusId SERIAL PRIMARY KEY,
--     StatusName VARCHAR(50) NOT NULL UNIQUE,
--     StatusCode VARCHAR(50) NOT NULL UNIQUE,
--     SequenceOrder INT NOT NULL,           -- Controls the flow of the workflow (e.g., 10 -> 20 -> 30)
--     IsFinalStatus BOOLEAN DEFAULT FALSE,  -- If TRUE, the document is locked (No more edits/approvals)
--     ColorCode VARCHAR(20) DEFAULT '#000000', -- Used by UI to render badges dynamically
--     IsActive BOOLEAN DEFAULT TRUE,
--     CreatedBy VARCHAR(100) DEFAULT 'System',
--     CreatedDate TIMESTAMP DEFAULT NOW(),
--     UpdatedDate TIMESTAMP DEFAULT NOW()
-- );

-- 2. Insert Seed Data dynamically (ON CONFLICT prevents duplication)
-- We use gaps in SequenceOrder (10, 20, 30) so you can easily insert a status (like 15) later without renumbering everything.

-- INSERT INTO tblDocumentStatusMaster (StatusName, StatusCode, SequenceOrder, IsFinalStatus, ColorCode)
-- VALUES 
--     ('Draft', 'DRAFT', 10, FALSE, '#6c757d'),      -- Gray
--     ('Pending', 'PENDING', 20, FALSE, '#ffc107'),    -- Yellow/Warning
--     ('Approved', 'APPROVED', 30, TRUE, '#198754'),   -- Green
--     ('Rejected', 'REJECTED', 90, TRUE, '#dc3545'),   -- Red
--     ('Cancelled', 'CANCELLED', 95, TRUE, '#343a40'), -- Dark Gray
--     ('Completed', 'COMPLETED', 100, TRUE, '#0d6efd') -- Blue
-- ON CONFLICT (StatusCode) DO NOTHING;

-- -- 3. FUNCTION: Fetch all active statuses
-- DROP FUNCTION IF EXISTS fnGetAllStatuses();
-- CREATE OR REPLACE FUNCTION fnGetAllStatuses()
-- RETURNS TABLE(
--     status_id INT, 
--     status_name VARCHAR, 
--     status_code VARCHAR, 
--     sequence_order INT, 
--     is_final_status BOOLEAN,
--     color_code VARCHAR
-- ) AS $$
-- BEGIN
--     RETURN QUERY 
--     SELECT 
--         StatusId, StatusName, StatusCode, SequenceOrder, IsFinalStatus, ColorCode
--     FROM tblDocumentStatusMaster 
--     WHERE IsActive = TRUE 
--     ORDER BY SequenceOrder ASC;
-- END;
-- $$ LANGUAGE plpgsql;

-- 4. FUNCTION: Get the Initial Status for any new document (Lowest Sequence)
-- DROP FUNCTION IF EXISTS fnGetInitialStatus();
-- CREATE OR REPLACE FUNCTION fnGetInitialStatus()
-- RETURNS VARCHAR AS $$
-- DECLARE
--     v_initial_code VARCHAR;
-- BEGIN
--     SELECT StatusCode INTO v_initial_code
--     FROM tblDocumentStatusMaster
--     WHERE IsActive = TRUE
--     ORDER BY SequenceOrder ASC
--     LIMIT 1;
    
--     RETURN v_initial_code;
-- END;
-- $$ LANGUAGE plpgsql;

-- -- 5. FUNCTION: Dynamic Workflow Engine - Get NEXT Status based on sequence
-- -- This completely eliminates hardcoding! The system just asks "What's next?"
-- DROP FUNCTION IF EXISTS fnGetNextWorkflowStatus(VARCHAR);
-- CREATE OR REPLACE FUNCTION fnGetNextWorkflowStatus(p_current_code VARCHAR)
-- RETURNS VARCHAR AS $$
-- DECLARE
--     v_current_seq INT;
--     v_next_code VARCHAR;
-- BEGIN
--     -- Get the sequence of the current status
--     SELECT SequenceOrder INTO v_current_seq
--     FROM tblDocumentStatusMaster
--     WHERE StatusCode = p_current_code AND IsActive = TRUE;

--     IF NOT FOUND THEN
--         RETURN NULL;
--     END IF;

--     -- Find the next logical step in the workflow
--     SELECT StatusCode INTO v_next_code
--     FROM tblDocumentStatusMaster
--     WHERE SequenceOrder > v_current_seq 
--       AND IsActive = TRUE 
--       AND IsFinalStatus = FALSE
--     ORDER BY SequenceOrder ASC
--     LIMIT 1;

--     RETURN v_next_code;
-- END;
-- $$ LANGUAGE plpgsql;







-- -- ==========================================
-- -- MODULE 3: ERP WORKFLOW CONFIGURATION ENGINE
-- -- ==========================================

-- -- 1. Create the Workflow Transition Table
-- CREATE TABLE IF NOT EXISTS tblDocumentWorkflow (
--     WorkflowId SERIAL PRIMARY KEY,
--     DocumentId INT REFERENCES tblDocumentMaster(DocumentId),
--     CurrentStatusId INT REFERENCES tblDocumentStatusMaster(StatusId),
--     NextStatusId INT REFERENCES tblDocumentStatusMaster(StatusId),
--     ActionName VARCHAR(50) NOT NULL, -- The button text (e.g., 'Approve', 'Reject', 'Submit')
--     RoleName VARCHAR(50) NOT NULL,   -- Who can perform this action
--     IsActive BOOLEAN DEFAULT TRUE,
--     CreatedDate TIMESTAMP DEFAULT NOW(),
--     UpdatedDate TIMESTAMP DEFAULT NOW(),
--     -- A role can only perform a specific action once per state on a specific document type
--     UNIQUE (DocumentId, CurrentStatusId, ActionName, RoleName) 
-- );



-- -- 2. Insert Seed Data Dynamically (NO HARDCODED IDs)
-- -- We use subqueries to fetch the exact IDs based on the codes we defined in Mod 1 & 2.
-- DO $$ 
-- BEGIN
--     -- Example: Leave Request Workflow
--     -- 1. Employee Submits Draft -> Pending
--     INSERT INTO tblDocumentWorkflow (DocumentId, CurrentStatusId, NextStatusId, ActionName, RoleName)
--     SELECT d.DocumentId, s1.StatusId, s2.StatusId, 'Submit', 'Employee'
--     FROM tblDocumentMaster d, tblDocumentStatusMaster s1, tblDocumentStatusMaster s2
--     WHERE d.DocumentCode = 'LEAVE_REQ' AND s1.StatusCode = 'DRAFT' AND s2.StatusCode = 'PENDING'
--     ON CONFLICT DO NOTHING;

--     -- 2. Manager Approves Pending -> Approved
--     INSERT INTO tblDocumentWorkflow (DocumentId, CurrentStatusId, NextStatusId, ActionName, RoleName)
--     SELECT d.DocumentId, s1.StatusId, s2.StatusId, 'Approve', 'Manager'
--     FROM tblDocumentMaster d, tblDocumentStatusMaster s1, tblDocumentStatusMaster s2
--     WHERE d.DocumentCode = 'LEAVE_REQ' AND s1.StatusCode = 'PENDING' AND s2.StatusCode = 'APPROVED'
--     ON CONFLICT DO NOTHING;

--     -- 3. Manager Rejects Pending -> Rejected
--     INSERT INTO tblDocumentWorkflow (DocumentId, CurrentStatusId, NextStatusId, ActionName, RoleName)
--     SELECT d.DocumentId, s1.StatusId, s2.StatusId, 'Reject', 'Manager'
--     FROM tblDocumentMaster d, tblDocumentStatusMaster s1, tblDocumentStatusMaster s2
--     WHERE d.DocumentCode = 'LEAVE_REQ' AND s1.StatusCode = 'PENDING' AND s2.StatusCode = 'REJECTED'
--     ON CONFLICT DO NOTHING;
-- END $$;

-- -- 3. FUNCTION: Get Available Actions (Renders dynamic UI buttons)
-- DROP FUNCTION IF EXISTS fnGetAvailableActions(VARCHAR, VARCHAR, VARCHAR);
-- CREATE OR REPLACE FUNCTION fnGetAvailableActions(
--     p_doc_code VARCHAR,
--     p_current_status_code VARCHAR,
--     p_role_name VARCHAR
-- )
-- RETURNS TABLE (
--     action_name VARCHAR,
--     next_status_code VARCHAR,
--     color_code VARCHAR
-- ) AS $$
-- BEGIN
--     RETURN QUERY
--     SELECT 
--         w.ActionName, 
--         ns.StatusCode AS next_status_code,
--         ns.ColorCode  AS color_code
--     FROM tblDocumentWorkflow w
--     JOIN tblDocumentMaster d ON w.DocumentId = d.DocumentId
--     JOIN tblDocumentStatusMaster cs ON w.CurrentStatusId = cs.StatusId
--     JOIN tblDocumentStatusMaster ns ON w.NextStatusId = ns.StatusId
--     WHERE d.DocumentCode = p_doc_code 
--       AND cs.StatusCode = p_current_status_code
--       AND w.RoleName = p_role_name
--       AND w.IsActive = TRUE;
-- END;
-- $$ LANGUAGE plpgsql;

-- -- 4. FUNCTION: Validate Transition and Process Workflow
-- DROP FUNCTION IF EXISTS fnProcessWorkflowAction(VARCHAR, VARCHAR, VARCHAR, VARCHAR);
-- CREATE OR REPLACE FUNCTION fnProcessWorkflowAction(
--     p_doc_code VARCHAR,
--     p_current_status_code VARCHAR,
--     p_action_name VARCHAR,
--     p_role_name VARCHAR
-- )
-- RETURNS VARCHAR AS $$
-- DECLARE
--     v_next_status_code VARCHAR;
-- BEGIN
--     -- Attempt to find the configured next status based on the provided parameters
--     SELECT ns.StatusCode INTO v_next_status_code
--     FROM tblDocumentWorkflow w
--     JOIN tblDocumentMaster d ON w.DocumentId = d.DocumentId
--     JOIN tblDocumentStatusMaster cs ON w.CurrentStatusId = cs.StatusId
--     JOIN tblDocumentStatusMaster ns ON w.NextStatusId = ns.StatusId
--     WHERE d.DocumentCode = p_doc_code 
--       AND cs.StatusCode = p_current_status_code
--       AND w.ActionName = p_action_name
--       AND w.RoleName = p_role_name
--       AND w.IsActive = TRUE;

--     -- If no valid transition exists, throw an error
--     IF NOT FOUND THEN
--         RAISE EXCEPTION 'Workflow Error: Action "%" is not permitted for Role "%" on Document "%" in Status "%"', 
--             p_action_name, p_role_name, p_doc_code, p_current_status_code;
--     END IF;

--     RETURN v_next_status_code;
-- END;
-- $$ LANGUAGE plpgsql;





-- -- ==========================================
-- -- MODULE 4: DYNAMIC DOCUMENT NUMBER GENERATION
-- -- ==========================================

-- DROP FUNCTION IF EXISTS spGenerateDocumentNumber(VARCHAR);

-- -- NOTE: We use a FUNCTION returning VARCHAR so Django can easily call it via SELECT.
-- -- The 'sp' prefix denotes a Stored Procedure-like behavior.
-- CREATE OR REPLACE FUNCTION spGenerateDocumentNumber(
--     p_document_code VARCHAR
-- )
-- RETURNS VARCHAR AS $$
-- DECLARE
--     v_prefix VARCHAR;
--     v_current_number INT;
--     v_new_number INT;
--     v_generated_number VARCHAR;
-- BEGIN
--     -- 1. ROW-LEVEL LOCKING (The Concurrency Secret)
--     -- 'FOR UPDATE' locks this specific document's row. 
--     -- If two users click 'Submit' at the exact same time, the second user 
--     -- is forced to wait until the first user's transaction finishes.
--     SELECT Prefix, RunningNumber 
--     INTO v_prefix, v_current_number
--     FROM tblDocumentMaster
--     WHERE DocumentCode = p_document_code AND IsActive = TRUE
--     FOR UPDATE;

--     -- 2. Validate if the document type exists
--     IF NOT FOUND THEN
--         RAISE EXCEPTION 'ERP Configuration Error: Document Code "%" not found or is inactive.', p_document_code;
--     END IF;

--     -- 3. Increment the running number
--     v_new_number := COALESCE(v_current_number, 0) + 1;

--     -- 4. Update the master table to save the new running number
--     UPDATE tblDocumentMaster
--     SET RunningNumber = v_new_number,
--         UpdatedDate = NOW()
--     WHERE DocumentCode = p_document_code;

--     -- 5. Format the new document number with 5 digits (e.g., ADM-00001, LEV-00042)
--     v_generated_number := v_prefix || '-' || LPAD(v_new_number::TEXT, 5, '0');

--     -- 6. Return the fully formatted string
--     RETURN v_generated_number;
-- END;
-- $$ LANGUAGE plpgsql;







-- -- ==========================================
-- -- MODULE 5: GENERIC APPROVAL ENGINE
-- -- ==========================================

-- -- 1. Create a Centralized Audit & History Table for ALL Modules
-- CREATE TABLE IF NOT EXISTS tblGenericApprovalHistory (
--     HistoryId SERIAL PRIMARY KEY,
--     DocumentCode VARCHAR(50) NOT NULL,  -- e.g., 'STUDENT_ADM', 'LEAVE_REQ'
--     RecordId VARCHAR(50) NOT NULL,      -- The ID of the record in the specific table
--     ActionName VARCHAR(50) NOT NULL,    -- 'Approve', 'Reject', 'Submit'
--     OldStatusCode VARCHAR(50) NOT NULL, -- 'PENDING'
--     NewStatusCode VARCHAR(50) NOT NULL, -- 'APPROVED'
--     Remarks TEXT,
--     PerformedBy VARCHAR(100) NOT NULL,  -- User ID or Username
--     PerformedDate TIMESTAMP DEFAULT NOW()
-- );




-- -- 2. The Universal Processing Procedure
-- DROP FUNCTION IF EXISTS spProcessDocumentAction(VARCHAR, VARCHAR, VARCHAR, VARCHAR, VARCHAR, VARCHAR, TEXT);

-- CREATE OR REPLACE FUNCTION spProcessDocumentAction(
--     p_DocumentCode VARCHAR,
--     p_RecordId VARCHAR,
--     p_CurrentStatusCode VARCHAR,
--     p_ActionName VARCHAR,
--     p_RoleName VARCHAR,
--     p_PerformedBy VARCHAR,
--     p_Remarks TEXT
-- )
-- RETURNS VARCHAR AS $$
-- DECLARE
--     v_NextStatusCode VARCHAR;
--     v_RecentAction VARCHAR;
--     v_TargetTable VARCHAR;
--     v_TargetStatusCol VARCHAR;
--     v_TargetPkCol VARCHAR;
--     v_DynamicSQL TEXT;
-- BEGIN
--     -- 1. VALIDATE WORKFLOW TRANSITION & FETCH TARGET TABLE METADATA
--     SELECT ns.StatusCode, d.TargetTableName, d.TargetStatusColumn, d.TargetPrimaryKey
--     INTO v_NextStatusCode, v_TargetTable, v_TargetStatusCol, v_TargetPkCol
--     FROM tblDocumentWorkflow w
--     JOIN tblDocumentMaster d ON w.DocumentId = d.DocumentId
--     JOIN tblDocumentStatusMaster cs ON w.CurrentStatusId = cs.StatusId
--     JOIN tblDocumentStatusMaster ns ON w.NextStatusId = ns.StatusId
--     WHERE d.DocumentCode = p_DocumentCode 
--       AND cs.StatusCode = p_CurrentStatusCode
--       AND w.ActionName = p_ActionName
--       AND w.RoleName = p_RoleName
--       AND w.IsActive = TRUE;

--     -- 2. PREVENT INVALID ACTIONS
--     IF NOT FOUND THEN
--         RAISE EXCEPTION 'Workflow Security Violation: Action "%" is not permitted for Role "%" on Document "%" in Status "%".', 
--             p_ActionName, p_RoleName, p_DocumentCode, p_CurrentStatusCode;
--     END IF;

--     -- 3. PREVENT DUPLICATE APPROVALS (Concurrency Check)
--     SELECT ActionName INTO v_RecentAction
--     FROM tblGenericApprovalHistory
--     WHERE DocumentCode = p_DocumentCode 
--       AND RecordId = p_RecordId 
--       AND NewStatusCode = v_NextStatusCode
--       AND PerformedDate >= NOW() - INTERVAL '2 seconds';

--     IF FOUND THEN
--         RAISE EXCEPTION 'Duplicate Action Error: This document was just processed.';
--     END IF;

--     -- 4. STORE ACTION HISTORY
--     INSERT INTO tblGenericApprovalHistory (
--         DocumentCode, RecordId, ActionName, OldStatusCode, NewStatusCode, Remarks, PerformedBy
--     ) VALUES (
--         p_DocumentCode, p_RecordId, p_ActionName, p_CurrentStatusCode, v_NextStatusCode, p_Remarks, p_PerformedBy
--     );

--     -- 5. DYNAMICALLY UPDATE THE PARENT TABLE (NO HARDCODING!)
--     -- The DB builds a string like: UPDATE students SET status = 'APPROVED' WHERE id = 1
--     IF v_TargetTable IS NOT NULL THEN
--         v_DynamicSQL := format('UPDATE %I SET %I = %L, updated_date = NOW() WHERE %I = %s', 
--                                v_TargetTable, v_TargetStatusCol, v_NextStatusCode, v_TargetPkCol, p_RecordId);
--         EXECUTE v_DynamicSQL;
--     END IF;

--     RETURN v_NextStatusCode;
-- END;
-- $$ LANGUAGE plpgsql;



-- -- Add Target Metadata Columns to Document Master
-- ALTER TABLE tblDocumentMaster
-- ADD COLUMN IF NOT EXISTS TargetTableName VARCHAR(50),
-- ADD COLUMN IF NOT EXISTS TargetStatusColumn VARCHAR(50) DEFAULT 'status',
-- ADD COLUMN IF NOT EXISTS TargetPrimaryKey VARCHAR(50) DEFAULT 'id';

-- -- Update the existing seed data so the DB knows where 'STUDENT_ADM' lives
-- UPDATE tblDocumentMaster 
-- SET TargetTableName = 'students', 
--     TargetStatusColumn = 'status', 
--     TargetPrimaryKey = 'id' 
-- WHERE DocumentCode = 'STUDENT_ADM';




-- -- ==========================================
-- -- MODULE 6: ERP AUDIT & HISTORY TRACKING
-- -- ==========================================

-- -- 1. Create the Centralized Audit Trail Table
-- CREATE TABLE IF NOT EXISTS tblDocumentHistory (
--     HistoryId SERIAL PRIMARY KEY,
--     DocumentId INT REFERENCES tblDocumentMaster(DocumentId),
--     RecordId VARCHAR(50) NOT NULL,
--     OldStatus VARCHAR(50),       -- For workflow transitions
--     NewStatus VARCHAR(50),       -- For workflow transitions
--     Action VARCHAR(50) NOT NULL, -- e.g., 'INSERT', 'UPDATE', 'DELETE', 'APPROVE'
--     Remarks TEXT,
--     OldData JSONB,               -- Captures the EXACT state of the row BEFORE edit
--     NewData JSONB,               -- Captures the EXACT state of the row AFTER edit
--     ActionBy VARCHAR(100) DEFAULT 'System',
--     ActionDate TIMESTAMP DEFAULT NOW(),
--     IPAddress VARCHAR(45)        -- Supports IPv4 and IPv6
-- );

-- -- 2. CREATE UNIVERSAL AUDIT TRIGGER FUNCTION
-- -- This single function can be attached to ANY table in the ERP.
-- -- It dynamically reads the table structure using row_to_json().
-- DROP FUNCTION IF EXISTS spGenericAuditTrigger() CASCADE;
-- CREATE OR REPLACE FUNCTION spGenericAuditTrigger()
-- RETURNS TRIGGER AS $$
-- DECLARE
--     -- The trigger expects two arguments: [1] DocumentCode, [2] Primary Key Column Name
--     v_DocCode VARCHAR := TG_ARGV[0];
--     v_PkColumn VARCHAR := TG_ARGV[1];
--     v_DocId INT;
--     v_RecordId VARCHAR;
--     v_OldData JSONB := NULL;
--     v_NewData JSONB := NULL;
--     v_ActionBy VARCHAR := 'System';
--     v_IPAddress VARCHAR := 'Unknown';
-- BEGIN
--     -- Look up the official DocumentId
--     SELECT DocumentId INTO v_DocId FROM tblDocumentMaster WHERE DocumentCode = v_DocCode;

--     -- Extract Context Variables (Passed from Django via SET LOCAL)
--     BEGIN
--         v_ActionBy := current_setting('erp.current_user', true);
--         v_IPAddress := current_setting('erp.current_ip', true);
--     EXCEPTION WHEN OTHERS THEN
--         -- Fallback if variables aren't set
--         v_ActionBy := 'System';
--     END;

--     -- Dynamically capture Before/After state based on the Action
--     IF TG_OP = 'INSERT' THEN
--         v_NewData := row_to_json(NEW)::jsonb;
--         v_RecordId := v_NewData->>v_PkColumn;
--     ELSIF TG_OP = 'UPDATE' THEN
--         v_OldData := row_to_json(OLD)::jsonb;
--         v_NewData := row_to_json(NEW)::jsonb;
--         v_RecordId := v_NewData->>v_PkColumn;
--     ELSIF TG_OP = 'DELETE' THEN
--         v_OldData := row_to_json(OLD)::jsonb;
--         v_RecordId := v_OldData->>v_PkColumn;
--     END IF;

--     -- Insert the deep audit record
--     INSERT INTO tblDocumentHistory (
--         DocumentId, RecordId, Action, OldData, NewData, ActionBy, ActionDate, IPAddress
--     ) VALUES (
--         v_DocId, v_RecordId, TG_OP, v_OldData, v_NewData, COALESCE(v_ActionBy, 'System'), NOW(), v_IPAddress
--     );

--     IF TG_OP = 'DELETE' THEN
--         RETURN OLD;
--     END IF;
--     RETURN NEW;
-- END;
-- $$ LANGUAGE plpgsql;

-- -- 3. EXAMPLE: How to attach this to your Students table
-- -- We pass the Module Code ('STUDENT_ADM') and the Primary Key column ('id')
-- DROP TRIGGER IF EXISTS trg_audit_students ON students;
-- CREATE TRIGGER trg_audit_students
-- AFTER INSERT OR UPDATE OR DELETE ON students
-- FOR EACH ROW EXECUTE FUNCTION spGenericAuditTrigger('STUDENT_ADM', 'id');




-- -- ==========================================
-- -- MODULE 6: Get Document History Function
-- -- ==========================================
-- DROP FUNCTION IF EXISTS fnGetDocumentHistory(VARCHAR, VARCHAR);

-- CREATE OR REPLACE FUNCTION fnGetDocumentHistory(
--     p_document_code VARCHAR,
--     p_record_id VARCHAR
-- )
-- RETURNS TABLE (
--     history_id INT,
--     action VARCHAR,
--     old_status VARCHAR,
--     new_status VARCHAR,
--     remarks TEXT,
--     action_by VARCHAR,
--     action_date TIMESTAMP,
--     ip_address VARCHAR,
--     old_data JSONB,
--     new_data JSONB
-- ) AS $$
-- BEGIN
--     RETURN QUERY
--     SELECT 
--         h.HistoryId, h.Action, h.OldStatus, h.NewStatus, 
--         h.Remarks, h.ActionBy, h.ActionDate, h.IPAddress,
--         h.OldData, h.NewData
--     FROM tblDocumentHistory h
--     JOIN tblDocumentMaster d ON h.DocumentId = d.DocumentId
--     WHERE d.DocumentCode = p_document_code 
--       AND h.RecordId = p_record_id
--     ORDER BY h.HistoryId DESC;
-- END;
-- $$ LANGUAGE plpgsql;





-- -- ==========================================
-- -- MODULE 7: STUDENT ADMISSION ERP MODULE 
-- -- ==========================================

-- -- 1. Upgrade the Students Table for ERP Standards
-- ALTER TABLE students 
-- ADD COLUMN IF NOT EXISTS document_number VARCHAR(50) UNIQUE;

-- -- We will use the existing 'status' column to store the dynamic 'StatusCode' (e.g., 'DRAFT', 'PENDING')
-- -- Drop the old hardcoded default if it exists.
-- ALTER TABLE students ALTER COLUMN status DROP DEFAULT;

-- -- 2. Attach the Universal Audit Trigger (From Module 6) to the Students table
-- -- This guarantees EVERY change to a student is forensically logged as a JSONB snapshot.

-- DROP TRIGGER IF EXISTS trg_audit_students ON students;

-- CREATE TRIGGER trg_audit_students
-- AFTER INSERT OR UPDATE OR DELETE ON students
-- FOR EACH ROW EXECUTE FUNCTION spGenericAuditTrigger('STUDENT_ADM', 'id');









-- -- ==========================================
-- -- MODULE 7 UPDATE 1: ERP-Native Add Student
-- -- ==========================================
-- DROP FUNCTION IF EXISTS fnAddStudent(VARCHAR, VARCHAR, VARCHAR, INT, VARCHAR);

-- CREATE OR REPLACE FUNCTION fnAddStudent(
--     p_name VARCHAR,
--     p_phone VARCHAR,
--     p_email VARCHAR,
--     p_course_id INT,
--     p_student_image VARCHAR DEFAULT NULL,
--     p_created_by VARCHAR DEFAULT 'System'
-- )
-- RETURNS INT AS $$
-- DECLARE
--     v_new_student_id INT;
--     v_doc_number VARCHAR;
--     v_initial_status VARCHAR;
-- BEGIN
--     -- 1. DYNAMIC ERP NUMBER: Get the next available ADM-XXXXX number safely
--     v_doc_number := spGenerateDocumentNumber('STUDENT_ADM');

--     -- 2. DYNAMIC STATUS: Ask the system what the first status is (e.g., 'DRAFT')
--     v_initial_status := fnGetInitialStatus();

--     -- 3. INSERT RECORD: Save the student with the official ERP configuration
--     INSERT INTO students (
--         document_number, name, phone, email, course_id, student_image, status, created_date, updated_date
--     )
--     VALUES (
--         v_doc_number, p_name, p_phone, p_email, p_course_id, p_student_image, v_initial_status, NOW(), NOW()
--     )
--     RETURNING id INTO v_new_student_id;

--     -- 4. COURSE MAPPING: Maintain relations
--     INSERT INTO tblStudentCourse (student_id, course_id, enrollment_date, status, created_date, updated_date)
--     VALUES (v_new_student_id, p_course_id, CURRENT_DATE, 'Active', NOW(), NOW());

--     -- 5. TRACK CREATION: Log the genesis of the document in the Universal History Table
--     INSERT INTO tblGenericApprovalHistory (
--         DocumentCode, RecordId, ActionName, OldStatusCode, NewStatusCode, Remarks, PerformedBy
--     ) VALUES (
--         'STUDENT_ADM', v_new_student_id::VARCHAR, 'Submit Application', 'NONE', v_initial_status, 'Initial Admission Record Created', p_created_by
--     );

--     RETURN v_new_student_id;
-- END;
-- $$ LANGUAGE plpgsql;




-- -- ==========================================
-- -- MODULE 7 UPDATE 2: ERP-Native Edit Student
-- -- ==========================================
-- DROP FUNCTION IF EXISTS fnEditStudent(INT, VARCHAR, VARCHAR, VARCHAR, INT, VARCHAR, INT, TEXT, DATE);

-- CREATE OR REPLACE FUNCTION fnEditStudent(
--     p_student_id INT,
--     p_name VARCHAR,
--     p_phone VARCHAR,
--     p_email VARCHAR,
--     p_course_id INT,
--     p_student_image VARCHAR DEFAULT NULL,
--     p_age INT DEFAULT NULL,
--     p_address TEXT DEFAULT NULL,
--     p_dob DATE DEFAULT NULL
-- )
-- RETURNS BOOLEAN AS $$
-- DECLARE
--     v_rows_affected INT;
--     v_reset_status VARCHAR;
-- BEGIN
--     -- Fetch the starting status dynamically so any edits push the document back to the start of the workflow
--     v_reset_status := fnGetInitialStatus();

--     UPDATE students 
--     SET 
--         name = COALESCE(p_name, name),
--         age = COALESCE(p_age, age),
--         phone = COALESCE(p_phone, phone),
--         email = COALESCE(p_email, email),
--         address = COALESCE(p_address, address),
--         dob = COALESCE(p_dob, dob),
--         student_image = COALESCE(p_student_image, student_image),
--         status = v_reset_status, -- ERP ENFORCEMENT: Reset workflow status dynamically
--         updated_date = NOW()
--     WHERE id = p_student_id;
    
--     GET DIAGNOSTICS v_rows_affected = ROW_COUNT;
    
--     -- Update course enrollment
--     IF p_course_id IS NOT NULL THEN
--         PERFORM fnUpdateStudentCourse(p_student_id, p_course_id);
--     END IF;
    
--     -- Log the workflow reset into the ERP generic history
--     IF v_rows_affected > 0 THEN
--         INSERT INTO tblGenericApprovalHistory (
--             DocumentCode, RecordId, ActionName, OldStatusCode, NewStatusCode, Remarks, PerformedBy
--         ) VALUES (
--             'STUDENT_ADM', p_student_id::VARCHAR, 'Edit Record', 'VARIOUS', v_reset_status, 'Record edited - Workflow reset', 'System'
--         );
--     END IF;
    
--     RETURN v_rows_affected > 0;
-- END;
-- $$ LANGUAGE plpgsql;





-- -- ==========================================
-- -- MODULE 7 UPDATE 3: ERP-Native Listing View
-- -- Removes the legacy LEFT JOIN on `studentapproval`
-- -- ==========================================
-- DROP FUNCTION IF EXISTS fnGetStudentsWithCurrentCourse(VARCHAR);

-- CREATE OR REPLACE FUNCTION fnGetStudentsWithCurrentCourse(p_search VARCHAR DEFAULT NULL)
-- RETURNS TABLE(
--      id INT, document_number VARCHAR, name VARCHAR, phone VARCHAR, email VARCHAR, 
--      course_id INT, course VARCHAR, course_code VARCHAR, student_image VARCHAR, 
--      created_date TIMESTAMP, updated_date TIMESTAMP, 
--      approval_status VARCHAR, approved_by VARCHAR, remarks TEXT, approved_date TIMESTAMP
-- ) AS $$
-- BEGIN
--      RETURN QUERY
--      SELECT
--          s.id, s.document_number, s.name, s.phone, s.email, sc.course_id,
--          COALESCE(c.course_name, 'Not assigned'), COALESCE(c.course_code, ''),
--          s.student_image, s.created_date, s.updated_date,
         
--          -- Pull directly from the new ERP status column
--          COALESCE(s.status, 'UNKNOWN'), 
         
--          -- Pull timeline details from the Universal Generic History Table
--          COALESCE(h.PerformedBy, 'System'),
--          COALESCE(h.Remarks, ''), 
--          h.PerformedDate::timestamp without time zone
--      FROM students s
--      LEFT JOIN tblStudentCourse sc ON s.id = sc.student_id AND sc.status = 'Active'
--      LEFT JOIN tblCourse c ON sc.course_id = c.course_id
--      -- Dynamic ERP Join
--      LEFT JOIN LATERAL (
--          -- FIX: Aliased table as 'gah' and explicitly selected gah.Remarks
--          SELECT gah.PerformedBy, gah.Remarks, gah.PerformedDate
--          FROM tblGenericApprovalHistory gah
--          WHERE gah.DocumentCode = 'STUDENT_ADM' 
--            AND gah.RecordId = s.id::VARCHAR 
--            AND gah.NewStatusCode = s.status
--          ORDER BY gah.HistoryId DESC LIMIT 1
--      ) h ON TRUE
--      WHERE s.is_deleted = FALSE
--        AND (p_search IS NULL OR s.name ILIKE '%' || p_search || '%' OR s.document_number ILIKE '%' || p_search || '%')
--      ORDER BY s.id DESC;
-- END;
-- $$ LANGUAGE plpgsql;





-- -- ==========================================
-- -- MODULE 8: LEAVE REQUEST ERP MODULE
-- -- ==========================================

-- -- 1. Create the Leave Request Table
-- CREATE TABLE IF NOT EXISTS tblLeaveRequests (
--     id SERIAL PRIMARY KEY,
--     document_number VARCHAR(50) UNIQUE NOT NULL,
--     employee_name VARCHAR(100) NOT NULL,
--     leave_type VARCHAR(50) NOT NULL,
--     start_date DATE NOT NULL,
--     end_date DATE NOT NULL,
--     reason TEXT,
--     status VARCHAR(50) NOT NULL, -- Managed dynamically by ERP Status Master
--     created_by VARCHAR(100) DEFAULT 'System',
--     created_date TIMESTAMP DEFAULT NOW(),
--     updated_date TIMESTAMP DEFAULT NOW(),
--     is_deleted BOOLEAN DEFAULT FALSE
-- );

-- -- 2. Metadata Registration (Crucial for the Generic Approval Engine!)
-- -- We update the Document Master so the Engine knows where 'LEAVE_REQ' data lives.
-- UPDATE tblDocumentMaster 
-- SET TargetTableName = 'tblLeaveRequests', 
--     TargetStatusColumn = 'status', 
--     TargetPrimaryKey = 'id' 
-- WHERE DocumentCode = 'LEAVE_REQ';

-- 3. Attach the Universal Audit Trigger
-- This guarantees EVERY edit/delete is captured in tblDocumentHistory automatically.
-- DROP TRIGGER IF EXISTS trg_audit_leaves ON tblLeaveRequests;
-- CREATE TRIGGER trg_audit_leaves
-- AFTER INSERT OR UPDATE OR DELETE ON tblLeaveRequests
-- FOR EACH ROW EXECUTE FUNCTION spGenericAuditTrigger('LEAVE_REQ', 'id');


-- -- -- ==========================================
-- -- -- FUNCTION: Create Leave Request
-- -- -- ==========================================
-- DROP FUNCTION IF EXISTS fnCreateLeaveRequest(VARCHAR, VARCHAR, DATE, DATE, TEXT, VARCHAR);

-- CREATE OR REPLACE FUNCTION fnCreateLeaveRequest(
--     p_employee_name VARCHAR,
--     p_leave_type VARCHAR,
--     p_start_date DATE,
--     p_end_date DATE,
--     p_reason TEXT,
--     p_created_by VARCHAR DEFAULT 'System'
-- )
-- RETURNS INT AS $$
-- DECLARE
--     v_new_leave_id INT;
--     v_doc_number VARCHAR;
--     v_initial_status VARCHAR;
-- BEGIN
--     -- 1. Get the dynamic LEV-XXXXX number
--     v_doc_number := spGenerateDocumentNumber('LEAVE_REQ');

--     -- 2. Ask the Status Master for the starting state (e.g., 'DRAFT')
--     v_initial_status := fnGetInitialStatus();

--     -- 3. Insert the record
--     INSERT INTO tblLeaveRequests (
--         document_number, employee_name, leave_type, start_date, end_date, reason, status, created_by
--     ) VALUES (
--         v_doc_number, p_employee_name, p_leave_type, p_start_date, p_end_date, p_reason, v_initial_status, p_created_by
--     ) RETURNING id INTO v_new_leave_id;

--     -- 4. Log the creation in the Generic Workflow History
--     INSERT INTO tblGenericApprovalHistory (
--         DocumentCode, RecordId, ActionName, OldStatusCode, NewStatusCode, Remarks, PerformedBy
--     ) VALUES (
--         'LEAVE_REQ', v_new_leave_id::VARCHAR, 'Create Draft', 'NONE', v_initial_status, 'Leave Request drafted.', p_created_by
--     );

--     RETURN v_new_leave_id;
-- END;
-- $$ LANGUAGE plpgsql;


-- -- ==========================================
-- -- FUNCTION: Edit Leave Request
-- -- ==========================================
-- DROP FUNCTION IF EXISTS fnEditLeaveRequest(INT, VARCHAR, VARCHAR, DATE, DATE, TEXT, VARCHAR);

-- CREATE OR REPLACE FUNCTION fnEditLeaveRequest(
--     p_leave_id INT,
--     p_employee_name VARCHAR,
--     p_leave_type VARCHAR,
--     p_start_date DATE,
--     p_end_date DATE,
--     p_reason TEXT,
--     p_edited_by VARCHAR DEFAULT 'System'
-- )
-- RETURNS BOOLEAN AS $$
-- DECLARE
--     v_rows_affected INT;
--     v_reset_status VARCHAR;
-- BEGIN
--     -- Fetch the starting status so edits reset the workflow safely
--     v_reset_status := fnGetInitialStatus();

--     UPDATE tblLeaveRequests 
--     SET 
--         employee_name = COALESCE(p_employee_name, employee_name),
--         leave_type = COALESCE(p_leave_type, leave_type),
--         start_date = COALESCE(p_start_date, start_date),
--         end_date = COALESCE(p_end_date, end_date),
--         reason = COALESCE(p_reason, reason),
--         status = v_reset_status, -- ERP Rule: Edits reset workflow to start
--         updated_date = NOW()
--     WHERE id = p_leave_id;
    
--     GET DIAGNOSTICS v_rows_affected = ROW_COUNT;
    
--     -- Log the workflow reset into the generic history
--     IF v_rows_affected > 0 THEN
--         INSERT INTO tblGenericApprovalHistory (
--             DocumentCode, RecordId, ActionName, OldStatusCode, NewStatusCode, Remarks, PerformedBy
--         ) VALUES (
--             'LEAVE_REQ', p_leave_id::VARCHAR, 'Edit Record', 'VARIOUS', v_reset_status, 'Request edited - Workflow reset', p_edited_by
--         );
--     END IF;
    
--     RETURN v_rows_affected > 0;
-- END;
-- $$ LANGUAGE plpgsql;


-- -- ==========================================
-- -- FUNCTION: Get Leave Requests Listing
-- -- ==========================================
-- DROP FUNCTION IF EXISTS fnGetLeaveRequests(VARCHAR);

-- CREATE OR REPLACE FUNCTION fnGetLeaveRequests(p_search VARCHAR DEFAULT NULL)
-- RETURNS TABLE(
--     id INT, document_number VARCHAR, employee_name VARCHAR, leave_type VARCHAR, 
--     start_date DATE, end_date DATE, status VARCHAR, created_date TIMESTAMP,
--     last_action_by VARCHAR, last_action_date TIMESTAMP
-- ) AS $$
-- BEGIN
--     RETURN QUERY
--     SELECT
--         l.id, l.document_number, l.employee_name, l.leave_type, 
--         l.start_date, l.end_date, l.status, l.created_date,
--         -- Fetch the timeline dynamically from the Universal Engine
--         COALESCE(h.PerformedBy, 'System'),
--         h.PerformedDate::timestamp without time zone
--     FROM tblLeaveRequests l
--     LEFT JOIN LATERAL (
--         SELECT PerformedBy, PerformedDate
--         FROM tblGenericApprovalHistory
--         WHERE DocumentCode = 'LEAVE_REQ' AND RecordId = l.id::VARCHAR AND NewStatusCode = l.status
--         ORDER BY HistoryId DESC LIMIT 1
--     ) h ON TRUE
--     WHERE l.is_deleted = FALSE
--       AND (p_search IS NULL OR l.employee_name ILIKE '%' || p_search || '%' OR l.document_number ILIKE '%' || p_search || '%')
--     ORDER BY l.id DESC;
-- END;
-- $$ LANGUAGE plpgsql;







-- -- ==========================================
-- -- MODULE 9: GENERIC ERP APIs 
-- -- ==========================================

-- -- 1. GET GENERIC DOCUMENT LISTING (With Search & Pagination)
-- DROP FUNCTION IF EXISTS fnGetDynamicDocuments(VARCHAR, VARCHAR, INT, INT);
-- CREATE OR REPLACE FUNCTION fnGetDynamicDocuments(
--     p_doc_code VARCHAR,
--     p_search VARCHAR DEFAULT NULL,
--     p_limit INT DEFAULT 10,
--     p_offset INT DEFAULT 0
-- )
-- RETURNS JSONB AS $$
-- DECLARE
--     v_table VARCHAR;
--     v_status_col VARCHAR;
--     v_sql TEXT;
--     v_result JSONB;
-- BEGIN
--     -- Dynamically find which table this document code belongs to
--     SELECT TargetTableName, TargetStatusColumn 
--     INTO v_table, v_status_col
--     FROM tblDocumentMaster WHERE DocumentCode = p_doc_code AND IsActive = TRUE;

--     IF NOT FOUND THEN
--         RAISE EXCEPTION 'Document Code % not found or inactive.', p_doc_code;
--     END IF;

--     -- Build a dynamic SQL query that searches all text columns using cast to text
--     -- and applies pagination. row_to_json captures the entire row dynamically!
--     v_sql := format('
--         WITH FilteredData AS (
--             SELECT * FROM %I 
--             WHERE is_deleted = FALSE
--             %s 
--             ORDER BY created_date DESC
--             LIMIT %s OFFSET %s
--         )
--         SELECT COALESCE(jsonb_agg(row_to_json(t)), ''[]''::jsonb) FROM FilteredData t;
--     ', 
--     v_table, 
--     CASE WHEN p_search IS NOT NULL AND p_search != '' THEN 
--         'AND (document_number ILIKE ' || quote_literal('%' || p_search || '%') || ')'
--     ELSE '' END,
--     p_limit, 
--     p_offset);

--     EXECUTE v_sql INTO v_result;
--     RETURN v_result;
-- END;
-- $$ LANGUAGE plpgsql;


-- -- 2. CREATE DYNAMIC DOCUMENT (Generic Insert)
-- DROP FUNCTION IF EXISTS spCreateDynamicDocument(VARCHAR, JSONB, VARCHAR);
-- CREATE OR REPLACE FUNCTION spCreateDynamicDocument(
--     p_doc_code VARCHAR,
--     p_payload JSONB,
--     p_created_by VARCHAR DEFAULT 'System'
-- )
-- RETURNS JSONB AS $$
-- DECLARE
--     v_table VARCHAR;
--     v_pk VARCHAR;
--     v_status_col VARCHAR;
--     v_doc_number VARCHAR;
--     v_initial_status VARCHAR;
--     v_cols TEXT;
--     v_vals TEXT;
--     v_sql TEXT;
--     v_new_id INT;
-- BEGIN
--     -- Get Configuration
--     SELECT TargetTableName, TargetPrimaryKey, TargetStatusColumn
--     INTO v_table, v_pk, v_status_col
--     FROM tblDocumentMaster WHERE DocumentCode = p_doc_code AND IsActive = TRUE;

--     IF NOT FOUND THEN RAISE EXCEPTION 'Invalid Document Code'; END IF;

--     -- Ask ERP Engine for Number and Status
--     v_doc_number := spGenerateDocumentNumber(p_doc_code);
--     v_initial_status := fnGetInitialStatus();

--     -- Inject ERP mandatory fields into the JSON payload automatically
--     p_payload := p_payload || jsonb_build_object(
--         'document_number', v_doc_number,
--         v_status_col, v_initial_status,
--         'created_by', p_created_by,
--         'created_date', NOW(),
--         'updated_date', NOW()
--     );

--     -- Dynamically extract keys and values from JSON to build the INSERT statement
--     SELECT string_agg(quote_ident(key), ','), string_agg(quote_nullable(value), ',')
--     INTO v_cols, v_vals
--     FROM jsonb_each_text(p_payload);

--     v_sql := format('INSERT INTO %I (%s) VALUES (%s) RETURNING %I', v_table, v_cols, v_vals, v_pk);
--     EXECUTE v_sql INTO v_new_id;

--     -- Track history
--     INSERT INTO tblGenericApprovalHistory (DocumentCode, RecordId, ActionName, OldStatusCode, NewStatusCode, Remarks, PerformedBy)
--     VALUES (p_doc_code, v_new_id::VARCHAR, 'Create Record', 'NONE', v_initial_status, 'API Genesis', p_created_by);

--     RETURN jsonb_build_object('id', v_new_id, 'document_number', v_doc_number, 'status', v_initial_status);
-- END;
-- $$ LANGUAGE plpgsql;


-- -- 3. UPDATE DYNAMIC DOCUMENT (Generic Update)
-- DROP FUNCTION IF EXISTS spUpdateDynamicDocument(VARCHAR, INT, JSONB, VARCHAR);
-- CREATE OR REPLACE FUNCTION spUpdateDynamicDocument(
--     p_doc_code VARCHAR,
--     p_record_id INT,
--     p_payload JSONB,
--     p_updated_by VARCHAR DEFAULT 'System'
-- )
-- RETURNS JSONB AS $$
-- DECLARE
--     v_table VARCHAR;
--     v_pk VARCHAR;
--     v_status_col VARCHAR;
--     v_reset_status VARCHAR;
--     v_set_clause TEXT;
--     v_sql TEXT;
-- BEGIN
--     SELECT TargetTableName, TargetPrimaryKey, TargetStatusColumn
--     INTO v_table, v_pk, v_status_col
--     FROM tblDocumentMaster WHERE DocumentCode = p_doc_code AND IsActive = TRUE;

--     IF NOT FOUND THEN RAISE EXCEPTION 'Invalid Document Code'; END IF;

--     -- Any Edit throws the document back to the beginning of the workflow!
--     v_reset_status := fnGetInitialStatus();
    
--     p_payload := p_payload || jsonb_build_object(
--         v_status_col, v_reset_status,
--         'updated_date', NOW()
--     );

--     -- Build dynamic SET clause (e.g., name = 'John', phone = '123')
--     SELECT string_agg(quote_ident(key) || ' = ' || quote_nullable(value), ', ')
--     INTO v_set_clause
--     FROM jsonb_each_text(p_payload);

--     v_sql := format('UPDATE %I SET %s WHERE %I = %s RETURNING *', v_table, v_set_clause, v_pk, p_record_id);
--     EXECUTE v_sql;

--     INSERT INTO tblGenericApprovalHistory (DocumentCode, RecordId, ActionName, OldStatusCode, NewStatusCode, Remarks, PerformedBy)
--     VALUES (p_doc_code, p_record_id::VARCHAR, 'Edit Record', 'VARIOUS', v_reset_status, 'Updated via API - Workflow Reset', p_updated_by);

--     RETURN jsonb_build_object('id', p_record_id, 'status', v_reset_status, 'message', 'Record updated successfully');
-- END;
-- $$ LANGUAGE plpgsql;



-- -- ==========================================
-- -- MODULE 10: ERP DASHBOARD METRICS & ANALYTICS
-- -- ==========================================

-- -- 1. FUNCTION: Compile comprehensive dashboard stats into a single optimized JSON payload
-- DROP FUNCTION IF EXISTS fnGetERPDashboardMetrics();
-- CREATE OR REPLACE FUNCTION fnGetERPDashboardMetrics()
-- RETURNS JSONB AS $$
-- DECLARE
--     v_admission_stats JSONB;
--     v_leave_stats JSONB;
--     v_course_stats JSONB;
--     v_approval_stats JSONB;
-- BEGIN
--     -- [A] Aggregate Admission Statistics
--     SELECT jsonb_build_object(
--         'total_admissions', COUNT(id),
--         'pending_approvals', COUNT(id) FILTER (WHERE status = 'PENDING'),
--         'approved_requests', COUNT(id) FILTER (WHERE status = 'APPROVED'),
--         'rejected_requests', COUNT(id) FILTER (WHERE status = 'REJECTED')
--     ) INTO v_admission_stats
--     FROM students WHERE is_deleted = FALSE;

--     -- [B] Aggregate Leave Statistics
--     SELECT jsonb_build_object(
--         'total_leaves', COUNT(id),
--         'pending_leaves', COUNT(id) FILTER (WHERE status = 'PENDING'),
--         'approved_leaves', COUNT(id) FILTER (WHERE status = 'APPROVED'),
--         'rejected_leaves', COUNT(id) FILTER (WHERE status = 'REJECTED')
--     ) INTO v_leave_stats
--     FROM tblLeaveRequests WHERE is_deleted = FALSE;

--     -- [C] Aggregate Course-wise Admissions dynamically
--     SELECT COALESCE(jsonb_agg(
--         jsonb_build_object(
--             'course_name', COALESCE(c.course_name, 'Unassigned'),
--             'student_count', sub.student_count
--         )
--     ), '[]'::jsonb) INTO v_course_stats
--     FROM (
--         SELECT sc.course_id, COUNT(s.id) as student_count
--         FROM students s
--         LEFT JOIN tblStudentCourse sc ON s.id = sc.student_id AND sc.status = 'Active'
--         WHERE s.is_deleted = FALSE
--         GROUP BY sc.course_id
--     ) sub
--     LEFT JOIN tblCourse c ON sub.course_id = c.course_id;

--     -- [D] Aggregate System-wide Approval Statistics (Last 30 Days)
--     SELECT jsonb_build_object(
--         'total_actions', COUNT(HistoryId),
--         'approvals', COUNT(HistoryId) FILTER (WHERE ActionName = 'Approve'),
--         'rejections', COUNT(HistoryId) FILTER (WHERE ActionName = 'Reject')
--     ) INTO v_approval_stats
--     FROM tblGenericApprovalHistory
--     WHERE PerformedDate >= NOW() - INTERVAL '30 days';

--     -- [E] Combine everything into a single return object
--     RETURN jsonb_build_object(
--         'admissions', v_admission_stats,
--         'leaves', v_leave_stats,
--         'course_wise', v_course_stats,
--         'approvals_30d', v_approval_stats
--     );
-- END;
-- $$ LANGUAGE plpgsql;


-- -- 2. FUNCTION: Get cross-module Recent Activities
-- DROP FUNCTION IF EXISTS fnGetERPRecentActivities(INT);
-- CREATE OR REPLACE FUNCTION fnGetERPRecentActivities(p_limit INT DEFAULT 10)
-- RETURNS TABLE (
--     history_id INT,
--     document_name VARCHAR,
--     document_code VARCHAR,
--     record_id VARCHAR,
--     action_name VARCHAR,
--     old_status VARCHAR,
--     new_status VARCHAR,
--     performed_by VARCHAR,
--     performed_date TIMESTAMP,
--     remarks TEXT
-- ) AS $$
-- BEGIN
--     RETURN QUERY
--     SELECT 
--         h.HistoryId,
--         CAST(d.DocumentName AS VARCHAR),
--         CAST(h.DocumentCode AS VARCHAR),
--         CAST(h.RecordId AS VARCHAR),
--         CAST(h.ActionName AS VARCHAR),
--         CAST(h.OldStatusCode AS VARCHAR),
--         CAST(h.NewStatusCode AS VARCHAR),
--         CAST(h.PerformedBy AS VARCHAR),
--         h.PerformedDate,
--         h.Remarks
--     FROM tblGenericApprovalHistory h
--     JOIN tblDocumentMaster d ON h.DocumentCode = d.DocumentCode
--     ORDER BY h.PerformedDate DESC
--     LIMIT p_limit;
-- END;
-- $$ LANGUAGE plpgsql;




-- ==========================================
-- MODULE 11: ERP SUPERUSER AUTHENTICATION
-- ==========================================

-- -- Enable the pgcrypto extension for secure SHA-256 / Blowfish hashing
-- CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- CREATE TABLE IF NOT EXISTS tblERPSuperuser (
--     id SERIAL PRIMARY KEY,
--     username VARCHAR(100) NOT NULL UNIQUE,
--     password_hash TEXT NOT NULL,
--     is_active BOOLEAN DEFAULT TRUE,
--     created_date TIMESTAMP DEFAULT NOW(),
--     updated_date TIMESTAMP DEFAULT NOW()
-- );

-- -- Seed an initial master superuser safely if it doesn't exist
-- -- Username: admin | Password: adminpassword123
-- INSERT INTO tblERPSuperuser (username, password_hash)
-- VALUES (
--     'admin', 
--     crypt('adminpassword123', gen_salt('bf', 8)) -- Blowfish hashing
-- )
-- ON CONFLICT (username) DO NOTHING;





-- ==========================================
-- CORRECTED FUNCTION: Verify ERP Superuser
-- ==========================================
DROP FUNCTION IF EXISTS fnVerifyERPSuperuser(VARCHAR, VARCHAR);

CREATE OR REPLACE FUNCTION fnVerifyERPSuperuser(
    p_username VARCHAR,
    p_password VARCHAR
)
RETURNS TABLE (
    user_id INT,
    user_name VARCHAR,
    is_authenticated BOOLEAN
) AS $$
DECLARE
    v_id INT;
    v_hash TEXT;
    v_active BOOLEAN;
BEGIN
    -- Look up the target profile using your actual column name: is_active
    SELECT id, password_hash, is_active 
    INTO v_id, v_hash, v_active
    FROM tblERPSuperuser
    WHERE username = p_username;

    -- Validate if the user exists, is active, and the password matches
    IF FOUND AND v_active = TRUE AND v_hash = crypt(p_password, v_hash) THEN
        RETURN QUERY SELECT v_id, CAST(p_username AS VARCHAR), TRUE;
    ELSE
        RETURN QUERY SELECT 0, CAST('' AS VARCHAR), FALSE;
    END IF;
END;
$$ LANGUAGE plpgsql;