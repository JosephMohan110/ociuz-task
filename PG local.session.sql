

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

-- -- SELECT * FROM students;
-- -- SELECT * FROM tblCourse;
-- -- SELECT * FROM studentapproval;
-- -- SELECT * FROM tblStudentCourse;

-- -- SELECT * FROM fnGetCourses();
-- -- SELECT * FROM fnGetApprovedStudents();
-- -- SELECT * FROM fnGetStudentsWithCurrentCourse(NULL);
-- -- SELECT * FROM fnGetStudentById(1);



-- -- CREATE OR REPLACE FUNCTION fnAddStudent(
-- --     p_name VARCHAR,
-- --     p_phone VARCHAR,
-- --     p_email VARCHAR,
-- --     p_course_id INT,
-- --     p_student_image VARCHAR DEFAULT NULL
-- -- )
-- -- RETURNS INT AS $$
-- -- DECLARE
-- --     new_student_id INT;
-- -- BEGIN
-- --     INSERT INTO students (
-- --         name,
-- --         phone,
-- --         email,
-- --         course_id,
-- --         student_image,
-- --         created_date,
-- --         updated_date
-- --     )
-- --     VALUES (
-- --         p_name,
-- --         p_phone,
-- --         p_email,
-- --         p_course_id,
-- --         p_student_image,
-- --         NOW(),
-- --         NOW()
-- --     )
-- --     RETURNING id INTO new_student_id;

-- --     INSERT INTO tblStudentCourse (
-- --         student_id,
-- --         course_id,
-- --         enrollment_date,
-- --         status,
-- --         created_date,
-- --         updated_date
-- --     )
-- --     VALUES (
-- --         new_student_id,
-- --         p_course_id,
-- --         CURRENT_DATE,
-- --         'Active',
-- --         NOW(),
-- --         NOW()
-- --     );

-- --     INSERT INTO studentapproval (
-- --         student_id,
-- --         approval_status,
-- --         approved_by,
-- --         approved_date,
-- --         remarks,
-- --         created_date
-- --     )
-- --     VALUES (
-- --         new_student_id,
-- --         'Pending',
-- --         'System',
-- --         NOW(),
-- --         'New student added',
-- --         NOW()
-- --     );

-- --     RETURN new_student_id;
-- -- END;
-- -- $$ LANGUAGE plpgsql;



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
-- -- 2. REWRITE FUNCTION: Soft Delete Student
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
-- -- Update fnGetStudentsWithCurrentCourse to exclude is_deleted = TRUE
-- CREATE OR REPLACE FUNCTION fnGetStudentsWithCurrentCourse(
--     p_search VARCHAR DEFAULT NULL
-- )
-- RETURNS TABLE(
--     id INT, name VARCHAR, phone VARCHAR, email VARCHAR, 
--     course_id INT, course VARCHAR, course_code VARCHAR, 
--     student_image VARCHAR, created_date TIMESTAMP, updated_date TIMESTAMP, 
--     approval_status VARCHAR, approved_by VARCHAR, remarks TEXT, approved_date TIMESTAMP
-- ) AS $$
-- BEGIN
--     RETURN QUERY
--     SELECT
--         s.id, s.name, s.phone, s.email, sc.course_id,
--         COALESCE(c.course_name, 'Not assigned'), COALESCE(c.course_code, ''),
--         s.student_image, s.created_date, s.updated_date,
--         COALESCE(a.approval_status, 'Pending'), COALESCE(a.approved_by, 'System'),
--         COALESCE(a.remarks, ''), a.approved_date::timestamp without time zone
--     FROM students s
--     LEFT JOIN tblStudentCourse sc ON s.id = sc.student_id AND sc.status = 'Active'
--     LEFT JOIN tblCourse c ON sc.course_id = c.course_id
--     LEFT JOIN LATERAL (
--         SELECT sa.approval_status, sa.approved_by, sa.remarks, sa.approved_date
--         FROM studentapproval sa
--         WHERE sa.student_id = s.id
--         ORDER BY sa.id DESC LIMIT 1
--     ) a ON TRUE
--     WHERE s.is_deleted = FALSE -- <--- CRITICAL ADDITION
--       AND (p_search IS NULL
--        OR s.name ILIKE '%' || p_search || '%'
--        OR s.phone ILIKE '%' || p_search || '%'
--        OR s.email ILIKE '%' || p_search || '%'
--        OR c.course_name ILIKE '%' || p_search || '%')
--     ORDER BY s.id DESC;
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