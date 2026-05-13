-- select * from tblcourse;

select * from students;


SELECT * FROM StudentApproval;

 
 CREATE TABLE IF NOT EXISTS students (
        id SERIAL PRIMARY KEY,
        name VARCHAR(100),
        age INT
    );

CREATE TABLE IF NOT EXISTS tblCourse (
    course_id SERIAL PRIMARY KEY,
    course_name VARCHAR(100) NOT NULL UNIQUE,
    course_code VARCHAR(20) NOT NULL UNIQUE,
    status VARCHAR(20) NOT NULL DEFAULT 'Active'
);

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

-- INSERT INTO students(name, age)
-- VALUES ('Joseph', 22);

-- INSERT INTO students(name, age)
-- VALUES ('Joseph', 22);

--SELECT * FROM students;



--CREAT A READ ONLY USER THING...
--ionly this  user will later get viewing permission

--CREATE USER readonly_user WITH PASSWORD 'readonly123';



-- next give database connection acces to above user...
--tables use cheyan ulla pemmision taken..

--GRANT CONNECT ON DATABASE demo TO readonly_user;



--now giving the schama access to above user...
--GRANT USAGE ON SCHEMA public TO readonly_user;



--now we giving only red ead he table access..
-- when we give it user cannot modify the data.
--GRANT SELECT ON students TO readonly_user;


--now just verify the read only user for it just login...login with above user and try to select data from students table and also try to insert data into students table to verify the read only access.

--psql -U readonly_user -d demo


--verify the read access
--SELECT * FROM students;


--now we want to verify he write access is blocked..

--INSERT INTO students(name, age)
--VALUES ('Test', 25);




--next task 1


-- now above exixting table we are adding 6 coloum.. studen table ku add cheyunu..

ALTER TABLE students
ADD COLUMN IF NOT EXISTS phone VARCHAR(15),
ADD COLUMN IF NOT EXISTS email VARCHAR(100),
ADD COLUMN IF NOT EXISTS address TEXT,
ADD COLUMN IF NOT EXISTS dob DATE,
ADD COLUMN IF NOT EXISTS course_id INT REFERENCES tblCourse(course_id),
ADD COLUMN IF NOT EXISTS student_image VARCHAR(255),
ADD COLUMN IF NOT EXISTS status VARCHAR(20),
ADD COLUMN IF NOT EXISTS created_date TIMESTAMP DEFAULT NOW(),
ADD COLUMN IF NOT EXISTS updated_date TIMESTAMP DEFAULT NOW();

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





-- next task..2



-- now kurachu values want to add into  student table..

-- INSERT INTO students (name, age, phone, email, address, dob, course, status) VALUES
-- ('Akhil', 20, '9876543210', 'akhil@gmail.com', 'Thrissur', '2004-05-15', 'cse', 'Active'),
-- ('Anjali', 21, '9876543211', 'anjk@gmail.com', 'Ernakulam', '2003-08-22', 'Math', 'Active'),
-- ('Vishnu', 22, '9876543212', 'vish@gmail.com', 'Thrissur', '2002-11-10', 'Physics', 'Graduated'),
-- ('Sreya', 20, '9876543213', 'srey@gmail.com', 'Ernakulam', '2004-02-18', 'Chemistry', 'Active'),
-- ('Arun', 23, '9876543214', 'arun@gmail.com', 'Thrissur', '2001-07-30', 'Bio', 'Graduated'),
-- ('Divya', 19, '9876543215', 'divy@gmail.com', 'Ernakulam', '2005-01-25', 'cse', 'Active'),
-- ('Harikrishnan', 22, '9876543216', 'hari@gmail.com', 'Thrissur', '2002-09-12', 'Electronics', 'Active'),
-- ('Lakshmi', 21, '9876543217', 'lakshmi@gmail.com', 'Ernakulam', '2003-12-05', 'Mech', 'On Leave'),
-- ('Manoj', 24, '9876543218', 'manoj@gmail.com', 'Thrissur', '2000-06-19', 'Civil', 'Graduated'),
-- ('Neethu', 20, '9876543219', 'neethu@gmail.com', 'Ernakulam', '2004-03-28', 'cse', 'Active'),
-- ('Praveen', 22, '9876543220', 'praveen@gmail.com', 'Thrissur', '2002-10-08', 'Electrical', 'Active'),
-- ('Rahul', 21, '9876543221', 'rahul@gmail.com', 'Ernakulam', '2003-04-17', 'Math', 'Active'),
-- ('Sandra', 19, '9876543222', 'sandra@gmail.com', 'Thrissur', '2005-07-23', 'Physics', 'Active'),
-- ('Tom Sebastian', 23, '9876543223', 'tom@gmail.com', 'Ernakulam', '2001-11-02', 'Chemistry', 'Graduated'),
-- ('Usha Kumari', 20, '9876543224', 'usha@gmail.com', 'Thrissur', '2004-08-14', 'Bio', 'Active'),
-- ('Vimal Rajesh', 22, '9876543225', 'vimal@gmail.com', 'Ernakulam', '2002-12-26', 'cse', 'Active'),
-- ('Yam Devi', 21, '9876543226', 'yam@gmail.com', 'Thrissur', '2003-05-09', 'Electronics', 'On Leave'),
-- ('Abhi', 20, '9876543227', 'abhi@gmail.com', 'Ernakulam', '2004-09-30', 'Mech', 'Active'),
-- ('Bin', 24, '9876543228', 'bin@gmail.com', 'Thrissur', '2000-01-15', 'Civil', 'Graduated'),
-- ('Chrit', 19, '9876543229', 'christy@gmail.com', 'Ernakulam', '2005-06-11', 'cse', 'Active');



