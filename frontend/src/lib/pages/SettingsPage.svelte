<script>
  import { onMount } from 'svelte';
  import { page } from '$app/stores';
  import { bootstrap } from '$lib/stores/bootstrap';
  import { apiFetch } from '$lib/utils/api';
  import { formatDate, relativeTime } from '$lib/utils/time';

  let loading = false;
  let blockedLoading = false;
  let securityEvents = [];
  let blockedUsers = [];
  let blockingUserId = null;

  $: section = getSection($page.url.pathname);
  $: viewer = $bootstrap.viewer;
  $: githubProfileUrl = viewer ? `https://github.com/${viewer.ident}` : '';
  $: providers = $bootstrap.auth?.providers || [];
  $: currentProvider = viewer?.authProvider || 'password';
  $: currentProviderLabel = providerLabel(currentProvider);

  function getSection(pathname) {
    const parts = pathname.split('/').filter(Boolean);
    return parts[1] || 'index';
  }

  async function loadSecurityEvents() {
    if (section !== 'security-events' || !$bootstrap.auth?.isAuthenticated) return;
    loading = true;
    try {
      const payload = await apiFetch('/api/v1/me/security-events');
      securityEvents = payload.items || [];
    } catch (error) {
      window.alert(error.message);
    } finally {
      loading = false;
    }
  }

  async function loadBlockedUsers() {
    if (section !== 'blocked-accounts' || !$bootstrap.auth?.isAuthenticated) return;
    blockedLoading = true;
    try {
      const payload = await apiFetch('/api/v1/me/blocked-users');
      blockedUsers = payload.items || [];
    } catch (error) {
      window.alert(error.message);
    } finally {
      blockedLoading = false;
    }
  }

  async function toggleBlockedUser(userId) {
    if (blockingUserId) return;
    blockingUserId = userId;
    try {
      await apiFetch(`/api/v1/users/${userId}/block`, { method: 'POST' });
      blockedUsers = blockedUsers.filter((item) => item.id !== userId);
    } catch (error) {
      window.alert(error.message);
    } finally {
      blockingUserId = null;
    }
  }

  function providerLabel(key) {
    if (key === 'google') return 'Google';
    if (key === 'kakao') return 'Kakao';
    if (key === 'naver') return 'Naver';
    return 'Password';
  }

  onMount(() => {
    loadSecurityEvents();
    loadBlockedUsers();
  });
  $: if (section === 'security-events' && $bootstrap.ready) {
    loadSecurityEvents();
  }
  $: if (section === 'blocked-accounts' && $bootstrap.ready) {
    loadBlockedUsers();
  }

  const links = [
    { href: '/settings', key: 'index', label: 'Overview' },
    { href: '/settings/account', key: 'account', label: 'Account' },
    { href: '/settings/connections', key: 'connections', label: 'Connections' },
    { href: '/settings/blocked-accounts', key: 'blocked-accounts', label: 'Blocked Accounts' },
    { href: '/settings/security-events', key: 'security-events', label: 'Security Events' },
    { href: '/settings/about', key: 'about', label: 'About' }
  ];
</script>

