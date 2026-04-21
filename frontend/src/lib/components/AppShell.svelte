<script>
  import { goto } from '$app/navigation';
  import { page } from '$app/stores';
  import { bootstrap } from '$lib/stores/bootstrap';
  import { apiFetch, postFormJson } from '$lib/utils/api';
  import GlobalPostModal from '$lib/components/GlobalPostModal.svelte';

  export let loading = false;

  let globalPostOpen = false;
  let logoutLoading = false;

  $: pathname = $page.url.pathname;
  $: isAuthPage = pathname === '/login' || pathname === '/register';
  $: isAdminPage = pathname === '/admin' || pathname.startsWith('/admin/');

  const adminLinks = [
    { href: '/admin', label: 'Overview' },
    { href: '/admin/boards', label: 'Boards' },
    { href: '/admin/companies', label: 'Companies' },
    { href: '/admin/company-categories', label: 'Categories' },
    { href: '/admin/users', label: 'Users' },
    { href: '/admin/settings', label: 'Settings' },
    { href: '/admin/ads', label: 'Ads' },
    { href: '/admin/moderation', label: 'Moderation' },
    { href: '/admin/moderation/logs', label: 'Logs' }
  ];

  function isActive(currentPath, href) {
    return currentPath === href || currentPath.startsWith(`${href}/`);
  }

  async function toggleFollow(userId) {
    try {
      const payload = await postFormJson(`/api/v1/users/${userId}/follow`, {});
      bootstrap.update((state) => ({
        ...state,
        suggestedUsers: state.suggestedUsers.map((user) =>
          user.id === userId ? { ...user, isFollowing: payload.state === 'followed' } : user
        )
      }));
    } catch (error) {
      window.alert(error.message);
    }
  }

  async function logout() {
    if (logoutLoading) return;
    logoutLoading = true;

    try {
      await apiFetch('/api/v1/auth/logout', { method: 'POST' });
      bootstrap.update((state) => ({
        ...state,
        auth: { ...state.auth, isAuthenticated: false },
        viewer: null,
        unreadNotificationCount: 0
      }));
      await goto('/login');
    } catch (error) {
      window.alert(error.message);
    } finally {
      logoutLoading = false;
    }
  }
</script>

