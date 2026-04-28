<script>
  import { onMount } from 'svelte';
  import PageEmpty from '$lib/components/PageEmpty.svelte';
  import { bootstrap } from '$lib/stores/bootstrap';
  import { apiFetch, sendJson } from '$lib/utils/api';
  import { formatDate, relativeTime } from '$lib/utils/time';

  let items = [];
  let companyOptions = [];
  let skillSuggestions = [];
  let loading = true;
  let open = false;
  let submitting = false;
  let closingJobId = null;
  let deletingJobId = null;
  let applyingJobId = null;
  let applicationsOpen = false;
  let applicationsLoading = false;
  let applicationsJob = null;
  let applications = [];
  let applicationStatusCounts = {};
  let applicationFilters = { status: '', q: '' };
  let updatingApplicationId = null;
  let myApplicationsOpen = false;
  let myApplicationsLoading = false;
  let myApplications = [];
  let withdrawingJobId = null;
  let editingJobId = null;
  const applicationStatusOptions = [
    { value: 'submitted', label: 'Submitted' },
    { value: 'reviewing', label: 'Reviewing' },
    { value: 'accepted', label: 'Accepted' },
    { value: 'rejected', label: 'Rejected' },
    { value: 'withdrawn', label: 'Withdrawn' }
  ];
  const employmentTypeOptions = [
    { value: 'full_time', label: 'Full time' },
    { value: 'part_time', label: 'Part time' },
    { value: 'contract', label: 'Contract' },
    { value: 'temporary', label: 'Temporary' },
    { value: 'internship', label: 'Internship' },
    { value: 'freelance', label: 'Freelance' },
    { value: 'casual', label: 'Casual' }
  ];
  const workplaceTypeOptions = [
    { value: 'on_site', label: 'On site' },
    { value: 'hybrid', label: 'Hybrid' },
    { value: 'remote', label: 'Remote' }
  ];
  const seniorityOptions = [
    { value: 'entry', label: 'Entry' },
    { value: 'junior', label: 'Junior' },
    { value: 'mid', label: 'Mid' },
    { value: 'senior', label: 'Senior' },
    { value: 'lead', label: 'Lead' }
  ];
  const salaryPeriodOptions = [
    { value: 'hourly', label: 'Hourly' },
    { value: 'monthly', label: 'Monthly' },
    { value: 'annual', label: 'Annual' }
  ];
  let filters = {
    employmentType: '',
    workplaceType: '',
    seniority: '',
    skill: '',
    salaryMin: '',
    salaryMax: ''
  };
  let form = {
    title: '',
    company: '',
    companyId: '',
    salary: '',
    salaryMin: '',
    salaryMax: '',
    salaryCurrency: 'KRW',
    salaryPeriod: '',
    workingHours: '',
    deadline: '',
    experience: '',
    seniority: '',
    employmentType: 'full_time',
    workplaceType: '',
    applyUrl: '',
    applyEmail: '',
    skills: '',
    benefits: '',
    content: ''
  };

  function resetForm() {
    form = {
      title: '',
      company: '',
      companyId: '',
      salary: '',
      salaryMin: '',
      salaryMax: '',
      salaryCurrency: 'KRW',
      salaryPeriod: '',
      workingHours: '',
      deadline: '',
      experience: '',
      seniority: '',
      employmentType: 'full_time',
      workplaceType: '',
      applyUrl: '',
      applyEmail: '',
      skills: '',
      benefits: '',
      content: ''
    };
    editingJobId = null;
  }

  function optionLabel(options, value) {
    return options.find((option) => option.value === value)?.label || value;
  }

  function numberOrNull(value) {
    if (value === '' || value === null || value === undefined) return null;
    return Number(value);
  }

  function csvList(value) {
    return value
      .split(',')
      .map((item) => item.trim())
      .filter(Boolean);
  }

  async function loadCompanyOptions() {
    try {
      const payload = await apiFetch('/api/v1/companies?size=100');
      companyOptions = payload.items || [];
    } catch {
      companyOptions = [];
    }
  }

  async function loadSkillSuggestions() {
    try {
      const payload = await apiFetch('/api/v1/job-skills');
      skillSuggestions = payload.items || [];
    } catch {
      skillSuggestions = [];
    }
  }

  function setCompanyFromSelect(companyId) {
    form.companyId = companyId;
    const selected = companyOptions.find((company) => String(company.id) === String(companyId));
    form.company = selected?.name || '';
  }

  function buildJobQuery() {
    const params = new URLSearchParams();
    Object.entries(filters).forEach(([key, value]) => {
      if (value !== '' && value !== null && value !== undefined) params.set(key, value);
    });
    const query = params.toString();
    return query ? `?${query}` : '';
  }

  function clearFilters() {
    filters = {
      employmentType: '',
      workplaceType: '',
      seniority: '',
      skill: '',
      salaryMin: '',
      salaryMax: ''
    };
    loadJobs();
  }

  function salarySummary(job) {
    const hasRange = job.salaryMin !== null && job.salaryMin !== undefined || job.salaryMax !== null && job.salaryMax !== undefined;
    if (!hasRange) return job.salary;
    const currency = job.salaryCurrency || '';
    const period = job.salaryPeriod ? `/${optionLabel(salaryPeriodOptions, job.salaryPeriod).toLowerCase()}` : '';
    const min = job.salaryMin !== null && job.salaryMin !== undefined ? job.salaryMin.toLocaleString() : '';
    const max = job.salaryMax !== null && job.salaryMax !== undefined ? job.salaryMax.toLocaleString() : '';
    if (min && max) return `${currency} ${min}-${max}${period}`.trim();
    return `${currency} ${min || max}${period}`.trim();
  }

  async function loadJobs() {
    loading = true;
    try {
      const payload = await apiFetch(`/api/v1/jobs${buildJobQuery()}`);
      items = payload.items || [];
    } finally {
      loading = false;
    }
  }

  async function submitJob() {
    if (submitting) return;
    submitting = true;

    try {
      const payload = {
        body: {
          title: form.title,
          company: form.company,
          companyId: form.companyId ? Number(form.companyId) : null,
          salary: form.salary || null,
          salaryMin: numberOrNull(form.salaryMin),
          salaryMax: numberOrNull(form.salaryMax),
          salaryCurrency: form.salaryCurrency || null,
          salaryPeriod: form.salaryPeriod || null,
          workingHours: form.workingHours || null,
          deadline: form.deadline || null,
          experience: form.experience || null,
          seniority: form.seniority || null,
          employmentType: form.employmentType,
          workplaceType: form.workplaceType || null,
          applyUrl: form.applyUrl || null,
          applyEmail: form.applyEmail || null,
          skills: csvList(form.skills),
          benefits: csvList(form.benefits),
          content: form.content
        }
      };
      if (editingJobId) {
        await sendJson(`/api/v1/jobs/${editingJobId}`, { method: 'PATCH', ...payload });
      } else {
        await sendJson('/api/v1/jobs', payload);
      }
      resetForm();
      open = false;
      await loadJobs();
    } catch (error) {
      window.alert(error.message);
    } finally {
      submitting = false;
    }
  }

  function openCreateJob() {
    resetForm();
    loadCompanyOptions();
    loadSkillSuggestions();
    open = true;
  }

  function openEditJob(job) {
    editingJobId = job.id;
    form = {
      title: job.title || '',
      company: job.company || '',
      companyId: job.companyId ? String(job.companyId) : '',
      salary: job.salary || '',
      salaryMin: job.salaryMin ?? '',
      salaryMax: job.salaryMax ?? '',
      salaryCurrency: job.salaryCurrency || 'KRW',
      salaryPeriod: job.salaryPeriod || '',
      workingHours: job.workingHours || '',
      deadline: job.deadline || '',
      experience: job.experience || '',
      seniority: job.seniority || '',
      employmentType: job.employmentType || 'full_time',
      workplaceType: job.workplaceType || '',
      applyUrl: job.applyUrl || '',
      applyEmail: job.applyEmail || '',
      skills: (job.skills || []).join(', '),
      benefits: (job.benefits || []).join(', '),
      content: job.content || ''
    };
    loadCompanyOptions();
    loadSkillSuggestions();
    open = true;
  }

  async function closeJob(jobId) {
    if (closingJobId) return;
    closingJobId = jobId;
    try {
      await apiFetch(`/api/v1/jobs/${jobId}/close`, { method: 'POST' });
      items = items.map((job) => (job.id === jobId ? { ...job, isClosed: true } : job));
    } catch (error) {
      window.alert(error.message);
    } finally {
      closingJobId = null;
    }
  }

  async function deleteJob(jobId) {
    if (deletingJobId || !window.confirm('Delete this job post?')) return;
    deletingJobId = jobId;
    try {
      await sendJson(`/api/v1/jobs/${jobId}`, { method: 'DELETE' });
      items = items.filter((job) => job.id !== jobId);
      if (editingJobId === jobId) {
        open = false;
        resetForm();
      }
    } catch (error) {
      window.alert(error.message);
    } finally {
      deletingJobId = null;
    }
  }

  async function applyJob(jobId) {
    if (applyingJobId) return;
    applyingJobId = jobId;
    try {
      await sendJson(`/api/v1/jobs/${jobId}/apply`, { method: 'POST', body: { note: null } });
      items = items.map((job) => (
        job.id === jobId
          ? { ...job, viewerHasApplied: true, applicationCount: (job.applicationCount || 0) + 1 }
          : job
      ));
    } catch (error) {
      window.alert(error.message);
    } finally {
      applyingJobId = null;
    }
  }

  async function loadMyApplications() {
    if (!$bootstrap.auth?.isAuthenticated) return;
    myApplicationsLoading = true;
    try {
      const payload = await apiFetch('/api/v1/me/job-applications');
      myApplications = payload.items || [];
    } catch (error) {
      window.alert(error.message);
    } finally {
      myApplicationsLoading = false;
    }
  }

  async function openMyApplications() {
    myApplicationsOpen = true;
    await loadMyApplications();
  }

  async function withdrawApplication(jobId) {
    if (withdrawingJobId || !window.confirm('Withdraw this application?')) return;
    withdrawingJobId = jobId;
    try {
      await sendJson(`/api/v1/jobs/${jobId}/apply`, { method: 'DELETE' });
      myApplications = myApplications.filter((application) => application.job?.id !== jobId);
      items = items.map((job) => (
        job.id === jobId
          ? { ...job, viewerHasApplied: false, applicationCount: Math.max((job.applicationCount || 1) - 1, 0) }
          : job
      ));
    } catch (error) {
      window.alert(error.message);
    } finally {
      withdrawingJobId = null;
    }
  }

  async function openApplications(job) {
    applicationsJob = job;
    applicationsOpen = true;
    applicationFilters = { status: '', q: '' };
    applicationStatusCounts = {};
    applications = [];
    await loadApplications();
  }

  async function loadApplications() {
    if (!applicationsJob) return;
    applicationsLoading = true;
    try {
      const params = new URLSearchParams();
      if (applicationFilters.status) params.set('status', applicationFilters.status);
      if (applicationFilters.q) params.set('q', applicationFilters.q);
      const query = params.toString();
      const payload = await apiFetch(`/api/v1/jobs/${applicationsJob.id}/applications${query ? `?${query}` : ''}`);
      applications = payload.items || [];
      applicationStatusCounts = payload.statusCounts || {};
    } catch (error) {
      window.alert(error.message);
      applicationsOpen = false;
      applicationsJob = null;
      applications = [];
    } finally {
      applicationsLoading = false;
    }
  }

  function applicationCsvUrl() {
    if (!applicationsJob) return '#';
    const params = new URLSearchParams({ format: 'csv' });
    if (applicationFilters.status) params.set('status', applicationFilters.status);
    if (applicationFilters.q) params.set('q', applicationFilters.q);
    return `/api/v1/jobs/${applicationsJob.id}/applications?${params.toString()}`;
  }

  async function updateApplication(application, updates) {
    if (!applicationsJob || updatingApplicationId) return;
    updatingApplicationId = application.id;
    try {
      const payload = await sendJson(`/api/v1/jobs/${applicationsJob.id}/applications/${application.id}`, {
        method: 'PATCH',
        body: {
          status: updates.status ?? application.status,
          managerNote: updates.managerNote ?? application.managerNote ?? null,
          rating: updates.rating === undefined ? application.rating : updates.rating
        }
      });
      applications = applications.map((application) => (
        application.id === payload.application.id ? payload.application : application
      ));
    } catch (error) {
      window.alert(error.message);
    } finally {
      updatingApplicationId = null;
    }
  }

  onMount(loadJobs);
