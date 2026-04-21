<script>
  import { goto } from '$app/navigation';
  import { onMount } from 'svelte';
  import { page } from '$app/stores';
  import PageEmpty from '$lib/components/PageEmpty.svelte';
  import PostCard from '$lib/components/PostCard.svelte';
  import RichEditor from '$lib/components/RichEditor.svelte';
  import { bootstrap } from '$lib/stores/bootstrap';
  import { apiFetch, sendJson } from '$lib/utils/api';

  let board;
  let items = [];
  let loading = true;
  let open = false;
  let title = '';
  let tags = '';
  let content = '';
  let submitting = false;

  async function loadBoard() {
    loading = true;
    try {
      const boardId = $page.params.id;
      board = ($bootstrap.boards || []).find((item) => String(item.id) === String(boardId));
      const payload = await apiFetch(`/api/v1/boards/${boardId}/posts`);
      items = payload.items || [];
    } finally {
      loading = false;
    }
  }

  onMount(loadBoard);
  $: if ($page.params.id) loadBoard();
  $: localRegionNotice =
    $bootstrap.viewer?.localRegionOnly && $bootstrap.viewer?.countryCode && $bootstrap.viewer?.state
      ? `내 지역 필터 적용 중: ${$bootstrap.viewer.state}, ${$bootstrap.viewer.countryCode}`
      : $bootstrap.viewer?.localRegionOnly
        ? '프로필에 국가와 주를 저장해야 내 지역 필터를 사용할 수 있습니다.'
        : null;

  async function submitPost() {
    if (submitting) return;
    submitting = true;

    try {
      const payload = await sendJson(`/api/v1/boards/${$page.params.id}/posts`, {
        body: {
          title,
          content,
          tags: tags || null
        }
      });
      const postId = payload?.data?.post?.id;
      title = '';
      tags = '';
      content = '';
      open = false;
      await loadBoard();
      if (postId) {
        await goto(`/post/${postId}`);
      }
    } catch (error) {
      window.alert(error.message);
    } finally {
      submitting = false;
    }
  }
</script>

<section class="bg-white border border-slate-200 shadow-sm rounded-2xl p-6 space-y-6">
  <header class="flex items-start justify-between gap-4">
    <div class="space-y-2">
      <p class="text-xs uppercase tracking-[0.3em] text-slate-400">Board</p>
      <h1 class="text-2xl font-bold text-slate-900">{board?.name || 'Board'}</h1>
      {#if board?.description}
        <p class="text-sm text-slate-500">{board.description}</p>
      {/if}
      {#if localRegionNotice}
        <p class="inline-flex rounded-full border border-sky-200 bg-sky-50 px-3 py-1 text-xs font-semibold text-sky-700">{localRegionNotice}</p>
      {/if}
    </div>
    {#if $bootstrap.auth?.isAuthenticated}
      <button type="button" class="rounded-lg bg-slate-900 px-3 py-1.5 text-xs font-semibold uppercase tracking-[0.2em] text-white" on:click={() => (open = true)}>New post</button>
    {:else}
      <a href="/login" class="rounded-lg border border-slate-900 px-3 py-1.5 text-xs font-semibold uppercase tracking-[0.2em] text-slate-900">Login to post</a>
    {/if}
  </header>

  <div class="space-y-4">
    <div class="flex items-center justify-between">
      <h2 class="text-lg font-semibold text-slate-900">Posts</h2>
      <span class="text-xs uppercase tracking-[0.3em] text-slate-400">{items.length} total</span>
    </div>
    {#if loading}
      <div class="text-sm text-slate-500">Loading posts…</div>
    {:else if !items.length}
      <PageEmpty title="No posts yet." />
    {:else}
      <div class="space-y-3">
        {#each items as post}
          <PostCard post={post} showBoard={false} compact />
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
    aria-label="Close new post dialog"
    on:click={() => (open = false)}
    on:keydown={(event) => {
      if (event.key === 'Escape' || event.key === 'Enter' || event.key === ' ') {
        open = false;
      }
    }}
  >
    <div class="w-[min(90vw,42rem)] rounded-2xl bg-white p-6 shadow-xl" role="dialog" tabindex="-1" aria-modal="true" on:click|stopPropagation on:keydown|stopPropagation={() => {}}>
      <div class="flex items-center justify-between">
        <h2 class="text-lg font-semibold text-slate-900">New post</h2>
        <button type="button" class="rounded-xl border border-slate-200 px-3 py-1 text-xs font-semibold uppercase tracking-[0.2em] text-slate-600" on:click={() => (open = false)}>Close</button>
      </div>
      <form class="mt-4 space-y-4" on:submit|preventDefault={submitPost}>
        <div class="space-y-1">
          <label class="text-sm font-semibold text-slate-700" for="board-post-title">Title</label>
          <input id="board-post-title" name="title" bind:value={title} required class="w-full rounded-xl border border-slate-200 bg-slate-50 px-3 py-2 text-slate-900" placeholder="Post title" />
        </div>
        <div class="space-y-1">
          <div class="text-sm font-semibold text-slate-700">Content</div>
          <RichEditor bind:value={content} name="content" placeholder="Share your thoughts" />
        </div>
        <div class="space-y-1">
          <label class="text-sm font-semibold text-slate-700" for="board-post-tags">Tags</label>
          <input id="board-post-tags" name="tags" bind:value={tags} class="w-full rounded-xl border border-slate-200 bg-white px-3 py-2 text-sm text-slate-900" placeholder="tag1, tag2" />
        </div>
        <div class="flex justify-end gap-2">
          <button type="submit" class="rounded-xl bg-slate-900 px-4 py-2 text-xs font-semibold uppercase tracking-[0.2em] text-white" disabled={submitting}>
            {submitting ? 'Posting…' : 'Post'}
          </button>
          <button type="button" class="rounded-xl border border-slate-200 px-4 py-2 text-xs font-semibold uppercase tracking-[0.2em] text-slate-600" on:click={() => (open = false)}>Cancel</button>
        </div>
      </form>
    </div>
  </div>
{/if}
