<script>
  import { onDestroy, onMount } from 'svelte';
  import { page } from '$app/stores';
  import { bootstrap } from '$lib/stores/bootstrap';
  import { apiFetch } from '$lib/utils/api';
  import { relativeTime } from '$lib/utils/time';

  let loading = false;
  let rooms = [];
  let messages = [];
  let search = '';
  let users = [];
  let messageContent = '';
  let searchTimer;
  let pollTimer;
  let activeRoomKey = null;

  $: parts = $page.url.pathname.split('/').filter(Boolean);
  $: mode = parts[1] || 'index';
  $: roomId = parts[1] === 'room' ? parts[2] : null;

  async function loadRooms() {
    if (!$bootstrap.auth?.isAuthenticated) return;
    const payload = await apiFetch('/api/v1/chats');
    rooms = payload.items || [];
  }

  async function loadMessages() {
    if (!roomId || !$bootstrap.auth?.isAuthenticated) return;
    loading = true;
    try {
      const payload = await apiFetch(`/api/v1/chats/${roomId}/messages`);
      messages = payload.items || [];
    } catch (error) {
      window.alert(error.message);
    } finally {
      loading = false;
    }
  }

  async function searchUsers() {
    if (!$bootstrap.auth?.isAuthenticated) return;
    if (!search.trim()) {
      users = [];
      return;
    }

    try {
      const payload = await apiFetch(`/api/v1/users?q=${encodeURIComponent(search.trim())}`);
      users = payload.items || [];
    } catch (error) {
      window.alert(error.message);
    }
  }

  async function createRoom(userId) {
    try {
      const payload = await apiFetch('/api/v1/chats', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ peerId: userId })
      });
      window.location.href = `/chats/room/${payload.room.id}`;
    } catch (error) {
      window.alert(error.message);
    }
  }

  async function sendMessage() {
    if (!roomId || !messageContent.trim()) return;
    try {
      const payload = await apiFetch(`/api/v1/chats/${roomId}/messages`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ content: messageContent.trim() })
      });
      messages = [...messages, payload.message];
      messageContent = '';
      await loadRooms();
    } catch (error) {
      window.alert(error.message);
    }
  }

  onMount(async () => {
    try {
      await loadRooms();
      await loadMessages();
      pollTimer = setInterval(() => {
        if (!$bootstrap.auth?.isAuthenticated) return;
        loadRooms();
        if (roomId) {
          loadMessages();
        }
      }, 5000);
    } catch (error) {
      window.alert(error.message);
    }
  });

  onDestroy(() => {
    clearTimeout(searchTimer);
    clearInterval(pollTimer);
  });

  $: if (mode === 'new' && search !== undefined) {
    clearTimeout(searchTimer);
    searchTimer = setTimeout(() => {
      searchUsers();
    }, 200);
  }

  $: if (roomId && $bootstrap.ready && roomId !== activeRoomKey) {
    activeRoomKey = roomId;
    loadMessages();
  }

  $: if (!roomId) {
    activeRoomKey = null;
  }

  $: activeRoom = roomId ? rooms.find((room) => String(room.id) === String(roomId)) : null;
</script>

