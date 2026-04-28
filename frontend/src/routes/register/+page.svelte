<script>
  import { bootstrap } from '$lib/stores/bootstrap';
  import { apiFetch } from '$lib/utils/api';

  let username = '';
  let password = '';
  let accountType = 'personal';
  let employerPlan = 'starter';
  let realEstatePlan = 'starter';
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
        body: JSON.stringify({
          username: username.trim(),
          password,
          accountType,
          employerPlan: accountType === 'employer' ? employerPlan : null,
          realEstatePlan: accountType === 'real_estate' ? realEstatePlan : null
        })
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
      <div>
        <label for="register-account-type" class="text-xs font-semibold uppercase tracking-[0.18em] text-slate-500">Account type</label>
        <select id="register-account-type" bind:value={accountType} class="mt-2 w-full rounded-xl border border-slate-200 bg-slate-50 px-4 py-3 text-sm text-slate-900">
          <option value="personal">Personal</option>
          <option value="employer">Employer</option>
          <option value="real_estate">Real estate agent</option>
        </select>
      </div>
      {#if accountType === 'employer'}
        <div>
          <label for="register-employer-plan" class="text-xs font-semibold uppercase tracking-[0.18em] text-slate-500">Employer plan</label>
          <select id="register-employer-plan" bind:value={employerPlan} class="mt-2 w-full rounded-xl border border-slate-200 bg-slate-50 px-4 py-3 text-sm text-slate-900">
            <option value="starter">월 10만원 · 공고 3개</option>
            <option value="growth">월 30만원 · 공고 10개</option>
            <option value="scale">월 50만원 · 공고 20개</option>
            <option value="enterprise">20개 초과 · 협의</option>
          </select>
          <p class="mt-2 text-xs text-slate-500">결제 연동 전까지는 선택한 플랜 권한을 즉시 부여합니다.</p>
        </div>
      {/if}
      {#if accountType === 'real_estate'}
        <div>
          <label for="register-real-estate-plan" class="text-xs font-semibold uppercase tracking-[0.18em] text-slate-500">Real estate plan</label>
          <select id="register-real-estate-plan" bind:value={realEstatePlan} class="mt-2 w-full rounded-xl border border-slate-200 bg-slate-50 px-4 py-3 text-sm text-slate-900">
            <option value="starter">월 10만원 · 매물 10개</option>
            <option value="growth">월 30만원 · 매물 30개</option>
            <option value="scale">월 50만원 · 매물 70개</option>
            <option value="enterprise">70개 초과 · 협의</option>
          </select>
          <p class="mt-2 text-xs text-slate-500">결제 연동 전까지는 선택한 플랜 권한을 즉시 부여합니다.</p>
        </div>
      {/if}
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
