<script>
  import { onMount } from 'svelte';
  import { page } from '$app/stores';
  import PageEmpty from '$lib/components/PageEmpty.svelte';
  import { apiFetch } from '$lib/utils/api';
  import { formatDate, relativeTime } from '$lib/utils/time';

  let job = null;
  let loading = true;
  let error = '';

  const employmentTypeLabels = {
    full_time: 'Full time',
    part_time: 'Part time',
    contract: 'Contract',
    temporary: 'Temporary',
    internship: 'Internship',
    freelance: 'Freelance',
    casual: 'Casual'
  };

  const workplaceTypeLabels = {
    on_site: 'On site',
    hybrid: 'Hybrid',
    remote: 'Remote'
  };

  function salarySummary(item) {
    const hasRange = item.salaryMin !== null && item.salaryMin !== undefined || item.salaryMax !== null && item.salaryMax !== undefined;
    if (!hasRange) return item.salary;
    const currency = item.salaryCurrency || '';
    const min = item.salaryMin !== null && item.salaryMin !== undefined ? item.salaryMin.toLocaleString() : '';
    const max = item.salaryMax !== null && item.salaryMax !== undefined ? item.salaryMax.toLocaleString() : '';
    const period = item.salaryPeriod ? `/${item.salaryPeriod}` : '';
    return `${currency} ${min && max ? `${min}-${max}` : min || max}${period}`.trim();
  }

  onMount(async () => {
    try {
      const payload = await apiFetch(`/api/v1/jobs/${$page.params.id}`);
      job = payload.job;
    } catch (err) {
      error = err.message;
    } finally {
      loading = false;
    }
  });
</script>

<section class="min-h-full bg-white">
  <div class="border-b border-slate-200 px-4 py-3.5">
    <a href="/jobs" class="text-xs font-semibold uppercase tracking-[0.2em] text-slate-500 transition hover:text-slate-900">Back to jobs</a>
  </div>

  {#if loading}
    <div class="flex min-h-[50vh] items-center justify-center text-slate-500">Loading job…</div>
  {:else if error}
    <PageEmpty title="공고를 불러올 수 없습니다." description={error} />
  {:else if job}
    <article class="mx-auto max-w-4xl px-4 py-8">
      <div class="flex flex-wrap items-start justify-between gap-4">
        <div>
          <div class="flex flex-wrap gap-2 text-xs font-semibold text-slate-600">
            <span class="rounded-full bg-slate-100 px-2.5 py-1">{employmentTypeLabels[job.employmentType] || job.employmentType}</span>
            {#if job.workplaceType}
              <span class="rounded-full bg-slate-100 px-2.5 py-1">{workplaceTypeLabels[job.workplaceType] || job.workplaceType}</span>
            {/if}
            {#if job.isClosed}
              <span class="rounded-full border border-rose-200 bg-rose-50 px-2.5 py-1 text-rose-700">Closed</span>
            {:else}
              <span class="rounded-full border border-emerald-200 bg-emerald-50 px-2.5 py-1 text-emerald-700">Open</span>
            {/if}
          </div>
          <h1 class="mt-4 text-4xl font-semibold tracking-tight text-slate-950">{job.title}</h1>
          <p class="mt-2 text-lg text-slate-700">{job.company}</p>
        </div>
        <p class="text-xs text-slate-500">Posted {relativeTime(job.createdAt)}</p>
      </div>

      <dl class="mt-8 grid grid-cols-1 gap-3 rounded-2xl border border-slate-200 bg-slate-50 p-4 sm:grid-cols-2">
        {#if salarySummary(job)}
          <div>
            <dt class="text-xs font-semibold uppercase tracking-[0.18em] text-slate-500">Salary</dt>
            <dd class="mt-1 text-sm text-slate-900">{salarySummary(job)}</dd>
          </div>
        {/if}
        {#if job.deadline}
          <div>
            <dt class="text-xs font-semibold uppercase tracking-[0.18em] text-slate-500">Deadline</dt>
            <dd class="mt-1 text-sm text-slate-900">{formatDate(job.deadline)}</dd>
          </div>
        {/if}
        {#if job.experience}
          <div>
            <dt class="text-xs font-semibold uppercase tracking-[0.18em] text-slate-500">Experience</dt>
            <dd class="mt-1 text-sm text-slate-900">{job.experience}</dd>
          </div>
        {/if}
        {#if job.workingHours}
          <div>
            <dt class="text-xs font-semibold uppercase tracking-[0.18em] text-slate-500">Working Hours</dt>
            <dd class="mt-1 text-sm text-slate-900">{job.workingHours}</dd>
          </div>
        {/if}
      </dl>

      {#if job.skills?.length || job.benefits?.length}
        <div class="mt-6 flex flex-wrap gap-2 text-xs">
          {#each job.skills || [] as skill}
            <span class="rounded-full bg-slate-100 px-2.5 py-1 font-semibold text-slate-700">#{skill}</span>
          {/each}
          {#each job.benefits || [] as benefit}
            <span class="rounded-full border border-emerald-200 bg-emerald-50 px-2.5 py-1 font-semibold text-emerald-700">{benefit}</span>
          {/each}
        </div>
      {/if}

      <div class="mt-8 whitespace-pre-wrap rounded-2xl border border-slate-200 bg-white p-5 text-sm leading-7 text-slate-800">{job.content}</div>

      <div class="mt-6 flex flex-wrap gap-2">
        {#if job.applyUrl}
          <a class="rounded-xl bg-slate-900 px-4 py-2 text-xs font-semibold uppercase tracking-[0.2em] text-white transition hover:bg-slate-800" href={job.applyUrl} target="_blank" rel="noreferrer">Apply Link</a>
        {/if}
        {#if job.applyEmail}
          <a class="rounded-xl border border-slate-200 px-4 py-2 text-xs font-semibold uppercase tracking-[0.2em] text-slate-700 transition hover:bg-slate-50" href={`mailto:${job.applyEmail}`}>Apply Email</a>
        {/if}
      </div>
    </article>
  {/if}
</section>
