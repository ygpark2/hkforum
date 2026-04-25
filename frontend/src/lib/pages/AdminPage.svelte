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
  $: companyCategoryOptions = (data?.companyCategories || []).filter((item) => item.majorCode);
  $: allCompanyCategories = data?.companyCategories || [];
  $: majorCategoryRows = allCompanyCategories.filter((item) => item.isMajor);
  $: minorCategoryRows = allCompanyCategories.filter((item) => item.majorCode);
  $: majorCategoryByCode = new Map(majorCategoryRows.map((item) => [item.code, item]));
  $: syntheticMajorGroups = Array.from(
    minorCategoryRows.reduce((groups, item) => {
      if (!item.majorCode || majorCategoryByCode.has(item.majorCode)) return groups;
      if (!groups.has(item.majorCode)) {
        groups.set(item.majorCode, {
          categoryId: null,
          code: item.majorCode,
          name: item.majorName || item.majorCode,
          description: '',
          isSystem: true,
          isSynthetic: true,
          sortOrder: item.sortOrder || 0,
          companyCount: 0,
          childCount: 0
        });
      }
      const current = groups.get(item.majorCode);
      current.companyCount += item.companyCount || 0;
      current.childCount += 1;
      current.sortOrder = Math.min(current.sortOrder, item.sortOrder || current.sortOrder || 0);
      return groups;
    }, new Map()).values()
  ).sort(sortCategoriesByOrder);
  $: majorGroups = [
    ...majorCategoryRows.map((item) => ({
      ...item,
      categoryId: item.id,
      isSynthetic: false
    })),
    ...syntheticMajorGroups
  ].sort(sortCategoriesByOrder);
  $: requestedMajorCode = $page.url.searchParams.get('major') || (selectedCategory ? (selectedCategory.isMajor ? selectedCategory.code : selectedCategory.majorCode) : '');
  $: selectedMajorCode = majorGroups.some((item) => item.code === requestedMajorCode) ? requestedMajorCode : (majorGroups[0]?.code || '');
  $: selectedMajorGroup = majorGroups.find((item) => item.code === selectedMajorCode) || null;
  $: selectedMajorChildren = minorCategoryRows.filter((item) => item.majorCode === selectedMajorCode).sort(sortCategoriesByOrder);
  $: categoryEditorKind = selectedCategory ? (selectedCategory.isMajor ? 'major' : 'minor') : ($page.url.searchParams.get('kind') === 'minor' ? 'minor' : 'major');
  $: categoryFormMajorCode = selectedCategory ? (selectedCategory.isMajor ? selectedCategory.code : selectedCategory.majorCode) : ($page.url.searchParams.get('major') || selectedMajorCode || '');
  $: selectedMajorCompanyTotal = (selectedMajorGroup?.companyCount || 0) + selectedMajorChildren.reduce((sum, item) => sum + (item.companyCount || 0), 0);

  function companyCategoryLabel(category) {
    const majorLabel = category.majorName || category.majorCode;
    return majorLabel ? `${majorLabel} > ${category.name}` : category.name;
  }

  function sortCategoriesByOrder(left, right) {
    return (left.sortOrder || 0) - (right.sortOrder || 0) || (left.name || '').localeCompare(right.name || '');
  }

  function companyCategoriesHref(majorCode = '') {
    return majorCode ? `/admin/company-categories?major=${encodeURIComponent(majorCode)}` : '/admin/company-categories';
  }

  function majorGroupHref(group) {
    return group.categoryId ? `/admin/company-categories/${group.categoryId}/view?major=${encodeURIComponent(group.code)}` : companyCategoriesHref(group.code);
  }

  function newMinorCategoryHref(majorCode) {
    return `/admin/company-categories/new?kind=minor&major=${encodeURIComponent(majorCode)}`;
  }

  function editMinorCategoryHref(category) {
    return `/admin/company-categories/${category.id}/view?major=${encodeURIComponent(category.majorCode || selectedMajorCode)}`;
  }

  function majorGroupCompanyTotal(groupCode) {
    return (majorCategoryByCode.get(groupCode)?.companyCount || 0) + minorCategoryRows.filter((item) => item.majorCode === groupCode).reduce((sum, item) => sum + (item.companyCount || 0), 0);
  }

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

  function settingOptions(key) {
    if (key === 'site_template') {
      const templates = $bootstrap.site?.availableTemplates || ['base', 'eu', 'anz'];
      return templates.map((value) => ({
        value,
        label:
          value === 'base'
            ? 'Base'
            : value === 'anz'
              ? 'ANZ'
              : value === 'eu'
                ? 'EU'
                : value.toUpperCase()
      }));
    }

    return null;
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
                  {#each companyCategoryOptions as category}
                    <option value={category.id} selected={category.id === selectedCompany?.categoryId}>{companyCategoryLabel(category)}</option>
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
        <div class="space-y-5">
          <div class="flex flex-wrap items-center justify-between gap-3">
            <div>
              <div class="text-sm font-semibold uppercase tracking-[0.18em] text-slate-500">Category Structure</div>
              <div class="mt-1 text-sm text-slate-500">대분류를 고르면 가운데에서 하위 분류를 보고, 오른쪽에서 바로 CRUD를 처리합니다.</div>
            </div>
            <a href="/admin/company-categories/new?kind=major" class="rounded-xl bg-slate-900 px-4 py-2 text-sm font-semibold text-white">New Major</a>
          </div>

          <div class="grid gap-5 lg:grid-cols-[280px_minmax(0,1fr)] xl:grid-cols-[280px_minmax(0,1fr)_360px]">
            <div class="overflow-hidden rounded-2xl border border-slate-200 bg-white">
              <div class="border-b border-slate-200 px-5 py-4">
                <div class="text-lg font-semibold text-slate-900">Major Categories</div>
                <div class="mt-1 text-sm text-slate-500">대분류별 하위 분류와 회사 수를 확인합니다.</div>
              </div>
              <div class="max-h-[calc(100vh-16rem)] overflow-y-auto divide-y divide-slate-200">
                {#if !majorGroups.length}
                  <div class="px-5 py-6 text-sm text-slate-500">아직 대분류가 없습니다.</div>
                {:else}
                  {#each majorGroups as item}
                    <a
                      href={majorGroupHref(item)}
                      class={`block px-5 py-4 transition ${selectedMajorCode === item.code ? 'bg-slate-900 text-white' : 'hover:bg-slate-50'}`}
                    >
                      <div class="flex items-start justify-between gap-3">
                        <div class="min-w-0">
                          <div class={`truncate text-base font-semibold ${selectedMajorCode === item.code ? 'text-white' : 'text-slate-900'}`}>{item.name}</div>
                          <div class={`mt-1 text-xs uppercase tracking-[0.18em] ${selectedMajorCode === item.code ? 'text-slate-300' : 'text-slate-500'}`}>{item.code}</div>
                        </div>
                        <div class="flex shrink-0 flex-wrap justify-end gap-2 text-[11px] font-semibold">
                          {#if item.isSystem}
                            <span class={`rounded-full px-2.5 py-1 ${selectedMajorCode === item.code ? 'bg-white/15 text-white' : 'bg-slate-900 text-white'}`}>System</span>
                          {/if}
                          {#if item.isSynthetic}
                            <span class={`rounded-full px-2.5 py-1 ${selectedMajorCode === item.code ? 'bg-white/15 text-white' : 'bg-slate-100 text-slate-700'}`}>Seed Group</span>
                          {/if}
                        </div>
                      </div>
                      <div class={`mt-3 flex flex-wrap gap-3 text-xs ${selectedMajorCode === item.code ? 'text-slate-300' : 'text-slate-500'}`}>
                        <span>{item.childCount || 0} subcategories</span>
                        <span>{majorGroupCompanyTotal(item.code)} companies</span>
                      </div>
                    </a>
                  {/each}
                {/if}
              </div>
            </div>

            <div class="space-y-5">
              <div class="rounded-2xl border border-slate-200 bg-white p-5">
                {#if selectedMajorGroup}
                  <div class="flex flex-wrap items-start justify-between gap-4">
                    <div class="min-w-0">
                      <div class="flex flex-wrap items-center gap-2">
                        <h2 class="text-xl font-semibold text-slate-900">{selectedMajorGroup.name}</h2>
                        {#if selectedMajorGroup.isSystem}
                          <span class="rounded-full bg-slate-900 px-2.5 py-1 text-xs font-semibold text-white">System</span>
                        {/if}
                        {#if selectedMajorGroup.isSynthetic}
                          <span class="rounded-full bg-slate-100 px-2.5 py-1 text-xs font-semibold text-slate-700">Seed Group</span>
                        {/if}
                      </div>
                      <div class="mt-2 text-sm text-slate-500">{selectedMajorGroup.code}</div>
                      <div class="mt-3 grid gap-3 sm:grid-cols-3">
                        <div class="rounded-xl bg-slate-50 px-4 py-3">
                          <div class="text-xs font-semibold uppercase tracking-[0.18em] text-slate-500">Subcategories</div>
                          <div class="mt-2 text-2xl font-semibold text-slate-900">{selectedMajorChildren.length}</div>
                        </div>
                        <div class="rounded-xl bg-slate-50 px-4 py-3">
                          <div class="text-xs font-semibold uppercase tracking-[0.18em] text-slate-500">Companies</div>
                          <div class="mt-2 text-2xl font-semibold text-slate-900">{selectedMajorCompanyTotal}</div>
                        </div>
                        <div class="rounded-xl bg-slate-50 px-4 py-3">
                          <div class="text-xs font-semibold uppercase tracking-[0.18em] text-slate-500">Type</div>
                          <div class="mt-2 text-sm font-semibold text-slate-900">{selectedMajorGroup.isSynthetic ? 'Seed-linked major' : 'Managed major'}</div>
                        </div>
                      </div>
                      <div class="mt-4 text-sm text-slate-600">{selectedMajorGroup.description || '선택된 대분류에 대한 설명이 없습니다.'}</div>
                    </div>
                    <div class="flex flex-wrap gap-2">
                      <a href={newMinorCategoryHref(selectedMajorGroup.code)} class="rounded-xl bg-slate-900 px-4 py-2 text-sm font-semibold text-white">Add Subcategory</a>
                      {#if selectedMajorGroup.categoryId}
                        <a href={majorGroupHref(selectedMajorGroup)} class="rounded-xl border border-slate-200 px-4 py-2 text-sm font-semibold text-slate-700">Edit Major</a>
                      {/if}
                    </div>
                  </div>
                {:else}
                  <div class="text-sm text-slate-500">왼쪽에서 대분류를 선택하면 가운데에 하위 분류 목록이 표시됩니다.</div>
                {/if}
              </div>

              <div class="overflow-hidden rounded-2xl border border-slate-200 bg-white">
                <div class="flex flex-wrap items-center justify-between gap-3 border-b border-slate-200 px-5 py-4">
                  <div>
                    <div class="text-lg font-semibold text-slate-900">Subcategories</div>
                    <div class="mt-1 text-sm text-slate-500">선택된 대분류 아래 분류를 바로 수정하거나 새로 추가합니다.</div>
                  </div>
                  {#if selectedMajorGroup}
                    <a href={newMinorCategoryHref(selectedMajorGroup.code)} class="rounded-xl border border-slate-200 px-4 py-2 text-sm font-semibold text-slate-700">New Subcategory</a>
                  {/if}
                </div>
                {#if !selectedMajorGroup}
                  <div class="px-5 py-6 text-sm text-slate-500">대분류를 먼저 선택하세요.</div>
                {:else if !selectedMajorChildren.length}
                  <div class="px-5 py-6 text-sm text-slate-500">이 대분류에 속한 분류가 아직 없습니다.</div>
                {:else}
                  <div class="divide-y divide-slate-200">
                    {#each selectedMajorChildren as item}
                      <div class="flex flex-wrap items-start justify-between gap-4 px-5 py-4">
                        <div class="min-w-0">
                          <div class="flex flex-wrap items-center gap-2">
                            <div class="text-base font-semibold text-slate-900">{item.name}</div>
                            {#if item.isSystem}
                              <span class="rounded-full bg-slate-900 px-2.5 py-1 text-xs font-semibold text-white">System</span>
                            {/if}
                          </div>
                          <div class="mt-1 text-xs uppercase tracking-[0.18em] text-slate-500">{item.code}</div>
                          <div class="mt-2 text-sm text-slate-600">{item.description || '설명이 없습니다.'}</div>
                          <div class="mt-3 flex flex-wrap gap-3 text-xs text-slate-500">
                            <span>{item.companyCount} companies</span>
                            <span>Sort {item.sortOrder || 0}</span>
                            <span>Major {item.majorName || item.majorCode}</span>
                          </div>
                        </div>
                        <div class="flex shrink-0 flex-wrap gap-2">
                          <a href={editMinorCategoryHref(item)} class="rounded-xl border border-slate-200 px-3 py-1.5 text-sm font-semibold text-slate-700">Edit</a>
                        </div>
                      </div>
                    {/each}
                  </div>
                {/if}
              </div>
            </div>

            <div class="xl:sticky xl:top-6 xl:self-start">
              {#if isNew || selectedCategory}
                <form
                  method="post"
                  action={isNew ? '/api/v1/admin/company-categories' : `/api/v1/admin/company-categories/${selectedCategory.id}`}
                  class="rounded-2xl border border-slate-200 bg-white p-6"
                  on:submit|preventDefault={(event) =>
                    submitAdminForm(event, {
                      redirectTo:
                        categoryEditorKind === 'minor' && categoryFormMajorCode
                          ? companyCategoriesHref(categoryFormMajorCode)
                          : '/admin/company-categories'
                    })}
                >
                  {#if hiddenCsrf()}
                    <input type="hidden" name={$bootstrap.auth.csrfParam} value={$bootstrap.auth.csrfToken} />
                  {/if}
                  {#if selectedCategory}
                    <input type="hidden" name="action" value="update" />
                  {/if}

                  <div class="flex flex-wrap items-start justify-between gap-3">
                    <div>
                      <div class="text-lg font-semibold text-slate-900">
                        {selectedCategory ? `Edit ${categoryEditorKind === 'major' ? 'Major Category' : 'Subcategory'}` : `New ${categoryEditorKind === 'major' ? 'Major Category' : 'Subcategory'}`}
                      </div>
                      <div class="mt-1 text-sm text-slate-500">
                        {#if categoryEditorKind === 'major'}
                          대분류를 만들거나 이름, 코드, 설명을 수정합니다.
                        {:else}
                          분류를 만들거나 대분류 소속을 변경합니다.
                        {/if}
                      </div>
                    </div>
                    <a href={categoryEditorKind === 'minor' && categoryFormMajorCode ? companyCategoriesHref(categoryFormMajorCode) : '/admin/company-categories'} class="rounded-xl border border-slate-200 px-4 py-2 text-sm font-semibold text-slate-700">Close</a>
                  </div>

                  <div class="mt-5 space-y-4">
                    {#if categoryEditorKind === 'minor'}
                      <div>
                        <label for="category-parent-major" class="text-xs font-semibold uppercase tracking-[0.18em] text-slate-500">Major category</label>
                        <select id="category-parent-major" name="parentMajorCode" class="mt-2 w-full rounded-xl border border-slate-200 bg-slate-50 px-4 py-3 text-sm text-slate-900" disabled={selectedCategory?.isSystem}>
                          {#each majorGroups as item}
                            <option value={item.code} selected={item.code === categoryFormMajorCode}>{item.name} ({item.code})</option>
                          {/each}
                        </select>
                      </div>
                    {/if}
                    <div>
                      <label for="category-name" class="text-xs font-semibold uppercase tracking-[0.18em] text-slate-500">Name</label>
                      <input id="category-name" name="name" value={selectedCategory?.name || ''} class="mt-2 w-full rounded-xl border border-slate-200 bg-slate-50 px-4 py-3 text-sm text-slate-900" disabled={selectedCategory?.isSystem} />
                    </div>
                    <div>
                      <label for="category-code" class="text-xs font-semibold uppercase tracking-[0.18em] text-slate-500">Code</label>
                      <input id="category-code" name="code" value={selectedCategory?.code || ''} class="mt-2 w-full rounded-xl border border-slate-200 bg-slate-50 px-4 py-3 text-sm text-slate-900" disabled={selectedCategory?.isSystem} />
                    </div>
                    <div>
                      <label for="category-description" class="text-xs font-semibold uppercase tracking-[0.18em] text-slate-500">Description</label>
                      <textarea id="category-description" name="description" class="mt-2 min-h-[180px] w-full rounded-xl border border-slate-200 bg-slate-50 px-4 py-3 text-sm text-slate-900" disabled={selectedCategory?.isSystem}>{selectedCategory?.description || ''}</textarea>
                    </div>
                  </div>

                  <div class="mt-5 flex flex-wrap gap-3">
                    <button class="rounded-xl bg-slate-900 px-4 py-2 text-sm font-semibold text-white" disabled={selectedCategory?.isSystem}>
                      {selectedCategory ? 'Save' : 'Create'}
                    </button>
                    {#if selectedCategory}
                      <button
                        formaction={`/api/v1/admin/company-categories/${selectedCategory.id}`}
                        name="action"
                        value="delete"
                        class="rounded-xl border border-rose-200 px-4 py-2 text-sm font-semibold text-rose-700"
                        disabled={selectedCategory.isSystem || selectedCategory.companyCount > 0 || selectedCategory.childCount > 0}
                      >
                        Delete
                      </button>
                    {/if}
                  </div>

                  {#if selectedCategory}
                    <div class="mt-4 flex flex-wrap gap-3 text-xs text-slate-500">
                      <span>{selectedCategory.companyCount} companies</span>
                      <span>{selectedCategory.childCount || 0} child categories</span>
                      {#if selectedCategory.isSystem}
                        <span>System category is read-only</span>
                      {/if}
                    </div>
                  {/if}
                </form>
              {:else}
                <div class="rounded-2xl border border-dashed border-slate-300 bg-slate-50 p-6">
                  <div class="text-lg font-semibold text-slate-900">Editor Panel</div>
                  <div class="mt-2 text-sm text-slate-600">왼쪽에서 대분류를 고르고, 가운데에서 분류를 선택하면 이 패널에서 바로 생성, 수정, 삭제할 수 있습니다.</div>
                  <div class="mt-5 space-y-3 text-sm text-slate-500">
                    <div class="rounded-xl bg-white px-4 py-3">`New Major`로 새 대분류 생성</div>
                    <div class="rounded-xl bg-white px-4 py-3">가운데 `New Subcategory`로 하위 분류 추가</div>
                    <div class="rounded-xl bg-white px-4 py-3">목록의 `Edit`으로 기존 분류 수정</div>
                  </div>
                </div>
              {/if}
            </div>
          </div>
        </div>
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
                    {:else if settingOptions(key)}
                      <select id={key} name={key} class="mt-2 w-full rounded-xl border border-slate-200 bg-white px-4 py-3 text-sm text-slate-900">
                        {#each settingOptions(key) as option}
                          <option value={option.value} selected={settingValue(key) === option.value}>{option.label}</option>
                        {/each}
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
