# #!/usr/bin/env python
# """
# Setup script to create tblCourse table and insert course data.
# Run from project root: python setup_courses.py
# """
# import os
# import django

# # Configure Django settings
# os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'studentproject.settings')
# django.setup()

# from django.db import connection

# def setup_courses():
#     """Create tblCourse table, fnGetCourses function, and insert course data."""
    
#     with connection.cursor() as cur:
#         # 1. Create tblCourse table
#         print("Creating tblCourse table...")
#         cur.execute("""
#             CREATE TABLE IF NOT EXISTS tblCourse (
#                 course_id SERIAL PRIMARY KEY,
#                 course_name VARCHAR(100) NOT NULL UNIQUE,
#                 course_code VARCHAR(20) NOT NULL UNIQUE,
#                 status VARCHAR(20) NOT NULL DEFAULT 'Active'
#             );
#         """)
#         print("✓ tblCourse table created/verified")
        
#         # 2. Create fnGetCourses() function
#         print("Creating fnGetCourses() function...")
#         cur.execute("""
#             DROP FUNCTION IF EXISTS fnGetCourses();
#             CREATE OR REPLACE FUNCTION fnGetCourses()
#             RETURNS TABLE(
#                 course_id INT,
#                 course_name VARCHAR,
#                 course_code VARCHAR,
#                 status VARCHAR
#             ) AS $$
#             BEGIN
#                 RETURN QUERY
#                 SELECT
#                     tblCourse.course_id AS course_id,
#                     tblCourse.course_name AS course_name,
#                     tblCourse.course_code AS course_code,
#                     tblCourse.status AS status
#                 FROM tblCourse
#                 WHERE tblCourse.status = 'Active'
#                 ORDER BY tblCourse.course_name;
#             END;
#             $$ LANGUAGE plpgsql;
#         """)
#         print("✓ fnGetCourses() function created")
        
#         # 3. Insert course data
#         print("Inserting course records...")
#         cur.execute("""
#             INSERT INTO tblCourse (course_name, course_code, status) VALUES
#                 ('Computer Science', 'CS101', 'Active'),
#                 ('Information Technology', 'IT102', 'Active'),
#                 ('Mechanical Engineering', 'ME103', 'Active'),
#                 ('Electrical Engineering', 'EE104', 'Active'),
#                 ('Civil Engineering', 'CE105', 'Active'),
#                 ('Electronics & Communication', 'EC106', 'Active'),
#                 ('Biotechnology', 'BT107', 'Active'),
#                 ('Chemical Engineering', 'CH108', 'Active'),
#                 ('Architecture', 'AR109', 'Active'),
#                 ('Business Administration', 'BA110', 'Active'),
#                 ('Thrissur Jobs', 'TH222', 'Active')
#             ON CONFLICT (course_code) DO NOTHING;
#         """)
#         print("✓ Course records inserted")
        
#         # 4. Verify data
#         cur.execute("SELECT COUNT(*) as course_count FROM tblCourse;")
#         count = cur.fetchone()[0]
#         print(f"✓ Total courses in database: {count}")
        
#         cur.execute("SELECT * FROM fnGetCourses();")
#         courses = cur.fetchall()
#         print(f"✓ Active courses returned by fnGetCourses(): {len(courses)}")
#         for course in courses:
#             print(f"  - {course[1]} ({course[2]})")

# if __name__ == '__main__':
#     try:
#         setup_courses()
#         print("\n✅ Database setup completed successfully!")
#     except Exception as e:
#         print(f"\n❌ Error during setup: {e}")
#         import traceback
#         traceback.print_exc()
