<script>
  import { goto } from '$app/navigation';
  import { bootstrap } from '$lib/stores/bootstrap';
  import { sendJson } from '$lib/utils/api';
  import RichEditor from '$lib/components/RichEditor.svelte';
  import LeafletMap from '$lib/components/LeafletMap.svelte';

  export let open = false;
  export let onClose = () => {};

  let boardId = '';
  let title = '';
  let tags = '';
  let content = '';
  let latitude = null;
  let longitude = null;
  let locationOpen = false;
  let submitting = false;

  $: if ($bootstrap.boards?.length && !boardId) {
    boardId = String($bootstrap.boards[0].id);
  }

  function normalizeTags(rawTags) {
    const items = (rawTags || '')
      .split(',')
      .map((item) => item.trim())
      .filter(Boolean);
    return items.length ? items : null;
  }

  function closeModal() {
    locationOpen = false;
    onClose();
  }

  async function submitPost() {
    if (submitting) return;
    submitting = true;

    try {
      const payload = await sendJson(`/api/v1/boards/${boardId}/posts`, {
        body: {
          title,
          content,
          tags: normalizeTags(tags),
          latitude,
          longitude
        }
      });
      const postId = payload?.data?.post?.id;
      title = '';
      tags = '';
      content = '';
      latitude = null;
      longitude = null;
      locationOpen = false;
      closeModal();
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
    class="fixed inset-0 z-[1000] flex items-start justify-center overflow-y-auto bg-slate-900/40 px-4 py-6 sm:items-center"
    role="button"
    tabindex="0"
    aria-label="Close new post dialog"
    on:click={closeModal}
    on:keydown={(event) => {
      if (event.key === 'Escape' || event.key === 'Enter' || event.key === ' ') {
        closeModal();
      }
    }}
  >
    <div class="max-h-[calc(100vh-3rem)] w-[min(90vw,42rem)] overflow-y-auto rounded-2xl bg-white p-6 shadow-xl" role="dialog" tabindex="-1" aria-modal="true" on:click|stopPropagation on:keydown|stopPropagation={() => {}}>
      <div class="flex items-center justify-between">
        <h2 class="text-lg font-semibold text-slate-900">New post</h2>
        <button
          type="button"
          class="rounded-xl border border-slate-200 px-3 py-1 text-xs font-semibold uppercase tracking-[0.2em] text-slate-600"
          on:click={closeModal}
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

        <div class="rounded-2xl border border-slate-200 bg-slate-50">
          <button type="button" class="flex w-full items-center justify-between gap-3 px-4 py-3 text-left" on:click={() => (locationOpen = !locationOpen)}>
            <div>
              <div class="text-sm font-semibold text-slate-700">Location</div>
              <div class="mt-1 text-xs text-slate-500">
                {#if latitude != null && longitude != null}
                  {latitude}, {longitude}
                {:else}
                  No location selected
                {/if}
              </div>
            </div>
            <span class="flex h-7 w-7 shrink-0 items-center justify-center rounded-full bg-white text-slate-600">
              {#if locationOpen}
                <svg viewBox="0 0 20 20" fill="none" class="h-4 w-4" aria-hidden="true">
                  <path d="M5 7.5L10 12.5L15 7.5" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round" />
                </svg>
              {:else}
                <svg viewBox="0 0 20 20" fill="none" class="h-4 w-4" aria-hidden="true">
                  <path d="M5 12.5L10 7.5L15 12.5" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round" />
                </svg>
              {/if}
            </span>
          </button>

          {#if locationOpen}
            <div class="border-t border-slate-200 px-4 py-4 space-y-2">
              <div class="flex items-center justify-end gap-3">
                {#if latitude != null && longitude != null}
                  <button type="button" class="text-xs font-semibold uppercase tracking-[0.18em] text-slate-500 hover:text-slate-900" on:click={() => { latitude = null; longitude = null; }}>
                    Clear
                  </button>
                {/if}
              </div>
              <LeafletMap bind:latitude bind:longitude interactive heightClass="h-56" />
              <div class="grid gap-3 sm:grid-cols-2">
                <div>
                  <label class="text-xs font-semibold uppercase tracking-[0.18em] text-slate-500" for="global-latitude">Latitude</label>
                  <input id="global-latitude" bind:value={latitude} class="mt-1 w-full rounded-xl border border-slate-200 bg-white px-3 py-2 text-sm text-slate-900" readonly />
                </div>
                <div>
                  <label class="text-xs font-semibold uppercase tracking-[0.18em] text-slate-500" for="global-longitude">Longitude</label>
                  <input id="global-longitude" bind:value={longitude} class="mt-1 w-full rounded-xl border border-slate-200 bg-white px-3 py-2 text-sm text-slate-900" readonly />
                </div>
              </div>
              <div class="text-xs text-slate-500">지도를 클릭하면 게시글 위치를 선택할 수 있습니다.</div>
            </div>
          {/if}
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
          <button type="button" class="rounded-xl border border-slate-200 px-4 py-2 text-xs font-semibold uppercase tracking-[0.2em] text-slate-600" on:click={closeModal}>
            Cancel
          </button>
        </div>
      </form>
    </div>
  </div>
{/if}
