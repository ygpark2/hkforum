<script>
  import { goto } from '$app/navigation';
  import { onMount } from 'svelte';
  import { page } from '$app/stores';
  import { bootstrap } from '$lib/stores/bootstrap';
  import { apiFetch, submitFormJson } from '$lib/utils/api';
  import { formatDate, relativeTime } from '$lib/utils/time';

  let loading = true;
  let data = null;
  let loadError = '';
  let saveError = '';
  let saveSuccess = '';
  let saving = false;

  const groupMeta = [
    { key: 'siteBasics', label: 'Site Basics', action: 'save-site-basics' },
    { key: 'forum', label: 'Forum', action: 'save-forum' },
    { key: 'upload', label: 'Upload', action: 'save-upload' },
    { key: 'moderation', label: 'Moderation', action: 'save-moderation' },
    { key: 'ads', label: 'Ads', action: 'save-ads' },
    { key: 'features', label: 'Features', action: 'save-features' }
  ];

  const booleanKeys = new Set([
    'maintenance_mode',
    'allow_user_registration',
    'allow_social_login',
    'allow_anonymous_read',
    'rich_text_enabled',
    'auto_delete_orphan_uploads',
    'auto_hide_flagged_posts',
    'allow_user_blocking',
    'allow_post_reporting',
    'ads_enabled',
    'ad_slots_sidebar_enabled',
    'ad_click_tracking_enabled',
    'maps_enabled',
    'local_region_filter_enabled',
    'companies_enabled',
    'jobs_enabled',
    'require_company_category_on_create'
  ]);

  $: parts = $page.url.pathname.split('/').filter(Boolean);
  $: segments = parts.slice(1);
  $: section = segments[0] || 'overview';
  $: selectedId = segments[1] && segments[2] === 'view' ? Number(segments[1]) : null;
  $: isNew = segments[1] === 'new';
  $: selectedBoard = data?.boards?.find((item) => item.id === selectedId);
  $: selectedCompany = data?.companies?.find((item) => item.id === selectedId);
  $: selectedCategory = data?.companyCategories?.find((item) => item.id === selectedId);
  $: selectedUser = data?.users?.find((item) => item.id === selectedId);
  $: selectedAd = data?.ads?.find((item) => item.id === selectedId);

  function hiddenCsrf() {
    return $bootstrap.auth?.csrfParam && $bootstrap.auth?.csrfToken;
  }

  function keyLabel(key) {
    return key
      .split('_')
      .map((chunk) => chunk.charAt(0).toUpperCase() + chunk.slice(1))
      .join(' ');
  }

  function settingValue(key) {
    return data?.settings?.values?.[key] ?? '';
  }

  function isBooleanKey(key) {
    return booleanKeys.has(key);
  }

  async function loadData() {
    loading = true;
    loadError = '';
    try {
      data = await apiFetch('/api/v1/admin/bootstrap');
    } catch (error) {
      loadError = error.message;
    } finally {
      loading = false;
    }
  }

  async function submitAdminForm(event, { redirectTo = null, confirmDelete = true } = {}) {
    const form = event.currentTarget;
    const submitter = event.submitter;
    const url = submitter?.getAttribute('formaction') || form.getAttribute('action');
    const submitAction = submitter?.value || new FormData(form).get('action');

    if (confirmDelete && submitAction === 'delete' && !window.confirm('Delete this item?')) {
      return;
    }

    saving = true;
    saveError = '';
    saveSuccess = '';

    try {
      const payload = await submitFormJson(url, form, { submitter });
      saveSuccess = payload.message || 'Saved.';
      if (redirectTo) {
        await goto(redirectTo);
      }
      await loadData();
    } catch (error) {
      saveError = error.message;
    } finally {
      saving = false;
    }
  }

  onMount(loadData);
</script>

