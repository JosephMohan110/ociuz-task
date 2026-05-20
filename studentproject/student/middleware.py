from django.shortcuts import render     #It loads HTML pages from template folder.
from django.db import DatabaseError
from django.http import Http404
import logging

logger = logging.getLogger(__name__)


class GlobalExceptionMiddleware:
    def __init__(self, get_response):
        self.get_response = get_response

    def __call__(self, request):
        return self.get_response(request)

    def process_exception(self, request, exception):
        # FIX: Ensure 'student/' prefix is added here so Django can locate the file
        return render(request, 'student/error.html', {
            'code': 500,
            'message': str(exception)
        }, status=500)