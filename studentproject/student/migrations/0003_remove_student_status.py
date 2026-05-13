# Migration: 0003
# Remove 'status' column from the students table.
# Update StudentApproval choices to include 'Pending'.
# Status is now tracked exclusively in student_approval.

from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('student', '0002_studentapproval'),
    ]

    operations = [
        # Remove status field from Student table
        migrations.RemoveField(
            model_name='student',
            name='status',
        ),

        # Update StudentApproval.approval_status to include 'Pending'
        migrations.AlterField(
            model_name='studentapproval',
            name='approval_status',
            field=models.CharField(
                choices=[
                    ('Pending',  'Pending'),
                    ('Approved', 'Approved'),
                    ('Rejected', 'Rejected'),
                ],
                default='Pending',
                max_length=20,
            ),
        ),
    ]
