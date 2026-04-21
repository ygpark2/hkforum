<script>
  import { onMount } from 'svelte';
  import { page } from '$app/stores';
  import PageEmpty from '$lib/components/PageEmpty.svelte';
  import RichEditor from '$lib/components/RichEditor.svelte';
  import { bootstrap } from '$lib/stores/bootstrap';
  import { apiFetch, sendJson } from '$lib/utils/api';
  import { relativeTime } from '$lib/utils/time';

  let items = [];
  let loading = true;
  let open = false;
  let name = '';
  let website = '';
  let size = '';
  let description = '';
  let categoryId = '';
  let submitting = false;
  let deletingCompanyId = null;
  let editingCompanyId = null;

  $: categories = $bootstrap.companyCategories || [];
  $: majorGroups = Array.from(new Map(categories.filter((item) => item.majorCode).map((item) => [item.majorCode, item.majorName || item.majorCode])).entries()).map(([code, label]) => ({ code, label }));
  $: selectedMajor = $page.url.searchParams.get('major') || '';
  $: selectedCategory = $page.url.searchParams.get('category') || '';
  $: filteredCategories = selectedMajor ? categories.filter((item) => item.majorCode === selectedMajor) : categories;
  $: if (!categoryId && filteredCategories[0]) categoryId = String(filteredCategories[0].id);

  function resetForm() {
    name = '';
    website = '';
    size = '';
    description = '';
    categoryId = categories[0] ? String(categories[0].id) : '';
    editingCompanyId = null;
  }

  async function loadCompanies() {
    loading = true;
    try {
      const params = new URLSearchParams($page.url.searchParams);
      const payload = await apiFetch(`/api/v1/companies?${params.toString()}`);
      items = payload.items || [];
    } finally {
      loading = false;
    }
  }

  async function submitCompany() {
    if (submitting) return;
    submitting = true;

    try {
      const payload = {
        body: {
          name,
          categoryId: Number(categoryId),
          website: website || null,
          size: size || null,
          description
        }
      };
      if (editingCompanyId) {
        await sendJson(`/api/v1/companies/${editingCompanyId}`, { method: 'PATCH', ...payload });
      } else {
        await sendJson('/api/v1/companies', payload);
      }
      resetForm();
      open = false;
      await loadCompanies();
    } catch (error) {
      window.alert(error.message);
    } finally {
      submitting = false;
    }
  }

  function openCreateCompany() {
    resetForm();
    open = true;
  }

  function openEditCompany(company) {
    editingCompanyId = company.id;
    name = company.name || '';
    website = company.website || '';
    size = company.size || '';
    description = company.description || '';
    categoryId = String(company.categoryId || '');
    open = true;
  }

  async function deleteCompany(companyId) {
    if (deletingCompanyId || !window.confirm('Delete this company?')) return;
    deletingCompanyId = companyId;
    try {
      await sendJson(`/api/v1/companies/${companyId}`, { method: 'DELETE' });
      items = items.filter((company) => company.id !== companyId);
      if (editingCompanyId === companyId) {
        open = false;
        resetForm();
      }
    } catch (error) {
      window.alert(error.message);
    } finally {
      deletingCompanyId = null;
    }
  }

  onMount(loadCompanies);
  $: if ($page.url.search || categories.length) loadCompanies();
</script>

