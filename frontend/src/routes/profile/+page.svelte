<script>
  import { onMount } from 'svelte';
  import { bootstrap } from '$lib/stores/bootstrap';
  import { apiFetch } from '$lib/utils/api';

  let loading = true;
  let saving = false;
  let form = {
    name: '',
    description: '',
    countryCode: '',
    state: '',
    localRegionOnly: false,
    latitude: '',
    longitude: ''
  };
  let countries = [];
  let states = [];
  let error = '';
  let success = '';

  $: availableStates = states.filter((item) => item.countryCode === form.countryCode);

  async function loadData() {
    loading = true;
    try {
      const [me, regions] = await Promise.all([apiFetch('/api/v1/me'), apiFetch('/api/v1/meta/regions')]);
      const user = me.user || {};
      countries = regions.countries || [];
      states = regions.states || [];
      form = {
        name: user.name || '',
        description: user.description || '',
        countryCode: user.countryCode || countries[0]?.code || '',
        state: user.state || '',
        localRegionOnly: Boolean(user.localRegionOnly),
        latitude: user.latitude ?? '',
        longitude: user.longitude ?? ''
      };
    } catch (err) {
      error = err.message;
    } finally {
      loading = false;
    }
  }

  async function save() {
    saving = true;
    error = '';
    success = '';

    try {
      const payload = await apiFetch('/api/v1/me/profile', {
        method: 'PATCH',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          name: form.name || null,
          description: form.description || null,
          countryCode: form.countryCode,
          state: form.state,
          localRegionOnly: form.localRegionOnly,
          latitude: form.latitude === '' ? null : Number(form.latitude),
          longitude: form.longitude === '' ? null : Number(form.longitude)
        })
      });
      bootstrap.update((state) => ({ ...state, viewer: payload.user }));
      success = 'Profile updated.';
    } catch (err) {
      error = err.message;
    } finally {
      saving = false;
    }
  }

  onMount(loadData);
</script>

<section class="min-h-full bg-slate-50">
  <div class="border-b border-slate-200 bg-white px-5 py-4">
    <h1 class="text-2xl font-semibold text-slate-900">Edit Profile</h1>
    <p class="mt-1 text-sm text-slate-500">This page replaces the old Yesod profile form.</p>
  </div>

  <div class="px-5 py-5">
    <div class="mx-auto max-w-3xl rounded-2xl border border-slate-200 bg-white p-6">
      {#if loading}
        <div class="text-sm text-slate-500">Loading profile…</div>
      {:else}
        <div class="grid gap-4 md:grid-cols-2">
          <div class="md:col-span-2">
            <label for="profile-name" class="text-xs font-semibold uppercase tracking-[0.18em] text-slate-500">Display name</label>
            <input id="profile-name" bind:value={form.name} class="mt-2 w-full rounded-xl border border-slate-200 bg-slate-50 px-4 py-3 text-sm text-slate-900" />
          </div>
          <div class="md:col-span-2">
            <label for="profile-description" class="text-xs font-semibold uppercase tracking-[0.18em] text-slate-500">Description</label>
            <textarea id="profile-description" bind:value={form.description} class="mt-2 min-h-[140px] w-full rounded-xl border border-slate-200 bg-slate-50 px-4 py-3 text-sm text-slate-900"></textarea>
          </div>
          <div>
            <label for="profile-country" class="text-xs font-semibold uppercase tracking-[0.18em] text-slate-500">Country</label>
            <select id="profile-country" bind:value={form.countryCode} class="mt-2 w-full rounded-xl border border-slate-200 bg-slate-50 px-4 py-3 text-sm text-slate-900">
              {#each countries as country}
                <option value={country.code}>{country.name} ({country.code})</option>
              {/each}
            </select>
          </div>
          <div>
            <label for="profile-state" class="text-xs font-semibold uppercase tracking-[0.18em] text-slate-500">State</label>
            <select id="profile-state" bind:value={form.state} class="mt-2 w-full rounded-xl border border-slate-200 bg-slate-50 px-4 py-3 text-sm text-slate-900">
              <option value="">Choose state</option>
              {#each availableStates as item}
                <option value={item.code}>{item.name}</option>
              {/each}
            </select>
          </div>
          <div>
            <label for="profile-latitude" class="text-xs font-semibold uppercase tracking-[0.18em] text-slate-500">Latitude</label>
            <input id="profile-latitude" bind:value={form.latitude} class="mt-2 w-full rounded-xl border border-slate-200 bg-slate-50 px-4 py-3 text-sm text-slate-900" />
          </div>
          <div>
            <label for="profile-longitude" class="text-xs font-semibold uppercase tracking-[0.18em] text-slate-500">Longitude</label>
            <input id="profile-longitude" bind:value={form.longitude} class="mt-2 w-full rounded-xl border border-slate-200 bg-slate-50 px-4 py-3 text-sm text-slate-900" />
          </div>
        </div>

        <label class="mt-5 flex items-center gap-3 rounded-xl bg-slate-50 px-4 py-3 text-sm text-slate-700">
          <input type="checkbox" bind:checked={form.localRegionOnly} />
          Use my region for local feeds
        </label>

        {#if error}
          <div class="mt-4 rounded-xl border border-rose-200 bg-rose-50 px-4 py-3 text-sm text-rose-700">{error}</div>
        {/if}
        {#if success}
          <div class="mt-4 rounded-xl border border-emerald-200 bg-emerald-50 px-4 py-3 text-sm text-emerald-700">{success}</div>
        {/if}

        <div class="mt-5 flex gap-3">
          <button type="button" class="rounded-xl bg-slate-900 px-4 py-2.5 text-sm font-semibold text-white" on:click={save} disabled={saving}>
            {saving ? 'Saving…' : 'Save Profile'}
          </button>
          <a href="/settings/account" class="rounded-xl border border-slate-200 px-4 py-2.5 text-sm font-semibold text-slate-700">Back to settings</a>
        </div>
      {/if}
    </div>
  </div>
</section>
