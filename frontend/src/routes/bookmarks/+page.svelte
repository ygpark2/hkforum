<script>
  import { onMount } from 'svelte';
  import PageEmpty from '$lib/components/PageEmpty.svelte';
  import PostCard from '$lib/components/PostCard.svelte';
  import { apiFetch } from '$lib/utils/api';

  let loading = true;
  let items = [];

  onMount(async () => {
    try {
      const payload = await apiFetch('/api/v1/me/bookmarks');
      items = payload.items || [];
    } catch (error) {
      window.alert(error.message);
    } finally {
      loading = false;
    }
  });
</script>

<section class="flex min-h-full flex-col bg-white">
  <div class="border-b border-slate-200 px-5 py-4">
    <h1 class="text-2xl font-semibold text-slate-900">Bookmarks</h1>
    <p class="mt-1 text-sm text-slate-500">Saved posts from your account.</p>
  </div>

  <div class="flex-1 overflow-y-auto">
    {#if loading}
      <div class="px-5 py-6 text-sm text-slate-500">Loading bookmarks…</div>
    {:else if !items.length}
      <PageEmpty title="No bookmarks yet." description="Saved posts will appear here." />
    {:else}
      <ul class="divide-y divide-slate-200">
        {#each items as post}
          <li class="px-5 py-4">
            <PostCard {post} />
          </li>
        {/each}
      </ul>
    {/if}
  </div>
</section>
