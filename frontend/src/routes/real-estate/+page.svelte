<script>
  import { onMount } from 'svelte';
  import LeafletMap from '$lib/components/LeafletMap.svelte';
  import PageEmpty from '$lib/components/PageEmpty.svelte';
  import { bootstrap } from '$lib/stores/bootstrap';
  import { apiFetch, sendJson, uploadFile } from '$lib/utils/api';
  import { formatDate, relativeTime } from '$lib/utils/time';

  const listingTypeOptions = [
    { value: 'rent', label: 'Rent' },
    { value: 'sale', label: 'Sale' },
    { value: 'share', label: 'Share' },
    { value: 'short_term', label: 'Short term' }
  ];
  const propertyTypeOptions = [
    { value: 'apartment', label: 'Apartment' },
    { value: 'house', label: 'House' },
    { value: 'townhouse', label: 'Townhouse' },
    { value: 'studio', label: 'Studio' },
    { value: 'room', label: 'Room' },
    { value: 'land', label: 'Land' },
    { value: 'commercial', label: 'Commercial' }
  ];
  const pricePeriodOptions = [
    { value: 'weekly', label: 'Weekly' },
    { value: 'monthly', label: 'Monthly' },
    { value: 'total', label: 'Total' }
  ];
  const inquiryStatusOptions = [
    { value: 'new', label: 'New' },
    { value: 'replied', label: 'Replied' },
    { value: 'closed', label: 'Closed' }
  ];

  let items = [];
  let loading = true;
  let open = false;
  let submitting = false;
  let editingListingId = null;
  let deletingListingId = null;
  let inquiryOpen = false;
  let inquiryListing = null;
  let inquirySubmitting = false;
  let managerOpen = false;
  let managerListing = null;
  let managerLoading = false;
  let managerInquiries = [];
  let updatingInquiryId = null;
  let uploadingImageListingId = null;
  let deletingImageId = null;
  let mapFilterOpen = false;
  let listingMapOpen = false;
  let quota = null;
  let plans = [];
  let managedListings = [];
  let agentProfile = null;
  let agentProfileForm = { agencyName: '', licenseNumber: '', website: '', phone: '', email: '' };
  let savingAgentProfile = false;
  let updatingApprovalId = null;

  let filters = {
    listingType: '',
    propertyType: '',
    countryCode: '',
    suburb: '',
    q: '',
    sort: '',
    minPrice: '',
    maxPrice: '',
    bedrooms: '',
    latitude: '',
    longitude: '',
    radiusKm: '10'
  };

  let form = initialForm();
  let inquiryForm = initialInquiryForm();

  function initialForm() {
    return {
      title: '',
      listingType: 'rent',
      propertyType: 'apartment',
      countryCode: 'AUS',
      state: '',
      city: '',
      suburb: '',
      addressText: '',
      latitude: null,
      longitude: null,
      currency: 'AUD',
      price: '',
      pricePeriod: 'weekly',
      bondAmount: '',
      depositAmount: '',
      bedrooms: '',
      bathrooms: '',
      parkingSpaces: '',
      floorAreaSqm: '',
      landAreaSqm: '',
      availableFrom: '',
      leaseTerm: '',
      petsAllowed: '',
      furnished: '',
      billsIncluded: '',
      features: '',
      contactName: '',
      contactEmail: '',
      contactPhone: '',
      content: ''
    };
  }

  function initialInquiryForm() {
    return { name: '', email: '', phone: '', message: '' };
  }

  function optionLabel(options, value) {
    return options.find((option) => option.value === value)?.label || value;
  }

  function numberOrNull(value) {
    if (value === '' || value === null || value === undefined) return null;
    return Number(value);
  }

  function boolOrNull(value) {
    if (value === '' || value === null || value === undefined) return null;
    return value === 'true';
  }

  function csvList(value) {
    return value
      .split(',')
      .map((item) => item.trim())
      .filter(Boolean);
  }

  function buildQuery() {
    const params = new URLSearchParams();
    Object.entries(filters).forEach(([key, value]) => {
      if (value !== '' && value !== null && value !== undefined) params.set(key, value);
    });
    const query = params.toString();
    return query ? `?${query}` : '';
  }

  function clearFilters() {
    filters = {
      listingType: '',
      propertyType: '',
      countryCode: '',
      suburb: '',
      q: '',
      sort: '',
      minPrice: '',
      maxPrice: '',
      bedrooms: '',
      latitude: '',
      longitude: '',
      radiusKm: '10'
    };
    mapFilterOpen = false;
    loadListings();
  }

  function clearMapFilter() {
    filters.latitude = '';
    filters.longitude = '';
    filters.radiusKm = '10';
    loadListings();
  }

  function resetForm() {
    form = initialForm();
    editingListingId = null;
    listingMapOpen = false;
  }

  function priceSummary(listing) {
    if (listing.price === null || listing.price === undefined) return '가격 문의';
    const currency = listing.currency || '';
    const period = listing.pricePeriod ? `/${optionLabel(pricePeriodOptions, listing.pricePeriod).toLowerCase()}` : '';
    return `${currency} ${Number(listing.price).toLocaleString()}${period}`.trim();
  }

  function locationSummary(listing) {
    return [listing.suburb, listing.city, listing.state, listing.countryCode].filter(Boolean).join(', ') || 'Location TBA';
  }

  function distanceSummary(listing) {
    if (listing.distanceKm === null || listing.distanceKm === undefined) return '';
    if (listing.distanceKm < 1) return `${Math.round(listing.distanceKm * 1000)}m away`;
    return `${Number(listing.distanceKm).toFixed(1)}km away`;
  }

  function listingMarkers() {
    return items
      .filter((listing) => listing.latitude !== null && listing.latitude !== undefined && listing.longitude !== null && listing.longitude !== undefined)
      .map((listing) => ({
        title: listing.title,
        subtitle: locationSummary(listing),
        latitude: listing.latitude,
        longitude: listing.longitude,
        url: '#'
      }));
  }

  function canManage(listing) {
    return $bootstrap.viewer && ($bootstrap.viewer.id === listing.authorId || $bootstrap.viewer.role === 'admin');
  }

  function canCreateListing() {
    return $bootstrap.viewer && ($bootstrap.viewer.role === 'admin' || $bootstrap.viewer.accountType === 'real_estate' || $bootstrap.viewer.realEstatePlan);
  }

  function quotaLabel() {
    if (!quota?.monthlyListingLimit) return `${quota?.usedThisMonth || 0} / 협의`;
    return `${quota.usedThisMonth} / ${quota.monthlyListingLimit}`;
  }

  function statusLabel(status) {
    if (status === 'pending') return 'Pending approval';
    if (status === 'rejected') return 'Rejected';
    if (status === 'expired') return 'Expired';
    if (status === 'published') return 'Published';
    return status || 'Unknown';
  }

  function statusBadgeClass(status) {
    if (status === 'published') return 'bg-emerald-50 text-emerald-700';
    if (status === 'rejected') return 'bg-rose-50 text-rose-700';
    if (status === 'expired') return 'bg-slate-200 text-slate-700';
    return 'bg-amber-50 text-amber-700';
  }

  async function loadListings() {
    loading = true;
    try {
      const payload = await apiFetch(`/api/v1/real-estate${buildQuery()}`);
      items = payload.items || [];
    } finally {
      loading = false;
    }
  }

  async function loadRealEstateDashboard() {
    if (!canCreateListing()) {
      quota = null;
      plans = [];
      return;
    }
    try {
      const payload = await apiFetch('/api/v1/real-estate-dashboard');
      quota = payload.quota;
      plans = payload.plans || [];
      managedListings = payload.listings || [];
      agentProfile = payload.agentProfiles?.[0] || null;
      agentProfileForm = {
        agencyName: agentProfile?.agencyName || '',
        licenseNumber: agentProfile?.licenseNumber || '',
        website: agentProfile?.website || '',
        phone: agentProfile?.phone || '',
        email: agentProfile?.email || ''
      };
    } catch {
      quota = null;
      plans = [];
      managedListings = [];
      agentProfile = null;
    }
  }

  async function saveAgentProfile() {
    if (savingAgentProfile) return;
    savingAgentProfile = true;
    try {
      const payload = await sendJson('/api/v1/real-estate-agent-profile', {
        method: 'PUT',
        body: {
          agencyName: agentProfileForm.agencyName,
          licenseNumber: agentProfileForm.licenseNumber || null,
          website: agentProfileForm.website || null,
          phone: agentProfileForm.phone || null,
          email: agentProfileForm.email || null
        }
      });
      agentProfile = payload.profile;
      window.alert('중개업자 프로필이 저장되었습니다.');
    } catch (error) {
      window.alert(error.message);
    } finally {
      savingAgentProfile = false;
    }
  }

  function buildPayload() {
    return {
      title: form.title,
      listingType: form.listingType,
      propertyType: form.propertyType,
      countryCode: form.countryCode || null,
      state: form.state || null,
      city: form.city || null,
      suburb: form.suburb || null,
      addressText: form.addressText || null,
      latitude: form.latitude === null || form.latitude === '' ? null : Number(form.latitude),
      longitude: form.longitude === null || form.longitude === '' ? null : Number(form.longitude),
      currency: form.currency || null,
      price: numberOrNull(form.price),
      pricePeriod: form.pricePeriod || null,
      bondAmount: numberOrNull(form.bondAmount),
      depositAmount: numberOrNull(form.depositAmount),
      bedrooms: numberOrNull(form.bedrooms),
      bathrooms: numberOrNull(form.bathrooms),
      parkingSpaces: numberOrNull(form.parkingSpaces),
      floorAreaSqm: numberOrNull(form.floorAreaSqm),
      landAreaSqm: numberOrNull(form.landAreaSqm),
      availableFrom: form.availableFrom || null,
      leaseTerm: form.leaseTerm || null,
      petsAllowed: boolOrNull(form.petsAllowed),
      furnished: boolOrNull(form.furnished),
      billsIncluded: boolOrNull(form.billsIncluded),
      features: csvList(form.features),
      contactName: form.contactName || null,
      contactEmail: form.contactEmail || null,
      contactPhone: form.contactPhone || null,
      content: form.content
    };
  }

  async function submitListing() {
    if (submitting) return;
    submitting = true;
    try {
      const payload = { body: buildPayload() };
      if (editingListingId) {
        await sendJson(`/api/v1/real-estate/${editingListingId}`, { method: 'PATCH', ...payload });
      } else {
        await sendJson('/api/v1/real-estate', payload);
      }
      resetForm();
      open = false;
      await loadListings();
      await loadRealEstateDashboard();
    } catch (error) {
      window.alert(error.message);
    } finally {
      submitting = false;
    }
  }

  function openCreateListing() {
    resetForm();
    open = true;
  }

  function openEditListing(listing) {
    editingListingId = listing.id;
    form = {
      title: listing.title || '',
      listingType: listing.listingType || 'rent',
      propertyType: listing.propertyType || 'apartment',
      countryCode: listing.countryCode || 'AUS',
      state: listing.state || '',
      city: listing.city || '',
      suburb: listing.suburb || '',
      addressText: listing.addressText || '',
      latitude: listing.latitude ?? null,
      longitude: listing.longitude ?? null,
      currency: listing.currency || 'AUD',
      price: listing.price ?? '',
      pricePeriod: listing.pricePeriod || '',
      bondAmount: listing.bondAmount ?? '',
      depositAmount: listing.depositAmount ?? '',
      bedrooms: listing.bedrooms ?? '',
      bathrooms: listing.bathrooms ?? '',
      parkingSpaces: listing.parkingSpaces ?? '',
      floorAreaSqm: listing.floorAreaSqm ?? '',
      landAreaSqm: listing.landAreaSqm ?? '',
      availableFrom: listing.availableFrom || '',
      leaseTerm: listing.leaseTerm || '',
      petsAllowed: listing.petsAllowed === null || listing.petsAllowed === undefined ? '' : String(listing.petsAllowed),
      furnished: listing.furnished === null || listing.furnished === undefined ? '' : String(listing.furnished),
      billsIncluded: listing.billsIncluded === null || listing.billsIncluded === undefined ? '' : String(listing.billsIncluded),
      features: (listing.features || []).join(', '),
      contactName: listing.contactName || '',
      contactEmail: listing.contactEmail || '',
      contactPhone: listing.contactPhone || '',
      content: listing.content || ''
    };
    open = true;
  }

  async function deleteListing(listingId) {
    if (deletingListingId || !window.confirm('Delete this real estate listing?')) return;
    deletingListingId = listingId;
    try {
      await sendJson(`/api/v1/real-estate/${listingId}`, { method: 'DELETE' });
      items = items.filter((listing) => listing.id !== listingId);
      managedListings = managedListings.filter((listing) => listing.id !== listingId);
    } catch (error) {
      window.alert(error.message);
    } finally {
      deletingListingId = null;
    }
  }

  async function updateListingApproval(listing, action) {
    if (updatingApprovalId) return;
    updatingApprovalId = listing.id;
    try {
      const payload = await sendJson(`/api/v1/real-estate/${listing.id}/${action}`, { method: 'POST' });
      managedListings = managedListings.map((item) => (item.id === listing.id ? payload.listing : item));
      if (payload.listing.status === 'published') {
        await loadListings();
      } else {
        items = items.filter((item) => item.id !== listing.id);
      }
      await loadRealEstateDashboard();
    } catch (error) {
      window.alert(error.message);
    } finally {
      updatingApprovalId = null;
    }
  }

  async function uploadListingImage(listing, file) {
    if (!file || uploadingImageListingId) return;
    uploadingImageListingId = listing.id;
    try {
      const uploaded = await uploadFile('/api/v1/uploads', file);
      const payload = await sendJson(`/api/v1/real-estate/${listing.id}/images`, {
        body: {
          fileKey: uploaded.key,
          caption: file.name,
          sortOrder: listing.images?.length || 0
        }
      });
      items = items.map((item) => (
        item.id === listing.id
          ? { ...item, images: [...(item.images || []), payload.image] }
          : item
      ));
    } catch (error) {
      window.alert(error.message);
    } finally {
      uploadingImageListingId = null;
    }
  }

  async function deleteListingImage(listing, image) {
    if (deletingImageId || !window.confirm('Delete this image?')) return;
    deletingImageId = image.id;
    try {
      await sendJson(`/api/v1/real-estate/${listing.id}/images/${image.id}`, { method: 'DELETE' });
      items = items.map((item) => (
        item.id === listing.id
          ? { ...item, images: (item.images || []).filter((candidate) => candidate.id !== image.id) }
          : item
      ));
    } catch (error) {
      window.alert(error.message);
    } finally {
      deletingImageId = null;
    }
  }

  function openInquiry(listing) {
    inquiryListing = listing;
    inquiryForm = initialInquiryForm();
    inquiryOpen = true;
  }

  async function submitInquiry() {
    if (!inquiryListing || inquirySubmitting) return;
    inquirySubmitting = true;
    try {
      await sendJson(`/api/v1/real-estate/${inquiryListing.id}/inquiries`, {
        body: {
          name: inquiryForm.name,
          email: inquiryForm.email,
          phone: inquiryForm.phone || null,
          message: inquiryForm.message
        }
      });
      inquiryOpen = false;
      inquiryListing = null;
      inquiryForm = initialInquiryForm();
      window.alert('문의가 등록되었습니다.');
    } catch (error) {
      window.alert(error.message);
    } finally {
      inquirySubmitting = false;
    }
  }

  async function openManager(listing) {
    managerListing = listing;
    managerOpen = true;
    await loadInquiries();
  }

  async function loadInquiries() {
    if (!managerListing) return;
    managerLoading = true;
    try {
      const payload = await apiFetch(`/api/v1/real-estate/${managerListing.id}/inquiries`);
      managerInquiries = payload.items || [];
    } catch (error) {
      window.alert(error.message);
      managerOpen = false;
      managerListing = null;
    } finally {
      managerLoading = false;
    }
  }

  async function updateInquiry(inquiry, status) {
    if (!managerListing || updatingInquiryId) return;
    updatingInquiryId = inquiry.id;
    try {
      const payload = await sendJson(`/api/v1/real-estate/${managerListing.id}/inquiries/${inquiry.id}`, {
        method: 'PATCH',
        body: { status }
      });
      managerInquiries = managerInquiries.map((item) => (item.id === inquiry.id ? payload.inquiry : item));
    } catch (error) {
      window.alert(error.message);
    } finally {
      updatingInquiryId = null;
    }
  }

  onMount(async () => {
    await loadListings();
    await loadRealEstateDashboard();
  });
