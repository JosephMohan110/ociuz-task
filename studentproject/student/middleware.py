# from django.shortcuts import render     It loads HTML pages from template folder.
from django.db import DatabaseError
from django.http import Http404

from django.shortcuts import render
import logging

logger = logging.getLogger(__name__)


class GlobalExceptionMiddleware:
    def __init__(self, get_response):
        self.get_response = get_response

    def __call__(self, request):
        return self.get_response(request)

    def process_exception(self, request, exception):
        logger.error(str(exception))

        return render(request, 'error.html', {
            'code': 500,
            'message': 'Internal Server Error'
        }, status=500)