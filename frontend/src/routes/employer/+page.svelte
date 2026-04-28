<script>
  import { onMount } from 'svelte';
  import PageEmpty from '$lib/components/PageEmpty.svelte';
  import { bootstrap } from '$lib/stores/bootstrap';
  import { apiFetch, sendJson } from '$lib/utils/api';
  import { relativeTime } from '$lib/utils/time';

  let loading = true;
  let error = '';
  let quota = null;
  let jobs = [];
  let plans = [];
  let selectedJob = null;
  let applications = [];
  let applicationsLoading = false;
  let applicationStatusCounts = {};
  let filters = { status: '', q: '' };
  let updatingApplicationId = null;

  const statuses = [
    { value: 'submitted', label: 'Submitted' },
    { value: 'reviewing', label: 'Reviewing' },
    { value: 'accepted', label: 'Accepted' },
    { value: 'rejected', label: 'Rejected' },
    { value: 'withdrawn', label: 'Withdrawn' }
  ];

  async function loadDashboard() {
    loading = true;
    error = '';
    try {
      const payload = await apiFetch('/api/v1/employer/dashboard');
      quota = payload.quota;
      jobs = payload.jobs || [];
      plans = payload.plans || [];
      if (!selectedJob && jobs.length) selectedJob = jobs[0];
    } catch (err) {
      error = err.message;
    } finally {
      loading = false;
    }
  }

  async function loadApplications(job = selectedJob) {
    if (!job) return;
    selectedJob = job;
    applicationsLoading = true;
    try {
      const params = new URLSearchParams();
      if (filters.status) params.set('status', filters.status);
      if (filters.q) params.set('q', filters.q);
      const query = params.toString();
      const payload = await apiFetch(`/api/v1/jobs/${job.id}/applications${query ? `?${query}` : ''}`);
      applications = payload.items || [];
      applicationStatusCounts = payload.statusCounts || {};
    } catch (err) {
      window.alert(err.message);
    } finally {
      applicationsLoading = false;
    }
  }

  function csvUrl() {
    if (!selectedJob) return '#';
    const params = new URLSearchParams({ format: 'csv' });
    if (filters.status) params.set('status', filters.status);
    if (filters.q) params.set('q', filters.q);
    return `/api/v1/jobs/${selectedJob.id}/applications?${params.toString()}`;
  }

  async function updateApplication(application, updates) {
    if (!selectedJob || updatingApplicationId) return;
    updatingApplicationId = application.id;
    try {
      const payload = await sendJson(`/api/v1/jobs/${selectedJob.id}/applications/${application.id}`, {
        method: 'PATCH',
        body: {
          status: updates.status ?? application.status,
          managerNote: updates.managerNote ?? application.managerNote ?? null,
          rating: updates.rating === undefined ? application.rating : updates.rating
        }
      });
      applications = applications.map((item) => (item.id === payload.application.id ? payload.application : item));
    } catch (err) {
      window.alert(err.message);
    } finally {
      updatingApplicationId = null;
    }
  }

  function quotaLabel() {
    if (!quota?.monthlyJobLimit) return `${quota?.usedThisMonth || 0} / 협의`;
    return `${quota.usedThisMonth} / ${quota.monthlyJobLimit}`;
  }

  onMount(async () => {
    await loadDashboard();
    if (selectedJob) await loadApplications(selectedJob);
  });
</script>

