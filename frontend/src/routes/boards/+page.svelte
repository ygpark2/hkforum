<script>
  import PageEmpty from '$lib/components/PageEmpty.svelte';
  import { bootstrap } from '$lib/stores/bootstrap';

  $: boards = $bootstrap.boards || [];

  $: localRegionNotice =
    $bootstrap.viewer?.localRegionOnly && !$bootstrap.viewer?.countryCode
      ? '프로필에 국가와 주를 저장해야 내 지역 필터를 사용할 수 있습니다.'
      : $bootstrap.viewer?.localRegionOnly && $bootstrap.viewer?.countryCode && $bootstrap.viewer?.state
        ? `내 지역 필터 적용 중: ${$bootstrap.viewer.state}, ${$bootstrap.viewer.countryCode}`
        : null;
</script>

<section class="flex h-full min-h-0 flex-col bg-white">
  <div class="shrink-0 border-b border-slate-200 px-4 py-3.5">
    <h1 class="text-3xl font-semibold text-slate-900">All Boards</h1>
    <p class="mt-1 text-sm text-slate-500">Browse every board and its latest posts.</p>
    {#if localRegionNotice}
      <p class="mt-2 inline-flex rounded-full border border-sky-200 bg-sky-50 px-3 py-1 text-xs font-semibold text-sky-700">{localRegionNotice}</p>
    {/if}
  </div>

  <div class="min-h-0 flex-1 overflow-y-auto no-scrollbar">
    {#if !boards.length}
      <PageEmpty title="No boards yet." />
    {:else}
      <ul class="divide-y divide-slate-200">
        {#each boards as board}
          <li class="px-4 py-4">
            <div class="flex items-start justify-between gap-4">
              <div class="min-w-0">
                <a href={`/board/${board.id}`} class="text-xl font-semibold text-slate-900 transition hover:text-slate-700">{board.name}</a>
                {#if board.description}
                  <p class="mt-1 text-sm text-slate-500">{board.description}</p>
                {/if}
                <p class="mt-1 text-xs text-slate-400">{board.postCount} posts · {board.commentCount} comments</p>
              </div>
              <a href={`/board/${board.id}`} class="shrink-0 rounded-lg border border-slate-200 px-3 py-1.5 text-xs font-semibold text-slate-700 transition hover:border-slate-400 hover:text-slate-900">Open</a>
            </div>
          </li>
        {/each}
      </ul>
    {/if}
  </div>
</section>
