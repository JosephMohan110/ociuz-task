# Image Upload, Preview & Database Storage - Complete Documentation

## Table of Contents
1. [Overview](#overview)
2. [Architecture & Flow](#architecture--flow)
3. [Frontend - Image Preview](#frontend---image-preview)
4. [Backend - Image Validation](#backend---image-validation)
5. [Backend - Image Storage](#backend---image-storage)
6. [Database - Image Path Storage](#database---image-path-storage)
7. [Image Display in Templates](#image-display-in-templates)
8. [Configuration](#configuration)
9. [File Structure](#file-structure)
10. [Testing & Verification](#testing--verification)

---

## Overview

The Student Management System implements a complete image handling pipeline for student profile pictures:
- **Frontend**: Real-time preview using JavaScript FileReader API
- **Validation**: Client-side + Server-side image validation
- **Storage**: Images saved to `/media/student_images/` with UUID filenames
- **Database**: Image paths stored in PostgreSQL `students` table
- **Display**: Images served via Django's media file serving mechanism

---

## Architecture & Flow

```
User Selects Image File
         ↓
[FRONTEND] JavaScript validates & shows preview
         ↓
Form submission with image file
         ↓
[BACKEND] Server-side validation in views.py
         ↓
Image validation passes?
    ├─ YES → Save to disk + Get image path
    │         ↓
    │    Pass image path to database function
    │         ↓
    │    [DATABASE] Store path in students table
    │         ↓
    │    Success message → Redirect
    │
    └─ NO  → Error message → Show form again
```

---

## Frontend - Image Preview

### Location: `templates/student/add_student.html` and `edit_student.html`

### HTML Form Input
```html
<div class="form-group">
    <label>Student Image</label>
    <input type="file" name="student_image" id="studentImage" 
           class="form-input" 
           accept="image/png,image/jpeg,image/gif">
    <small class="form-hint">
        Upload a JPG, PNG, or GIF image. Max size 2MB.
    </small>
    <div class="image-preview-wrapper">
        <img id="imagePreview" class="image-preview" 
             src="" alt="Image preview" style="display:none;" />
    </div>
    <div class="error-message" id="studentImage-error"></div>
</div>
```

**Key Features:**
- `accept="image/png,image/jpeg,image/gif"` - Browser file picker shows only image files
- `id="studentImage"` - Used by JavaScript to reference the input
- `id="imagePreview"` - Shows preview image
- `id="studentImage-error"` - Displays validation errors

### JavaScript Preview Logic

```javascript
// Reference the file input and preview image
const imageInput = document.getElementById('studentImage');
const imagePreview = document.getElementById('imagePreview');
const errorElements = {
    studentImage: document.getElementById('studentImage-error')
};

// Listen for file selection change
imageInput.addEventListener('change', validateImage);

// Validation function
function validateImage() {
    const file = imageInput.files[0];
    
    // No file selected - hide preview
    if (!file) {
        imagePreview.style.display = 'none';
        imagePreview.src = '';
        errorElements.studentImage.textContent = '';
        return true;
    }

    // Validate MIME type
    const allowedTypes = ['image/jpeg', 'image/png', 'image/gif'];
    if (!allowedTypes.includes(file.type)) {
        imagePreview.style.display = 'none';
        imagePreview.src = '';
        errorElements.studentImage.textContent = 
            'Only JPG, PNG, or GIF images are allowed.';
        return false;
    }

    // Validate file size (max 2MB)
    const MAX_SIZE = 2 * 1024 * 1024;  // 2 MB in bytes
    if (file.size > MAX_SIZE) {
        imagePreview.style.display = 'none';
        imagePreview.src = '';
        errorElements.studentImage.textContent = 
            'Image size must be 2MB or less.';
        return false;
    }

    // File is valid - show preview using FileReader API
    errorElements.studentImage.textContent = '';
    const reader = new FileReader();
    
    reader.onload = function(event) {
        imagePreview.src = event.target.result;  // Data URL
        imagePreview.style.display = 'block';
    };
    
    reader.readAsDataURL(file);  // Convert file to base64 data URL
    return true;
}
```

**How Preview Works:**
1. **FileReader API**: Reads the selected file as a data URL (base64 encoded)
2. **Base64 Data URL**: `data:image/jpeg;base64,/9j/4AAQSkZJRg...`
3. **Direct Display**: Sets `<img src>` directly to the data URL
4. **No Server Needed**: Preview happens entirely in the browser, no server request

**Validation Checks:**
- ✓ MIME type must be `image/jpeg`, `image/png`, or `image/gif`
- ✓ File size must be ≤ 2 MB (2,097,152 bytes)
- ✓ Real-time feedback in `#studentImage-error` div

---

## Backend - Image Validation

### Location: `student/views.py`

### Constants & Configuration
```python
# Allowed image formats
ALLOWED_IMAGE_EXTENSIONS = {'jpg', 'jpeg', 'png', 'gif'}
ALLOWED_IMAGE_CONTENT_TYPES = {
    'image/jpeg',
    'image/png',
    'image/gif',
}
MAX_IMAGE_SIZE = 2 * 1024 * 1024  # 2 MB
```

### Validation Function: `_validate_student_image()`

```python
def _validate_student_image(request, image_file):
    """
    Validate the uploaded image file.
    
    Args:
        request: Django request object (for error messages)
        image_file: File object from request.FILES
    
    Returns:
        True if there's an ERROR (validation failed)
        False if validation PASSED
        
    This function:
    1. Checks if file exists
    2. Checks file size
    3. Checks MIME type
    4. Checks actual file signature (magic bytes)
    5. Checks file extension
    """
    
    # Step 1: Check if file exists
    if not image_file:
        return False  # No error (image is optional)

    # Step 2: Check file size
    if image_file.size > MAX_IMAGE_SIZE:
        messages.error(request, 'Image must be 2MB or smaller.')
        return True  # Error found
    
    # Step 3: Check MIME type from browser
    if image_file.content_type not in ALLOWED_IMAGE_CONTENT_TYPES:
        messages.error(request, 
            'Only JPG, PNG, and GIF image files are allowed.')
        return True  # Error found

    # Step 4: Verify actual file signature (magic bytes)
    # This prevents attacks where files are renamed to fake images
    header = image_file.read(512)  # Read first 512 bytes
    image_file.seek(0)  # Reset file pointer to start
    image_type = imghdr.what(None, header)  # Detect format from bytes
    
    if image_type not in ALLOWED_IMAGE_EXTENSIONS:
        messages.error(request, 'Uploaded file is not a valid image.')
        return True  # Error found

    # Step 5: Check file extension (.jpg, .png, etc)
    ext = os.path.splitext(image_file.name)[1].lower()  # Get extension
    if ext and ext.lstrip('.') not in ALLOWED_IMAGE_EXTENSIONS:
        messages.error(request, 
            'Image file extension must be JPG, PNG, or GIF.')
        return True  # Error found

    return False  # All validations passed
```

**Validation Layers:**

| Layer | Check | Method | Prevents |
|-------|-------|--------|----------|
| 1 | File size | `image_file.size` | Disk space abuse |
| 2 | MIME type | `image_file.content_type` | Wrong file types (browser) |
| 3 | File signature | `imghdr.what()` | Renamed non-image files |
| 4 | Extension | `os.path.splitext()` | Extension spoofing |

**Security Features:**
- ✓ **Multi-layer validation**: Can't bypass by just renaming files
- ✓ **Magic bytes check**: Reads actual file header, not just name
- ✓ **Size limit**: Prevents disk space attacks
- ✓ **MIME type check**: Server-side validation (client can be bypassed)

---

## Backend - Image Storage

### Location: `student/views.py`

### Storage Function: `_save_student_image()`

```python
def _save_student_image(image_file):
    """
    Save the uploaded image file to disk.
    
    Args:
        image_file: File object from request.FILES
    
    Returns:
        Relative path string: 'student_images/abc123def456.jpg'
        This path is stored in the database
    """
    
    # Step 1: Create directory if it doesn't exist
    uploads_dir = Path(settings.MEDIA_ROOT) / 'student_images'
    uploads_dir.mkdir(parents=True, exist_ok=True)
    # Example: C:\...\media\student_images\

    # Step 2: Get file extension
    extension = os.path.splitext(image_file.name)[1].lower()
    # Example: '.jpg', '.png'
    
    # If no extension found, detect from file content
    if not extension:
        extension = '.' + (imghdr.what(None, image_file.read(512)) or 'jpg')
        image_file.seek(0)
    # Example: If header says PNG but no extension → '.png'

    # Step 3: Generate unique filename using UUID
    filename = f"{uuid.uuid4().hex}{extension}"
    # Example: '6a2278d8b9ec424db5e103c6d55fa0f0.png'
    # UUID ensures no filename collisions, even with same image
    
    save_path = uploads_dir / filename
    # Example: C:\...\media\student_images\6a2278d8b9ec424db5e103c6d55fa0f0.png

    # Step 4: Write file to disk in chunks
    # This is memory-efficient for large files
    with open(save_path, 'wb') as destination:
        for chunk in image_file.chunks():
            destination.write(chunk)

    # Step 5: Return relative path for database storage
    return f'student_images/{filename}'
    # Example: 'student_images/6a2278d8b9ec424db5e103c6d55fa0f0.png'
```

**Storage Details:**

```
User uploads: profile.jpg (2 MB)
       ↓
Validation passes
       ↓
Generate UUID: 6a2278d8b9ec424db5e103c6d55fa0f0
       ↓
Create filename: 6a2278d8b9ec424db5e103c6d55fa0f0.jpg
       ↓
Save to disk:
    C:\Users\LENOVO\Desktop\psql\studentproject\
    media\
    student_images\
    6a2278d8b9ec424db5e103c6d55fa0f0.jpg
       ↓
Return relative path:
    'student_images/6a2278d8b9ec424db5e103c6d55fa0f0.jpg'
```

**Why UUID Filenames?**
- ✓ Prevents filename collisions
- ✓ No directory traversal attacks (`../../../etc/passwd`)
- ✓ Original filename not exposed (privacy)
- ✓ Multiple uploads of same file create different files

**Directory Structure:**
```
studentproject/
├── media/
│   └── student_images/
│       ├── 6a2278d8b9ec424db5e103c6d55fa0f0.png
│       ├── 90d9a779cdff48c1be93a1e395d34ef2.png
│       ├── f8c98571a73841a2bbab2ede8d56d447.png
│       └── fba5f3b5826f47e1adf8b80083b968f0.jpeg
├── static/
├── templates/
└── studentproject/
```

---

## Database - Image Path Storage

### Location: `student/views.py` (add_student and edit_student functions)

### In Add Student View:
```python
def add_student(request):
    if request.method == 'POST':
        # ... collect form data ...
        image_file = request.FILES.get('student_image')

        # Validate image (optional field)
        image_has_error = _validate_student_image(request, image_file)
        
        # Only save if form validation passes
        if not _validate_form(...) and not image_has_error:
            # Save image and get relative path
            image_path = _save_student_image(image_file) if image_file else None
            # Example: 'student_images/6a2278d8b9ec424db5e103c6d55fa0f0.png' or None
            
            # Pass to database function
            db_add_student(name, phone, email, int(course), image_path)
            # ↓
            # This calls PostgreSQL function:
            # SELECT fnAddStudent(name, phone, email, course_id, image_path)
```

### Database Function: `fnAddStudent()` (PostgreSQL)

```sql
SELECT fnAddStudent(
    'John Doe',           -- name
    '9876543210',         -- phone
    'john@example.com',   -- email
    1,                    -- course_id
    'student_images/6a2278d8b9ec424db5e103c6d55fa0f0.png'  -- student_image
)
```

**This PostgreSQL function:**
1. Inserts student with `student_image` column set to the relative path
2. Creates initial `Pending` approval record
3. Returns new student ID

### In Edit Student View:
```python
def edit_student(request, student_id):
    if request.method == 'POST':
        # ... collect form data ...
        image_file = request.FILES.get('student_image')
        
        # Validate image (optional, can update without changing image)
        image_has_error = _validate_student_image(request, image_file)
        
        if not _validate_form(...) and not image_has_error:
            # Only save new image if provided
            image_path = _save_student_image(image_file) if image_file else None
            
            # Pass to database update function
            db_update_student(
                student_id, 
                name, phone, email, int(course), 
                image_path  # None if not updating image
            )
            # Resets approval status to 'Pending' automatically
```

### Database Storage Structure:

**students Table:**
```
┌─────────────────────────────────────────────────────┐
│ students                                            │
├────────┬────────┬────────┬──────────┬──────────────┤
│ id     │ name   │ email  │ phone    │ student_image│
├────────┼────────┼────────┼──────────┼──────────────┤
│ 1      │ John   │ john@…│ 9876543210│ student_images/
│        │ Doe    │        │           │ 6a2278d8b….png
│        │        │        │           │              │
│ 2      │ Jane   │ jane@…│ 8765432109│ student_images/
│        │ Smith  │        │           │ 90d9a779cd….png
│        │        │        │           │              │
│ 3      │ Bob    │ bob@… │ 7654321098│ NULL         │
│        │ Jones  │        │           │ (no image)   │
└────────┴────────┴────────┴──────────┴──────────────┘
```

**Example Queries:**
```sql
-- Get student with image
SELECT id, name, student_image 
FROM students 
WHERE id = 1;
-- Result: (1, 'John Doe', 'student_images/6a2278d8b9ec424db5e103c6d55fa0f0.png')

-- Get all students with images
SELECT id, name, student_image 
FROM students 
WHERE student_image IS NOT NULL;
-- Returns list of students who have uploaded images

-- Update student image
UPDATE students 
SET student_image = 'student_images/90d9a779cdff48c1be93a1e395d34ef2.png'
WHERE id = 1;
```

---

## Image Display in Templates

### Location: `templates/student/student_list.html`

```html
<td>
    {% if student.student_image %}
    <img src="{{ MEDIA_URL }}{{ student.student_image }}" 
         alt="{{ student.name }}" 
         class="student-thumb">
    {% else %}
    —
    {% endif %}
</td>
```

**How URLs are Built:**

```
From Database:  'student_images/6a2278d8b9ec424db5e103c6d55fa0f0.png'

{{ MEDIA_URL }} = '/media/'  (from settings.py)

Final URL:      /media/student_images/6a2278d8b9ec424db5e103c6d55fa0f0.png

Browser loads:  http://localhost:8000/media/student_images/6a2278d8b9ec424db5e103c6d55fa0f0.png
                ↓
                Django serves from disk:
                C:\...\media\student_images\6a2278d8b9ec424db5e103c6d55fa0f0.png
```

### In Edit Student Template:

**Display Current Image:**
```html
{% if student.student_image %}
<div class="form-group">
    <label>Current Image</label>
    <div class="current-image-preview">
        <img src="{{ MEDIA_URL }}{{ student.student_image }}" 
             alt="{{ student.name }}" 
             class="image-preview" />
    </div>
</div>
{% endif %}
```

**Upload New Image:**
```html
<div class="form-group">
    <label>Update Student Image</label>
    <input type="file" name="student_image" id="studentImage" 
           class="form-input" 
           accept="image/png,image/jpeg,image/gif">
    <small class="form-hint">
        Upload a JPG, PNG, or GIF image. Max size 2MB.
    </small>
    <div class="image-preview-wrapper">
        <img id="imagePreview" class="image-preview" 
             src="" alt="Image preview" style="display:none;" />
    </div>
    <div class="error-message" id="studentImage-error"></div>
</div>
```

---

## Configuration

### Django Settings: `studentproject/settings.py`

```python
# Media files (uploaded by users)
MEDIA_URL = '/media/'
MEDIA_ROOT = os.path.join(BASE_DIR, 'media')

# Example:
# MEDIA_URL = '/media/'
# MEDIA_ROOT = 'C:\...\media\'
# 
# So a file at: C:\...\media\student_images\abc123.png
# Is served at:  /media/student_images/abc123.png
```

### URL Configuration: `studentproject/urls.py`

```python
from django.conf import settings
from django.conf.urls.static import static

urlpatterns = [
    path('admin/', admin.site.urls),
    path('', student_views.student_list, name='home'),
    path('student/', include('student.urls')),
]

# Serve media files in development (when DEBUG=True)
if settings.DEBUG:
    urlpatterns += static(
        settings.MEDIA_URL,             # /media/
        document_root=settings.MEDIA_ROOT  # C:\...\media\
    )
    # This tells Django: 
    # When browser requests /media/*, 
    # Serve from C:\...\media\*
```

**Important:** Media serving only works when `DEBUG = True`. In production, use a web server (nginx/Apache).

---

## File Structure

```
studentproject/
│
├── media/                          ← All uploaded files here
│   └── student_images/
│       ├── 6a2278d8b9ec424db5e103c6d55fa0f0.png
│       ├── 90d9a779cdff48c1be93a1e395d34ef2.png
│       ├── f8c98571a73841a2bbab2ede8d56d447.png
│       └── fba5f3b5826f47e1adf8b80083b968f0.jpeg
│
├── student/                        ← Student app
│   ├── views.py                    ← Image validation & storage
│   │   ├── _validate_student_image()
│   │   ├── _save_student_image()
│   │   ├── add_student()
│   │   └── edit_student()
│   │
│   ├── db_functions.py             ← Database operations
│   │   ├── db_add_student()
│   │   └── db_update_student()
│   │
│   └── models.py                   ← Not used (using raw SQL)
│
├── templates/
│   └── student/
│       ├── add_student.html        ← Preview + form
│       ├── edit_student.html       ← Show current + update form
│       ├── student_list.html       ← Display images in list
│       └── base.html               ← Base template
│
├── studentproject/
│   ├── settings.py                 ← MEDIA_URL, MEDIA_ROOT
│   ├── urls.py                     ← Media file serving
│   └── wsgi.py
│
└── manage.py
```

---

## Complete Request-Response Flow

### Adding a Student with Image:

```
1. USER INTERFACE
   ├─ User opens: http://localhost:8000/student/add/
   └─ Template: add_student.html loads
         ├─ Form with file input: <input type="file" name="student_image">
         ├─ Preview container: <img id="imagePreview">
         └─ JavaScript attached to validate on change

2. USER SELECTS IMAGE
   ├─ Browser file picker opens (accept=".jpg,.png,.gif")
   ├─ User selects: profile.jpg (1.5 MB)
   └─ JavaScript validateImage() function triggers

3. CLIENT-SIDE VALIDATION (JavaScript)
   ├─ Get file object from: imageInput.files[0]
   ├─ Check MIME type: 'image/jpeg' ✓
   ├─ Check file size: 1572864 bytes < 2097152 bytes ✓
   ├─ Use FileReader API to read file
   ├─ Convert to data URL: 'data:image/jpeg;base64,...'
   ├─ Display in preview: <img src="data:image/jpeg;base64,...">
   └─ No errors → Clear error message

4. USER FILLS OTHER FORM FIELDS
   ├─ Name: John Doe
   ├─ Phone: 9876543210
   ├─ Email: john@example.com
   ├─ Course: Java Programming
   └─ Image: (selected from step 2)

5. USER SUBMITS FORM
   ├─ Client-side validation runs on all fields
   ├─ All valid → Form data sent to server via POST
   └─ Request includes file upload (multipart/form-data)

6. SERVER RECEIVES REQUEST (views.add_student)
   ├─ Parse POST fields
   ├─ Get file from request.FILES['student_image']
   └─ Proceed to validation

7. SERVER-SIDE VALIDATION (Backend)
   ├─ Call _validate_student_image(request, image_file)
   ├─ Check 1: File size 1572864 ≤ 2097152 ✓
   ├─ Check 2: MIME type 'image/jpeg' in allowed list ✓
   ├─ Check 3: Magic bytes (imghdr) = 'jpeg' ✓
   ├─ Check 4: Extension '.jpg' in allowed list ✓
   └─ Return False (no errors)

8. SAVE IMAGE TO DISK (Backend)
   ├─ Call _save_student_image(image_file)
   ├─ Create directory: C:\...\media\student_images\
   ├─ Get extension: '.jpg'
   ├─ Generate UUID: '6a2278d8b9ec424db5e103c6d55fa0f0'
   ├─ Create filename: '6a2278d8b9ec424db5e103c6d55fa0f0.jpg'
   ├─ Open file: C:\...\media\student_images\6a2278d8b9ec424db5e103c6d55fa0f0.jpg
   ├─ Write chunks to disk
   └─ Return relative path: 'student_images/6a2278d8b9ec424db5e103c6d55fa0f0.jpg'

9. SAVE TO DATABASE (Backend)
   ├─ Call db_add_student(
   │      name='John Doe',
   │      phone='9876543210',
   │      email='john@example.com',
   │      course_id=1,
   │      student_image_path='student_images/6a2278d8b9ec424db5e103c6d55fa0f0.jpg'
   │  )
   │
   └─ Execute PostgreSQL function:
       SELECT fnAddStudent(
           'John Doe',
           '9876543210',
           'john@example.com',
           1,
           'student_images/6a2278d8b9ec424db5e103c6d55fa0f0.jpg'
       )
       
       Function executes:
       ├─ INSERT into students table
       │  └─ student_image column gets: 'student_images/6a2278d8b9ec424db5e103c6d55fa0f0.jpg'
       │
       ├─ INSERT into student_approval table
       │  └─ Create 'Pending' record
       │
       └─ Return: new_student_id (5)

10. REDIRECT TO LIST
    ├─ Success message: "Student 'John Doe' added successfully."
    └─ Redirect to: http://localhost:8000/student/

11. DISPLAY IN LIST (student_list.html)
    ├─ Fetch student from database
    ├─ Get student_image: 'student_images/6a2278d8b9ec424db5e103c6d55fa0f0.jpg'
    ├─ Template renders:
    │  <img src="/media/student_images/6a2278d8b9ec424db5e103c6d55fa0f0.jpg"
    │       alt="John Doe"
    │       class="student-thumb">
    │
    └─ Browser requests: http://localhost:8000/media/student_images/6a2278d8b9ec424db5e103c6d55fa0f0.jpg

12. SERVE IMAGE
    ├─ Django media handler catches /media/* request
    ├─ Looks up MEDIA_ROOT setting
    ├─ Loads file: C:\...\media\student_images\6a2278d8b9ec424db5e103c6d55fa0f0.jpg
    ├─ Sends file to browser with Content-Type: image/jpeg
    └─ Browser displays image in <img> tag
```

---

## Testing & Verification

### Test Results:
```
✓ Media directory exists with 4 images stored
✓ Images saved with UUID filenames
✓ Database contains image paths
✓ All image files verified and accessible
✓ JavaScript preview working
✓ Server-side validation working
✓ Django media serving working
```

### Manual Testing Steps:

**1. Add a Student with Image:**
```
1. Navigate to: http://localhost:8000/student/add/
2. Fill form with valid data
3. Click "Choose File" for student image
4. Select a JPG, PNG, or GIF file
5. Observe preview image appears
6. Submit form
7. Verify: Student appears in list with image thumbnail
8. Verify: Image file exists in C:\...\media\student_images\
```

**2. Edit Student Image:**
```
1. Navigate to student list
2. Click "Edit" on any student
3. Current image displays (if exists)
4. Upload new image
5. Observe preview of new image
6. Submit form
7. Verify: List shows updated image
8. Verify: New image file in media folder
```

**3. Check Database:**
```
1. Connect to PostgreSQL
2. Query: SELECT id, name, student_image FROM students;
3. Verify: student_image contains path like 'student_images/xxx.jpg'
4. Or: SELECT id, name, student_image FROM students WHERE student_image IS NOT NULL;
```

**4. Check Disk:**
```
PowerShell: Get-ChildItem C:\...\media\student_images\
Expected output:
    6a2278d8b9ec424db5e103c6d55fa0f0.png
    90d9a779cdff48c1be93a1e395d34ef2.png
    f8c98571a73841a2bbab2ede8d56d447.png
    fba5f3b5826f47e1adf8b80083b968f0.jpeg
```

---

## Security Considerations

### ✓ Implemented Protections:

1. **File Size Limit**: Prevents disk space attacks (max 2MB)
2. **MIME Type Checking**: Server-side validation of file type
3. **Magic Bytes Verification**: Detects renamed non-image files
4. **UUID Filenames**: Prevents directory traversal and filename collision
5. **Original Filename Not Exposed**: Privacy protection
6. **File Extension Validation**: Another layer of defense

### ⚠️ Production Considerations:

1. **DEBUG=False**: In production, don't serve media via Django
   - Use nginx, Apache, or CDN instead
   
2. **Disk Space**: Monitor disk usage as images accumulate
   - Implement image cleanup for deleted students
   
3. **Image Optimization**: Consider compressing images
   - Use Pillow library for resizing thumbnails
   
4. **Virus Scanning**: Add antivirus scanning for production
   - Use libraries like python-clamav
   
5. **Backup**: Ensure media files are backed up regularly

---

## Summary

**Image Preview:**
- JavaScript FileReader API reads file as base64 data URL
- Real-time display in `<img>` tag without server request

**Validation:**
- Client-side: MIME type & file size (JavaScript)
- Server-side: 4-layer validation (size, MIME, magic bytes, extension)

**Storage:**
- Save to disk: `/media/student_images/{UUID}.{ext}`
- Store path in database: `'student_images/{UUID}.{ext}'`
- Build display URL: `{{ MEDIA_URL }}{{ student.student_image }}`

**Serving:**
- Django serves `/media/*` requests in development
- Browser loads image from server and displays in `<img>` tag

**Security:**
- Multiple validation layers prevent attacks
- UUID filenames prevent exploits
- Size limits prevent abuse
