<script>
  import { goto } from '$app/navigation';
  import { onMount, tick } from 'svelte';
  import { page } from '$app/stores';
  import PageEmpty from '$lib/components/PageEmpty.svelte';
  import { bootstrap } from '$lib/stores/bootstrap';
  import { apiFetch, refreshBootstrap, sendJson } from '$lib/utils/api';
  import { relativeTime } from '$lib/utils/time';

  let payload = null;
  let loading = true;
  let replyTarget = null;
  let commentContent = '';
  let commentSubmitting = false;
  let deleting = false;
  let commentInput;

  function orderedComments(comments) {
    const children = new Map();
    const byId = new Map();

    for (const comment of comments) {
      byId.set(comment.id, comment);
      const key = comment.parentCommentId || 0;
      const list = children.get(key) || [];
      list.push(comment);
      children.set(key, list);
    }

    const result = [];

    function walk(parentId = 0, depth = 0) {
      for (const comment of children.get(parentId) || []) {
        result.push({ ...comment, depth, parent: comment.parentCommentId ? byId.get(comment.parentCommentId) : null });
        walk(comment.id, depth + 1);
      }
    }

    walk();
    return result;
  }

  async function loadPost() {
    loading = true;
    try {
      payload = await apiFetch(`/api/v1/posts/${$page.params.id}`);
    } finally {
      loading = false;
    }
  }

  onMount(loadPost);
  $: if ($page.params.id) loadPost();
  $: comments = orderedComments(payload?.data?.comments || []);
  $: post = payload?.data?.post;
  $: replyTargetComment = comments.find((comment) => comment.id === replyTarget) || null;

  function replyPreview(content, limit = 96) {
    const normalized = (content || '').replace(/\s+/g, ' ').trim();
    if (!normalized) return '';
    return normalized.length > limit ? `${normalized.slice(0, limit)}...` : normalized;
  }

  async function beginReply(comment) {
    replyTarget = comment.id;
    await tick();
    commentInput?.focus();
    commentInput?.scrollIntoView({ behavior: 'smooth', block: 'center' });
  }

  async function deletePost() {
    if (deleting) return;
    if (!window.confirm('Delete this post?')) return;
    deleting = true;

    try {
      await apiFetch(`/api/v1/posts/${post.id}`, { method: 'DELETE' });
      await refreshBootstrap();
      await goto(`/board/${post.board?.id || ''}`);
    } catch (error) {
      window.alert(error.message);
    } finally {
      deleting = false;
    }
  }

  async function submitComment() {
    if (commentSubmitting) return;
    commentSubmitting = true;

    try {
      const response = await sendJson(`/api/v1/posts/${post.id}/comments`, {
        body: {
          content: commentContent,
          parentCommentId: replyTarget || null
        }
      });
      payload = {
        ...payload,
        data: {
          ...payload.data,
          comments: [...(payload.data?.comments || []), response.comment]
        }
      };
      await refreshBootstrap();
      commentContent = '';
      replyTarget = null;
    } catch (error) {
      window.alert(error.message);
    } finally {
      commentSubmitting = false;
    }
  }
</script>

