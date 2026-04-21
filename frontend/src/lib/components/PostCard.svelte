<script>
  import { bootstrap } from '$lib/stores/bootstrap';
  import { postFormJson, sendJson } from '$lib/utils/api';
  import { relativeTime } from '$lib/utils/time';

  export let post;
  export let showBoard = true;
  export let compact = false;

  const reactionEmojiOptions = ['👍', '👎', '🎉', '😀', '😮', '❤️', '🚀', '👏', '🤯', '💸', '💯', '😂', '😢', '🤮'];
  let reactionOpen = false;

  async function toggleAction(action) {
    try {
      const payload = await postFormJson(`/api/v1/posts/${post.id}/${action}`, {});
      if (action === 'like') {
        const liked = payload.state === 'liked' || !post.isLiked;
        post = {
          ...post,
          isLiked: liked,
          likeCount: payload.count ?? post.likeCount + (liked ? 1 : -1)
        };
      }

      if (action === 'bookmark') {
        post = {
          ...post,
          isBookmarked: payload.state === 'bookmarked' || !post.isBookmarked
        };
      }

      if (action === 'watch') {
        post = {
          ...post,
          isWatching: payload.state === 'watching' || !post.isWatching
        };
      }
    } catch (error) {
      window.alert(error.message);
    }
  }

  async function react(emoji) {
    try {
      const payload = await sendJson(`/api/v1/posts/${post.id}/react`, {
        body: { emoji }
      });
      post = {
        ...post,
        viewerReaction: payload.selected ?? null,
        reactions: payload.reactions || post.reactions
      };
      reactionOpen = false;
    } catch (error) {
      window.alert(error.message);
    }
  }

  async function simpleAction(action) {
    try {
      await postFormJson(`/api/v1/posts/${post.id}/${action}`, {});
      window.alert(action === 'flag' ? 'Post flagged.' : 'Post hidden.');
    } catch (error) {
      window.alert(error.message);
    }
  }

  async function blockAuthor() {
    if (!post.author?.id) return;
    try {
      await postFormJson(`/api/v1/users/${post.author.id}/block`, {});
      window.alert('User blocked.');
      window.location.reload();
    } catch (error) {
      window.alert(error.message);
    }
  }
</script>

