import { get } from 'svelte/store';
import { bootstrap } from '$lib/stores/bootstrap';

async function parsePayload(response) {
  const contentType = response.headers.get('content-type') || '';
  if (contentType.includes('application/json')) {
    return response.json();
  }

  return response.text();
}

export async function apiFetch(url, options = {}) {
  const response = await fetch(url, {
    credentials: 'same-origin',
    headers: {
      Accept: 'application/json',
      ...(options.headers || {})
    },
    ...options
  });

  if (response.redirected && response.url.includes('/auth/')) {
    throw new Error('로그인이 필요합니다.');
  }

  const payload = await parsePayload(response);

  if (!response.ok) {
    const message =
      payload?.message ||
      payload?.error ||
      (typeof payload === 'string' ? payload : 'Request failed.');
    throw new Error(message);
  }

  return payload;
}

export async function refreshBootstrap() {
  const payload = await apiFetch('/api/v1/bootstrap');
  bootstrap.set({
    ready: true,
    loading: false,
    ...payload
  });
  return payload;
}

export async function sendJson(url, { method = 'POST', body, headers = {}, ...options } = {}) {
  return apiFetch(url, {
    method,
    headers: {
      'Content-Type': 'application/json',
      ...headers
    },
    body: body === undefined ? undefined : JSON.stringify(body),
    ...options
  });
}

export function appendCsrf(formData) {
  const state = get(bootstrap);
  const csrfParam = state?.auth?.csrfParam;
  const csrfToken = state?.auth?.csrfToken;
  if (csrfParam && csrfToken) {
    formData.append(csrfParam, csrfToken);
  }
}

export async function postFormJson(url, fields = {}) {
  const formData = new FormData();
  appendCsrf(formData);

  for (const [key, value] of Object.entries(fields)) {
    if (value === undefined || value === null) continue;
    formData.append(key, value);
  }

  return apiFetch(url, {
    method: 'POST',
    body: formData,
    headers: {
      'X-Requested-With': 'XMLHttpRequest'
    }
  });
}

export async function uploadFile(url, file) {
  const formData = new FormData();
  formData.append('file', file);
  appendCsrf(formData);

  return apiFetch(url, {
    method: 'POST',
    body: formData,
    headers: {
      'X-Requested-With': 'XMLHttpRequest'
    }
  });
}

export async function submitFormJson(url, form, { method = 'POST', submitter } = {}) {
  const formData = new FormData(form);

  if (submitter?.name) {
    formData.set(submitter.name, submitter.value ?? '');
  }

  return apiFetch(url, {
    method,
    body: formData,
    headers: {
      Accept: 'application/json',
      'X-Requested-With': 'XMLHttpRequest'
    }
  });
}
