<script>
  import { onMount } from 'svelte';
  import PageEmpty from '$lib/components/PageEmpty.svelte';
  import { bootstrap } from '$lib/stores/bootstrap';
  import { apiFetch, sendJson } from '$lib/utils/api';
  import { formatDate, relativeTime } from '$lib/utils/time';

  let items = [];
  let loading = true;
  let open = false;
  let submitting = false;
  let closingJobId = null;
  let deletingJobId = null;
  let editingJobId = null;
  let form = {
    title: '',
    company: '',
    salary: '',
    workingHours: '',
    deadline: '',
    experience: '',
    employmentType: '',
    content: ''
  };

  function resetForm() {
    form = {
      title: '',
      company: '',
      salary: '',
      workingHours: '',
      deadline: '',
      experience: '',
      employmentType: '',
      content: ''
    };
    editingJobId = null;
  }

  async function loadJobs() {
    loading = true;
    try {
      const payload = await apiFetch('/api/v1/jobs');
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
          salary: form.salary || null,
          workingHours: form.workingHours || null,
          deadline: form.deadline || null,
          experience: form.experience || null,
          employmentType: form.employmentType || null,
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
    open = true;
  }

  function openEditJob(job) {
    editingJobId = job.id;
    form = {
      title: job.title || '',
      company: job.company || '',
      salary: job.salary || '',
      workingHours: job.workingHours || '',
      deadline: job.deadline || '',
      experience: job.experience || '',
      employmentType: job.employmentType || '',
      content: job.content || ''
    };
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
        <button type="button" class="rounded-lg bg-slate-900 px-3 py-1.5 text-xs font-semibold uppercase tracking-[0.2em] text-white transition hover:bg-slate-800" on:click={openCreateJob}>New Job</button>
      {:else}
        <a href="/login" class="rounded-lg border border-slate-900 px-3 py-1.5 text-xs font-semibold uppercase tracking-[0.2em] text-slate-900 transition hover:bg-slate-900 hover:text-white">Login to post</a>
      {/if}
    </div>
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
                <h2 class="break-words text-xl font-semibold text-slate-900">{job.title}</h2>
                <p class="mt-1 text-sm font-medium text-slate-700">{job.company}</p>
                <div class="mt-1 flex flex-wrap items-center gap-x-2 gap-y-1 text-xs text-slate-500">
                  {#if job.salary}
                    <span>연봉: {job.salary}</span>
                  {/if}
                  {#if job.workingHours}
                    <span>· 근무시간: {job.workingHours}</span>
                  {/if}
                  {#if job.experience}
                    <span>· 경력: {job.experience}</span>
                  {/if}
                  {#if job.employmentType}
                    <span>· {job.employmentType}</span>
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
            <p class="mt-3 text-xs text-slate-500">@{job.author?.ident} · {job.author?.name || job.author?.ident}</p>
            {#if $bootstrap.viewer && ($bootstrap.viewer.id === job.author?.id || $bootstrap.viewer.role === 'admin') && !job.isClosed}
              <div class="mt-3 flex flex-wrap gap-2">
                <button type="button" class="rounded-lg border border-slate-200 bg-white px-3 py-1.5 text-xs font-semibold uppercase tracking-[0.15em] text-slate-700 transition hover:bg-slate-50" on:click={() => openEditJob(job)}>
                  Edit
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
    <div class="w-[min(94vw,43rem)] rounded-2xl bg-white p-6 shadow-xl" role="dialog" tabindex="-1" aria-modal="true" on:click|stopPropagation on:keydown|stopPropagation={() => {}}>
      <div class="flex items-center justify-between">
        <h2 class="text-lg font-semibold text-slate-900">{editingJobId ? 'Edit job post' : 'New job post'}</h2>
        <button type="button" class="rounded-xl border border-slate-200 px-3 py-1 text-xs font-semibold uppercase tracking-[0.2em] text-slate-600" on:click={() => { open = false; resetForm(); }}>Close</button>
      </div>
      <form class="mt-4 space-y-4" on:submit|preventDefault={submitJob}>
        <div class="space-y-1">
          <label class="text-sm font-semibold text-slate-700" for="job-title">Title</label>
          <input id="job-title" type="text" bind:value={form.title} required class="w-full rounded-xl border border-slate-200 bg-slate-50 px-3 py-2 text-slate-900" placeholder="Backend Engineer" />
        </div>
        <div class="grid grid-cols-2 gap-3 !grid">
          <div class="flex flex-col space-y-1">
            <label class="text-sm font-semibold text-slate-700" for="job-company">Company</label>
            <input id="job-company" type="text" bind:value={form.company} required class="w-full rounded-xl border border-slate-200 bg-slate-50 px-3 py-2 text-slate-900" placeholder="Type company name" />
          </div>
          <div class="flex flex-col space-y-1">
            <label class="text-sm font-semibold text-slate-700" for="job-salary">Salary</label>
            <input id="job-salary" type="text" bind:value={form.salary} class="w-full rounded-xl border border-slate-200 bg-slate-50 px-3 py-2 text-slate-900" placeholder="연 7,000만원~9,000만원" />
          </div>
        </div>
        <div class="grid grid-cols-2 gap-3 !grid">
          <div class="flex flex-col space-y-1">
            <label class="text-sm font-semibold text-slate-700" for="job-working-hours">Working hours</label>
            <input id="job-working-hours" type="text" bind:value={form.workingHours} class="w-full rounded-xl border border-slate-200 bg-slate-50 px-3 py-2 text-slate-900" placeholder="09:00-18:00" />
          </div>
          <div class="flex flex-col space-y-1">
            <label class="text-sm font-semibold text-slate-700" for="job-deadline">Deadline</label>
            <input id="job-deadline" type="date" bind:value={form.deadline} class="w-full rounded-xl border border-slate-200 bg-slate-50 px-3 py-2 text-slate-900" />
          </div>
        </div>
        <div class="grid grid-cols-2 gap-3 !grid">
          <div class="flex flex-col space-y-1">
            <label class="text-sm font-semibold text-slate-700" for="job-experience">Experience</label>
            <input id="job-experience" type="text" bind:value={form.experience} class="w-full rounded-xl border border-slate-200 bg-slate-50 px-3 py-2 text-slate-900" placeholder="3년 이상" />
          </div>
          <div class="flex flex-col space-y-1">
            <label class="text-sm font-semibold text-slate-700" for="job-employment-type">Employment type</label>
            <input id="job-employment-type" type="text" bind:value={form.employmentType} class="w-full rounded-xl border border-slate-200 bg-slate-50 px-3 py-2 text-slate-900" placeholder="Full-time" />
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