</script>

<section class="flex h-full min-h-0 flex-col bg-white">
  <div class="shrink-0 border-b border-slate-200 px-4 py-3.5">
    <div class="flex flex-wrap items-start justify-between gap-4">
      <div>
        <h1 class="text-3xl font-semibold text-slate-900">Real Estate</h1>
        <p class="mt-1 text-sm text-slate-500">호주/유럽 기준 임대, 매매, 쉐어, 단기 숙소 매물을 관리합니다.</p>
      </div>
      {#if canCreateListing()}
        <button type="button" class="rounded-lg bg-slate-900 px-3 py-1.5 text-xs font-semibold uppercase tracking-[0.2em] text-white transition hover:bg-slate-800" on:click={openCreateListing}>New Listing</button>
      {:else if $bootstrap.auth?.isAuthenticated}
        <a href="/register" class="rounded-lg border border-slate-900 px-3 py-1.5 text-xs font-semibold uppercase tracking-[0.2em] text-slate-900 transition hover:bg-slate-900 hover:text-white">Agent plan required</a>
      {:else}
        <a href="/login" class="rounded-lg border border-slate-900 px-3 py-1.5 text-xs font-semibold uppercase tracking-[0.2em] text-slate-900 transition hover:bg-slate-900 hover:text-white">Login to post</a>
      {/if}
    </div>

    {#if quota}
      <div class="mt-4 grid gap-3 rounded-2xl border border-slate-200 bg-white p-3 md:grid-cols-[1fr_auto]">
        <div>
          <div class="text-xs font-semibold uppercase tracking-[0.18em] text-slate-500">Real estate plan</div>
          <div class="mt-1 text-lg font-semibold text-slate-900">{quota.plan?.name} · {quota.plan?.description}</div>
        </div>
        <div class="rounded-xl bg-slate-50 px-4 py-3 text-sm font-semibold text-slate-900">{quotaLabel()} listings this month</div>
      </div>
      {#if managedListings.length}
        <div class="mt-3 rounded-2xl border border-slate-200 bg-white p-3">
          <div class="flex flex-wrap items-center justify-between gap-3">
            <div>
              <div class="text-xs font-semibold uppercase tracking-[0.18em] text-slate-500">Approval workflow</div>
              <p class="mt-1 text-sm text-slate-500">신규 매물은 승인 전까지 공개 목록에 노출되지 않습니다.</p>
            </div>
            <div class="text-xs font-semibold text-slate-500">{managedListings.length} managed listings</div>
          </div>
          <div class="mt-3 grid gap-2 md:grid-cols-2">
            {#each managedListings as listing}
              <article class="rounded-xl border border-slate-200 bg-slate-50 p-3">
                <div class="flex items-start justify-between gap-3">
                  <div class="min-w-0">
                    <div class="truncate text-sm font-semibold text-slate-900">{listing.title}</div>
                    <div class="mt-1 text-xs text-slate-500">{locationSummary(listing)} · {relativeTime(listing.createdAt)}</div>
                  </div>
                  <span class={`shrink-0 rounded-full px-2.5 py-1 text-[11px] font-semibold ${statusBadgeClass(listing.status)}`}>{statusLabel(listing.status)}</span>
                </div>
                {#if listing.expiresAt}
                  <p class="mt-2 text-xs text-slate-500">Expires {relativeTime(listing.expiresAt)}</p>
                {/if}
                {#if $bootstrap.viewer?.role === 'admin'}
                  <div class="mt-3 flex flex-wrap gap-2">
                    {#if listing.status !== 'published'}
                      <button type="button" class="rounded-lg border border-emerald-200 bg-white px-3 py-1.5 text-xs font-semibold uppercase tracking-[0.15em] text-emerald-700 transition hover:bg-emerald-50" disabled={updatingApprovalId === listing.id} on:click={() => updateListingApproval(listing, 'approve')}>
                        {updatingApprovalId === listing.id ? 'Saving…' : 'Approve'}
                      </button>
                    {/if}
                    {#if listing.status !== 'rejected'}
                      <button type="button" class="rounded-lg border border-rose-200 bg-white px-3 py-1.5 text-xs font-semibold uppercase tracking-[0.15em] text-rose-700 transition hover:bg-rose-50" disabled={updatingApprovalId === listing.id} on:click={() => updateListingApproval(listing, 'reject')}>
                        {updatingApprovalId === listing.id ? 'Saving…' : 'Reject'}
                      </button>
                    {/if}
                  </div>
                {/if}
                {#if canManage(listing)}
                  <div class="mt-3 flex flex-wrap gap-2">
                    {#if listing.status === 'expired' || listing.status === 'rejected'}
                      <button type="button" class="rounded-lg border border-slate-300 bg-white px-3 py-1.5 text-xs font-semibold uppercase tracking-[0.15em] text-slate-700 transition hover:bg-slate-100" disabled={updatingApprovalId === listing.id} on:click={() => updateListingApproval(listing, 'republish')}>
                        {updatingApprovalId === listing.id ? 'Saving…' : 'Republish'}
                      </button>
                    {/if}
                    <button type="button" class="rounded-lg border border-slate-200 bg-white px-3 py-1.5 text-xs font-semibold uppercase tracking-[0.15em] text-slate-700 transition hover:bg-slate-50" on:click={() => openEditListing(listing)}>Edit</button>
                    <button type="button" class="rounded-lg border border-rose-200 bg-white px-3 py-1.5 text-xs font-semibold uppercase tracking-[0.15em] text-rose-700 transition hover:bg-rose-50" disabled={deletingListingId === listing.id} on:click={() => deleteListing(listing.id)}>
                      {deletingListingId === listing.id ? 'Deleting…' : 'Delete'}
                    </button>
                  </div>
                {/if}
              </article>
            {/each}
          </div>
        </div>
      {/if}
      <form class="mt-3 grid gap-2 rounded-2xl border border-slate-200 bg-white p-3 md:grid-cols-5" on:submit|preventDefault={saveAgentProfile}>
        <div class="md:col-span-5">
          <div class="text-xs font-semibold uppercase tracking-[0.18em] text-slate-500">Agent profile</div>
          <p class="mt-1 text-sm text-slate-500">중개업소명, 라이선스, 연락처를 저장합니다.</p>
        </div>
        <input bind:value={agentProfileForm.agencyName} required class="rounded-xl border border-slate-200 px-3 py-2 text-sm" placeholder="Agency name" />
        <input bind:value={agentProfileForm.licenseNumber} class="rounded-xl border border-slate-200 px-3 py-2 text-sm" placeholder="License number" />
        <input bind:value={agentProfileForm.website} class="rounded-xl border border-slate-200 px-3 py-2 text-sm" placeholder="Website" />
        <input bind:value={agentProfileForm.phone} class="rounded-xl border border-slate-200 px-3 py-2 text-sm" placeholder="Phone" />
        <button class="rounded-xl bg-slate-900 px-3 py-2 text-xs font-semibold uppercase tracking-[0.16em] text-white" disabled={savingAgentProfile}>{savingAgentProfile ? 'Saving…' : 'Save profile'}</button>
      </form>
    {:else if $bootstrap.auth?.isAuthenticated && !canCreateListing()}
      <div class="mt-4 rounded-2xl border border-amber-200 bg-amber-50 p-3 text-sm text-amber-800">
        부동산 매물 등록은 부동산 중개업자 유료 회원 또는 관리자만 가능합니다. 플랜: 월 10만원 10개, 월 30만원 30개, 월 50만원 70개, 그 이상 협의.
      </div>
    {/if}

    <form class="mt-4 grid grid-cols-1 gap-2 rounded-2xl border border-slate-200 bg-slate-50 p-3 sm:grid-cols-2 lg:grid-cols-6" on:submit|preventDefault={loadListings}>
      <label class="flex flex-col gap-1 text-xs font-semibold text-slate-600">
        Listing
        <select bind:value={filters.listingType} class="rounded-xl border border-slate-200 bg-white px-3 py-2 text-sm font-normal text-slate-900">
          <option value="">All</option>
          {#each listingTypeOptions as option}
            <option value={option.value}>{option.label}</option>
          {/each}
        </select>
      </label>
      <label class="flex flex-col gap-1 text-xs font-semibold text-slate-600">
        Property
        <select bind:value={filters.propertyType} class="rounded-xl border border-slate-200 bg-white px-3 py-2 text-sm font-normal text-slate-900">
          <option value="">All</option>
          {#each propertyTypeOptions as option}
            <option value={option.value}>{option.label}</option>
          {/each}
        </select>
      </label>
      <label class="flex flex-col gap-1 text-xs font-semibold text-slate-600">
        Country
        <input type="text" bind:value={filters.countryCode} maxlength="3" class="rounded-xl border border-slate-200 bg-white px-3 py-2 text-sm font-normal uppercase text-slate-900" placeholder="AUS" />
      </label>
      <label class="flex flex-col gap-1 text-xs font-semibold text-slate-600">
        Search
        <input type="text" bind:value={filters.q} class="rounded-xl border border-slate-200 bg-white px-3 py-2 text-sm font-normal text-slate-900" placeholder="station, school" />
      </label>
      <label class="flex flex-col gap-1 text-xs font-semibold text-slate-600">
        Suburb
        <input type="text" bind:value={filters.suburb} class="rounded-xl border border-slate-200 bg-white px-3 py-2 text-sm font-normal text-slate-900" placeholder="Chatswood" />
      </label>
      <label class="flex flex-col gap-1 text-xs font-semibold text-slate-600">
        Sort
        <select bind:value={filters.sort} class="rounded-xl border border-slate-200 bg-white px-3 py-2 text-sm font-normal text-slate-900">
          <option value="">Latest</option>
          <option value="price_asc">Price low</option>
          <option value="price_desc">Price high</option>
          <option value="distance">Distance</option>
        </select>
      </label>
      <label class="flex flex-col gap-1 text-xs font-semibold text-slate-600">
        Min price
        <input type="number" min="0" bind:value={filters.minPrice} class="rounded-xl border border-slate-200 bg-white px-3 py-2 text-sm font-normal text-slate-900" placeholder="500" />
      </label>
      <label class="flex flex-col gap-1 text-xs font-semibold text-slate-600">
        Max price
        <input type="number" min="0" bind:value={filters.maxPrice} class="rounded-xl border border-slate-200 bg-white px-3 py-2 text-sm font-normal text-slate-900" placeholder="1200" />
      </label>
      <label class="flex flex-col gap-1 text-xs font-semibold text-slate-600">
        Bedrooms
        <input type="number" min="0" bind:value={filters.bedrooms} class="rounded-xl border border-slate-200 bg-white px-3 py-2 text-sm font-normal text-slate-900" placeholder="2" />
      </label>
      <div class="flex items-end gap-2 lg:col-span-2">
        <button type="submit" class="flex-1 rounded-xl bg-slate-900 px-3 py-2 text-xs font-semibold uppercase tracking-[0.16em] text-white transition hover:bg-slate-800">Filter</button>
        <button type="button" class="rounded-xl border border-slate-200 bg-white px-3 py-2 text-xs font-semibold uppercase tracking-[0.16em] text-slate-600 transition hover:bg-slate-100" on:click={clearFilters}>Clear</button>
      </div>
      <div class="flex flex-wrap items-end gap-2 lg:col-span-4">
        <label class="flex min-w-[9rem] flex-1 flex-col gap-1 text-xs font-semibold text-slate-600">
          Radius km
          <input type="number" min="1" max="1000" step="1" bind:value={filters.radiusKm} class="rounded-xl border border-slate-200 bg-white px-3 py-2 text-sm font-normal text-slate-900" />
        </label>
        <button type="button" class="rounded-xl border border-slate-200 bg-white px-3 py-2 text-xs font-semibold uppercase tracking-[0.16em] text-slate-600 transition hover:bg-slate-100 disabled:cursor-not-allowed disabled:text-slate-300" disabled={!$bootstrap.site?.mapsEnabled} on:click={() => (mapFilterOpen = !mapFilterOpen)}>
          {filters.latitude !== '' && filters.longitude !== '' ? 'Change Map Area' : 'Pick Map Area'}
        </button>
        {#if filters.latitude !== '' && filters.longitude !== ''}
          <button type="button" class="rounded-xl border border-rose-200 bg-white px-3 py-2 text-xs font-semibold uppercase tracking-[0.16em] text-rose-700 transition hover:bg-rose-50" on:click={clearMapFilter}>Clear Map</button>
          <span class="self-center text-xs text-slate-500">{Number(filters.latitude).toFixed(4)}, {Number(filters.longitude).toFixed(4)}</span>
        {/if}
      </div>
      {#if mapFilterOpen && $bootstrap.site?.mapsEnabled}
        <div class="space-y-2 lg:col-span-6">
          <LeafletMap bind:latitude={filters.latitude} bind:longitude={filters.longitude} interactive heightClass="h-72" />
          <p class="text-xs text-slate-500">지도에서 중심점을 선택한 뒤 Filter를 누르면 반경 {filters.radiusKm || 10}km 안의 매물을 검색합니다.</p>
        </div>
      {/if}
    </form>
  </div>

  <div class="min-h-0 flex-1 overflow-y-auto no-scrollbar bg-slate-50/70">
    {#if loading}
      <div class="flex h-full items-center justify-center px-6 text-center text-slate-500">Loading listings…</div>
    {:else if !items.length}
      <PageEmpty title="등록된 부동산 매물이 없습니다." />
    {:else}
      {#if $bootstrap.site?.mapsEnabled && listingMarkers().length}
        <div class="px-4 pt-4">
          <LeafletMap markers={listingMarkers()} heightClass="h-80" />
        </div>
      {/if}
      <ul class="grid grid-cols-1 gap-4 p-4 xl:grid-cols-2">
        {#each items as listing}
          <li class="rounded-3xl border border-slate-200 bg-white p-5 shadow-sm">
            <div class="flex flex-wrap items-start justify-between gap-3">
              <div class="min-w-0">
                <div class="flex flex-wrap gap-2 text-xs font-semibold">
                  <span class="rounded-full bg-slate-900 px-2.5 py-1 text-white">{optionLabel(listingTypeOptions, listing.listingType)}</span>
                  <span class="rounded-full bg-slate-100 px-2.5 py-1 text-slate-700">{optionLabel(propertyTypeOptions, listing.propertyType)}</span>
                </div>
                <h2 class="mt-3 break-words text-xl font-semibold text-slate-900">
                  <a class="transition hover:text-slate-600" href={`/real-estate/${listing.id}`}>{listing.title}</a>
                </h2>
                <p class="mt-1 text-sm text-slate-500">{locationSummary(listing)}</p>
                {#if distanceSummary(listing)}
                  <p class="mt-1 text-xs font-semibold text-slate-600">{distanceSummary(listing)}</p>
                {/if}
              </div>
              <div class="text-right">
                <p class="text-lg font-bold text-slate-900">{priceSummary(listing)}</p>
                <p class="mt-1 text-xs text-slate-400">{relativeTime(listing.createdAt)}</p>
              </div>
            </div>

            <div class="mt-4 grid grid-cols-2 gap-2 text-sm text-slate-700 sm:grid-cols-4">
              <span class="rounded-2xl bg-slate-50 px-3 py-2">{listing.bedrooms ?? '-'} bed</span>
              <span class="rounded-2xl bg-slate-50 px-3 py-2">{listing.bathrooms ?? '-'} bath</span>
              <span class="rounded-2xl bg-slate-50 px-3 py-2">{listing.parkingSpaces ?? '-'} parking</span>
              <span class="rounded-2xl bg-slate-50 px-3 py-2">{listing.floorAreaSqm ?? '-'} sqm</span>
            </div>

            <p class="mt-4 line-clamp-4 whitespace-pre-wrap break-words text-sm leading-6 text-slate-700">{listing.content}</p>

            {#if listing.images?.length}
              <div class="mt-4 grid grid-cols-2 gap-2 sm:grid-cols-3">
                {#each listing.images as image}
                  <figure class="group relative overflow-hidden rounded-2xl border border-slate-200 bg-slate-100">
                    <img src={image.url} alt={image.caption || listing.title} class="h-36 w-full object-cover" loading="lazy" />
                    {#if canManage(listing)}
                      <button type="button" class="absolute right-2 top-2 rounded-full bg-white/90 px-2 py-1 text-[11px] font-semibold text-rose-700 shadow-sm opacity-0 transition group-hover:opacity-100" disabled={deletingImageId === image.id} on:click={() => deleteListingImage(listing, image)}>
                        {deletingImageId === image.id ? 'Deleting…' : 'Delete'}
                      </button>
                    {/if}
                  </figure>
                {/each}
              </div>
            {/if}

            {#if listing.availableFrom || listing.bondAmount || listing.depositAmount || listing.leaseTerm}
              <div class="mt-4 flex flex-wrap gap-x-3 gap-y-1 text-xs text-slate-500">
                {#if listing.availableFrom}<span>Available: {formatDate(listing.availableFrom)}</span>{/if}
                {#if listing.bondAmount}<span>Bond: {(listing.currency || '')} {Number(listing.bondAmount).toLocaleString()}</span>{/if}
                {#if listing.depositAmount}<span>Deposit: {(listing.currency || '')} {Number(listing.depositAmount).toLocaleString()}</span>{/if}
                {#if listing.leaseTerm}<span>Lease: {listing.leaseTerm}</span>{/if}
              </div>
            {/if}
            {#if listing.expiresAt}
              <p class="mt-3 text-xs font-semibold text-slate-500">Expires {relativeTime(listing.expiresAt)}</p>
            {/if}

            {#if listing.features?.length}
              <div class="mt-4 flex flex-wrap gap-2 text-xs">
                {#each listing.features as feature}
                  <span class="rounded-full border border-emerald-200 bg-emerald-50 px-2.5 py-1 font-semibold text-emerald-700">{feature}</span>
                {/each}
              </div>
            {/if}

            <div class="mt-5 flex flex-wrap gap-2">
              <button type="button" class="rounded-lg border border-slate-900 bg-slate-900 px-3 py-1.5 text-xs font-semibold uppercase tracking-[0.15em] text-white transition hover:bg-slate-800" on:click={() => openInquiry(listing)}>Inquiry</button>
              <a href={`/real-estate/${listing.id}`} class="rounded-lg border border-slate-200 bg-white px-3 py-1.5 text-xs font-semibold uppercase tracking-[0.15em] text-slate-700 transition hover:bg-slate-50">Detail</a>
              {#if canManage(listing)}
                <button type="button" class="rounded-lg border border-slate-200 bg-white px-3 py-1.5 text-xs font-semibold uppercase tracking-[0.15em] text-slate-700 transition hover:bg-slate-50" on:click={() => openEditListing(listing)}>Edit</button>
                <button type="button" class="rounded-lg border border-slate-200 bg-white px-3 py-1.5 text-xs font-semibold uppercase tracking-[0.15em] text-slate-700 transition hover:bg-slate-50" on:click={() => openManager(listing)}>Inquiries ({listing.inquiryCount || 0})</button>
                <label class="cursor-pointer rounded-lg border border-slate-200 bg-white px-3 py-1.5 text-xs font-semibold uppercase tracking-[0.15em] text-slate-700 transition hover:bg-slate-50">
                  {uploadingImageListingId === listing.id ? 'Uploading…' : 'Upload Image'}
                  <input type="file" accept="image/*" class="sr-only" disabled={uploadingImageListingId === listing.id} on:change={(event) => {
                    const file = event.currentTarget.files?.[0];
                    event.currentTarget.value = '';
                    uploadListingImage(listing, file);
                  }} />
                </label>
                <button type="button" class="rounded-lg border border-rose-200 bg-white px-3 py-1.5 text-xs font-semibold uppercase tracking-[0.15em] text-rose-700 transition hover:bg-rose-50" disabled={deletingListingId === listing.id} on:click={() => deleteListing(listing.id)}>
                  {deletingListingId === listing.id ? 'Deleting…' : 'Delete'}
                </button>
              {/if}
            </div>
          </li>
        {/each}
      </ul>
    {/if}
  </div>
</section>

{#if open}
  <div class="fixed inset-0 z-40 flex items-center justify-center bg-slate-900/40 px-4" role="button" tabindex="0" aria-label="Close listing dialog" on:click={() => (open = false)} on:keydown={(event) => {
    if (event.key === 'Escape' || event.key === 'Enter' || event.key === ' ') {
      open = false;
      resetForm();
    }
  }}>
    <div class="max-h-[92vh] w-[min(94vw,56rem)] overflow-y-auto rounded-2xl bg-white p-6 shadow-xl" role="dialog" tabindex="-1" aria-modal="true" on:click|stopPropagation on:keydown|stopPropagation={() => {}}>
      <div class="flex items-center justify-between">
        <h2 class="text-lg font-semibold text-slate-900">{editingListingId ? 'Edit listing' : 'New real estate listing'}</h2>
        <button type="button" class="rounded-xl border border-slate-200 px-3 py-1 text-xs font-semibold uppercase tracking-[0.2em] text-slate-600" on:click={() => { open = false; resetForm(); }}>Close</button>
      </div>
      <form class="mt-4 space-y-4" on:submit|preventDefault={submitListing}>
        <div class="space-y-1">
          <label class="text-sm font-semibold text-slate-700" for="real-estate-title">Title</label>
          <input id="real-estate-title" type="text" bind:value={form.title} required class="w-full rounded-xl border border-slate-200 bg-slate-50 px-3 py-2 text-slate-900" placeholder="2 bedroom apartment near station" />
        </div>
        <div class="grid grid-cols-1 gap-3 sm:grid-cols-3">
          <label class="flex flex-col space-y-1 text-sm font-semibold text-slate-700">
            Listing type
            <select bind:value={form.listingType} required class="w-full rounded-xl border border-slate-200 bg-slate-50 px-3 py-2 font-normal text-slate-900">
              {#each listingTypeOptions as option}
                <option value={option.value}>{option.label}</option>
              {/each}
            </select>
          </label>
          <label class="flex flex-col space-y-1 text-sm font-semibold text-slate-700">
            Property type
            <select bind:value={form.propertyType} required class="w-full rounded-xl border border-slate-200 bg-slate-50 px-3 py-2 font-normal text-slate-900">
              {#each propertyTypeOptions as option}
                <option value={option.value}>{option.label}</option>
              {/each}
            </select>
          </label>
          <label class="flex flex-col space-y-1 text-sm font-semibold text-slate-700">
            Country
            <input type="text" bind:value={form.countryCode} maxlength="3" class="w-full rounded-xl border border-slate-200 bg-slate-50 px-3 py-2 font-normal uppercase text-slate-900" placeholder="AUS" />
          </label>
        </div>
        <div class="grid grid-cols-1 gap-3 sm:grid-cols-4">
          <input type="text" bind:value={form.state} class="rounded-xl border border-slate-200 bg-slate-50 px-3 py-2 text-slate-900" placeholder="State/region" />
          <input type="text" bind:value={form.city} class="rounded-xl border border-slate-200 bg-slate-50 px-3 py-2 text-slate-900" placeholder="City" />
          <input type="text" bind:value={form.suburb} class="rounded-xl border border-slate-200 bg-slate-50 px-3 py-2 text-slate-900" placeholder="Suburb" />
          <input type="text" bind:value={form.addressText} class="rounded-xl border border-slate-200 bg-slate-50 px-3 py-2 text-slate-900" placeholder="Address text" />
        </div>
        <div class="rounded-2xl border border-slate-200 bg-slate-50 p-3">
          <div class="flex flex-wrap items-center justify-between gap-3">
            <div>
              <div class="text-sm font-semibold text-slate-900">Map location</div>
              <p class="mt-1 text-xs text-slate-500">좌표를 넣으면 지도와 반경 검색에 표시됩니다.</p>
            </div>
            <div class="flex flex-wrap items-center gap-2">
              {#if form.latitude !== null && form.longitude !== null && form.latitude !== '' && form.longitude !== ''}
                <span class="text-xs text-slate-500">{Number(form.latitude).toFixed(6)}, {Number(form.longitude).toFixed(6)}</span>
                <button type="button" class="rounded-xl border border-rose-200 bg-white px-3 py-2 text-xs font-semibold uppercase tracking-[0.16em] text-rose-700" on:click={() => { form.latitude = null; form.longitude = null; }}>Clear</button>
              {/if}
              <button type="button" class="rounded-xl border border-slate-200 bg-white px-3 py-2 text-xs font-semibold uppercase tracking-[0.16em] text-slate-700 disabled:cursor-not-allowed disabled:text-slate-300" disabled={!$bootstrap.site?.mapsEnabled} on:click={() => (listingMapOpen = !listingMapOpen)}>
                {listingMapOpen ? 'Hide Map' : 'Pick on Map'}
              </button>
            </div>
          </div>
          {#if listingMapOpen && $bootstrap.site?.mapsEnabled}
            <div class="mt-3">
              <LeafletMap bind:latitude={form.latitude} bind:longitude={form.longitude} interactive heightClass="h-72" />
            </div>
          {/if}
        </div>
        <div class="grid grid-cols-1 gap-3 sm:grid-cols-4">
          <input type="text" bind:value={form.currency} maxlength="3" class="rounded-xl border border-slate-200 bg-slate-50 px-3 py-2 uppercase text-slate-900" placeholder="AUD" />
          <input type="number" min="0" bind:value={form.price} class="rounded-xl border border-slate-200 bg-slate-50 px-3 py-2 text-slate-900" placeholder="Price" />
          <select bind:value={form.pricePeriod} class="rounded-xl border border-slate-200 bg-slate-50 px-3 py-2 text-slate-900">
            <option value="">No period</option>
            {#each pricePeriodOptions as option}
              <option value={option.value}>{option.label}</option>
            {/each}
          </select>
          <input type="date" bind:value={form.availableFrom} class="rounded-xl border border-slate-200 bg-slate-50 px-3 py-2 text-slate-900" />
        </div>
        <div class="grid grid-cols-1 gap-3 sm:grid-cols-5">
          <input type="number" min="0" bind:value={form.bedrooms} class="rounded-xl border border-slate-200 bg-slate-50 px-3 py-2 text-slate-900" placeholder="Bedrooms" />
          <input type="number" min="0" bind:value={form.bathrooms} class="rounded-xl border border-slate-200 bg-slate-50 px-3 py-2 text-slate-900" placeholder="Bathrooms" />
          <input type="number" min="0" bind:value={form.parkingSpaces} class="rounded-xl border border-slate-200 bg-slate-50 px-3 py-2 text-slate-900" placeholder="Parking" />
          <input type="number" min="0" step="0.1" bind:value={form.floorAreaSqm} class="rounded-xl border border-slate-200 bg-slate-50 px-3 py-2 text-slate-900" placeholder="Floor sqm" />
          <input type="number" min="0" step="0.1" bind:value={form.landAreaSqm} class="rounded-xl border border-slate-200 bg-slate-50 px-3 py-2 text-slate-900" placeholder="Land sqm" />
        </div>
        <div class="grid grid-cols-1 gap-3 sm:grid-cols-4">
          <input type="number" min="0" bind:value={form.bondAmount} class="rounded-xl border border-slate-200 bg-slate-50 px-3 py-2 text-slate-900" placeholder="Bond" />
          <input type="number" min="0" bind:value={form.depositAmount} class="rounded-xl border border-slate-200 bg-slate-50 px-3 py-2 text-slate-900" placeholder="Deposit" />
          <input type="text" bind:value={form.leaseTerm} class="rounded-xl border border-slate-200 bg-slate-50 px-3 py-2 text-slate-900" placeholder="Lease term" />
          <input type="text" bind:value={form.features} class="rounded-xl border border-slate-200 bg-slate-50 px-3 py-2 text-slate-900" placeholder="Features: gym, balcony" />
        </div>
        <div class="grid grid-cols-1 gap-3 sm:grid-cols-3">
          <select bind:value={form.furnished} class="rounded-xl border border-slate-200 bg-slate-50 px-3 py-2 text-slate-900">
            <option value="">Furnished?</option>
            <option value="true">Furnished</option>
            <option value="false">Unfurnished</option>
          </select>
          <select bind:value={form.petsAllowed} class="rounded-xl border border-slate-200 bg-slate-50 px-3 py-2 text-slate-900">
            <option value="">Pets?</option>
            <option value="true">Pets allowed</option>
            <option value="false">No pets</option>
          </select>
          <select bind:value={form.billsIncluded} class="rounded-xl border border-slate-200 bg-slate-50 px-3 py-2 text-slate-900">
            <option value="">Bills?</option>
            <option value="true">Bills included</option>
            <option value="false">Bills excluded</option>
          </select>
        </div>
        <div class="grid grid-cols-1 gap-3 sm:grid-cols-3">
          <input type="text" bind:value={form.contactName} class="rounded-xl border border-slate-200 bg-slate-50 px-3 py-2 text-slate-900" placeholder="Contact name" />
          <input type="email" bind:value={form.contactEmail} class="rounded-xl border border-slate-200 bg-slate-50 px-3 py-2 text-slate-900" placeholder="Contact email" />
          <input type="text" bind:value={form.contactPhone} class="rounded-xl border border-slate-200 bg-slate-50 px-3 py-2 text-slate-900" placeholder="Contact phone" />
        </div>
        <div class="space-y-1">
          <label class="text-sm font-semibold text-slate-700" for="real-estate-content">Description</label>
          <textarea id="real-estate-content" bind:value={form.content} required rows="7" class="w-full rounded-xl border border-slate-200 bg-slate-50 px-3 py-2 text-sm text-slate-900" placeholder="교통, 주변 시설, 입주 조건, 검사/뷰잉 방법을 적어주세요."></textarea>
        </div>
        <div class="flex justify-end gap-2 pt-1">
          <button type="submit" class="rounded-xl bg-gradient-to-r from-slate-900 to-slate-700 px-4 py-2 text-center text-xs font-semibold uppercase tracking-[0.2em] text-white" disabled={submitting}>
            {submitting ? (editingListingId ? 'Saving…' : 'Posting…') : (editingListingId ? 'Save' : 'Post')}
          </button>
          <button type="button" class="rounded-xl border border-slate-200 px-4 py-2 text-xs font-semibold uppercase tracking-[0.2em] text-slate-600" on:click={() => { open = false; resetForm(); }}>Cancel</button>
        </div>
      </form>
    </div>
  </div>
{/if}

{#if inquiryOpen}
  <div class="fixed inset-0 z-40 flex items-center justify-center bg-slate-900/40 px-4" role="button" tabindex="0" aria-label="Close inquiry dialog" on:click={() => (inquiryOpen = false)} on:keydown={(event) => {
    if (event.key === 'Escape' || event.key === 'Enter' || event.key === ' ') inquiryOpen = false;
  }}>
    <div class="max-h-[92vh] w-[min(94vw,36rem)] overflow-y-auto rounded-2xl bg-white p-6 shadow-xl" role="dialog" tabindex="-1" aria-modal="true" on:click|stopPropagation on:keydown|stopPropagation={() => {}}>
      <div class="flex items-start justify-between gap-4">
        <div>
          <h2 class="text-lg font-semibold text-slate-900">Send inquiry</h2>
          <p class="mt-1 text-sm text-slate-500">{inquiryListing?.title}</p>
        </div>
        <button type="button" class="rounded-xl border border-slate-200 px-3 py-1 text-xs font-semibold uppercase tracking-[0.2em] text-slate-600" on:click={() => (inquiryOpen = false)}>Close</button>
      </div>
      <form class="mt-5 space-y-3" on:submit|preventDefault={submitInquiry}>
        <input type="text" bind:value={inquiryForm.name} required class="w-full rounded-xl border border-slate-200 bg-slate-50 px-3 py-2 text-slate-900" placeholder="Name" />
        <input type="email" bind:value={inquiryForm.email} required class="w-full rounded-xl border border-slate-200 bg-slate-50 px-3 py-2 text-slate-900" placeholder="Email" />
        <input type="text" bind:value={inquiryForm.phone} class="w-full rounded-xl border border-slate-200 bg-slate-50 px-3 py-2 text-slate-900" placeholder="Phone" />
        <textarea bind:value={inquiryForm.message} required rows="5" class="w-full rounded-xl border border-slate-200 bg-slate-50 px-3 py-2 text-sm text-slate-900" placeholder="문의 내용을 입력하세요."></textarea>
        <div class="flex justify-end">
          <button type="submit" class="rounded-xl bg-slate-900 px-4 py-2 text-xs font-semibold uppercase tracking-[0.2em] text-white" disabled={inquirySubmitting}>{inquirySubmitting ? 'Sending…' : 'Send'}</button>
        </div>
      </form>
    </div>
  </div>
{/if}

{#if managerOpen}
  <div class="fixed inset-0 z-40 flex items-center justify-center bg-slate-900/40 px-4" role="button" tabindex="0" aria-label="Close inquiries dialog" on:click={() => (managerOpen = false)} on:keydown={(event) => {
    if (event.key === 'Escape' || event.key === 'Enter' || event.key === ' ') managerOpen = false;
  }}>
    <div class="max-h-[92vh] w-[min(94vw,44rem)] overflow-y-auto rounded-2xl bg-white p-6 shadow-xl" role="dialog" tabindex="-1" aria-modal="true" on:click|stopPropagation on:keydown|stopPropagation={() => {}}>
      <div class="flex items-start justify-between gap-4">
        <div>
          <h2 class="text-lg font-semibold text-slate-900">Listing inquiries</h2>
          <p class="mt-1 text-sm text-slate-500">{managerListing?.title}</p>
        </div>
        <button type="button" class="rounded-xl border border-slate-200 px-3 py-1 text-xs font-semibold uppercase tracking-[0.2em] text-slate-600" on:click={() => (managerOpen = false)}>Close</button>
      </div>

      {#if managerLoading}
        <div class="mt-6 rounded-2xl border border-slate-200 bg-slate-50 p-6 text-center text-sm text-slate-500">Loading inquiries…</div>
      {:else if !managerInquiries.length}
        <div class="mt-6 rounded-2xl border border-slate-200 bg-slate-50 p-6 text-center text-sm text-slate-500">아직 문의가 없습니다.</div>
      {:else}
        <ul class="mt-5 divide-y divide-slate-200 rounded-2xl border border-slate-200">
          {#each managerInquiries as inquiry}
            <li class="p-4">
              <div class="flex flex-wrap items-start justify-between gap-3">
                <div>
                  <p class="text-sm font-semibold text-slate-900">{inquiry.name} · {inquiry.email}</p>
                  <p class="mt-1 text-xs text-slate-500">{inquiry.phone || 'No phone'} · {relativeTime(inquiry.createdAt)}</p>
                  <p class="mt-2 whitespace-pre-wrap text-sm text-slate-700">{inquiry.message}</p>
                </div>
                <select class="rounded-xl border border-slate-200 bg-slate-50 px-3 py-2 text-sm text-slate-900" value={inquiry.status} disabled={updatingInquiryId === inquiry.id} on:change={(event) => updateInquiry(inquiry, event.currentTarget.value)}>
                  {#each inquiryStatusOptions as option}
                    <option value={option.value}>{option.label}</option>
                  {/each}
                </select>
              </div>
            </li>
          {/each}
        </ul>
      {/if}
    </div>
  </div>
{/if}