</script>

<section class="flex h-full min-h-0 flex-col bg-white">
  <div class="shrink-0 border-b border-slate-200 px-4 py-3.5">
    <div class="flex flex-wrap items-start justify-between gap-4">
      <div>
        <h1 class="text-3xl font-semibold text-slate-900">Jobs</h1>
        <p class="mt-1 text-sm text-slate-500">구인/구직 글을 확인하고 새로운 공고를 등록하세요.</p>
      </div>
      {#if $bootstrap.auth?.isAuthenticated}
        <div class="flex flex-wrap gap-2">
          <button type="button" class="rounded-lg border border-slate-200 px-3 py-1.5 text-xs font-semibold uppercase tracking-[0.2em] text-slate-700 transition hover:bg-slate-50" on:click={openMyApplications}>My Applications</button>
          <button type="button" class="rounded-lg bg-slate-900 px-3 py-1.5 text-xs font-semibold uppercase tracking-[0.2em] text-white transition hover:bg-slate-800" on:click={openCreateJob}>New Job</button>
        </div>
      {:else}
        <a href="/login" class="rounded-lg border border-slate-900 px-3 py-1.5 text-xs font-semibold uppercase tracking-[0.2em] text-slate-900 transition hover:bg-slate-900 hover:text-white">Login to post</a>
      {/if}
    </div>
    <form class="mt-4 grid grid-cols-1 gap-2 rounded-2xl border border-slate-200 bg-slate-50 p-3 sm:grid-cols-2 lg:grid-cols-6" on:submit|preventDefault={loadJobs}>
      <label class="flex flex-col gap-1 text-xs font-semibold text-slate-600">
        Employment
        <select bind:value={filters.employmentType} class="rounded-xl border border-slate-200 bg-white px-3 py-2 text-sm font-normal text-slate-900">
          <option value="">All</option>
          {#each employmentTypeOptions as option}
            <option value={option.value}>{option.label}</option>
          {/each}
        </select>
      </label>
      <label class="flex flex-col gap-1 text-xs font-semibold text-slate-600">
        Workplace
        <select bind:value={filters.workplaceType} class="rounded-xl border border-slate-200 bg-white px-3 py-2 text-sm font-normal text-slate-900">
          <option value="">All</option>
          {#each workplaceTypeOptions as option}
            <option value={option.value}>{option.label}</option>
          {/each}
        </select>
      </label>
      <label class="flex flex-col gap-1 text-xs font-semibold text-slate-600">
        Seniority
        <select bind:value={filters.seniority} class="rounded-xl border border-slate-200 bg-white px-3 py-2 text-sm font-normal text-slate-900">
          <option value="">All</option>
          {#each seniorityOptions as option}
            <option value={option.value}>{option.label}</option>
          {/each}
        </select>
      </label>
      <label class="flex flex-col gap-1 text-xs font-semibold text-slate-600">
        Skill
        <input type="text" bind:value={filters.skill} class="rounded-xl border border-slate-200 bg-white px-3 py-2 text-sm font-normal text-slate-900" placeholder="haskell" />
      </label>
      <label class="flex flex-col gap-1 text-xs font-semibold text-slate-600">
        Min salary
        <input type="number" min="0" bind:value={filters.salaryMin} class="rounded-xl border border-slate-200 bg-white px-3 py-2 text-sm font-normal text-slate-900" placeholder="50000000" />
      </label>
      <label class="flex flex-col gap-1 text-xs font-semibold text-slate-600">
        Max salary
        <input type="number" min="0" bind:value={filters.salaryMax} class="rounded-xl border border-slate-200 bg-white px-3 py-2 text-sm font-normal text-slate-900" placeholder="90000000" />
      </label>
      <div class="flex items-end gap-2 lg:col-span-2">
        <button type="submit" class="flex-1 rounded-xl bg-slate-900 px-3 py-2 text-xs font-semibold uppercase tracking-[0.16em] text-white transition hover:bg-slate-800">Filter</button>
        <button type="button" class="rounded-xl border border-slate-200 bg-white px-3 py-2 text-xs font-semibold uppercase tracking-[0.16em] text-slate-600 transition hover:bg-slate-100" on:click={clearFilters}>Clear</button>
      </div>
    </form>
  </div>

  <div class="min-h-0 flex-1 overflow-y-auto no-scrollbar">
    {#if loading}
      <div class="flex h-full items-center justify-center px-6 text-center text-slate-500">Loading jobs…</div>
    {:else if !items.length}
      <PageEmpty title="등록된 구인/구직 글이 없습니다." />
    {:else}
      <ul class="divide-y divide-slate-200">
        {#each items as job}
          <li class="px-4 py-4">
            <div class="flex flex-wrap items-start justify-between gap-2">
              <div class="min-w-0">
                <h2 class="break-words text-xl font-semibold text-slate-900">
                  <a class="transition hover:text-slate-600" href={`/jobs/${job.id}`}>{job.title}</a>
                </h2>
                <p class="mt-1 text-sm font-medium text-slate-700">{job.company}</p>
                <div class="mt-1 flex flex-wrap items-center gap-x-2 gap-y-1 text-xs text-slate-500">
                  {#if salarySummary(job)}
                    <span>급여: {salarySummary(job)}</span>
                  {/if}
                  {#if job.workingHours}
                    <span>· 근무시간: {job.workingHours}</span>
                  {/if}
                  {#if job.experience}
                    <span>· 경력: {job.experience}</span>
                  {/if}
                  {#if job.employmentType}
                    <span>· {optionLabel(employmentTypeOptions, job.employmentType)}</span>
                  {/if}
                  {#if job.workplaceType}
                    <span>· {optionLabel(workplaceTypeOptions, job.workplaceType)}</span>
                  {/if}
                  {#if job.seniority}
                    <span>· {optionLabel(seniorityOptions, job.seniority)}</span>
                  {/if}
                  {#if job.deadline}
                    <span>· 마감일: {formatDate(job.deadline)}</span>
                  {/if}
                </div>
              </div>
              <span class="shrink-0 text-xs text-slate-400">{relativeTime(job.createdAt)}</span>
            </div>
            <div class="mt-2">
              {#if job.isClosed}
                <span class="inline-flex rounded-full border border-rose-200 bg-rose-50 px-2.5 py-1 text-xs font-semibold text-rose-700">Closed</span>
              {:else}
                <span class="inline-flex rounded-full border border-emerald-200 bg-emerald-50 px-2.5 py-1 text-xs font-semibold text-emerald-700">Open</span>
              {/if}
            </div>
            <p class="mt-3 whitespace-pre-wrap break-words text-sm text-slate-700">{job.content}</p>
            {#if job.skills?.length || job.benefits?.length}
              <div class="mt-3 flex flex-wrap gap-2 text-xs">
                {#each job.skills || [] as skill}
                  <span class="rounded-full bg-slate-100 px-2.5 py-1 font-semibold text-slate-700">#{skill}</span>
                {/each}
                {#each job.benefits || [] as benefit}
                  <span class="rounded-full border border-emerald-200 bg-emerald-50 px-2.5 py-1 font-semibold text-emerald-700">{benefit}</span>
                {/each}
              </div>
            {/if}
            {#if job.applyUrl || job.applyEmail}
              <div class="mt-3 flex flex-wrap gap-2 text-xs font-semibold text-slate-700">
                {#if job.applyUrl}
                  <a class="rounded-lg border border-slate-200 px-3 py-1.5 transition hover:bg-slate-50" href={job.applyUrl} target="_blank" rel="noreferrer">Apply link</a>
                {/if}
                {#if job.applyEmail}
                  <a class="rounded-lg border border-slate-200 px-3 py-1.5 transition hover:bg-slate-50" href={`mailto:${job.applyEmail}`}>Apply email</a>
                {/if}
              </div>
            {/if}
            <p class="mt-3 text-xs text-slate-500">@{job.author?.ident} · {job.author?.name || job.author?.ident} · 지원 {job.applicationCount || 0}건</p>
            {#if $bootstrap.viewer && $bootstrap.viewer.id !== job.author?.id && !job.isClosed}
              <div class="mt-3">
                <button type="button" class="rounded-lg border border-slate-900 bg-slate-900 px-3 py-1.5 text-xs font-semibold uppercase tracking-[0.15em] text-white transition hover:bg-slate-800 disabled:cursor-not-allowed disabled:border-slate-200 disabled:bg-slate-100 disabled:text-slate-400" on:click={() => applyJob(job.id)} disabled={job.viewerHasApplied || applyingJobId === job.id}>
                  {job.viewerHasApplied ? 'Applied' : (applyingJobId === job.id ? 'Applying…' : 'Apply')}
                </button>
              </div>
            {/if}
            {#if $bootstrap.viewer && ($bootstrap.viewer.id === job.author?.id || $bootstrap.viewer.role === 'admin') && !job.isClosed}
              <div class="mt-3 flex flex-wrap gap-2">
                <button type="button" class="rounded-lg border border-slate-200 bg-white px-3 py-1.5 text-xs font-semibold uppercase tracking-[0.15em] text-slate-700 transition hover:bg-slate-50" on:click={() => openEditJob(job)}>
                  Edit
                </button>
                <button type="button" class="rounded-lg border border-slate-200 bg-white px-3 py-1.5 text-xs font-semibold uppercase tracking-[0.15em] text-slate-700 transition hover:bg-slate-50" on:click={() => openApplications(job)}>
                  Applications
                </button>
                <button type="button" class="rounded-lg border border-rose-300 bg-white px-3 py-1.5 text-xs font-semibold uppercase tracking-[0.15em] text-rose-700 transition hover:bg-rose-50" on:click={() => closeJob(job.id)} disabled={closingJobId === job.id}>
                  {closingJobId === job.id ? 'Closing…' : 'Close Job'}
                </button>
                <button type="button" class="rounded-lg border border-rose-200 bg-white px-3 py-1.5 text-xs font-semibold uppercase tracking-[0.15em] text-rose-700 transition hover:bg-rose-50" on:click={() => deleteJob(job.id)} disabled={deletingJobId === job.id}>
                  {deletingJobId === job.id ? 'Deleting…' : 'Delete'}
                </button>
              </div>
            {:else if $bootstrap.viewer && ($bootstrap.viewer.id === job.author?.id || $bootstrap.viewer.role === 'admin')}
              <div class="mt-3 flex flex-wrap gap-2">
                <button type="button" class="rounded-lg border border-slate-200 bg-white px-3 py-1.5 text-xs font-semibold uppercase tracking-[0.15em] text-slate-700 transition hover:bg-slate-50" on:click={() => openEditJob(job)}>
                  Edit
                </button>
                <button type="button" class="rounded-lg border border-slate-200 bg-white px-3 py-1.5 text-xs font-semibold uppercase tracking-[0.15em] text-slate-700 transition hover:bg-slate-50" on:click={() => openApplications(job)}>
                  Applications
                </button>
                <button type="button" class="rounded-lg border border-rose-200 bg-white px-3 py-1.5 text-xs font-semibold uppercase tracking-[0.15em] text-rose-700 transition hover:bg-rose-50" on:click={() => deleteJob(job.id)} disabled={deletingJobId === job.id}>
                  {deletingJobId === job.id ? 'Deleting…' : 'Delete'}
                </button>
              </div>
            {/if}
          </li>
        {/each}
      </ul>
    {/if}
  </div>
</section>

{#if open}
  <div
    class="fixed inset-0 z-40 flex items-center justify-center bg-slate-900/40 px-4"
    role="button"
    tabindex="0"
    aria-label="Close new job dialog"
    on:click={() => (open = false)}
    on:keydown={(event) => {
      if (event.key === 'Escape' || event.key === 'Enter' || event.key === ' ') {
        open = false;
        resetForm();
      }
    }}
  >
    <div class="max-h-[92vh] w-[min(94vw,48rem)] overflow-y-auto rounded-2xl bg-white p-6 shadow-xl" role="dialog" tabindex="-1" aria-modal="true" on:click|stopPropagation on:keydown|stopPropagation={() => {}}>
      <div class="flex items-center justify-between">
        <h2 class="text-lg font-semibold text-slate-900">{editingJobId ? 'Edit job post' : 'New job post'}</h2>
        <button type="button" class="rounded-xl border border-slate-200 px-3 py-1 text-xs font-semibold uppercase tracking-[0.2em] text-slate-600" on:click={() => { open = false; resetForm(); }}>Close</button>
      </div>
      <form class="mt-4 space-y-4" on:submit|preventDefault={submitJob}>
        <div class="space-y-1">
          <label class="text-sm font-semibold text-slate-700" for="job-title">Title</label>
          <input id="job-title" type="text" bind:value={form.title} required class="w-full rounded-xl border border-slate-200 bg-slate-50 px-3 py-2 text-slate-900" placeholder="Backend Engineer" />
        </div>
        <div class="grid grid-cols-1 gap-3 sm:grid-cols-2">
          <div class="flex flex-col space-y-1">
            <label class="text-sm font-semibold text-slate-700" for="job-company">Company</label>
            <select id="job-company" bind:value={form.companyId} required class="w-full rounded-xl border border-slate-200 bg-slate-50 px-3 py-2 text-slate-900" on:change={(event) => setCompanyFromSelect(event.currentTarget.value)}>
              <option value="">Select company</option>
              {#each companyOptions as company}
                <option value={String(company.id)}>{company.name}</option>
              {/each}
            </select>
            <input type="hidden" bind:value={form.company} />
          </div>
          <div class="flex flex-col space-y-1">
            <label class="text-sm font-semibold text-slate-700" for="job-salary">Salary</label>
            <input id="job-salary" type="text" bind:value={form.salary} class="w-full rounded-xl border border-slate-200 bg-slate-50 px-3 py-2 text-slate-900" placeholder="연 7,000만원~9,000만원" />
          </div>
        </div>
        <div class="grid grid-cols-1 gap-3 sm:grid-cols-4">
          <div class="flex flex-col space-y-1">
            <label class="text-sm font-semibold text-slate-700" for="job-salary-min">Salary min</label>
            <input id="job-salary-min" type="number" min="0" bind:value={form.salaryMin} class="w-full rounded-xl border border-slate-200 bg-slate-50 px-3 py-2 text-slate-900" />
          </div>
          <div class="flex flex-col space-y-1">
            <label class="text-sm font-semibold text-slate-700" for="job-salary-max">Salary max</label>
            <input id="job-salary-max" type="number" min="0" bind:value={form.salaryMax} class="w-full rounded-xl border border-slate-200 bg-slate-50 px-3 py-2 text-slate-900" />
          </div>
          <div class="flex flex-col space-y-1">
            <label class="text-sm font-semibold text-slate-700" for="job-salary-currency">Currency</label>
            <input id="job-salary-currency" type="text" bind:value={form.salaryCurrency} maxlength="3" class="w-full rounded-xl border border-slate-200 bg-slate-50 px-3 py-2 text-slate-900 uppercase" placeholder="KRW" />
          </div>
          <div class="flex flex-col space-y-1">
            <label class="text-sm font-semibold text-slate-700" for="job-salary-period">Period</label>
            <select id="job-salary-period" bind:value={form.salaryPeriod} class="w-full rounded-xl border border-slate-200 bg-slate-50 px-3 py-2 text-slate-900">
              <option value="">Unspecified</option>
              {#each salaryPeriodOptions as option}
                <option value={option.value}>{option.label}</option>
              {/each}
            </select>
          </div>
        </div>
        <div class="grid grid-cols-1 gap-3 sm:grid-cols-2">
          <div class="flex flex-col space-y-1">
            <label class="text-sm font-semibold text-slate-700" for="job-working-hours">Working hours</label>
            <input id="job-working-hours" type="text" bind:value={form.workingHours} class="w-full rounded-xl border border-slate-200 bg-slate-50 px-3 py-2 text-slate-900" placeholder="09:00-18:00" />
          </div>
          <div class="flex flex-col space-y-1">
            <label class="text-sm font-semibold text-slate-700" for="job-deadline">Deadline</label>
            <input id="job-deadline" type="date" bind:value={form.deadline} class="w-full rounded-xl border border-slate-200 bg-slate-50 px-3 py-2 text-slate-900" />
          </div>
        </div>
        <div class="grid grid-cols-1 gap-3 sm:grid-cols-3">
          <div class="flex flex-col space-y-1">
            <label class="text-sm font-semibold text-slate-700" for="job-experience">Experience</label>
            <input id="job-experience" type="text" bind:value={form.experience} class="w-full rounded-xl border border-slate-200 bg-slate-50 px-3 py-2 text-slate-900" placeholder="3년 이상" />
          </div>
          <div class="flex flex-col space-y-1">
            <label class="text-sm font-semibold text-slate-700" for="job-employment-type">Employment type</label>
            <select id="job-employment-type" bind:value={form.employmentType} required class="w-full rounded-xl border border-slate-200 bg-slate-50 px-3 py-2 text-slate-900">
              {#each employmentTypeOptions as option}
                <option value={option.value}>{option.label}</option>
              {/each}
            </select>
          </div>
          <div class="flex flex-col space-y-1">
            <label class="text-sm font-semibold text-slate-700" for="job-workplace-type">Workplace</label>
            <select id="job-workplace-type" bind:value={form.workplaceType} class="w-full rounded-xl border border-slate-200 bg-slate-50 px-3 py-2 text-slate-900">
              <option value="">Unspecified</option>
              {#each workplaceTypeOptions as option}
                <option value={option.value}>{option.label}</option>
              {/each}
            </select>
          </div>
        </div>
        <div class="grid grid-cols-1 gap-3 sm:grid-cols-3">
          <div class="flex flex-col space-y-1">
            <label class="text-sm font-semibold text-slate-700" for="job-seniority">Seniority</label>
            <select id="job-seniority" bind:value={form.seniority} class="w-full rounded-xl border border-slate-200 bg-slate-50 px-3 py-2 text-slate-900">
              <option value="">Unspecified</option>
              {#each seniorityOptions as option}
                <option value={option.value}>{option.label}</option>
              {/each}
            </select>
          </div>
          <div class="flex flex-col space-y-1">
            <label class="text-sm font-semibold text-slate-700" for="job-apply-url">Apply URL</label>
            <input id="job-apply-url" type="url" bind:value={form.applyUrl} class="w-full rounded-xl border border-slate-200 bg-slate-50 px-3 py-2 text-slate-900" placeholder="https://example.com/apply" />
          </div>
          <div class="flex flex-col space-y-1">
            <label class="text-sm font-semibold text-slate-700" for="job-apply-email">Apply email</label>
            <input id="job-apply-email" type="email" bind:value={form.applyEmail} class="w-full rounded-xl border border-slate-200 bg-slate-50 px-3 py-2 text-slate-900" placeholder="jobs@example.com" />
          </div>
        </div>
        <div class="grid grid-cols-1 gap-3 sm:grid-cols-2">
          <div class="flex flex-col space-y-1">
            <label class="text-sm font-semibold text-slate-700" for="job-skills">Skills</label>
            <input id="job-skills" type="text" bind:value={form.skills} list="job-skill-suggestions" class="w-full rounded-xl border border-slate-200 bg-slate-50 px-3 py-2 text-slate-900" placeholder="haskell, postgresql, aws" />
            <datalist id="job-skill-suggestions">
              {#each skillSuggestions as skill}
                <option value={skill}></option>
              {/each}
            </datalist>
          </div>
          <div class="flex flex-col space-y-1">
            <label class="text-sm font-semibold text-slate-700" for="job-benefits">Benefits</label>
            <input id="job-benefits" type="text" bind:value={form.benefits} class="w-full rounded-xl border border-slate-200 bg-slate-50 px-3 py-2 text-slate-900" placeholder="재택근무, 교육비, 스톡옵션" />
          </div>
        </div>
        <div class="space-y-1">
          <label class="text-sm font-semibold text-slate-700" for="job-content">Description</label>
          <textarea id="job-content" bind:value={form.content} required rows="7" class="w-full rounded-xl border border-slate-200 bg-slate-50 px-3 py-2 text-sm text-slate-900" placeholder="역할, 요구사항, 지원 방법을 적어주세요."></textarea>
        </div>
        <div class="flex justify-end gap-2 pt-1">
          <button type="submit" class="rounded-xl bg-gradient-to-r from-slate-900 to-slate-700 px-4 py-2 text-center text-xs font-semibold uppercase tracking-[0.2em] text-white" disabled={submitting}>
            {submitting ? (editingJobId ? 'Saving…' : 'Posting…') : (editingJobId ? 'Save' : 'Post')}
          </button>
          <button type="button" class="rounded-xl border border-slate-200 px-4 py-2 text-xs font-semibold uppercase tracking-[0.2em] text-slate-600" on:click={() => { open = false; resetForm(); }}>Cancel</button>
        </div>
      </form>
    </div>
  </div>
{/if}

{#if myApplicationsOpen}
  <div class="fixed inset-0 z-40 flex items-center justify-center bg-slate-900/40 px-4" role="button" tabindex="0" aria-label="Close my applications dialog" on:click={() => (myApplicationsOpen = false)} on:keydown={(event) => {
    if (event.key === 'Escape' || event.key === 'Enter' || event.key === ' ') myApplicationsOpen = false;
  }}>
    <div class="max-h-[92vh] w-[min(94vw,42rem)] overflow-y-auto rounded-2xl bg-white p-6 shadow-xl" role="dialog" tabindex="-1" aria-modal="true" on:click|stopPropagation on:keydown|stopPropagation={() => {}}>
      <div class="flex items-start justify-between gap-4">
        <div>
          <h2 class="text-lg font-semibold text-slate-900">My Applications</h2>
          <p class="mt-1 text-sm text-slate-500">지원한 공고와 현재 상태를 확인합니다.</p>
        </div>
        <button type="button" class="rounded-xl border border-slate-200 px-3 py-1 text-xs font-semibold uppercase tracking-[0.2em] text-slate-600" on:click={() => (myApplicationsOpen = false)}>Close</button>
      </div>

      {#if myApplicationsLoading}
        <div class="mt-6 rounded-2xl border border-slate-200 bg-slate-50 p-6 text-center text-sm text-slate-500">Loading applications…</div>
      {:else if !myApplications.length}
        <div class="mt-6 rounded-2xl border border-slate-200 bg-slate-50 p-6 text-center text-sm text-slate-500">지원한 공고가 없습니다.</div>
      {:else}
        <ul class="mt-5 divide-y divide-slate-200 rounded-2xl border border-slate-200">
          {#each myApplications as application}
            <li class="p-4">
              <div class="flex flex-wrap items-start justify-between gap-3">
                <div>
                  <p class="text-sm font-semibold text-slate-900">{application.job?.title}</p>
                  <p class="mt-1 text-sm text-slate-600">{application.job?.company}</p>
                  <p class="mt-1 text-xs text-slate-500">상태: {optionLabel(applicationStatusOptions, application.status)} · 지원일: {relativeTime(application.createdAt)}</p>
                  {#if application.note}
                    <p class="mt-2 whitespace-pre-wrap text-sm text-slate-700">{application.note}</p>
                  {/if}
                </div>
                <button type="button" class="rounded-lg border border-rose-200 bg-white px-3 py-1.5 text-xs font-semibold uppercase tracking-[0.15em] text-rose-700 transition hover:bg-rose-50" disabled={withdrawingJobId === application.job?.id} on:click={() => withdrawApplication(application.job?.id)}>
                  {withdrawingJobId === application.job?.id ? 'Withdrawing…' : 'Withdraw'}
                </button>
              </div>
            </li>
          {/each}
        </ul>
      {/if}
    </div>
  </div>
{/if}

{#if applicationsOpen}
  <div class="fixed inset-0 z-40 flex items-center justify-center bg-slate-900/40 px-4" role="button" tabindex="0" aria-label="Close applications dialog" on:click={() => (applicationsOpen = false)} on:keydown={(event) => {
    if (event.key === 'Escape' || event.key === 'Enter' || event.key === ' ') applicationsOpen = false;
  }}>
    <div class="max-h-[92vh] w-[min(94vw,44rem)] overflow-y-auto rounded-2xl bg-white p-6 shadow-xl" role="dialog" tabindex="-1" aria-modal="true" on:click|stopPropagation on:keydown|stopPropagation={() => {}}>
      <div class="flex items-start justify-between gap-4">
        <div>
          <h2 class="text-lg font-semibold text-slate-900">Applications</h2>
          <p class="mt-1 text-sm text-slate-500">{applicationsJob?.title} · {applicationsJob?.company}</p>
        </div>
        <button type="button" class="rounded-xl border border-slate-200 px-3 py-1 text-xs font-semibold uppercase tracking-[0.2em] text-slate-600" on:click={() => (applicationsOpen = false)}>Close</button>
      </div>

      <form class="mt-5 grid grid-cols-1 gap-2 rounded-2xl border border-slate-200 bg-slate-50 p-3 sm:grid-cols-[1fr_1fr_auto]" on:submit|preventDefault={loadApplications}>
        <label class="flex flex-col gap-1 text-xs font-semibold text-slate-600">
          Status
          <select bind:value={applicationFilters.status} class="rounded-xl border border-slate-200 bg-white px-3 py-2 text-sm font-normal text-slate-900">
            <option value="">All</option>
            {#each applicationStatusOptions as option}
              <option value={option.value}>{option.label} ({applicationStatusCounts[option.value] || 0})</option>
            {/each}
          </select>
        </label>
        <label class="flex flex-col gap-1 text-xs font-semibold text-slate-600">
          Search
          <input type="text" bind:value={applicationFilters.q} class="rounded-xl border border-slate-200 bg-white px-3 py-2 text-sm font-normal text-slate-900" placeholder="applicant, note" />
        </label>
        <div class="flex items-end gap-2">
          <button type="submit" class="rounded-xl bg-slate-900 px-3 py-2 text-xs font-semibold uppercase tracking-[0.16em] text-white">Filter</button>
          <a class="rounded-xl border border-slate-200 bg-white px-3 py-2 text-xs font-semibold uppercase tracking-[0.16em] text-slate-600 transition hover:bg-slate-100" href={applicationCsvUrl()}>CSV</a>
        </div>
      </form>

      {#if applicationsLoading}
        <div class="mt-6 rounded-2xl border border-slate-200 bg-slate-50 p-6 text-center text-sm text-slate-500">Loading applications…</div>
      {:else if !applications.length}
        <div class="mt-6 rounded-2xl border border-slate-200 bg-slate-50 p-6 text-center text-sm text-slate-500">아직 지원자가 없습니다.</div>
      {:else}
        <ul class="mt-5 divide-y divide-slate-200 rounded-2xl border border-slate-200">
          {#each applications as application}
            <li class="p-4">
              <div class="flex flex-wrap items-start justify-between gap-3">
                <div>
                  <p class="text-sm font-semibold text-slate-900">@{application.applicant?.ident}</p>
                  <p class="mt-1 text-xs text-slate-500">지원일: {relativeTime(application.createdAt)}</p>
                  {#if application.note}
                    <p class="mt-2 whitespace-pre-wrap text-sm text-slate-700">{application.note}</p>
                  {/if}
                </div>
                <div class="grid min-w-[13rem] gap-2">
                  <select class="rounded-xl border border-slate-200 bg-slate-50 px-3 py-2 text-sm text-slate-900" value={application.status} disabled={updatingApplicationId === application.id} on:change={(event) => updateApplication(application, { status: event.currentTarget.value })}>
                    {#each applicationStatusOptions as option}
                      <option value={option.value}>{option.label}</option>
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
            </li>
          {/each}
        </ul>
      {/if}
    </div>
  </div>
{/if}
