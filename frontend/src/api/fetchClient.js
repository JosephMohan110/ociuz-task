const API_BASE = '/student';

function buildUrl(path, params) {
  const normalizedPath = path.startsWith('/') ? path : `/${path}`;
  const url = new URL(`${API_BASE}${normalizedPath}`, window.location.origin);
  if (params) {
    Object.entries(params).forEach(([key, value]) => {
      if (value !== undefined && value !== null && value !== '') {
        url.searchParams.append(key, value);
      }
    });
  }
  return url.toString();
}

export function apiUrl(path, params) {
  return buildUrl(path, params);
}

export function getCsrfToken() {
  const match = document.cookie.match('(^|;)\\s*csrftoken\\s*=\\s*([^;]+)');
  return match ? match.pop() : '';
}

export async function fetchJson(path, options = {}) {
  const { method = 'GET', params, headers = {}, body, ...rest } = options;
  const url = buildUrl(path, params);

  const finalHeaders = {
    ...headers,
  };

  if (!(body instanceof FormData) && body !== undefined && body !== null && method.toUpperCase() !== 'GET') {
    finalHeaders['Content-Type'] = 'application/json';
  }

  const csrfToken = getCsrfToken();
  if (csrfToken) {
    finalHeaders['X-CSRFToken'] = csrfToken;
  }

  const response = await fetch(url, {
    method,
    credentials: 'include',
    headers: finalHeaders,
    body: body instanceof FormData ? body : body !== undefined && body !== null && method.toUpperCase() !== 'GET' ? JSON.stringify(body) : undefined,
    ...rest,
  });

  const text = await response.text();
  let data = null;
  try {
    data = text ? JSON.parse(text) : null;
  } catch (_) {
    data = text;
  }

  if (!response.ok) {
    const error = new Error(data?.error || response.statusText || 'Request failed');
    error.response = { status: response.status, data };
    throw error;
  }

  return data;
}
