<script>
  import { onMount } from 'svelte';
  import { bootstrap } from '$lib/stores/bootstrap';
  import { apiFetch } from '$lib/utils/api';
  import { relativeTime } from '$lib/utils/time';

  let loading = true;
  let items = [];

  async function loadData() {
    loading = true;
    try {
      const payload = await apiFetch('/api/v1/notifications');
      items = payload.items || [];
    } catch (error) {
      window.alert(error.message);
    } finally {
      loading = false;
    }
  }

  async function markAllRead() {
    try {
      await apiFetch('/api/v1/notifications/read-all', { method: 'POST' });
      items = items.map((item) => ({ ...item, isRead: true }));
      bootstrap.update((state) => ({ ...state, unreadNotificationCount: 0 }));
    } catch (error) {
      window.alert(error.message);
    }
  }

  onMount(loadData);

  function notificationHref(item) {
    if (item.jobId) return `/jobs/${item.jobId}`;
    if (item.postId) return `/post/${item.postId}`;
    return '/home';
  }
</script>

<section class="min-h-full bg-slate-50">
  <div class="border-b border-slate-200 bg-white px-5 py-4">
    <div class="flex items-center justify-between gap-3">
      <div>
        <h1 class="text-2xl font-semibold text-slate-900">Notifications</h1>
        <p class="mt-1 text-sm text-slate-500">Recent alerts from follows, comments, and reactions.</p>
      </div>
      <button type="button" class="rounded-xl border border-slate-200 px-4 py-2 text-sm font-semibold text-slate-700" on:click={markAllRead}>Mark all read</button>
    </div>
  </div>

  <div class="px-5 py-5">
    {#if loading}
      <div class="text-sm text-slate-500">Loading notifications…</div>
    {:else if !items.length}
      <div class="rounded-2xl border border-slate-200 bg-white px-6 py-8 text-sm text-slate-500">No notifications yet.</div>
    {:else}
      <div class="space-y-3">
        {#each items as item}
          <a href={notificationHref(item)} class={`block rounded-2xl border px-5 py-4 transition ${item.isRead ? 'border-slate-200 bg-white' : 'border-slate-900 bg-slate-900 text-white'}`}>
            <div class="text-sm font-semibold">{item.message}</div>
            <div class={`mt-2 text-sm ${item.isRead ? 'text-slate-500' : 'text-slate-300'}`}>{relativeTime(item.createdAt)}</div>
          </a>
        {/each}
      </div>
    {/if}
  </div>
</section>