-- select * from students;





--next task 3

-- now new table want to create table is student approval table

CREATE TABLE IF NOT EXISTS student_approval (
    id SERIAL PRIMARY KEY,
    student_id INT REFERENCES students(id),
    approval_status VARCHAR(50),
    approved_by VARCHAR(100),
    approved_date TIMESTAMP,
    remarks TEXT,
    created_date TIMESTAMP DEFAULT NOW()
);





-- now add some values in to above tble...
-- INSERT INTO StudentApproval (student_id, approval_status, approved_by, approved_date, remarks, created_date) VALUES
-- (1, 'Approved', 'Admin', '2024-01-15', 'All documents verified', '2024-01-10'),
-- (2, 'Approved', 'Admin', '2024-01-20', 'Eligible for graduation', '2024-01-18'),
-- (3, 'Rejected', 'Admin', '2024-01-25', 'Incomplete documents', '2024-01-22'),
-- (4, 'Approved', 'Staff', '2024-02-01', 'Verified', '2024-01-30');




-- select * FROM studentapproval;




-- next task 4 approve functioon


--ow making a function to approve student records
-- buy using this function we can appriove the students..
-- name of function is fnApproveStudent and it takes 3 parameters
-- student id, approved by and remarks
-- and it will return text message about the approval status of the student.
-- parameters means inputs..
--$$ it will act as a seprater. after this symbol the function logic will start...
-- instread of many quirs we can do it with one function.. and also we can reuse the function for many times..
-- and also we can call the function from other queries also..



