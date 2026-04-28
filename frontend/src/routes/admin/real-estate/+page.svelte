<script>
  import { onMount } from 'svelte';
  import PageEmpty from '$lib/components/PageEmpty.svelte';
  import { apiFetch, sendJson } from '$lib/utils/api';
  import { relativeTime } from '$lib/utils/time';

  let loading = true;
  let error = '';
  let listings = [];
  let reports = [];
  let agentProfiles = [];
  let updatingId = null;

  async function loadDashboard() {
    loading = true;
    error = '';
    try {
      const payload = await apiFetch('/api/v1/real-estate-dashboard');
      listings = payload.listings || [];
      reports = payload.reports || [];
      agentProfiles = payload.agentProfiles || [];
    } catch (err) {
      error = err.message;
    } finally {
      loading = false;
    }
  }

  async function listingAction(listing, action) {
    updatingId = `listing-${listing.id}`;
    try {
      const payload = await sendJson(`/api/v1/real-estate/${listing.id}/${action}`, { method: 'POST' });
      listings = listings.map((item) => (item.id === listing.id ? payload.listing : item));
    } catch (err) {
      window.alert(err.message);
    } finally {
      updatingId = null;
    }
  }

  async function updateReport(report, status) {
    updatingId = `report-${report.id}`;
    try {
      const payload = await sendJson(`/api/v1/real-estate-report/${report.id}`, { method: 'PATCH', body: { status } });
      reports = reports.map((item) => (item.id === report.id ? payload.report : item));
    } catch (err) {
      window.alert(err.message);
    } finally {
      updatingId = null;
    }
  }

  onMount(loadDashboard);
</script>

<section class="min-h-full bg-slate-50 p-5">
  <div class="mb-5 flex flex-wrap items-start justify-between gap-4">
    <div>
      <h1 class="text-3xl font-semibold text-slate-900">Real Estate Admin</h1>
      <p class="mt-1 text-sm text-slate-500">매물 승인, 신고 처리, 중개업자 프로필을 관리합니다.</p>
    </div>
    <a href="/real-estate" class="rounded-xl border border-slate-200 bg-white px-4 py-2 text-xs font-semibold uppercase tracking-[0.18em] text-slate-700">Public page</a>
  </div>

  {#if loading}
    <div class="text-sm text-slate-500">Loading real estate admin…</div>
  {:else if error}
    <PageEmpty title="접근할 수 없습니다." description={error} />
  {:else}
    <div class="grid gap-5 xl:grid-cols-[minmax(0,1fr)_24rem]">
      <main class="space-y-5">
        <section class="rounded-3xl border border-slate-200 bg-white p-5">
          <h2 class="text-xl font-semibold text-slate-900">Listings</h2>
          <div class="mt-4 divide-y divide-slate-200 rounded-2xl border border-slate-200">
            {#each listings as listing}
              <article class="p-4">
                <div class="flex flex-wrap items-start justify-between gap-3">
                  <div>
                    <a href={`/real-estate/${listing.id}`} class="text-sm font-semibold text-slate-900 underline underline-offset-4">{listing.title}</a>
                    <p class="mt-1 text-xs text-slate-500">{listing.status} · {listing.city || ''} {listing.suburb || ''} · {relativeTime(listing.createdAt)}</p>
                  </div>
                  <div class="flex flex-wrap gap-2">
                    {#if listing.status !== 'published'}
                      <button class="rounded-lg border border-emerald-200 px-3 py-1.5 text-xs font-semibold text-emerald-700" disabled={updatingId === `listing-${listing.id}`} on:click={() => listingAction(listing, 'approve')}>Approve</button>
                    {/if}
                    {#if listing.status !== 'rejected'}
                      <button class="rounded-lg border border-rose-200 px-3 py-1.5 text-xs font-semibold text-rose-700" disabled={updatingId === `listing-${listing.id}`} on:click={() => listingAction(listing, 'reject')}>Reject</button>
                    {/if}
                    {#if listing.status === 'expired'}
                      <button class="rounded-lg border border-slate-200 px-3 py-1.5 text-xs font-semibold text-slate-700" disabled={updatingId === `listing-${listing.id}`} on:click={() => listingAction(listing, 'republish')}>Republish</button>
                    {/if}
                  </div>
                </div>
              </article>
            {/each}
          </div>
        </section>

        <section class="rounded-3xl border border-slate-200 bg-white p-5">
          <h2 class="text-xl font-semibold text-slate-900">Reports</h2>
          <div class="mt-4 divide-y divide-slate-200 rounded-2xl border border-slate-200">
            {#each reports as report}
              <article class="p-4">
                <div class="flex flex-wrap items-start justify-between gap-3">
                  <div>
                    <p class="text-sm font-semibold text-slate-900">{report.reason} · listing #{report.listingId}</p>
                    <p class="mt-1 text-xs text-slate-500">{report.status} · {relativeTime(report.createdAt)}</p>
                    {#if report.details}<p class="mt-2 whitespace-pre-wrap text-sm text-slate-700">{report.details}</p>{/if}
                  </div>
                  <select class="rounded-xl border border-slate-200 px-3 py-2 text-sm" value={report.status} disabled={updatingId === `report-${report.id}`} on:change={(event) => updateReport(report, event.currentTarget.value)}>
                    <option value="new">New</option>
                    <option value="reviewing">Reviewing</option>
                    <option value="resolved">Resolved</option>
                    <option value="dismissed">Dismissed</option>
                  </select>
                </div>
              </article>
            {/each}
          </div>
        </section>
      </main>

      <aside class="rounded-3xl border border-slate-200 bg-white p-5">
        <h2 class="text-xl font-semibold text-slate-900">Agent Profiles</h2>
        <div class="mt-4 space-y-3">
          {#each agentProfiles as profile}
            <article class="rounded-2xl border border-slate-200 p-3">
              <div class="text-sm font-semibold text-slate-900">{profile.agencyName}</div>
              <p class="mt-1 text-xs text-slate-500">user #{profile.userId} · {profile.verified ? 'verified' : 'unverified'}</p>
              {#if profile.licenseNumber}<p class="mt-2 text-xs text-slate-600">License: {profile.licenseNumber}</p>{/if}
              {#if profile.email}<p class="mt-1 text-xs text-slate-600">{profile.email}</p>{/if}
            </article>
          {/each}
        </div>
      </aside>
    </div>
  {/if}
</section>