<svelte:head>
  <title>{$bootstrap.site?.title || 'HKForum'}</title>
  {#if $bootstrap.site?.description}
    <meta name="description" content={$bootstrap.site.description} />
  {/if}
</svelte:head>

<div class="min-h-screen">
  {#if isAuthPage}
    <main class="mx-auto flex min-h-[calc(100vh-4rem)] w-full max-w-5xl items-center justify-center px-4 py-10">
      {#if loading}
        <div class="rounded-2xl border border-slate-200 bg-white px-8 py-10 text-sm text-slate-500">Loading shell…</div>
      {:else}
        <slot />
      {/if}
    </main>
  {:else if isAdminPage}
    <main class="mx-auto w-full max-w-[1280px] px-3 py-3">
      {#if $bootstrap.ready}
        <div class="grid min-h-[calc(100vh-2.5rem)] grid-cols-1 overflow-hidden rounded-2xl border border-slate-200 bg-white min-[960px]:grid-cols-[240px_minmax(0,1fr)]">
          <aside class="border-b border-slate-200 bg-slate-950 px-5 py-6 text-slate-200 min-[960px]:border-b-0 min-[960px]:border-r min-[960px]:border-slate-800">
            <a href="/admin" class="block text-xl font-semibold text-white">Admin Console</a>
            <div class="mt-2 text-sm text-slate-400">{$bootstrap.site?.title || 'HKForum'}</div>

            <nav class="mt-6 space-y-1.5">
              {#each adminLinks as link}
                <a
                  href={link.href}
                  class={`block rounded-xl px-3 py-2 text-sm font-medium transition ${isActive(pathname, link.href) ? 'bg-white text-slate-900' : 'text-slate-300 hover:bg-slate-900 hover:text-white'}`}
                >
                  {link.label}
                </a>
              {/each}
            </nav>

            <div class="mt-8 rounded-xl border border-slate-800 bg-slate-900 px-3 py-3">
              <div class="text-sm font-semibold text-white">{$bootstrap.viewer?.name || $bootstrap.viewer?.ident || 'Admin'}</div>
              <div class="mt-1 text-xs uppercase tracking-[0.16em] text-slate-500">{$bootstrap.viewer?.role || 'admin'}</div>
              <div class="mt-4 flex flex-col gap-2">
                <a href="/home" class="text-sm text-slate-300 hover:text-white">Back to forum</a>
                <button type="button" class="text-left text-sm text-slate-300 hover:text-white" on:click={logout}>Log out</button>
              </div>
            </div>
          </aside>

          <div class="min-w-0 bg-slate-50">
            {#if loading}
              <div class="flex h-full items-center justify-center px-6 text-sm text-slate-500">Loading admin…</div>
            {:else}
              <slot />
            {/if}
          </div>
        </div>
      {:else}
        <div class="flex min-h-[70vh] items-center justify-center rounded-2xl border border-slate-200 bg-white text-sm text-slate-500">
          Loading shell…
        </div>
      {/if}
    </main>
  {:else}
    <main class="mx-auto w-full max-w-[1216px] px-2 py-3 md:px-3">
      {#if $bootstrap.ready}
        <div class="forum-layout-grid grid min-h-[calc(100vh-7rem)] grid-cols-1 overflow-hidden rounded-xl border border-slate-200 bg-[#f4f5f6] min-[1000px]:h-[calc(100vh-2.5rem)] min-[1000px]:grid-cols-[280px_minmax(0,1fr)_280px]">
          <aside class="border-b border-slate-200 bg-[#f4f5f6] px-6 py-6 min-[1000px]:h-full min-[1000px]:overflow-y-auto min-[1000px]:border-b-0 min-[1000px]:border-r">
            <div class="flex h-full flex-col">
              <a href="/home" class="mx-auto mb-6 inline-flex items-center justify-center">
                {#if $bootstrap.site?.logoUrl}
                  <img src={$bootstrap.site.logoUrl} alt={$bootstrap.site.title} class="max-h-12 w-auto rounded-lg" />
                {:else}
                  <div class="text-2xl font-semibold text-slate-900">{$bootstrap.site?.title || 'HKForum'}</div>
                {/if}
              </a>

              <nav class="mx-auto w-full max-w-[186px] space-y-1.5">
                <a href="/home" class={`flex items-center gap-3 rounded-xl px-3 py-2.5 text-[16px] font-medium transition ${isActive(pathname, '/home') ? 'bg-white text-slate-900 shadow-sm' : 'text-slate-700 hover:bg-white hover:text-slate-900'}`}>Home</a>
                <a href="/boards" class={`flex items-center gap-3 rounded-xl px-3 py-2.5 text-[16px] font-medium transition ${isActive(pathname, '/boards') ? 'bg-white text-slate-900 shadow-sm' : 'text-slate-700 hover:bg-white hover:text-slate-900'}`}>Boards</a>
                {#if $bootstrap.site?.showCompaniesNav}
                  <a href="/companies" class={`flex items-center gap-3 rounded-xl px-3 py-2.5 text-[16px] font-medium transition ${isActive(pathname, '/companies') ? 'bg-white text-slate-900 shadow-sm' : 'text-slate-700 hover:bg-white hover:text-slate-900'}`}>Company</a>
                {/if}
                {#if $bootstrap.site?.showJobsNav}
                  <a href="/jobs" class={`flex items-center gap-3 rounded-xl px-3 py-2.5 text-[16px] font-medium transition ${isActive(pathname, '/jobs') ? 'bg-white text-slate-900 shadow-sm' : 'text-slate-700 hover:bg-white hover:text-slate-900'}`}>Jobs</a>
                {/if}
                <a href="/chats" class={`flex items-center gap-3 rounded-xl px-3 py-2.5 text-[16px] font-medium transition ${isActive(pathname, '/chats') ? 'bg-white text-slate-900 shadow-sm' : 'text-slate-700 hover:bg-white hover:text-slate-900'}`}>Chats</a>
                {#if $bootstrap.auth?.isAuthenticated}
                  <a href="/notifications" class={`flex items-center justify-between gap-2 rounded-xl px-3 py-2.5 text-[16px] font-medium transition ${isActive(pathname, '/notifications') ? 'bg-white text-slate-900 shadow-sm' : 'text-slate-700 hover:bg-white hover:text-slate-900'}`}>
                    <span>Notifications</span>
                    {#if $bootstrap.unreadNotificationCount > 0}
                      <span class="rounded-full bg-slate-900 px-2 py-0.5 text-[11px] font-semibold text-white">{$bootstrap.unreadNotificationCount}</span>
                    {/if}
                  </a>
                  <a href="/bookmarks" class={`flex items-center gap-3 rounded-xl px-3 py-2.5 text-[16px] font-medium transition ${isActive(pathname, '/bookmarks') ? 'bg-white text-slate-900 shadow-sm' : 'text-slate-700 hover:bg-white hover:text-slate-900'}`}>Bookmarks</a>
                {:else}
                  <a href="/login" class={`flex items-center gap-3 rounded-xl px-3 py-2.5 text-[16px] font-medium transition ${isActive(pathname, '/login') ? 'bg-white text-slate-900 shadow-sm' : 'text-slate-700 hover:bg-white hover:text-slate-900'}`}>Login</a>
                {/if}
              </nav>

              {#if $bootstrap.auth?.isAuthenticated}
                <button type="button" class="mx-auto mt-5 inline-flex w-full max-w-[170px] items-center justify-center gap-2 rounded-full bg-slate-900 px-5 py-2 text-sm font-semibold text-white transition hover:bg-slate-800" on:click={() => (globalPostOpen = true)}>
                  New Post
                </button>
              {:else}
                <a href="/login" class="mx-auto mt-5 inline-flex w-full max-w-[170px] items-center justify-center gap-2 rounded-full bg-slate-900 px-5 py-2 text-sm font-semibold text-white transition hover:bg-slate-800">
                  New Post
                </a>
              {/if}

              {#if $bootstrap.viewer}
                <div class="mx-auto mt-auto w-full max-w-[170px] rounded-xl border border-slate-200 bg-white px-2.5 py-2">
                  <div class="truncate text-sm font-semibold text-slate-900">{$bootstrap.viewer.name || $bootstrap.viewer.ident}</div>
                  <div class="truncate text-xs text-slate-500">@{$bootstrap.viewer.ident}</div>
                  <div class="mt-3 flex flex-col gap-2">
                    <a href="/profile" class="text-sm text-slate-700 hover:text-slate-900">Profile</a>
                    <a href="/settings" class="text-sm text-slate-700 hover:text-slate-900">Settings</a>
                    {#if $bootstrap.viewer.role === 'admin'}
                      <a href="/admin" class="text-sm text-slate-700 hover:text-slate-900">Admin</a>
                    {/if}
                    <button type="button" class="text-left text-sm text-slate-700 hover:text-slate-900" on:click={logout} disabled={logoutLoading}>
                      {logoutLoading ? 'Logging out…' : 'Log Out'}
                    </button>
                  </div>
                </div>
              {:else}
                <a href="/login" class="mx-auto mt-auto flex w-full max-w-[170px] items-center gap-2 rounded-xl border border-slate-200 bg-white px-2.5 py-2 transition hover:border-slate-300">
                  <div class="flex h-8 w-8 shrink-0 items-center justify-center rounded-full bg-slate-200 text-xs font-semibold text-slate-700">G</div>
                  <div class="min-w-0 flex-1">
                    <div class="truncate text-sm font-semibold text-slate-900">Guest</div>
                    <div class="truncate text-xs text-slate-500">Sign in to personalize</div>
                  </div>
                </a>
              {/if}
            </div>
          </aside>

          <div class="feed-shell min-w-0 border-b border-slate-200 bg-white min-[1000px]:h-full min-[1000px]:overflow-y-auto min-[1000px]:border-b-0 min-[1000px]:border-r">
            {#if loading}
              <div class="flex h-full items-center justify-center text-sm text-slate-500">Loading…</div>
            {:else}
              <slot />
            {/if}
          </div>

          <aside class="bg-[#f4f5f6] p-3 min-[1000px]:h-full min-[1000px]:overflow-y-auto">
            <div class="mx-auto w-full max-w-[292px] space-y-3">
              <form method="get" action="/home" class="relative rounded-xl border border-slate-200 bg-white p-2">
                <input type="search" name="q" placeholder="Type '/' to search" class="w-full rounded-lg border border-slate-200 py-2 pl-3 pr-3 text-sm text-slate-700 placeholder:text-slate-400 focus:border-slate-400 focus:outline-none" />
              </form>

              {#if $bootstrap.sidebarAds?.length}
                <div class="space-y-3">
                  {#each $bootstrap.sidebarAds as ad}
                    <div class="rounded-xl border border-slate-200 bg-white p-4">
                      <div class="text-base font-semibold text-slate-900">{ad.title}</div>
                      <div class="mt-2 whitespace-pre-wrap text-sm text-slate-600">{ad.body}</div>
                      {#if ad.link}
                        <a href={ad.link} target="_blank" rel="noreferrer" class="mt-3 inline-flex text-sm font-semibold text-slate-700 underline underline-offset-2 hover:text-slate-900">Learn more</a>
                      {/if}
                    </div>
                  {/each}
                </div>
              {/if}

              <div class="rounded-xl border border-slate-200 bg-white p-4">
                <div class="mb-3 text-xl font-semibold text-slate-900">Who to follow</div>
                <div class="space-y-3.5">
                  {#if !$bootstrap.suggestedUsers?.length}
                    <div class="text-sm text-slate-500">No user suggestion yet.</div>
                  {:else}
                    {#each $bootstrap.suggestedUsers as user}
                      <div class="flex items-center justify-between gap-3">
                        <div class="flex min-w-0 items-center gap-2.5">
                          <div class="flex h-9 w-9 items-center justify-center rounded-full bg-slate-200 text-xs font-semibold text-slate-700">
                            {(user.ident || 'U').slice(0, 1).toUpperCase()}
                          </div>
                          <div class="min-w-0">
                            <div class="truncate text-sm font-semibold text-slate-900">{user.name || user.ident}</div>
                            <div class="truncate text-xs text-slate-500">@{user.ident.toLowerCase()}</div>
                          </div>
                        </div>
                        {#if $bootstrap.auth?.isAuthenticated}
                          <button type="button" class="rounded-lg bg-slate-900 px-3 py-1.5 text-xs font-semibold text-white" on:click={() => toggleFollow(user.id)}>
                            {user.isFollowing ? 'Following' : 'Follow'}
                          </button>
                        {:else}
                          <a href="/login" class="rounded-lg bg-slate-900 px-3 py-1.5 text-xs font-semibold text-white">Follow</a>
                        {/if}
                      </div>
                    {/each}
                  {/if}
                </div>
              </div>

              <div class="rounded-xl border border-slate-200 bg-white p-4">
                <div class="mb-3 text-xl font-semibold text-slate-900">Boards</div>
                <div class="space-y-3.5">
                  {#each $bootstrap.boards.slice(0, 3) as board}
                    <a href={`/board/${board.id}`} class="flex items-center justify-between gap-2 rounded-lg px-1 py-1.5 transition hover:bg-slate-50">
                      <div class="flex min-w-0 items-center gap-2.5">
                        <div class="h-9 w-9 rounded-full bg-slate-200"></div>
                        <div class="min-w-0">
                          <div class="truncate text-sm font-semibold text-slate-900">{board.name}</div>
                          <div class="truncate text-xs text-slate-500">{board.postCount} posts</div>
                        </div>
                      </div>
                    </a>
                  {/each}
                </div>
                <a href="/boards" class="mt-3 inline-flex text-sm font-semibold text-slate-700 hover:text-slate-900">Show more</a>
              </div>

              <div class="px-1 text-xs text-slate-500">
                <span>Built by {$bootstrap.site?.title}</span>
                {#if $bootstrap.site?.subtitle}
                  <div class="mt-1">{$bootstrap.site.subtitle}</div>
                {/if}
              </div>
            </div>
          </aside>
        </div>

        <GlobalPostModal open={globalPostOpen} onClose={() => (globalPostOpen = false)} />
      {:else}
        <div class="flex min-h-[60vh] items-center justify-center rounded-xl border border-slate-200 bg-white text-sm text-slate-500">
          Loading shell…
        </div>
      {/if}
    </main>
  {/if}

  {#if $bootstrap.site?.footerText}
    <footer class="mx-auto w-full max-w-[1216px] px-2 py-4 text-center text-xs text-slate-500 md:px-3">
      {$bootstrap.site.footerText}
    </footer>
  {/if}
</div>