<section class="min-h-full bg-slate-50">
  <div class="border-b border-slate-200 bg-white px-5 py-4">
    <div class="flex flex-wrap items-start justify-between gap-4">
      <div>
        <h1 class="text-3xl font-semibold text-slate-900">Recruiting Manager</h1>
        <p class="mt-1 text-sm text-slate-500">기업 회원 전용 채용 관리 페이지입니다. 관리자는 모든 공고에 접근할 수 있습니다.</p>
      </div>
      <a href="/jobs" class="rounded-xl border border-slate-200 px-4 py-2 text-xs font-semibold uppercase tracking-[0.18em] text-slate-700">Jobs</a>
    </div>
  </div>

  {#if loading}
    <div class="p-5 text-sm text-slate-500">Loading recruiting dashboard…</div>
  {:else if error}
    <div class="p-5">
      <PageEmpty title="접근할 수 없습니다." description={error} />
    </div>
  {:else}
    <div class="grid gap-4 p-5 xl:grid-cols-[320px_minmax(0,1fr)]">
      <aside class="space-y-4">
        <div class="rounded-2xl border border-slate-200 bg-white p-4">
          <div class="text-xs font-semibold uppercase tracking-[0.18em] text-slate-500">Current Plan</div>
          <div class="mt-2 text-2xl font-semibold text-slate-900">{quota?.plan?.name}</div>
          <p class="mt-1 text-sm text-slate-500">{quota?.plan?.description}</p>
          <div class="mt-4 rounded-xl bg-slate-50 px-3 py-3">
            <div class="text-xs font-semibold uppercase tracking-[0.18em] text-slate-500">This month</div>
            <div class="mt-1 text-lg font-semibold text-slate-900">{quotaLabel()} posts</div>
          </div>
        </div>

        <div class="rounded-2xl border border-slate-200 bg-white p-4">
          <div class="text-xs font-semibold uppercase tracking-[0.18em] text-slate-500">Plans</div>
          <div class="mt-3 space-y-2">
            {#each plans as plan}
              <div class="rounded-xl border border-slate-200 px-3 py-2">
                <div class="text-sm font-semibold text-slate-900">{plan.name}</div>
                <div class="mt-1 text-xs text-slate-500">{plan.description}</div>
              </div>
            {/each}
          </div>
        </div>

        <div class="rounded-2xl border border-slate-200 bg-white p-4">
          <div class="flex items-center justify-between">
            <div class="text-xs font-semibold uppercase tracking-[0.18em] text-slate-500">Job Posts</div>
            <a href="/jobs" class="text-xs font-semibold text-slate-900 underline underline-offset-4">New</a>
          </div>
          <div class="mt-3 space-y-2">
            {#each jobs as job}
              <button type="button" class={`block w-full rounded-xl border px-3 py-3 text-left transition ${selectedJob?.id === job.id ? 'border-slate-900 bg-slate-900 text-white' : 'border-slate-200 bg-white hover:bg-slate-50'}`} on:click={() => loadApplications(job)}>
                <div class="text-sm font-semibold">{job.title}</div>
                <div class={`mt-1 text-xs ${selectedJob?.id === job.id ? 'text-slate-300' : 'text-slate-500'}`}>{job.company} · {job.applicationCount || 0} applicants</div>
              </button>
            {/each}
          </div>
        </div>
      </aside>

      <main class="rounded-2xl border border-slate-200 bg-white p-4">
        {#if !selectedJob}
          <PageEmpty title="관리할 공고가 없습니다." description="기업 회원 플랜 한도 내에서 Jobs 페이지에서 공고를 등록하세요." />
        {:else}
          <div class="flex flex-wrap items-start justify-between gap-3">
            <div>
              <h2 class="text-2xl font-semibold text-slate-900">{selectedJob.title}</h2>
              <p class="mt-1 text-sm text-slate-500">{selectedJob.company} · posted {relativeTime(selectedJob.createdAt)}</p>
            </div>
            <a href={`/jobs/${selectedJob.id}`} class="rounded-xl border border-slate-200 px-3 py-2 text-xs font-semibold uppercase tracking-[0.16em] text-slate-700">Detail</a>
          </div>

          <form class="mt-4 grid grid-cols-1 gap-2 rounded-2xl border border-slate-200 bg-slate-50 p-3 sm:grid-cols-[1fr_1fr_auto]" on:submit|preventDefault={() => loadApplications(selectedJob)}>
            <select bind:value={filters.status} class="rounded-xl border border-slate-200 bg-white px-3 py-2 text-sm text-slate-900">
              <option value="">All statuses</option>
              {#each statuses as status}
                <option value={status.value}>{status.label} ({applicationStatusCounts[status.value] || 0})</option>
              {/each}
            </select>
            <input type="text" bind:value={filters.q} class="rounded-xl border border-slate-200 bg-white px-3 py-2 text-sm text-slate-900" placeholder="Search applicant or memo" />
            <div class="flex gap-2">
              <button type="submit" class="rounded-xl bg-slate-900 px-3 py-2 text-xs font-semibold uppercase tracking-[0.16em] text-white">Filter</button>
              <a href={csvUrl()} class="rounded-xl border border-slate-200 bg-white px-3 py-2 text-xs font-semibold uppercase tracking-[0.16em] text-slate-700">CSV</a>
            </div>
          </form>

          {#if applicationsLoading}
            <div class="mt-5 text-sm text-slate-500">Loading applications…</div>
          {:else if !applications.length}
            <div class="mt-5 rounded-2xl border border-slate-200 bg-slate-50 p-6 text-center text-sm text-slate-500">지원자가 없습니다.</div>
          {:else}
            <div class="mt-5 space-y-3">
              {#each applications as application}
                <article class="rounded-2xl border border-slate-200 p-4">
                  <div class="flex flex-wrap items-start justify-between gap-3">
                    <div>
                      <div class="text-sm font-semibold text-slate-900">@{application.applicant?.ident}</div>
                      <div class="mt-1 text-xs text-slate-500">Applied {relativeTime(application.createdAt)}</div>
                      {#if application.note}
                        <p class="mt-2 whitespace-pre-wrap text-sm text-slate-700">{application.note}</p>
                      {/if}
                    </div>
                    <div class="grid min-w-[13rem] gap-2">
                      <select class="rounded-xl border border-slate-200 bg-slate-50 px-3 py-2 text-sm text-slate-900" value={application.status} disabled={updatingApplicationId === application.id} on:change={(event) => updateApplication(application, { status: event.currentTarget.value })}>
                        {#each statuses as status}
                          <option value={status.value}>{status.label}</option>
                        {/each}
                      </select>
                      <select class="rounded-xl border border-slate-200 bg-slate-50 px-3 py-2 text-sm text-slate-900" value={application.rating || ''} disabled={updatingApplicationId === application.id} on:change={(event) => updateApplication(application, { rating: event.currentTarget.value ? Number(event.currentTarget.value) : null })}>
                        <option value="">No rating</option>
                        <option value="1">1 star</option>
                        <option value="2">2 stars</option>
                        <option value="3">3 stars</option>
                        <option value="4">4 stars</option>
                        <option value="5">5 stars</option>
                      </select>
                    </div>
                  </div>
                  <label class="mt-3 block text-xs font-semibold text-slate-600">
                    Manager note
                    <textarea class="mt-1 w-full rounded-xl border border-slate-200 bg-slate-50 px-3 py-2 text-sm font-normal text-slate-900" rows="2" disabled={updatingApplicationId === application.id} value={application.managerNote || ''} on:change={(event) => updateApplication(application, { managerNote: event.currentTarget.value || null })}></textarea>
                  </label>
                </article>
              {/each}
            </div>
          {/if}
        {/if}
      </main>
    </div>
  {/if}
</section>
