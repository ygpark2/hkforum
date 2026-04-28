<script>
  import { onMount } from 'svelte';
  import { page } from '$app/stores';
  import LeafletMap from '$lib/components/LeafletMap.svelte';
  import PageEmpty from '$lib/components/PageEmpty.svelte';
  import { apiFetch, sendJson } from '$lib/utils/api';
  import { formatDate, relativeTime } from '$lib/utils/time';

  let listing = null;
  let loading = true;
  let error = '';
  let inquiry = { name: '', email: '', phone: '', message: '' };
  let report = { name: '', email: '', reason: 'wrong_info', details: '' };
  let submittingInquiry = false;
  let submittingReport = false;

  function priceSummary(item) {
    if (item?.price === null || item?.price === undefined) return '가격 문의';
    return `${item.currency || ''} ${Number(item.price).toLocaleString()}${item.pricePeriod ? `/${item.pricePeriod}` : ''}`.trim();
  }

  function locationSummary(item) {
    return [item?.suburb, item?.city, item?.state, item?.countryCode].filter(Boolean).join(', ') || 'Location TBA';
  }

  async function loadListing() {
    loading = true;
    error = '';
    try {
      const payload = await apiFetch(`/api/v1/real-estate/${$page.params.id}`);
      listing = payload.listing;
    } catch (err) {
      error = err.message;
    } finally {
      loading = false;
    }
  }

  async function submitInquiry() {
    if (!listing || submittingInquiry) return;
    submittingInquiry = true;
    try {
      await sendJson(`/api/v1/real-estate/${listing.id}/inquiries`, { body: inquiry });
      inquiry = { name: '', email: '', phone: '', message: '' };
      window.alert('문의가 등록되었습니다.');
    } catch (err) {
      window.alert(err.message);
    } finally {
      submittingInquiry = false;
    }
  }

  async function submitReport() {
    if (!listing || submittingReport) return;
    submittingReport = true;
    try {
      await sendJson(`/api/v1/real-estate/${listing.id}/reports`, { body: { ...report, phone: undefined } });
      report = { name: '', email: '', reason: 'wrong_info', details: '' };
      window.alert('신고가 접수되었습니다.');
    } catch (err) {
      window.alert(err.message);
    } finally {
      submittingReport = false;
    }
  }

  onMount(loadListing);
</script>