DROP FUNCTION IF EXISTS fnApproveStudent(INT, VARCHAR, TEXT);
CREATE OR REPLACE FUNCTION fnApproveStudent(
    p_student_id INT,
    p_approved_by VARCHAR,
    p_remarks TEXT DEFAULT NULL
)
RETURNS BOOLEAN AS $$
BEGIN
    INSERT INTO student_approval (
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








-- useing the function...
-- SELECT fnApproveStudent(1, 'John');
-- SELECT fnApproveStudent(2, 'Admin');
-- SELECT fnApproveStudent(3, 'Staff');

-- SELECT * FROM StudentApproval WHERE student_id = 4;
SELECT * FROM StudentApproval;




-- adding values using the function....
--SELECT fnApproveStudent(14, 'Admin');
--SELECT * FROM StudentApproval;








-- next taks 5
-- this task create a custom listimg function...

-- -- create means make a new connection.. function name is fnGetApprovedStudents.




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
    LEFT JOIN tblCourse c ON s.course_id = c.course_id;
END;
$$ LANGUAGE plpgsql;




-- TASK 6: EDIT FUNCTION
-- this function allows us to edit/update student details
-- function name is fnEditStudent
-- parameters: student_id, and optional fields to update (name, phone, email, address, course, dob, age)
-- it will update the students table with new values
-- using COALESCE to update only provided values, leaving others unchanged

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
        course_id = COALESCE(p_course_id, course_id),
        student_image = COALESCE(p_student_image, student_image),
        updated_date = NOW()
    WHERE id = p_student_id;
    
    GET DIAGNOSTICS v_rows_affected = ROW_COUNT;
    
    IF v_rows_affected > 0 THEN
        INSERT INTO student_approval (
            student_id, approval_status, approved_by, remarks, approved_date, created_date
        ) VALUES (
            p_student_id, 'Pending', 'System', 'Updated - Pending re-approval', NOW(), NOW()
        );
    END IF;
    
    RETURN v_rows_affected > 0;
END;
$$ LANGUAGE plpgsql;




-- using the edit function...
-- SELECT fnEditStudent(1, 'Akhil Updated', 21, '9999999999', 'akhil.new@gmail.com', 'Kochi', '2003-05-15', 'ECE');
-- SELECT * FROM students WHERE id = 1;


-- SELECT fnEditStudent(2, p_email => 'anjali.new@gmail.com', p_phone => '8888888888');
-- SELECT * FROM students WHERE id = 2;












-- TASK 7: DELETE FUNCTION
-- this function allows us to delete a student and all related records
-- function name is fnDeleteStudent
-- parameters: student_id
-- it will delete from StudentApproval table first (due to foreign key constraint)
-- then delete from students table
-- returns a message about the deletion status

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
    
    DELETE FROM student_approval 
    WHERE student_id = p_student_id;
    
    DELETE FROM students 
    WHERE id = p_student_id;
    
    GET DIAGNOSTICS v_rows_affected = ROW_COUNT;
    
    RETURN v_rows_affected > 0;
END;
$$ LANGUAGE plpgsql;



DROP FUNCTION IF EXISTS fnGetStudentsWithStatus(VARCHAR);
CREATE OR REPLACE FUNCTION fnGetStudentsWithStatus(
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
        s.course_id,
        COALESCE(c.course_name, 'Not assigned'),
        COALESCE(c.course_code, ''),
        s.student_image,
        s.created_date,
        s.updated_date,
        COALESCE(a.approval_status, 'Pending'),
        COALESCE(a.approved_by, 'System'),
        COALESCE(a.remarks, ''),
        a.approved_date
    FROM students s
    LEFT JOIN tblCourse c ON s.course_id = c.course_id
    LEFT JOIN LATERAL (
        SELECT sa.approval_status, sa.approved_by, sa.remarks, sa.approved_date
        FROM student_approval sa
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
        s.course_id,
        COALESCE(c.course_name, 'Unknown'),
        s.created_date,
        s.updated_date,
        COALESCE(a.approval_status, 'Pending'),
        COALESCE(a.approved_by, 'System'),
        COALESCE(a.remarks, ''),
        a.approved_date
    FROM students s
    LEFT JOIN tblCourse c ON s.course_id = c.course_id
    LEFT JOIN LATERAL (
        SELECT sa.approval_status, sa.approved_by, sa.remarks, sa.approved_date
        FROM student_approval sa
        WHERE sa.student_id = s.id
        ORDER BY sa.id DESC
        LIMIT 1
    ) a ON TRUE
    WHERE s.id = p_student_id
    ORDER BY s.id DESC
    LIMIT 1;
END;
$$ LANGUAGE plpgsql;



DROP FUNCTION IF EXISTS fnAddStudent(VARCHAR, VARCHAR, VARCHAR, INT);
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
        name, phone, email, course_id, student_image, created_date, updated_date
    ) VALUES (
        p_name, p_phone, p_email, p_course_id, p_student_image, NOW(), NOW()
    ) RETURNING id INTO new_student_id;

    INSERT INTO student_approval (
        student_id, approval_status, approved_by, remarks, approved_date, created_date
    ) VALUES (
        new_student_id, 'Pending', 'System', 'Initial registration', NOW(), NOW()
    );

    RETURN new_student_id;
END;
$$ LANGUAGE plpgsql;



DROP FUNCTION IF EXISTS fnRejectStudent(INT, VARCHAR, TEXT);
CREATE OR REPLACE FUNCTION fnRejectStudent(
    p_student_id INT,
    p_approved_by VARCHAR,
    p_remarks TEXT DEFAULT NULL
)
RETURNS BOOLEAN AS $$
BEGIN
    INSERT INTO student_approval (
        student_id, approval_status, approved_by, remarks, approved_date, created_date
    ) VALUES (
        p_student_id, 'Rejected', p_approved_by, COALESCE(p_remarks, ''), NOW(), NOW()
    );

    UPDATE students
    SET updated_date = NOW()
    WHERE id = p_student_id;

    RETURN TRUE;
END;
$$ LANGUAGE plpgsql;



DROP FUNCTION IF EXISTS fnGetApprovalHistory(INT);
CREATE OR REPLACE FUNCTION fnGetApprovalHistory(
    p_student_id INT
)
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
    FROM student_approval sa
    WHERE sa.student_id = p_student_id
    ORDER BY sa.id DESC;
END;
$$ LANGUAGE plpgsql;




-- using the delete function...
-- SELECT fnDeleteStudent(20);
-- SELECT * FROM students WHERE id = 20;
-- SELECT * FROM StudentApproval WHERE student_id = 20;

-- SELECT fnDeleteStudent(19);
-- SELECT * FROM students WHERE id = 19;
-- SELECT * FROM StudentApproval WHERE student_id = 19;


 