<section class="min-h-full">
  <div class="border-b border-slate-200 bg-white px-6 py-4">
    <div class="text-sm font-semibold uppercase tracking-[0.18em] text-slate-500">Admin</div>
    <h1 class="mt-2 text-2xl font-semibold text-slate-900">{section === 'overview' ? 'Overview' : keyLabel(section)}</h1>
  </div>

  {#if loading}
    <div class="px-6 py-6 text-sm text-slate-500">Loading admin data…</div>
  {:else if loadError}
    <div class="px-6 py-6">
      <div class="rounded-2xl border border-rose-200 bg-rose-50 px-5 py-4 text-sm text-rose-700">{loadError}</div>
    </div>
  {:else}
    <div class="space-y-5 px-6 py-6">
      {#if saveError}
        <div class="rounded-2xl border border-rose-200 bg-rose-50 px-5 py-4 text-sm text-rose-700">{saveError}</div>
      {/if}
      {#if saveSuccess}
        <div class="rounded-2xl border border-emerald-200 bg-emerald-50 px-5 py-4 text-sm text-emerald-700">{saveSuccess}</div>
      {/if}
      {#if section === 'overview'}
        <div class="grid gap-4 md:grid-cols-2 xl:grid-cols-5">
          {#each Object.entries(data.summary || {}) as [key, value]}
            <div class="rounded-2xl border border-slate-200 bg-white p-4">
              <div class="text-xs uppercase tracking-[0.18em] text-slate-500">{keyLabel(key)}</div>
              <div class="mt-2 text-2xl font-semibold text-slate-900">{value}</div>
            </div>
          {/each}
        </div>

        <div class="grid gap-5 xl:grid-cols-2">
          <div class="rounded-2xl border border-slate-200 bg-white p-5">
            <div class="flex items-center justify-between gap-3">
              <div class="text-lg font-semibold text-slate-900">Moderation queue</div>
              <a href="/admin/moderation" class="text-sm font-semibold text-slate-700">Open</a>
            </div>
            <div class="mt-4 space-y-3">
              {#each (data.moderation?.queue?.postFlags || []).slice(0, 5) as item}
                <div class="rounded-xl bg-slate-50 p-4">
                  <div class="text-sm font-semibold text-slate-900">{item.postTitle}</div>
                  <div class="mt-1 text-sm text-slate-600">Flagged by {item.user?.ident || 'unknown'}</div>
                </div>
              {/each}
              {#if !(data.moderation?.queue?.postFlags || []).length}
                <div class="text-sm text-slate-500">No flagged posts.</div>
              {/if}
            </div>
          </div>

          <div class="rounded-2xl border border-slate-200 bg-white p-5">
            <div class="flex items-center justify-between gap-3">
              <div class="text-lg font-semibold text-slate-900">Recent logs</div>
              <a href="/admin/moderation/logs" class="text-sm font-semibold text-slate-700">Open</a>
            </div>
            <div class="mt-4 space-y-3">
              {#each (data.moderation?.logs || []).slice(0, 5) as item}
                <div class="rounded-xl bg-slate-50 p-4">
                  <div class="text-sm font-semibold text-slate-900">{item.targetType} / {item.action}</div>
                  <div class="mt-1 text-sm text-slate-600">{item.actor?.ident || 'unknown'} · {relativeTime(item.createdAt)}</div>
                </div>
              {/each}
            </div>
          </div>
        </div>
      {:else if section === 'boards'}
        {#if isNew || selectedBoard}
          <form method="post" action={isNew ? '/api/v1/admin/boards' : `/api/v1/admin/boards/${selectedBoard.id}`} class="rounded-2xl border border-slate-200 bg-white p-6" on:submit|preventDefault={(event) => submitAdminForm(event, { redirectTo: '/admin/boards' })}>
            {#if hiddenCsrf()}
              <input type="hidden" name={$bootstrap.auth.csrfParam} value={$bootstrap.auth.csrfToken} />
            {/if}
            {#if !isNew}
              <input type="hidden" name="action" value="update" />
            {/if}
            <div class="text-lg font-semibold text-slate-900">{isNew ? 'New Board' : 'Edit Board'}</div>
            <div class="mt-5 space-y-4">
              <div>
                <label for="board-name" class="text-xs font-semibold uppercase tracking-[0.18em] text-slate-500">Name</label>
                <input id="board-name" name="name" value={selectedBoard?.name || ''} class="mt-2 w-full rounded-xl border border-slate-200 bg-slate-50 px-4 py-3 text-sm text-slate-900" />
              </div>
              <div>
                <label for="board-description" class="text-xs font-semibold uppercase tracking-[0.18em] text-slate-500">Description</label>
                <textarea id="board-description" name="description" class="mt-2 min-h-[140px] w-full rounded-xl border border-slate-200 bg-slate-50 px-4 py-3 text-sm text-slate-900">{selectedBoard?.description || ''}</textarea>
              </div>
            </div>
            <div class="mt-5 flex flex-wrap gap-3">
              <button class="rounded-xl bg-slate-900 px-4 py-2 text-sm font-semibold text-white">{isNew ? 'Create' : 'Save'}</button>
              {#if selectedBoard}
                <button formaction={`/api/v1/admin/boards/${selectedBoard.id}`} name="action" value="delete" class="rounded-xl border border-rose-200 px-4 py-2 text-sm font-semibold text-rose-700">Delete</button>
              {/if}
              <a href="/admin/boards" class="rounded-xl border border-slate-200 px-4 py-2 text-sm font-semibold text-slate-700">Back</a>
            </div>
          </form>
        {:else}
          <div class="flex items-center justify-between gap-3">
            <div class="text-sm text-slate-500">Manage board taxonomy and descriptions.</div>
            <a href="/admin/boards/new" class="rounded-xl bg-slate-900 px-4 py-2 text-sm font-semibold text-white">New Board</a>
          </div>
          <div class="overflow-hidden rounded-2xl border border-slate-200 bg-white">
            <table class="min-w-full divide-y divide-slate-200 text-sm">
              <thead class="bg-slate-50 text-left text-slate-500">
                <tr><th class="px-4 py-3">Name</th><th class="px-4 py-3">Posts</th><th class="px-4 py-3">Comments</th><th class="px-4 py-3"></th></tr>
              </thead>
              <tbody class="divide-y divide-slate-200">
                {#each data.boards || [] as item}
                  <tr>
                    <td class="px-4 py-3"><div class="font-semibold text-slate-900">{item.name}</div><div class="text-slate-500">{item.description || ''}</div></td>
                    <td class="px-4 py-3">{item.postCount}</td>
                    <td class="px-4 py-3">{item.commentCount}</td>
                    <td class="px-4 py-3 text-right"><a href={`/admin/boards/${item.id}/view`} class="font-semibold text-slate-700">Edit</a></td>
                  </tr>
                {/each}
              </tbody>
            </table>
          </div>
        {/if}
      {:else if section === 'companies'}
        {#if isNew || selectedCompany}
          <form method="post" action={isNew ? '/api/v1/admin/companies' : `/api/v1/admin/companies/${selectedCompany.id}`} class="rounded-2xl border border-slate-200 bg-white p-6" on:submit|preventDefault={(event) => submitAdminForm(event, { redirectTo: '/admin/companies' })}>
            {#if hiddenCsrf()}
              <input type="hidden" name={$bootstrap.auth.csrfParam} value={$bootstrap.auth.csrfToken} />
            {/if}
            {#if !isNew}
              <input type="hidden" name="action" value="update" />
            {/if}
            <div class="grid gap-4 md:grid-cols-2">
              <div class="md:col-span-2">
                <label for="company-name" class="text-xs font-semibold uppercase tracking-[0.18em] text-slate-500">Name</label>
                <input id="company-name" name="name" value={selectedCompany?.name || ''} class="mt-2 w-full rounded-xl border border-slate-200 bg-slate-50 px-4 py-3 text-sm text-slate-900" />
              </div>
              <div>
                <label for="company-category" class="text-xs font-semibold uppercase tracking-[0.18em] text-slate-500">Category</label>
                <select id="company-category" name="categoryId" class="mt-2 w-full rounded-xl border border-slate-200 bg-slate-50 px-4 py-3 text-sm text-slate-900">
                  {#each data.companyCategories || [] as category}
                    <option value={category.id} selected={category.id === selectedCompany?.categoryId}>{category.name}</option>
                  {/each}
                </select>
              </div>
              <div>
                <label for="company-website" class="text-xs font-semibold uppercase tracking-[0.18em] text-slate-500">Website</label>
                <input id="company-website" name="website" value={selectedCompany?.website || ''} class="mt-2 w-full rounded-xl border border-slate-200 bg-slate-50 px-4 py-3 text-sm text-slate-900" />
              </div>
              <div class="md:col-span-2">
                <label for="company-size" class="text-xs font-semibold uppercase tracking-[0.18em] text-slate-500">Size</label>
                <input id="company-size" name="size" value={selectedCompany?.size || ''} class="mt-2 w-full rounded-xl border border-slate-200 bg-slate-50 px-4 py-3 text-sm text-slate-900" />
              </div>
              <div class="md:col-span-2">
                <label for="company-description" class="text-xs font-semibold uppercase tracking-[0.18em] text-slate-500">Description</label>
                <textarea id="company-description" name="description" class="mt-2 min-h-[180px] w-full rounded-xl border border-slate-200 bg-slate-50 px-4 py-3 text-sm text-slate-900">{selectedCompany?.description || ''}</textarea>
              </div>
            </div>
            <div class="mt-5 flex flex-wrap gap-3">
              <button class="rounded-xl bg-slate-900 px-4 py-2 text-sm font-semibold text-white">{isNew ? 'Create' : 'Save'}</button>
              {#if selectedCompany}
                <button formaction={`/api/v1/admin/companies/${selectedCompany.id}`} name="action" value="delete" class="rounded-xl border border-rose-200 px-4 py-2 text-sm font-semibold text-rose-700">Delete</button>
              {/if}
              <a href="/admin/companies" class="rounded-xl border border-slate-200 px-4 py-2 text-sm font-semibold text-slate-700">Back</a>
            </div>
          </form>
        {:else}
          <div class="flex items-center justify-between gap-3">
            <div class="text-sm text-slate-500">Manage directory listings and company metadata.</div>
            <a href="/admin/companies/new" class="rounded-xl bg-slate-900 px-4 py-2 text-sm font-semibold text-white">New Company</a>
          </div>
          <div class="grid gap-4 xl:grid-cols-2">
            {#each data.companies || [] as item}
              <a href={`/admin/companies/${item.id}/view`} class="rounded-2xl border border-slate-200 bg-white p-5 transition hover:border-slate-300">
                <div class="text-lg font-semibold text-slate-900">{item.name}</div>
                <div class="mt-1 text-sm text-slate-500">{item.categoryName || 'Uncategorized'} · {item.author?.ident || 'unknown'}</div>
                <div class="mt-3 line-clamp-3 text-sm text-slate-600">{item.description}</div>
              </a>
            {/each}
          </div>
        {/if}
      {:else if section === 'company-categories'}
        {#if isNew || selectedCategory}
          <form method="post" action={isNew ? '/api/v1/admin/company-categories' : `/api/v1/admin/company-categories/${selectedCategory.id}`} class="rounded-2xl border border-slate-200 bg-white p-6" on:submit|preventDefault={(event) => submitAdminForm(event, { redirectTo: '/admin/company-categories' })}>
            {#if hiddenCsrf()}
              <input type="hidden" name={$bootstrap.auth.csrfParam} value={$bootstrap.auth.csrfToken} />
            {/if}
            {#if selectedCategory}
              <input type="hidden" name="action" value="update" />
            {/if}
            {#if isNew && $page.url.searchParams.get('parent')}
              <input type="hidden" name="parentCategoryId" value={$page.url.searchParams.get('parent')} />
            {/if}
            <div class="grid gap-4 md:grid-cols-2">
              <div>
                <label for="category-name" class="text-xs font-semibold uppercase tracking-[0.18em] text-slate-500">Name</label>
                <input id="category-name" name="name" value={selectedCategory?.name || ''} class="mt-2 w-full rounded-xl border border-slate-200 bg-slate-50 px-4 py-3 text-sm text-slate-900" />
              </div>
              <div>
                <label for="category-code" class="text-xs font-semibold uppercase tracking-[0.18em] text-slate-500">Code</label>
                <input id="category-code" name="code" value={selectedCategory?.code || ''} class="mt-2 w-full rounded-xl border border-slate-200 bg-slate-50 px-4 py-3 text-sm text-slate-900" disabled={selectedCategory?.isSystem} />
              </div>
              <div class="md:col-span-2">
                <label for="category-description" class="text-xs font-semibold uppercase tracking-[0.18em] text-slate-500">Description</label>
                <textarea id="category-description" name="description" class="mt-2 min-h-[160px] w-full rounded-xl border border-slate-200 bg-slate-50 px-4 py-3 text-sm text-slate-900" disabled={selectedCategory?.isSystem}>{selectedCategory?.description || ''}</textarea>
              </div>
            </div>
            <div class="mt-5 flex flex-wrap gap-3">
              <button class="rounded-xl bg-slate-900 px-4 py-2 text-sm font-semibold text-white" disabled={selectedCategory?.isSystem}>{isNew ? 'Create' : 'Save'}</button>
              {#if selectedCategory}
                <button formaction={`/api/v1/admin/company-categories/${selectedCategory.id}`} name="action" value="delete" class="rounded-xl border border-rose-200 px-4 py-2 text-sm font-semibold text-rose-700" disabled={selectedCategory.isSystem || selectedCategory.companyCount > 0}>Delete</button>
              {/if}
              <a href="/admin/company-categories" class="rounded-xl border border-slate-200 px-4 py-2 text-sm font-semibold text-slate-700">Back</a>
            </div>
          </form>
        {:else}
          <div class="flex items-center justify-between gap-3">
            <div class="text-sm text-slate-500">System and custom category tree.</div>
            <a href="/admin/company-categories/new" class="rounded-xl bg-slate-900 px-4 py-2 text-sm font-semibold text-white">New Category</a>
          </div>
          <div class="grid gap-4 xl:grid-cols-2">
            {#each data.companyCategories || [] as item}
              <a href={`/admin/company-categories/${item.id}/view`} class="rounded-2xl border border-slate-200 bg-white p-5 transition hover:border-slate-300">
                <div class="flex items-center justify-between gap-3">
                  <div class="text-lg font-semibold text-slate-900">{item.name}</div>
                  {#if item.isSystem}
                    <span class="rounded-full bg-slate-900 px-3 py-1 text-xs font-semibold text-white">System</span>
                  {/if}
                </div>
                <div class="mt-1 text-sm text-slate-500">{item.code} · {item.companyCount} companies</div>
                <div class="mt-3 text-sm text-slate-600">{item.description || 'No description'}</div>
              </a>
            {/each}
          </div>
        {/if}
      {:else if section === 'users'}
        {#if isNew || selectedUser}
          <form method="post" action={isNew ? '/api/v1/admin/users' : `/api/v1/admin/users/${selectedUser.id}`} class="rounded-2xl border border-slate-200 bg-white p-6" on:submit|preventDefault={(event) => submitAdminForm(event, { redirectTo: '/admin/users' })}>
            {#if hiddenCsrf()}
              <input type="hidden" name={$bootstrap.auth.csrfParam} value={$bootstrap.auth.csrfToken} />
            {/if}
            {#if !isNew}
              <input type="hidden" name="action" value="update" />
            {/if}
            <div class="grid gap-4 md:grid-cols-2">
              <div>
                <label for="user-ident" class="text-xs font-semibold uppercase tracking-[0.18em] text-slate-500">Username</label>
                <input id="user-ident" name="ident" value={selectedUser?.ident || ''} class="mt-2 w-full rounded-xl border border-slate-200 bg-slate-50 px-4 py-3 text-sm text-slate-900" />
              </div>
              <div>
                <label for="user-role" class="text-xs font-semibold uppercase tracking-[0.18em] text-slate-500">Role</label>
                <select id="user-role" name="role" class="mt-2 w-full rounded-xl border border-slate-200 bg-slate-50 px-4 py-3 text-sm text-slate-900">
                  <option value="user" selected={selectedUser?.role !== 'admin'}>user</option>
                  <option value="admin" selected={selectedUser?.role === 'admin'}>admin</option>
                </select>
              </div>
              <div>
                <label for="user-name" class="text-xs font-semibold uppercase tracking-[0.18em] text-slate-500">Display name</label>
                <input id="user-name" name="name" value={selectedUser?.name || ''} class="mt-2 w-full rounded-xl border border-slate-200 bg-slate-50 px-4 py-3 text-sm text-slate-900" />
              </div>
              <div>
                <label for="user-password" class="text-xs font-semibold uppercase tracking-[0.18em] text-slate-500">Password {isNew ? '' : '(optional)'}</label>
                <input id="user-password" type="password" name="password" class="mt-2 w-full rounded-xl border border-slate-200 bg-slate-50 px-4 py-3 text-sm text-slate-900" />
              </div>
              <div class="md:col-span-2">
                <label for="user-description" class="text-xs font-semibold uppercase tracking-[0.18em] text-slate-500">Description</label>
                <textarea id="user-description" name="description" class="mt-2 min-h-[140px] w-full rounded-xl border border-slate-200 bg-slate-50 px-4 py-3 text-sm text-slate-900">{selectedUser?.description || ''}</textarea>
              </div>
            </div>
            <div class="mt-5 flex flex-wrap gap-3">
              <button class="rounded-xl bg-slate-900 px-4 py-2 text-sm font-semibold text-white">{isNew ? 'Create' : 'Save'}</button>
              {#if selectedUser}
                <button formaction={`/api/v1/admin/users/${selectedUser.id}`} name="action" value="delete" class="rounded-xl border border-rose-200 px-4 py-2 text-sm font-semibold text-rose-700">Delete</button>
              {/if}
              <a href="/admin/users" class="rounded-xl border border-slate-200 px-4 py-2 text-sm font-semibold text-slate-700">Back</a>
            </div>
          </form>
        {:else}
          <div class="flex items-center justify-between gap-3">
            <div class="text-sm text-slate-500">Administrate forum members and roles.</div>
            <a href="/admin/users/new" class="rounded-xl bg-slate-900 px-4 py-2 text-sm font-semibold text-white">New User</a>
          </div>
          <div class="overflow-hidden rounded-2xl border border-slate-200 bg-white">
            <table class="min-w-full divide-y divide-slate-200 text-sm">
              <thead class="bg-slate-50 text-left text-slate-500">
                <tr><th class="px-4 py-3">User</th><th class="px-4 py-3">Role</th><th class="px-4 py-3">Region</th><th class="px-4 py-3"></th></tr>
              </thead>
              <tbody class="divide-y divide-slate-200">
                {#each data.users || [] as item}
                  <tr>
                    <td class="px-4 py-3"><div class="font-semibold text-slate-900">{item.name || item.ident}</div><div class="text-slate-500">@{item.ident}</div></td>
                    <td class="px-4 py-3">{item.role}</td>
                    <td class="px-4 py-3">{item.state || '-'}{item.countryCode ? `, ${item.countryCode}` : ''}</td>
                    <td class="px-4 py-3 text-right"><a href={`/admin/users/${item.id}/view`} class="font-semibold text-slate-700">Edit</a></td>
                  </tr>
                {/each}
              </tbody>
            </table>
          </div>
        {/if}
      {:else if section === 'settings'}
        <div class="space-y-5">
          {#each groupMeta as group}
            <form method="post" action="/api/v1/admin/settings" class="rounded-2xl border border-slate-200 bg-white p-6" on:submit|preventDefault={(event) => submitAdminForm(event)}>
              {#if hiddenCsrf()}
                <input type="hidden" name={$bootstrap.auth.csrfParam} value={$bootstrap.auth.csrfToken} />
              {/if}
              <input type="hidden" name="action" value={group.action} />
              <div class="flex items-center justify-between gap-3">
                <div class="text-lg font-semibold text-slate-900">{group.label}</div>
                <button class="rounded-xl bg-slate-900 px-4 py-2 text-sm font-semibold text-white">Save</button>
              </div>
              <div class="mt-5 grid gap-4 md:grid-cols-2">
                {#each data.settings.groups[group.key] || [] as key}
                  <div class="rounded-xl bg-slate-50 p-4">
                    <label for={key} class="text-xs font-semibold uppercase tracking-[0.18em] text-slate-500">{keyLabel(key)}</label>
                    {#if isBooleanKey(key)}
                      <select id={key} name={key} class="mt-2 w-full rounded-xl border border-slate-200 bg-white px-4 py-3 text-sm text-slate-900">
                        <option value="false" selected={settingValue(key) !== 'true'}>false</option>
                        <option value="true" selected={settingValue(key) === 'true'}>true</option>
                      </select>
                    {:else}
                      <input id={key} name={key} value={settingValue(key)} class="mt-2 w-full rounded-xl border border-slate-200 bg-white px-4 py-3 text-sm text-slate-900" />
                    {/if}
                  </div>
                {/each}
              </div>
            </form>
          {/each}
        </div>
      {:else if section === 'ads'}
        {#if isNew || selectedAd}
          <form method="post" action={isNew ? '/api/v1/admin/ads' : `/api/v1/admin/ads/${selectedAd.id}`} class="rounded-2xl border border-slate-200 bg-white p-6" on:submit|preventDefault={(event) => submitAdminForm(event, { redirectTo: '/admin/ads' })}>
            {#if hiddenCsrf()}
              <input type="hidden" name={$bootstrap.auth.csrfParam} value={$bootstrap.auth.csrfToken} />
            {/if}
            {#if !isNew}
              <input type="hidden" name="action" value="update" />
            {/if}
            <div class="grid gap-4 md:grid-cols-2">
              <div class="md:col-span-2">
                <label for="ad-title" class="text-xs font-semibold uppercase tracking-[0.18em] text-slate-500">Title</label>
                <input id="ad-title" name="title" value={selectedAd?.title || ''} class="mt-2 w-full rounded-xl border border-slate-200 bg-slate-50 px-4 py-3 text-sm text-slate-900" />
              </div>
              <div class="md:col-span-2">
                <label for="ad-body" class="text-xs font-semibold uppercase tracking-[0.18em] text-slate-500">Body</label>
                <textarea id="ad-body" name="body" class="mt-2 min-h-[160px] w-full rounded-xl border border-slate-200 bg-slate-50 px-4 py-3 text-sm text-slate-900">{selectedAd?.body || ''}</textarea>
              </div>
              <div>
                <label for="ad-link" class="text-xs font-semibold uppercase tracking-[0.18em] text-slate-500">Link</label>
                <input id="ad-link" name="link" value={selectedAd?.link || ''} class="mt-2 w-full rounded-xl border border-slate-200 bg-slate-50 px-4 py-3 text-sm text-slate-900" />
              </div>
              <div>
                <label for="ad-position" class="text-xs font-semibold uppercase tracking-[0.18em] text-slate-500">Position</label>
                <input id="ad-position" name="position" value={selectedAd?.position || 'sidebar-right'} class="mt-2 w-full rounded-xl border border-slate-200 bg-slate-50 px-4 py-3 text-sm text-slate-900" />
              </div>
              <div>
                <label for="ad-sort-order" class="text-xs font-semibold uppercase tracking-[0.18em] text-slate-500">Sort order</label>
                <input id="ad-sort-order" type="number" name="sortOrder" value={selectedAd?.sortOrder || 0} class="mt-2 w-full rounded-xl border border-slate-200 bg-slate-50 px-4 py-3 text-sm text-slate-900" />
              </div>
              <div class="flex items-center gap-3 rounded-xl bg-slate-50 px-4 py-3">
                <input id="ad-is-active" type="checkbox" name="isActive" checked={selectedAd?.isActive} />
                <label for="ad-is-active" class="text-sm text-slate-700">Active</label>
              </div>
              <div>
                <label for="ad-start-date" class="text-xs font-semibold uppercase tracking-[0.18em] text-slate-500">Start date</label>
                <input id="ad-start-date" type="date" name="startDate" value={selectedAd?.startDate || ''} class="mt-2 w-full rounded-xl border border-slate-200 bg-slate-50 px-4 py-3 text-sm text-slate-900" />
              </div>
              <div>
                <label for="ad-end-date" class="text-xs font-semibold uppercase tracking-[0.18em] text-slate-500">End date</label>
                <input id="ad-end-date" type="date" name="endDate" value={selectedAd?.endDate || ''} class="mt-2 w-full rounded-xl border border-slate-200 bg-slate-50 px-4 py-3 text-sm text-slate-900" />
              </div>
            </div>
            <div class="mt-5 flex flex-wrap gap-3">
              <button class="rounded-xl bg-slate-900 px-4 py-2 text-sm font-semibold text-white">{isNew ? 'Create' : 'Save'}</button>
              {#if selectedAd}
                <button formaction={`/api/v1/admin/ads/${selectedAd.id}`} name="action" value="delete" class="rounded-xl border border-rose-200 px-4 py-2 text-sm font-semibold text-rose-700">Delete</button>
              {/if}
              <a href="/admin/ads" class="rounded-xl border border-slate-200 px-4 py-2 text-sm font-semibold text-slate-700">Back</a>
            </div>
          </form>
        {:else}
          <div class="flex items-center justify-between gap-3">
            <div class="text-sm text-slate-500">Schedule and manage sidebar ads.</div>
            <a href="/admin/ads/new" class="rounded-xl bg-slate-900 px-4 py-2 text-sm font-semibold text-white">New Ad</a>
          </div>
          <div class="grid gap-4 xl:grid-cols-2">
            {#each data.ads || [] as item}
              <a href={`/admin/ads/${item.id}/view`} class="rounded-2xl border border-slate-200 bg-white p-5 transition hover:border-slate-300">
                <div class="flex items-center justify-between gap-3">
                  <div class="text-lg font-semibold text-slate-900">{item.title}</div>
                  <span class={`rounded-full px-3 py-1 text-xs font-semibold ${item.isActive ? 'bg-emerald-100 text-emerald-700' : 'bg-slate-100 text-slate-600'}`}>{item.isActive ? 'Active' : 'Inactive'}</span>
                </div>
                <div class="mt-3 text-sm text-slate-600">{item.body}</div>
              </a>
            {/each}
          </div>
        {/if}
      {:else if section === 'moderation' && segments[1] === 'logs'}
        <div class="rounded-2xl border border-slate-200 bg-white">
          <table class="min-w-full divide-y divide-slate-200 text-sm">
            <thead class="bg-slate-50 text-left text-slate-500">
              <tr><th class="px-4 py-3">Type</th><th class="px-4 py-3">Target</th><th class="px-4 py-3">Actor</th><th class="px-4 py-3">When</th></tr>
            </thead>
            <tbody class="divide-y divide-slate-200">
              {#each data.moderation?.logs || [] as item}
                <tr>
                  <td class="px-4 py-3">{item.targetType}</td>
                  <td class="px-4 py-3">{item.targetId} / {item.action}</td>
                  <td class="px-4 py-3">{item.actor?.ident || 'unknown'}</td>
                  <td class="px-4 py-3">{formatDate(item.createdAt)} · {relativeTime(item.createdAt)}</td>
                </tr>
              {/each}
            </tbody>
          </table>
        </div>
      {:else if section === 'moderation'}
        <div class="grid gap-5 xl:grid-cols-2">
          <div class="rounded-2xl border border-slate-200 bg-white p-5">
            <div class="text-lg font-semibold text-slate-900">Post flags</div>
            <div class="mt-4 space-y-3">
              {#each data.moderation?.queue?.postFlags || [] as item}
                <div class="rounded-xl bg-slate-50 p-4">
                  <div class="text-sm font-semibold text-slate-900">{item.postTitle}</div>
                  <div class="mt-1 text-sm text-slate-600">{item.postPreview}</div>
                  <div class="mt-3 flex items-center justify-between gap-3">
                    <div class="text-xs text-slate-500">{item.user?.ident || 'unknown'} · {relativeTime(item.createdAt)}</div>
                    <form method="post" action="/api/v1/admin/moderation/action" on:submit|preventDefault={(event) => submitAdminForm(event, { confirmDelete: false })}>
                      {#if hiddenCsrf()}
                        <input type="hidden" name={$bootstrap.auth.csrfParam} value={$bootstrap.auth.csrfToken} />
                      {/if}
                      <input type="hidden" name="action" value="post-flag-delete" />
                      <input type="hidden" name="id" value={item.id} />
                      <button class="text-sm font-semibold text-rose-700">Remove</button>
                    </form>
                  </div>
                </div>
              {/each}
            </div>
          </div>

          <div class="rounded-2xl border border-slate-200 bg-white p-5">
            <div class="text-lg font-semibold text-slate-900">Post blocks</div>
            <div class="mt-4 space-y-3">
              {#each data.moderation?.queue?.postBlocks || [] as item}
                <div class="rounded-xl bg-slate-50 p-4">
                  <div class="text-sm font-semibold text-slate-900">{item.postTitle}</div>
                  <div class="mt-1 text-sm text-slate-600">{item.postPreview}</div>
                  <div class="mt-3 flex items-center justify-between gap-3">
                    <div class="text-xs text-slate-500">{item.user?.ident || 'unknown'} · {relativeTime(item.createdAt)}</div>
                    <form method="post" action="/api/v1/admin/moderation/action" on:submit|preventDefault={(event) => submitAdminForm(event, { confirmDelete: false })}>
                      {#if hiddenCsrf()}
                        <input type="hidden" name={$bootstrap.auth.csrfParam} value={$bootstrap.auth.csrfToken} />
                      {/if}
                      <input type="hidden" name="action" value="post-block-delete" />
                      <input type="hidden" name="id" value={item.id} />
                      <button class="text-sm font-semibold text-rose-700">Remove</button>
                    </form>
                  </div>
                </div>
              {/each}
            </div>
          </div>
        </div>
      {/if}
    </div>
  {/if}
</section>
