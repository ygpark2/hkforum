<script>
  import { goto } from '$app/navigation';
  import { bootstrap } from '$lib/stores/bootstrap';
  import { sendJson } from '$lib/utils/api';
  import RichEditor from '$lib/components/RichEditor.svelte';

  export let open = false;
  export let onClose = () => {};

  let boardId = '';
  let title = '';
  let tags = '';
  let content = '';
  let submitting = false;

  $: if ($bootstrap.boards?.length && !boardId) {
    boardId = String($bootstrap.boards[0].id);
  }

  async function submitPost() {
    if (submitting) return;
    submitting = true;

    try {
      const payload = await sendJson(`/api/v1/boards/${boardId}/posts`, {
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
      onClose();
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

{#if open}
  <div
    class="fixed inset-0 z-40 flex items-center justify-center bg-slate-900/40 px-4"
    role="button"
    tabindex="0"
    aria-label="Close new post dialog"
    on:click={onClose}
    on:keydown={(event) => {
      if (event.key === 'Escape' || event.key === 'Enter' || event.key === ' ') {
        onClose();
      }
    }}
  >
    <div class="w-[min(90vw,42rem)] rounded-2xl bg-white p-6 shadow-xl" role="dialog" tabindex="-1" aria-modal="true" on:click|stopPropagation on:keydown|stopPropagation={() => {}}>
      <div class="flex items-center justify-between">
        <h2 class="text-lg font-semibold text-slate-900">New post</h2>
        <button
          type="button"
          class="rounded-xl border border-slate-200 px-3 py-1 text-xs font-semibold uppercase tracking-[0.2em] text-slate-600"
          on:click={onClose}
        >
          Close
        </button>
      </div>

      <form class="mt-4 space-y-4" on:submit|preventDefault={submitPost}>
        <div class="space-y-1">
          <label class="text-sm font-semibold text-slate-700" for="global-board">Board</label>
          <select
            id="global-board"
            bind:value={boardId}
            class="w-full rounded-xl border border-slate-200 bg-slate-50 px-3 py-2 text-sm text-slate-900"
          >
            {#each $bootstrap.boards as board}
              <option value={String(board.id)}>{board.name}</option>
            {/each}
          </select>
        </div>

        <div class="space-y-1">
          <label class="text-sm font-semibold text-slate-700" for="global-title">Title</label>
          <input
            id="global-title"
            name="title"
            bind:value={title}
            class="w-full rounded-xl border border-slate-200 bg-slate-50 px-3 py-2 text-slate-900"
            placeholder="Optional"
          />
        </div>

        <div class="space-y-1">
          <div class="text-sm font-semibold text-slate-700">Content</div>
          <RichEditor bind:value={content} name="content" placeholder="Share your thoughts" />
        </div>

        <div class="space-y-1">
          <label class="text-sm font-semibold text-slate-700" for="global-tags">Tags</label>
          <input
            id="global-tags"
            name="tags"
            bind:value={tags}
            class="w-full rounded-xl border border-slate-200 bg-white px-3 py-2 text-sm text-slate-900"
            placeholder="tag1, tag2"
          />
        </div>

        <div class="flex justify-end gap-2">
          <button type="submit" class="rounded-xl bg-slate-900 px-4 py-2 text-xs font-semibold uppercase tracking-[0.2em] text-white" disabled={submitting}>
            {submitting ? 'Posting…' : 'Post'}
          </button>
          <button type="button" class="rounded-xl border border-slate-200 px-4 py-2 text-xs font-semibold uppercase tracking-[0.2em] text-slate-600" on:click={onClose}>
            Cancel
          </button>
        </div>
      </form>
    </div>
  </div>
{/if}