<section class="flex h-full min-h-0 flex-col bg-white">
  <div class="shrink-0 border-b border-slate-200 px-4 py-3.5">
    <div class="flex flex-wrap items-start justify-between gap-4">
      <div>
        <h1 class="text-3xl font-semibold text-slate-900">Company</h1>
        <p class="mt-1 text-sm text-slate-500">대분류와 세부 분류로 회사를 찾고, 최신 등록 기업부터 바로 확인하세요.</p>
      </div>
      {#if $bootstrap.auth?.isAuthenticated}
        <button type="button" class="rounded-lg bg-slate-900 px-3 py-1.5 text-xs font-semibold uppercase tracking-[0.2em] text-white transition hover:bg-slate-800" on:click={openCreateCompany}>New Company</button>
      {:else}
        <a href="/login" class="rounded-lg border border-slate-900 px-3 py-1.5 text-xs font-semibold uppercase tracking-[0.2em] text-slate-900 transition hover:bg-slate-900 hover:text-white">Login to register</a>
      {/if}
    </div>

    <form method="get" action="/companies" class="mt-4 flex flex-wrap items-end gap-3 lg:max-w-3xl">
      <div class="min-w-[140px] flex-1 space-y-1">
        <label for="company-major-filter" class="text-sm font-semibold text-slate-700">대분류</label>
        <select id="company-major-filter" name="major" class="w-full rounded-xl border border-slate-200 bg-slate-50 px-3 py-2 text-sm text-slate-900">
          <option value="">전체 대분류</option>
          {#each majorGroups as major}
            <option value={major.code} selected={selectedMajor === major.code}>{major.label}</option>
          {/each}
        </select>
      </div>
      <div class="min-w-[140px] flex-1 space-y-1">
        <label for="company-category-filter" class="text-sm font-semibold text-slate-700">분류</label>
        <select id="company-category-filter" name="category" class="w-full rounded-xl border border-slate-200 bg-slate-50 px-3 py-2 text-sm text-slate-900">
          <option value="">전체 분류</option>
          {#each filteredCategories as category}
            <option value={category.id} selected={selectedCategory === String(category.id)}>{category.name}</option>
          {/each}
        </select>
      </div>
      <button type="submit" class="rounded-lg border border-slate-200 px-3 py-2 text-xs font-semibold uppercase tracking-[0.2em] text-slate-700">Apply</button>
    </form>
  </div>

  <div class="min-h-0 flex-1 overflow-y-auto no-scrollbar">
    <div class="sticky top-0 z-10 border-b border-slate-200 bg-white/95 px-4 py-2.5 backdrop-blur-sm">
      <span class="rounded-full bg-slate-100 px-2.5 py-1 text-xs font-semibold text-slate-700">{items.length} companies</span>
    </div>

    {#if loading}
      <div class="flex h-full items-center justify-center px-6 text-center text-slate-500">Loading companies…</div>
    {:else if !categories.length}
      <PageEmpty title="회사 분류가 아직 준비되지 않았습니다." description="시스템 업종 분류가 생성되면 기업을 등록하고 조회할 수 있습니다." />
    {:else if !items.length}
      <PageEmpty title="등록된 회사가 없습니다." description="첫 회사를 등록하면 최신 등록순으로 목록에 표시됩니다." />
    {:else}
      <div class="space-y-4 px-4 py-4">
        {#each items as company}
          <article class="rounded-2xl border border-slate-200 bg-slate-50/60 p-4">
            <div class="flex flex-wrap items-start justify-between gap-3">
              <div class="min-w-0">
                <div class="flex flex-wrap items-center gap-2 text-[11px] font-semibold uppercase tracking-[0.18em] text-slate-500">
                  {#if company.majorCode}
                    <span class="rounded-full bg-slate-900 px-2.5 py-1 text-white">{company.majorCode}</span>
                  {/if}
                  {#if company.categoryName}
                    <span class="rounded-full bg-slate-100 px-2.5 py-1 text-slate-700">{company.categoryName}</span>
                  {/if}
                </div>
                <h2 class="mt-3 break-words text-2xl font-semibold text-slate-900">{company.name}</h2>
                <div class="mt-2 flex flex-wrap items-center gap-x-2 gap-y-1 text-xs text-slate-500">
                  {#if company.size}
                    <span>{company.size}</span>
                  {/if}
                  <span>· 등록 {relativeTime(company.createdAt)}</span>
                </div>
              </div>
              {#if company.website}
                <a href={company.website} target="_blank" rel="noreferrer" class="shrink-0 rounded-full border border-sky-200 bg-sky-50 px-3 py-1.5 text-xs font-semibold text-sky-700 transition hover:border-sky-300 hover:text-sky-900">Visit website</a>
              {/if}
            </div>
            <div class="company-richtext mt-4 rounded-2xl border border-slate-200 bg-white px-4 py-3 text-sm text-slate-700">
              {@html company.description}
            </div>
            <p class="mt-4 text-xs text-slate-500">@{company.author?.ident} · {company.author?.name || company.author?.ident}</p>
            {#if $bootstrap.viewer && ($bootstrap.viewer.id === company.author?.id || $bootstrap.viewer.role === 'admin')}
              <div class="mt-3 flex flex-wrap gap-2">
                <button type="button" class="rounded-lg border border-slate-200 bg-white px-3 py-1.5 text-xs font-semibold uppercase tracking-[0.15em] text-slate-700 transition hover:bg-slate-50" on:click={() => openEditCompany(company)}>
                  Edit
                </button>
                <button type="button" class="rounded-lg border border-rose-200 bg-white px-3 py-1.5 text-xs font-semibold uppercase tracking-[0.15em] text-rose-700 transition hover:bg-rose-50" on:click={() => deleteCompany(company.id)} disabled={deletingCompanyId === company.id}>
                  {deletingCompanyId === company.id ? 'Deleting…' : 'Delete'}
                </button>
              </div>
            {/if}
          </article>
        {/each}
      </div>
    {/if}
  </div>
</section>

{#if open}
  <div
    class="fixed inset-0 z-40 flex items-center justify-center bg-slate-900/40 px-4"
    role="button"
    tabindex="0"
    aria-label="Close new company dialog"
    on:click={() => (open = false)}
    on:keydown={(event) => {
      if (event.key === 'Escape' || event.key === 'Enter' || event.key === ' ') {
        open = false;
        resetForm();
      }
    }}
  >
    <div class="w-[min(94vw,43rem)] rounded-2xl bg-white p-6 shadow-xl" role="dialog" tabindex="-1" aria-modal="true" on:click|stopPropagation on:keydown|stopPropagation={() => {}}>
      <div class="flex items-center justify-between">
        <h2 class="text-lg font-semibold text-slate-900">{editingCompanyId ? 'Edit company' : 'New company'}</h2>
        <button type="button" class="rounded-xl border border-slate-200 px-3 py-1 text-xs font-semibold uppercase tracking-[0.2em] text-slate-600" on:click={() => { open = false; resetForm(); }}>Close</button>
      </div>
      <form class="mt-4 space-y-4" on:submit|preventDefault={submitCompany}>
        <div class="space-y-1">
          <label class="text-sm font-semibold text-slate-700" for="company-name">Company name</label>
          <input id="company-name" name="name" bind:value={name} required class="w-full rounded-xl border border-slate-200 bg-slate-50 px-3 py-2 text-slate-900" placeholder="Acme Labs" />
        </div>
        <div class="grid grid-cols-2 gap-3 !grid">
          <div class="flex flex-col space-y-1">
            <label class="text-sm font-semibold text-slate-700" for="company-create-major">대분류</label>
            <select id="company-create-major" class="w-full rounded-xl border border-slate-200 bg-slate-50 px-3 py-2 text-sm text-slate-900" on:change={(event) => {
              const next = event.currentTarget.value;
              const nextCategories = next ? categories.filter((item) => item.majorCode === next) : categories;
              categoryId = nextCategories[0] ? String(nextCategories[0].id) : '';
            }}>
              <option value="">대분류를 선택하세요</option>
              {#each majorGroups as major}
                <option value={major.code}>{major.label}</option>
              {/each}
            </select>
          </div>
          <div class="flex flex-col space-y-1">
            <label class="text-sm font-semibold text-slate-700" for="company-create-category">분류</label>
            <select id="company-create-category" bind:value={categoryId} class="w-full rounded-xl border border-slate-200 bg-slate-50 px-3 py-2 text-sm text-slate-900">
              {#each categories as category}
                <option value={String(category.id)}>{category.name}</option>
              {/each}
            </select>
          </div>
        </div>
        <div class="grid grid-cols-2 gap-3 !grid">
          <div class="flex flex-col space-y-1">
            <label class="text-sm font-semibold text-slate-700" for="company-website">Website</label>
            <input id="company-website" name="website" bind:value={website} class="w-full rounded-xl border border-slate-200 bg-slate-50 px-3 py-2 text-slate-900" placeholder="https://example.com" />
          </div>
          <div class="flex flex-col space-y-1">
            <label class="text-sm font-semibold text-slate-700" for="company-size">Size</label>
            <input id="company-size" name="size" bind:value={size} class="w-full rounded-xl border border-slate-200 bg-slate-50 px-3 py-2 text-slate-900" placeholder="50-200 employees" />
          </div>
        </div>
        <div class="space-y-1">
          <div class="text-sm font-semibold text-slate-700">Description</div>
          <RichEditor bind:value={description} name="description" placeholder="Tell people about this company" />
        </div>
        <div class="flex justify-end gap-2 pt-1">
          <button type="submit" class="rounded-xl bg-gradient-to-r from-slate-900 to-slate-700 px-4 py-2 text-center text-xs font-semibold uppercase tracking-[0.2em] text-white" disabled={submitting}>
            {submitting ? (editingCompanyId ? 'Saving…' : 'Creating…') : (editingCompanyId ? 'Save' : 'Create')}
          </button>
          <button type="button" class="rounded-xl border border-slate-200 px-4 py-2 text-xs font-semibold uppercase tracking-[0.2em] text-slate-600" on:click={() => { open = false; resetForm(); }}>Cancel</button>
        </div>
      </form>
    </div>
  </div>
{/if}