<article class={compact ? 'rounded-2xl border border-slate-200 bg-slate-50/60 p-4' : ''}>
  <div class="flex items-start justify-between gap-3">
    <div class="flex min-w-0 flex-1 gap-3">
      <div class="mt-0.5 flex h-10 w-10 shrink-0 items-center justify-center rounded-full bg-slate-200 text-sm font-semibold text-slate-700">
        {(post.author?.name || post.author?.ident || 'U').slice(0, 1).toUpperCase()}
      </div>
      <div class="min-w-0 flex-1">
        <div class="flex flex-wrap items-center gap-x-2 gap-y-0.5 text-sm">
          <span class="font-semibold text-slate-900">{post.author?.name || post.author?.ident || 'Unknown'}</span>
          <span class="text-slate-500">@{(post.author?.ident || 'unknown').toLowerCase()}</span>
          <span class="text-slate-400">{relativeTime(post.createdAt)}</span>
        </div>
        {#if post.title}
          <a href={`/post/${post.id}`} class="mt-1 block text-lg font-semibold text-slate-900 hover:text-slate-700">{post.title}</a>
        {/if}
        <a href={`/post/${post.id}`} class="ql-editor forum-content-wrap mt-1 block break-words text-[17px] leading-7 text-slate-800 hover:text-slate-900">
          {@html post.content}
        </a>
        {#if post.tags?.length}
          <div class="mt-2 flex flex-wrap gap-1.5">
            {#each post.tags.slice(0, compact ? 99 : 3) as tag}
              <span class="rounded-full border border-slate-200 bg-slate-50 px-2 py-0.5 text-[11px] font-semibold text-slate-600">#{tag}</span>
            {/each}
          </div>
        {/if}
        {#if showBoard && post.board}
          <div class="mt-2 text-xs text-slate-500">{post.board.name}</div>
        {/if}
      </div>
    </div>

    <details class="relative">
      <summary class="cursor-pointer list-none rounded-lg px-2 py-1 text-slate-500 hover:bg-slate-100">...</summary>
      <div class="absolute right-0 z-20 mt-2 w-48 rounded-xl border border-slate-200 bg-white p-2 shadow-lg">
      <button
        type="button"
        class="flex w-full items-center gap-2 rounded-lg px-3 py-2 text-left text-sm text-slate-700 hover:bg-slate-50"
        on:click={async () => {
          try {
            await navigator.clipboard.writeText(window.location.origin + `/post/${post.id}`);
          } catch {
            window.alert('Failed to copy link.');
          }
        }}
      >
        <span>🔗</span>
        <span>Copy link</span>
      </button>
        {#if $bootstrap.auth?.isAuthenticated}
          <button type="button" class="flex w-full items-center gap-2 rounded-lg px-3 py-2 text-left text-sm text-slate-700 hover:bg-slate-50" on:click={() => toggleAction('watch')}>
            <span>{post.isWatching ? '👁' : '👁‍🗨'}</span>
            <span>{post.isWatching ? 'Watching' : 'Watch'}</span>
          </button>
          <button type="button" class="flex w-full items-center gap-2 rounded-lg px-3 py-2 text-left text-sm text-slate-700 hover:bg-slate-50" on:click={() => simpleAction('flag')}>
            <span>⚑</span>
            <span>Flag</span>
          </button>
          <button type="button" class="flex w-full items-center gap-2 rounded-lg px-3 py-2 text-left text-sm text-slate-700 hover:bg-slate-50" on:click={() => simpleAction('block')}>
            <span>✕</span>
            <span>Hide post</span>
          </button>
          {#if $bootstrap.site?.allowUserBlocking && post.author?.id && post.author?.id !== $bootstrap.viewer?.id}
            <button type="button" class="flex w-full items-center gap-2 rounded-lg px-3 py-2 text-left text-sm text-slate-700 hover:bg-slate-50" on:click={blockAuthor}>
              <span>⛔</span>
              <span>Block user</span>
            </button>
          {/if}
        {/if}
      </div>
    </details>
  </div>

  <div class="mt-3 flex items-center justify-between text-sm">
    <div class="flex items-center gap-4 text-slate-500">
      <a href={`/post/${post.id}`} class="inline-flex items-center gap-1.5 hover:text-slate-700">
        <span>💬</span>
        <span>{post.commentCount}</span>
      </a>
      {#if $bootstrap.auth?.isAuthenticated}
        <div class="relative">
          <button
            type="button"
            class="inline-flex items-center gap-1.5 rounded-md px-1 py-0.5 hover:bg-slate-100 hover:text-slate-800"
            on:click={() => (reactionOpen = !reactionOpen)}
          >
            <span>🙂</span>
          </button>
          {#if reactionOpen}
            <div class="absolute bottom-[calc(100%+10px)] left-0 z-20 min-w-[340px] rounded-full border border-slate-200 bg-white px-2 py-1.5 shadow-lg">
              <div class="flex flex-wrap items-center gap-1">
                {#each reactionEmojiOptions as emoji}
                  <button
                    type="button"
                    class={`inline-flex h-8 w-8 items-center justify-center rounded-full text-base transition hover:bg-slate-100 ${post.viewerReaction === emoji ? 'bg-slate-900 text-white hover:bg-slate-800' : ''}`}
                    on:click={() => react(emoji)}
                  >
                    {emoji}
                  </button>
                {/each}
              </div>
            </div>
          {/if}
        </div>
      {/if}
      {#if post.reactions?.length}
        <div class="flex items-center gap-1.5">
          {#each post.reactions as reaction}
            <span class="inline-flex items-center gap-1 rounded-full border border-slate-200 px-2 py-0.5 text-sm text-slate-700">
              <span>{reaction.emoji}</span>
              <span>{reaction.count}</span>
            </span>
          {/each}
        </div>
      {/if}
    </div>

    <div class="flex items-center gap-2">
      {#if $bootstrap.auth?.isAuthenticated}
        <button type="button" class="rounded-lg border border-slate-200 px-2.5 py-1 text-xs font-semibold uppercase tracking-[0.2em] text-slate-700 hover:border-slate-900 hover:text-slate-900" on:click={() => toggleAction('like')}>
          <span>{post.isLiked ? '♥' : '♡'}</span>
          <span class="ml-1">{post.likeCount}</span>
        </button>
        <button type="button" class="inline-flex h-7 w-7 items-center justify-center rounded-md text-slate-500 transition hover:bg-slate-100 hover:text-slate-800" aria-label="Bookmark" on:click={() => toggleAction('bookmark')}>
          <svg viewBox="0 0 24 24" class="h-4 w-4" fill={post.isBookmarked ? 'currentColor' : 'none'} stroke="currentColor" stroke-width="2">
            <path d="M7 4h10a1 1 0 0 1 1 1v15l-6-3-6 3V5a1 1 0 0 1 1-1z"></path>
          </svg>
        </button>
      {/if}
    </div>
  </div>
</article>
