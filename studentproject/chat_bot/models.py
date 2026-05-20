from django.db import models


class ChatbotUserDetails(models.Model):
    """
    Stores user information collected through conversational chatbot
    Data collected naturally during chat - name, email, phone
    """
    session_id = models.CharField(max_length=200, unique=True, db_index=True)
    name = models.CharField(max_length=150, null=True, blank=True)
    email = models.EmailField(max_length=200, null=True, blank=True)
    phone = models.CharField(max_length=20, null=True, blank=True)
    
    # Status tracking
    INTERESTED = 'interested'
    SKIPPED = 'skipped'
    PENDING = 'pending'
    
    STATUS_CHOICES = [
        (INTERESTED, 'User shared their information'),
        (SKIPPED, 'User declined to share'),
        (PENDING, 'Still collecting info'),
    ]
    status = models.CharField(max_length=50, choices=STATUS_CHOICES, default=PENDING)
    
    # Timestamps
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)
    
    class Meta:
        db_table = 'chatbot_user_details'
        verbose_name_plural = 'Chatbot User Details'
        ordering = ['-created_at']
    
    def __str__(self):
        return f"{self.name or 'Guest'} ({self.session_id[:8]}...)"

