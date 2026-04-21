<script>
  import { bootstrap } from '$lib/stores/bootstrap';
  import { apiFetch } from '$lib/utils/api';

  let username = '';
  let password = '';
  let loading = false;
  let error = '';

  async function submit() {
    if (!username.trim() || !password) return;
    loading = true;
    error = '';

    try {
      await apiFetch('/api/v1/auth/register', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ username: username.trim(), password })
      });
      window.location.href = '/home';
    } catch (err) {
      error = err.message;
    } finally {
      loading = false;
    }
  }
</script>

<section class="w-full max-w-md rounded-[2rem] border border-slate-200 bg-white p-8 shadow-sm">
  <div class="text-sm font-semibold uppercase tracking-[0.2em] text-slate-500">HKForum</div>
  <h1 class="mt-3 text-3xl font-semibold text-slate-900">Register</h1>
  <p class="mt-2 text-sm text-slate-600">Create an account to use the migrated forum UI.</p>

  {#if !$bootstrap.site?.allowUserRegistration}
    <div class="mt-6 rounded-xl border border-amber-200 bg-amber-50 px-4 py-3 text-sm text-amber-700">Registration is currently disabled.</div>
  {:else}
    <div class="mt-6 space-y-4">
      <div>
        <label for="register-username" class="text-xs font-semibold uppercase tracking-[0.18em] text-slate-500">Username</label>
        <input id="register-username" bind:value={username} class="mt-2 w-full rounded-xl border border-slate-200 bg-slate-50 px-4 py-3 text-sm text-slate-900" />
      </div>
      <div>
        <label for="register-password" class="text-xs font-semibold uppercase tracking-[0.18em] text-slate-500">Password</label>
        <input id="register-password" type="password" bind:value={password} class="mt-2 w-full rounded-xl border border-slate-200 bg-slate-50 px-4 py-3 text-sm text-slate-900" />
      </div>
      {#if error}
        <div class="rounded-xl border border-rose-200 bg-rose-50 px-4 py-3 text-sm text-rose-700">{error}</div>
      {/if}
      <button type="button" class="w-full rounded-xl bg-slate-900 px-4 py-3 text-sm font-semibold text-white" on:click={submit} disabled={loading}>
        {loading ? 'Creating account…' : 'Create Account'}
      </button>
    </div>
  {/if}

  <div class="mt-6 text-sm text-slate-500">
    Already registered?
    <a href="/login" class="font-semibold text-slate-900 underline underline-offset-4">Login</a>
  </div>
</section>
