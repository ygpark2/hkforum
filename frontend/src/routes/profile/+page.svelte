<script>
  import { onMount } from 'svelte';
  import { bootstrap } from '$lib/stores/bootstrap';
  import { apiFetch } from '$lib/utils/api';
  import LeafletMap from '$lib/components/LeafletMap.svelte';

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
  let locationModalOpen = false;
  let draftLatitude = null;
  let draftLongitude = null;

  $: availableStates = states.filter((item) => item.countryCode === form.countryCode);

  function parseCoordinate(value) {
    if (value === '' || value == null) return null;
    const number = Number(value);
    return Number.isFinite(number) ? number : null;
  }

  function openLocationModal() {
    draftLatitude = parseCoordinate(form.latitude);
    draftLongitude = parseCoordinate(form.longitude);
    locationModalOpen = true;
  }

  function closeLocationModal() {
    locationModalOpen = false;
  }

  function applyLocationModal() {
    form = {
      ...form,
      latitude: draftLatitude == null ? '' : String(draftLatitude),
      longitude: draftLongitude == null ? '' : String(draftLongitude)
    };
    closeLocationModal();
  }

  function clearLocation() {
    form = {
      ...form,
      latitude: '',
      longitude: ''
    };
  }

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
          <div class="md:col-span-2">
            <div class="flex items-center justify-between gap-3">
              <div class="text-xs font-semibold uppercase tracking-[0.18em] text-slate-500">Location</div>
              <div class="flex items-center gap-2">
                {#if form.latitude !== '' && form.longitude !== ''}
                  <button type="button" class="text-xs font-semibold uppercase tracking-[0.18em] text-slate-500 hover:text-slate-900" on:click={clearLocation}>
                    Clear
                  </button>
                {/if}
                <button type="button" class="rounded-xl border border-slate-200 px-3 py-2 text-xs font-semibold uppercase tracking-[0.18em] text-slate-700" on:click={openLocationModal} disabled={!$bootstrap.site?.mapsEnabled}>
                  Select on map
                </button>
              </div>
            </div>
            <div class="mt-2 rounded-xl border border-slate-200 bg-slate-50 px-4 py-3">
              {#if form.latitude !== '' && form.longitude !== ''}
                <div class="text-sm font-semibold text-slate-900">{form.latitude}, {form.longitude}</div>
                <div class="mt-1 text-xs text-slate-500">선택된 좌표가 프로필 위치로 저장됩니다.</div>
              {:else if $bootstrap.site?.mapsEnabled}
                <div class="text-sm text-slate-500">아직 선택된 위치가 없습니다. `Select on map`으로 좌표를 선택하세요.</div>
              {:else}
                <div class="text-sm text-slate-500">지도 기능이 비활성화되어 있어 좌표를 선택할 수 없습니다.</div>
              {/if}
            </div>
            <input type="hidden" name="latitude" value={form.latitude} />
            <input type="hidden" name="longitude" value={form.longitude} />
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

{#if locationModalOpen}
  <div
    class="fixed inset-0 z-40 flex items-center justify-center bg-slate-900/40 px-4"
    role="button"
    tabindex="0"
    aria-label="Close location picker"
    on:click={closeLocationModal}
    on:keydown={(event) => {
      if (event.key === 'Escape' || event.key === 'Enter' || event.key === ' ') {
        closeLocationModal();
      }
    }}
  >
    <div class="w-[min(92vw,52rem)] rounded-2xl bg-white p-6 shadow-xl" role="dialog" tabindex="-1" aria-modal="true" on:click|stopPropagation on:keydown|stopPropagation={() => {}}>
      <div class="flex items-center justify-between gap-3">
        <div>
          <h2 class="text-lg font-semibold text-slate-900">Select profile location</h2>
          <p class="mt-1 text-sm text-slate-500">지도를 클릭해서 프로필에 저장할 좌표를 선택하세요.</p>
        </div>
        <button type="button" class="rounded-xl border border-slate-200 px-3 py-1 text-xs font-semibold uppercase tracking-[0.2em] text-slate-600" on:click={closeLocationModal}>
          Close
        </button>
      </div>

      <div class="mt-4 space-y-4">
        <LeafletMap bind:latitude={draftLatitude} bind:longitude={draftLongitude} interactive heightClass="h-[26rem]" />

        <div class="grid gap-4 md:grid-cols-2">
          <div class="rounded-xl border border-slate-200 bg-slate-50 px-4 py-3">
            <div class="text-xs font-semibold uppercase tracking-[0.18em] text-slate-500">Latitude</div>
            <div class="mt-2 text-sm font-semibold text-slate-900">{draftLatitude == null ? '-' : draftLatitude}</div>
          </div>
          <div class="rounded-xl border border-slate-200 bg-slate-50 px-4 py-3">
            <div class="text-xs font-semibold uppercase tracking-[0.18em] text-slate-500">Longitude</div>
            <div class="mt-2 text-sm font-semibold text-slate-900">{draftLongitude == null ? '-' : draftLongitude}</div>
          </div>
        </div>

        <div class="flex justify-end gap-2">
          <button type="button" class="rounded-xl border border-slate-200 px-4 py-2 text-xs font-semibold uppercase tracking-[0.18em] text-slate-600" on:click={() => { draftLatitude = null; draftLongitude = null; }}>
            Clear
          </button>
          <button type="button" class="rounded-xl bg-slate-900 px-4 py-2 text-xs font-semibold uppercase tracking-[0.18em] text-white" on:click={applyLocationModal}>
            Apply
          </button>
        </div>
      </div>
    </div>
  </div>
{/if}