<section class="min-h-full bg-slate-50">
  <div class="border-b border-slate-200 bg-white px-5 py-4">
    <h1 class="text-2xl font-semibold text-slate-900">Settings</h1>
    <p class="mt-1 text-sm text-slate-500">Manage your account, profile, and site preferences.</p>
  </div>

  <div class="grid gap-5 px-5 py-5 lg:grid-cols-[220px_minmax(0,1fr)]">
    <aside class="space-y-1">
      {#each links as link}
        <a
          href={link.href}
          class={`block rounded-xl px-3 py-2 text-sm font-medium transition ${section === link.key ? 'bg-slate-900 text-white' : 'bg-white text-slate-700 hover:bg-slate-100 hover:text-slate-900'}`}
        >
          {link.label}
        </a>
      {/each}
    </aside>

    <div class="space-y-4">
      {#if section === 'index'}
        <div class="rounded-2xl border border-slate-200 bg-white p-6">
          <div class="text-lg font-semibold text-slate-900">Account summary</div>
          <div class="mt-4 grid gap-3 md:grid-cols-3">
            <div class="rounded-xl bg-slate-50 p-4">
              <div class="text-xs uppercase tracking-[0.18em] text-slate-500">Handle</div>
              <div class="mt-2 text-base font-semibold text-slate-900">@{viewer?.ident || 'guest'}</div>
            </div>
            <div class="rounded-xl bg-slate-50 p-4">
              <div class="text-xs uppercase tracking-[0.18em] text-slate-500">Region</div>
              <div class="mt-2 text-base font-semibold text-slate-900">{viewer?.state || 'Unset'}{viewer?.countryCode ? `, ${viewer.countryCode}` : ''}</div>
            </div>
            <div class="rounded-xl bg-slate-50 p-4">
              <div class="text-xs uppercase tracking-[0.18em] text-slate-500">Role</div>
              <div class="mt-2 text-base font-semibold text-slate-900">{viewer?.role || 'user'}</div>
            </div>
          </div>
        </div>

        <div class="rounded-2xl border border-slate-200 bg-white p-6">
          <div class="text-lg font-semibold text-slate-900">Quick actions</div>
          <div class="mt-4 flex flex-wrap gap-3">
            <a href="/profile" class="rounded-xl bg-slate-900 px-4 py-2 text-sm font-semibold text-white">Edit Profile</a>
            <a href="/settings/security-events" class="rounded-xl border border-slate-200 px-4 py-2 text-sm font-semibold text-slate-700">Security Events</a>
            <a href="/bookmarks" class="rounded-xl border border-slate-200 px-4 py-2 text-sm font-semibold text-slate-700">Bookmarks</a>
          </div>
        </div>
      {:else if section === 'account'}
        <div class="rounded-2xl border border-slate-200 bg-white p-6">
          <div class="text-lg font-semibold text-slate-900">Account</div>
          <dl class="mt-5 grid gap-4 md:grid-cols-2">
            <div class="rounded-xl bg-slate-50 p-4">
              <dt class="text-xs uppercase tracking-[0.18em] text-slate-500">Username</dt>
              <dd class="mt-2 text-base font-semibold text-slate-900">{viewer?.ident}</dd>
            </div>
            <div class="rounded-xl bg-slate-50 p-4">
              <dt class="text-xs uppercase tracking-[0.18em] text-slate-500">Display name</dt>
              <dd class="mt-2 text-base font-semibold text-slate-900">{viewer?.name || 'Unset'}</dd>
            </div>
            <div class="rounded-xl bg-slate-50 p-4">
              <dt class="text-xs uppercase tracking-[0.18em] text-slate-500">Description</dt>
              <dd class="mt-2 whitespace-pre-wrap text-sm text-slate-700">{viewer?.description || 'No bio yet.'}</dd>
            </div>
            <div class="rounded-xl bg-slate-50 p-4">
              <dt class="text-xs uppercase tracking-[0.18em] text-slate-500">Region</dt>
              <dd class="mt-2 text-sm text-slate-700">{viewer?.state || 'Unset'}{viewer?.countryCode ? `, ${viewer.countryCode}` : ''}</dd>
            </div>
          </dl>
          <a href="/profile" class="mt-5 inline-flex rounded-xl bg-slate-900 px-4 py-2 text-sm font-semibold text-white">Update profile</a>
        </div>
      {:else if section === 'connections'}
        <div class="rounded-2xl border border-slate-200 bg-white p-6">
          <div class="text-lg font-semibold text-slate-900">Connections</div>
          <div class="mt-4 rounded-xl bg-slate-50 p-4">
            <div class="text-sm text-slate-500">Current sign-in method</div>
            <div class="mt-2 text-base font-semibold text-slate-900">{currentProviderLabel}</div>
          </div>
          <div class="mt-4 rounded-xl bg-slate-50 p-4">
            <div class="text-sm text-slate-500">Primary profile link</div>
            <a href={githubProfileUrl} target="_blank" rel="noreferrer" class="mt-2 inline-flex text-base font-semibold text-slate-900 underline underline-offset-4">
              {githubProfileUrl}
            </a>
          </div>
          <div class="mt-4">
            <div class="text-sm font-semibold text-slate-900">Available social providers</div>
            {#if providers.length}
              <div class="mt-3 flex flex-wrap gap-3">
                {#each providers as provider}
                  <a href={provider.url} class="rounded-xl border border-slate-200 bg-white px-4 py-2 text-sm font-semibold text-slate-700 transition hover:border-slate-300 hover:text-slate-900">
                    Continue with {provider.label}
                  </a>
                {/each}
              </div>
            {:else}
              <p class="mt-3 text-sm text-slate-600">No external OAuth providers are configured in this environment.</p>
            {/if}
          </div>
        </div>
      {:else if section === 'blocked-accounts'}
        <div class="rounded-2xl border border-slate-200 bg-white p-6">
          <div class="text-lg font-semibold text-slate-900">Blocked accounts</div>
          {#if blockedLoading}
            <p class="mt-3 text-sm text-slate-600">Loading blocked accounts…</p>
          {:else if !blockedUsers.length}
            <p class="mt-3 text-sm text-slate-600">No blocked accounts.</p>
          {:else}
            <div class="mt-4 space-y-3">
              {#each blockedUsers as user}
                <div class="flex items-center justify-between gap-4 rounded-xl bg-slate-50 p-4">
                  <div>
                    <div class="font-semibold text-slate-900">{user.name || user.ident}</div>
                    <div class="mt-1 text-sm text-slate-500">@{user.ident}</div>
                    {#if user.description}
                      <div class="mt-2 text-sm text-slate-600">{user.description}</div>
                    {/if}
                    <div class="mt-2 text-xs text-slate-400">Blocked {relativeTime(user.createdAt)}</div>
                  </div>
                  <button
                    type="button"
                    class="rounded-xl border border-slate-200 bg-white px-4 py-2 text-sm font-semibold text-slate-700 transition hover:border-slate-300 hover:text-slate-900"
                    on:click={() => toggleBlockedUser(user.id)}
                    disabled={blockingUserId === user.id}
                  >
                    {blockingUserId === user.id ? 'Unblocking…' : 'Unblock'}
                  </button>
                </div>
              {/each}
            </div>
          {/if}
        </div>
      {:else if section === 'security-events'}
        <div class="rounded-2xl border border-slate-200 bg-white p-6">
          <div class="flex items-center justify-between gap-3">
            <div>
              <div class="text-lg font-semibold text-slate-900">Security events</div>
              <p class="mt-1 text-sm text-slate-500">Recent account activity inferred from your interactions.</p>
            </div>
          </div>
          {#if loading}
            <div class="mt-6 text-sm text-slate-500">Loading events…</div>
          {:else if !securityEvents.length}
            <div class="mt-6 text-sm text-slate-500">No events available.</div>
          {:else}
            <div class="mt-6 space-y-3">
              {#each securityEvents as event}
                <div class="rounded-xl bg-slate-50 p-4">
                  <div class="flex items-center justify-between gap-4">
                    <div class="font-semibold text-slate-900">{event.label}</div>
                    <div class="text-xs uppercase tracking-[0.16em] text-slate-500">{event.platform}</div>
                  </div>
                  <div class="mt-2 text-sm text-slate-600">{relativeTime(event.createdAt)} · {formatDate(event.createdAt)}</div>
                </div>
              {/each}
            </div>
          {/if}
        </div>
      {:else if section === 'about'}
        <div class="rounded-2xl border border-slate-200 bg-white p-6">
          <div class="text-lg font-semibold text-slate-900">About {$bootstrap.site?.title || 'HKForum'}</div>
          <p class="mt-3 text-sm text-slate-600">{$bootstrap.site?.description || $bootstrap.site?.subtitle}</p>
          <dl class="mt-5 grid gap-3 md:grid-cols-2">
            <div class="rounded-xl bg-slate-50 p-4">
              <dt class="text-xs uppercase tracking-[0.18em] text-slate-500">Default locale</dt>
              <dd class="mt-2 text-sm font-semibold text-slate-900">{$bootstrap.site?.defaultLocale || 'en'}</dd>
            </div>
            <div class="rounded-xl bg-slate-50 p-4">
              <dt class="text-xs uppercase tracking-[0.18em] text-slate-500">Footer</dt>
              <dd class="mt-2 text-sm text-slate-700">{$bootstrap.site?.footerText || 'Not configured'}</dd>
            </div>
          </dl>
        </div>
      {/if}
    </div>
  </div>
</section>