<section class="flex min-h-full flex-col bg-slate-50">
  <div class="border-b border-slate-200 bg-white px-5 py-4">
    <div class="flex items-center justify-between gap-3">
      <div>
        <h1 class="text-2xl font-semibold text-slate-900">Chats</h1>
        <p class="mt-1 text-sm text-slate-500">Direct messages are fully rendered from SvelteKit now.</p>
      </div>
      {#if $bootstrap.auth?.isAuthenticated}
        <a href="/chats/new" class="rounded-xl bg-slate-900 px-4 py-2 text-sm font-semibold text-white">New Chat</a>
      {/if}
    </div>
  </div>

  {#if !$bootstrap.auth?.isAuthenticated}
    <div class="px-5 py-6 text-sm text-slate-600">Login is required to view chats.</div>
  {:else}
    <div class="grid flex-1 gap-5 px-5 py-5 lg:grid-cols-[320px_minmax(0,1fr)]">
      <aside class="space-y-3">
        <a href="/chats" class={`block rounded-xl px-4 py-3 text-sm font-medium ${mode === 'index' ? 'bg-slate-900 text-white' : 'bg-white text-slate-700'}`}>Inbox</a>
        {#each rooms as room}
          <a href={`/chats/room/${room.id}`} class={`block rounded-xl border px-4 py-3 transition ${String(room.id) === String(roomId) ? 'border-slate-900 bg-white' : 'border-slate-200 bg-white hover:border-slate-300'}`}>
            <div class="text-sm font-semibold text-slate-900">{room.peer?.name || room.peer?.ident}</div>
            <div class="mt-1 truncate text-sm text-slate-500">{room.preview}</div>
            <div class="mt-2 text-xs text-slate-400">{relativeTime(room.updatedAt)}</div>
          </a>
        {/each}
      </aside>

      <div class="min-h-[32rem] rounded-2xl border border-slate-200 bg-white">
        {#if mode === 'new'}
          <div class="p-5">
            <label class="text-xs font-semibold uppercase tracking-[0.18em] text-slate-500" for="chat-search">Search users</label>
            <input id="chat-search" bind:value={search} class="mt-2 w-full rounded-xl border border-slate-200 bg-slate-50 px-4 py-3 text-sm text-slate-900" placeholder="Search by handle or name" />
            <div class="mt-4 space-y-3">
              {#each users as user}
                <button type="button" class="flex w-full items-center justify-between rounded-xl border border-slate-200 px-4 py-3 text-left transition hover:border-slate-300" on:click={() => createRoom(user.id)}>
                  <div>
                    <div class="text-sm font-semibold text-slate-900">{user.name || user.ident}</div>
                    <div class="text-sm text-slate-500">@{user.ident}</div>
                  </div>
                  <span class="text-xs font-semibold uppercase tracking-[0.18em] text-slate-500">Start</span>
                </button>
              {/each}
            </div>
          </div>
        {:else if mode === 'room' && roomId}
          <div class="flex h-full flex-col">
            <div class="border-b border-slate-200 px-5 py-4">
              <div class="text-lg font-semibold text-slate-900">{activeRoom?.peer?.name || activeRoom?.peer?.ident || 'Chat room'}</div>
              <div class="mt-1 text-sm text-slate-500">@{activeRoom?.peer?.ident || 'unknown'}</div>
            </div>
            <div class="flex-1 space-y-3 overflow-y-auto px-5 py-5">
              {#if loading}
                <div class="text-sm text-slate-500">Loading messages…</div>
              {:else if !messages.length}
                <div class="text-sm text-slate-500">No messages yet.</div>
              {:else}
                {#each messages as message}
                  <div class={`max-w-[80%] rounded-2xl px-4 py-3 ${message.author?.id === $bootstrap.viewer?.id ? 'ml-auto bg-slate-900 text-white' : 'bg-slate-100 text-slate-900'}`}>
                    <div class="text-xs uppercase tracking-[0.18em] opacity-70">{message.author?.ident || 'unknown'}</div>
                    <div class="mt-2 whitespace-pre-wrap text-sm">{message.content}</div>
                    <div class="mt-2 text-xs opacity-70">{relativeTime(message.createdAt)}</div>
                  </div>
                {/each}
              {/if}
            </div>
            <div class="border-t border-slate-200 p-4">
              <div class="flex gap-3">
                <textarea bind:value={messageContent} class="min-h-[96px] flex-1 rounded-xl border border-slate-200 bg-slate-50 px-4 py-3 text-sm text-slate-900" placeholder="Write a message"></textarea>
                <button type="button" class="rounded-xl bg-slate-900 px-4 py-3 text-sm font-semibold text-white" on:click={sendMessage}>Send</button>
              </div>
            </div>
          </div>
        {:else}
          <div class="flex h-full items-center justify-center px-6 text-center text-sm text-slate-500">Choose a room or start a new chat.</div>
        {/if}
      </div>
    </div>
  {/if}
</section>