<section class="min-h-full bg-slate-50">
  {#if loading}
    <div class="p-6 text-sm text-slate-500">Loading listing…</div>
  {:else if error}
    <div class="p-6"><PageEmpty title="매물을 찾을 수 없습니다." description={error} /></div>
  {:else if listing}
    <div class="mx-auto grid max-w-6xl gap-5 p-5 lg:grid-cols-[minmax(0,1fr)_22rem]">
      <main class="space-y-5">
        <article class="rounded-3xl border border-slate-200 bg-white p-5 shadow-sm">
          {#if listing.images?.length}
            <div class="grid gap-2 sm:grid-cols-3">
              {#each listing.images as image}
                <img src={image.url} alt={image.caption || listing.title} class="h-56 w-full rounded-2xl object-cover" />
              {/each}
            </div>
          {/if}
          <div class="mt-5 flex flex-wrap items-start justify-between gap-4">
            <div>
              <div class="text-xs font-semibold uppercase tracking-[0.18em] text-slate-500">{listing.listingType} · {listing.propertyType}</div>
              <h1 class="mt-2 text-3xl font-semibold text-slate-900">{listing.title}</h1>
              <p class="mt-2 text-sm text-slate-500">{locationSummary(listing)} · posted {relativeTime(listing.createdAt)}</p>
            </div>
            <div class="text-right text-2xl font-bold text-slate-900">{priceSummary(listing)}</div>
          </div>
          <div class="mt-5 grid grid-cols-2 gap-2 text-sm text-slate-700 sm:grid-cols-4">
            <span class="rounded-2xl bg-slate-50 px-3 py-2">{listing.bedrooms ?? '-'} bed</span>
            <span class="rounded-2xl bg-slate-50 px-3 py-2">{listing.bathrooms ?? '-'} bath</span>
            <span class="rounded-2xl bg-slate-50 px-3 py-2">{listing.parkingSpaces ?? '-'} parking</span>
            <span class="rounded-2xl bg-slate-50 px-3 py-2">{listing.floorAreaSqm ?? '-'} sqm</span>
          </div>
          <p class="mt-5 whitespace-pre-wrap break-words text-sm leading-7 text-slate-700">{listing.content}</p>
          {#if listing.features?.length}
            <div class="mt-5 flex flex-wrap gap-2">
              {#each listing.features as feature}
                <span class="rounded-full bg-emerald-50 px-3 py-1 text-xs font-semibold text-emerald-700">{feature}</span>
              {/each}
            </div>
          {/if}
        </article>

        {#if listing.latitude != null && listing.longitude != null}
          <LeafletMap markers={[{ title: listing.title, subtitle: locationSummary(listing), latitude: listing.latitude, longitude: listing.longitude }]} heightClass="h-96" />
        {/if}
      </main>

      <aside class="space-y-4">
        <section class="rounded-3xl border border-slate-200 bg-white p-5 shadow-sm">
          <h2 class="text-lg font-semibold text-slate-900">Contact</h2>
          <p class="mt-2 text-sm text-slate-500">{listing.contactName || 'Listing contact'}</p>
          <form class="mt-4 space-y-3" on:submit|preventDefault={submitInquiry}>
            <input bind:value={inquiry.name} required class="w-full rounded-xl border border-slate-200 px-3 py-2 text-sm" placeholder="Name" />
            <input bind:value={inquiry.email} required type="email" class="w-full rounded-xl border border-slate-200 px-3 py-2 text-sm" placeholder="Email" />
            <input bind:value={inquiry.phone} class="w-full rounded-xl border border-slate-200 px-3 py-2 text-sm" placeholder="Phone" />
            <textarea bind:value={inquiry.message} required rows="5" class="w-full rounded-xl border border-slate-200 px-3 py-2 text-sm" placeholder="문의 내용을 입력하세요."></textarea>
            <button class="w-full rounded-xl bg-slate-900 px-4 py-2 text-xs font-semibold uppercase tracking-[0.18em] text-white" disabled={submittingInquiry}>{submittingInquiry ? 'Sending…' : 'Send inquiry'}</button>
          </form>
        </section>

        <section class="rounded-3xl border border-rose-100 bg-white p-5 shadow-sm">
          <h2 class="text-lg font-semibold text-slate-900">Report listing</h2>
          <form class="mt-4 space-y-3" on:submit|preventDefault={submitReport}>
            <select bind:value={report.reason} class="w-full rounded-xl border border-slate-200 px-3 py-2 text-sm">
              <option value="wrong_info">Wrong information</option>
              <option value="fraud">Fraud</option>
              <option value="duplicate">Duplicate</option>
              <option value="unavailable">Unavailable</option>
              <option value="spam">Spam</option>
              <option value="other">Other</option>
            </select>
            <input bind:value={report.name} class="w-full rounded-xl border border-slate-200 px-3 py-2 text-sm" placeholder="Name optional" />
            <input bind:value={report.email} type="email" class="w-full rounded-xl border border-slate-200 px-3 py-2 text-sm" placeholder="Email optional" />
            <textarea bind:value={report.details} rows="4" class="w-full rounded-xl border border-slate-200 px-3 py-2 text-sm" placeholder="Details"></textarea>
            <button class="w-full rounded-xl border border-rose-200 px-4 py-2 text-xs font-semibold uppercase tracking-[0.18em] text-rose-700" disabled={submittingReport}>{submittingReport ? 'Submitting…' : 'Report'}</button>
          </form>
        </section>
      </aside>
    </div>
  {/if}
</section>
