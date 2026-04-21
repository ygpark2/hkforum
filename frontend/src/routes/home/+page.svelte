<script>
  import { onMount } from 'svelte';
  import { page } from '$app/stores';
  import PageEmpty from '$lib/components/PageEmpty.svelte';
  import PostCard from '$lib/components/PostCard.svelte';
  import { bootstrap } from '$lib/stores/bootstrap';
  import { apiFetch } from '$lib/utils/api';

  const tabs = [
    { key: 'everything', label: 'Everything' },
    { key: 'trends', label: 'Trending' },
    { key: 'unread', label: 'Unread' },
    { key: 'following', label: 'Following' },
    { key: 'local', label: 'Local' },
    { key: 'interests', label: 'Interests' }
  ];

  let items = [];
  let loading = true;
  let customTabs = [];
  let addTabOpen = false;
  let customName = '';
  let customTag = '';

  $: activeTab = $page.url.searchParams.get('tab') || 'everything';
  $: activeTag = $page.url.searchParams.get('tag') || '';
  $: localRegionNotice = getLocalRegionNotice();

  function getLocalRegionNotice() {
    if (activeTab !== 'local') return null;
    if (!$bootstrap.site?.localRegionFilterEnabled) return '내지역 기능이 현재 비활성화되어 있습니다.';
    if (!$bootstrap.auth?.isAuthenticated) return '로그인해야 내지역 탭을 사용할 수 있습니다.';
    if (!$bootstrap.viewer?.countryCode || !$bootstrap.viewer?.state) return '프로필에 국가와 주를 저장해야 내지역 탭을 사용할 수 있습니다.';
    return `내 지역 필터 적용 중: ${$bootstrap.viewer.state}, ${$bootstrap.viewer.countryCode}`;
  }

  function loadCustomTabs() {
    try {
      customTabs = JSON.parse(localStorage.getItem('hkforum-home-custom-tabs') || '[]');
    } catch {
      customTabs = [];
    }
  }

  function saveCustomTabs() {
    localStorage.setItem('hkforum-home-custom-tabs', JSON.stringify(customTabs));
  }

  function addCustomTab() {
    if (!customName.trim() || !customTag.trim()) return;
    customTabs = [...customTabs, { key: `custom-${Date.now()}`, label: customName.trim(), tag: customTag.trim() }];
    saveCustomTabs();
    customName = '';
    customTag = '';
    addTabOpen = false;
  }

  async function loadFeed() {
    loading = true;
    try {
      const params = new URLSearchParams($page.url.searchParams);
      const payload = await apiFetch(`/api/v1/feed?${params.toString()}`);
      items = payload.items || [];
    } finally {
      loading = false;
    }
  }

  onMount(() => {
    loadCustomTabs();
    loadFeed();
  });

  $: if ($page.url.search) {
    loadFeed();
  }
</script>

<section class="flex h-full min-h-0 flex-col bg-[#f6f7f8]">
  <div class="shrink-0 border-b border-slate-200 bg-white px-4 py-2.5">
    <div class="mb-2">
      <h1 class="text-xl font-semibold text-slate-900">Home</h1>
    </div>
    <div class="flex items-center justify-between gap-3">
      <nav class="flex items-center gap-5 overflow-x-auto whitespace-nowrap text-[15px] font-semibold text-slate-500 no-scrollbar">
        {#each tabs as tab}
          <a href={`/home?tab=${tab.key}`} class={`pb-2 transition ${activeTab === tab.key ? 'border-b-2 border-slate-900 text-slate-900' : 'text-slate-500 hover:text-slate-900'}`}>{tab.label}</a>
        {/each}
        {#each customTabs as tab}
          <a href={`/home?tag=${encodeURIComponent(tab.tag)}`} class={`pb-2 transition ${activeTag === tab.tag ? 'border-b-2 border-slate-900 text-slate-900' : 'text-slate-500 hover:text-slate-900'}`}>{tab.label}</a>
        {/each}
      </nav>
      <button type="button" class="inline-flex h-8 w-8 items-center justify-center rounded-lg text-slate-700 transition hover:bg-slate-100 hover:text-slate-900" on:click={() => (addTabOpen = true)}>+</button>
    </div>
    {#if localRegionNotice}
      <div class="mt-2">
        <span class="inline-flex rounded-full border border-sky-200 bg-sky-50 px-3 py-1 text-xs font-semibold text-sky-700">{localRegionNotice}</span>
      </div>
    {/if}
  </div>

  <div class="min-h-0 flex-1 overflow-y-auto no-scrollbar bg-white">
    {#if loading}
      <div class="flex h-full items-center justify-center px-6 text-center text-slate-500">Loading feed…</div>
    {:else if !items.length}
      <PageEmpty title="No posts yet." description="Feed results will appear here." />
    {:else}
      <ul class="divide-y divide-slate-200">
        {#each items as post}
          <li class="px-4 py-4">
            <PostCard {post} />
          </li>
        {/each}
      </ul>
    {/if}
  </div>
</section>

{#if addTabOpen}
  <div
    class="fixed inset-0 z-40 flex items-center justify-center bg-slate-900/40 px-4"
    role="button"
    tabindex="0"
    aria-label="Close add tab dialog"
    on:click={() => (addTabOpen = false)}
    on:keydown={(event) => {
      if (event.key === 'Escape' || event.key === 'Enter' || event.key === ' ') {
        addTabOpen = false;
      }
    }}
  >
    <div class="w-[min(90vw,32rem)] rounded-2xl bg-white p-6 shadow-xl" role="dialog" tabindex="-1" aria-modal="true" on:click|stopPropagation on:keydown|stopPropagation={() => {}}>
      <div class="flex items-center justify-between">
        <h2 class="text-lg font-semibold text-slate-900">Add tab</h2>
        <button type="button" class="rounded-xl border border-slate-200 px-3 py-1 text-xs font-semibold uppercase tracking-[0.2em] text-slate-600" on:click={() => (addTabOpen = false)}>Close</button>
      </div>
      <div class="mt-4 space-y-3">
        <div class="space-y-1">
          <label class="text-xs font-semibold uppercase tracking-[0.2em] text-slate-500" for="custom-tab-name">Tab name</label>
          <input id="custom-tab-name" bind:value={customName} maxlength="24" class="w-full rounded-xl border border-slate-200 bg-slate-50 px-3 py-2 text-sm text-slate-900" placeholder="e.g. Haskell" />
        </div>
        <div class="space-y-1">
          <label class="text-xs font-semibold uppercase tracking-[0.2em] text-slate-500" for="custom-tab-tag">Tag filter</label>
          <input id="custom-tab-tag" bind:value={customTag} maxlength="32" class="w-full rounded-xl border border-slate-200 bg-slate-50 px-3 py-2 text-sm text-slate-900" placeholder="e.g. haskell" />
        </div>
        <div class="flex justify-end gap-2">
          <button type="button" class="rounded-lg bg-slate-900 px-3 py-1.5 text-xs font-semibold uppercase tracking-[0.2em] text-white" on:click={addCustomTab}>Add</button>
          <button type="button" class="rounded-lg border border-slate-200 px-3 py-1.5 text-xs font-semibold uppercase tracking-[0.2em] text-slate-600" on:click={() => (addTabOpen = false)}>Cancel</button>
        </div>
      </div>
    </div>
  </div>
{/if}