<section class="bg-white border border-slate-200 shadow-sm rounded-2xl p-6 space-y-6">
  {#if loading}
    <div class="text-sm text-slate-500">Loading post…</div>
  {:else if !post}
    <PageEmpty title="Post not found." />
  {:else}
    <header class="space-y-2">
      <p class="text-xs uppercase tracking-[0.3em] text-slate-400">Post</p>
      <h1 class="text-2xl font-bold text-slate-900">{post.title}</h1>
      <p class="text-sm text-slate-500">
        In <a href={`/board/${post.board?.id}`} class="font-semibold text-slate-700 hover:text-slate-900">{post.board?.name}</a>
        · By @{post.author?.ident}
        · {relativeTime(post.createdAt)}
      </p>
      <p class="text-xs text-slate-500">{post.likeCount} likes · {post.viewCount} views</p>
      {#if post.tags?.length}
        <div class="flex flex-wrap gap-1.5">
          {#each post.tags as tag}
            <span class="rounded-full border border-slate-200 bg-slate-50 px-2 py-0.5 text-[11px] font-semibold text-slate-600">#{tag}</span>
          {/each}
        </div>
      {/if}
    </header>

    <div class="ql-editor forum-content-wrap rounded-2xl border border-slate-200 bg-slate-50/60 p-4 text-sm text-slate-700">
      {@html post.content}
    </div>

    {#if $bootstrap.viewer && ($bootstrap.viewer.id === post.author?.id || $bootstrap.viewer.role === 'admin')}
      <div class="flex items-center gap-2">
        <button type="button" class="rounded-lg border border-rose-200 px-3 py-1 text-xs font-semibold uppercase tracking-[0.2em] text-rose-700" on:click={deletePost} disabled={deleting}>
          {deleting ? 'Deleting…' : 'Delete post'}
        </button>
      </div>
    {/if}

    <section class="space-y-3">
      <div class="flex items-center justify-between">
        <h2 class="text-lg font-semibold text-slate-900">Comments</h2>
        <span class="text-xs uppercase tracking-[0.3em] text-slate-400">{comments.length}</span>
      </div>

      {#if !comments.length}
        <p class="text-sm text-slate-500">No comments yet.</p>
      {:else}
        <div class="space-y-2">
          {#each comments as comment}
            <div class="relative" style={`margin-left:${Math.min(comment.depth, 8) * 18}px;`}>
              <article class={`rounded-xl border p-3 text-sm text-slate-700 ${comment.depth === 0 ? 'border-slate-200 bg-slate-50/70' : comment.depth === 1 ? 'border-slate-300 bg-white' : 'border-slate-300 bg-slate-100/60'} ${replyTarget === comment.id ? 'ring-2 ring-slate-900/15' : ''}`}>
                {#if comment.parent}
                  <p class="mb-1 text-xs text-slate-500">↳ reply to @{comment.parent.author?.ident}</p>
                {/if}
                <div class="forum-content-wrap whitespace-pre-wrap">{comment.content}</div>
                <div class="mt-2 flex items-center gap-2 text-xs text-slate-500">
                  <span>@{comment.author?.ident}</span>
                  <span>· {relativeTime(comment.createdAt)}</span>
                  {#if $bootstrap.auth?.isAuthenticated}
                    <button type="button" class="rounded-lg border border-slate-200 px-2 py-1 font-semibold uppercase tracking-[0.2em] text-slate-600 hover:border-slate-900 hover:text-slate-900" on:click={() => beginReply(comment)}>
                      Reply
                    </button>
                  {/if}
                </div>
              </article>
            </div>
          {/each}
        </div>
      {/if}
    </section>

    <section>
      {#if $bootstrap.auth?.isAuthenticated}
        <form class="space-y-3" on:submit|preventDefault={submitComment}>
          {#if replyTargetComment}
            <div class="rounded-xl border border-slate-300 bg-slate-50 px-4 py-3 text-sm text-slate-700">
              <div class="font-semibold text-slate-900">Replying to @{replyTargetComment.author?.ident}</div>
              {#if replyPreview(replyTargetComment.content)}
                <div class="mt-1 text-xs text-slate-500">{replyPreview(replyTargetComment.content)}</div>
              {/if}
            </div>
          {/if}
          <textarea bind:this={commentInput} bind:value={commentContent} required rows="5" class="w-full rounded-xl border border-slate-200 bg-slate-50 px-3 py-2 text-sm text-slate-900" placeholder={replyTarget ? 'Write a reply…' : 'Add a comment…'}></textarea>
          <div class="flex justify-end gap-2">
            {#if replyTarget}
              <button type="button" class="rounded-xl border border-slate-200 px-4 py-2 text-xs font-semibold uppercase tracking-[0.2em] text-slate-600" on:click={() => (replyTarget = null)}>Cancel reply</button>
            {/if}
            <button type="submit" class="rounded-xl bg-slate-900 px-4 py-2 text-xs font-semibold uppercase tracking-[0.2em] text-white" disabled={commentSubmitting}>
              {commentSubmitting ? 'Saving…' : replyTarget ? 'Reply' : 'Add comment'}
            </button>
          </div>
        </form>
      {:else}
        <a href="/login" class="inline-flex rounded-lg border border-slate-900 px-3 py-1.5 text-xs font-semibold uppercase tracking-[0.2em] text-slate-900 transition hover:bg-slate-900 hover:text-white">Login to comment</a>
      {/if}
    </section>
  {/if}
</section>
