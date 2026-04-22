<script>
  import { onMount } from 'svelte';
  import { bootstrap } from '$lib/stores/bootstrap';
  import LeafletMap from '$lib/components/LeafletMap.svelte';
  import PageEmpty from '$lib/components/PageEmpty.svelte';
  import { apiFetch } from '$lib/utils/api';

  let loading = true;
  let markers = [];
  let loadError = '';

  async function loadMarkers() {
    loading = true;
    loadError = '';
    try {
      const payload = await apiFetch('/api/v1/map/markers');
      markers = payload.markers || [];
    } catch (error) {
      loadError = error.message;
    } finally {
      loading = false;
    }
  }

  onMount(loadMarkers);
</script>

<section class="flex h-full min-h-0 flex-col bg-white">
  <div class="shrink-0 border-b border-slate-200 px-4 py-3">
    <div class="text-xs font-semibold uppercase tracking-[0.18em] text-slate-500">Map</div>
    <div class="mt-1 flex items-end justify-between gap-4">
      <div>
        <h1 class="text-2xl font-semibold text-slate-900">Community Map</h1>
        <p class="mt-1 text-sm text-slate-500">지도에 표시된 게시글, 회사, 채용 위치를 확인할 수 있습니다.</p>
      </div>
      <div class="text-sm text-slate-500">{markers.length} markers</div>
    </div>
  </div>

  <div class="min-h-0 flex-1 px-4 py-4">
    {#if !$bootstrap.site?.mapsEnabled}
      <PageEmpty title="Maps are disabled." description="관리자 설정에서 지도 기능을 켜야 합니다." />
    {:else if loading}
      <div class="flex h-full items-center justify-center text-sm text-slate-500">Loading map…</div>
    {:else if loadError}
      <PageEmpty title="Could not load map." description={loadError} />
    {:else if !markers.length}
      <PageEmpty title="No map markers yet." description="좌표가 있는 게시글, 회사, 채용이 생기면 여기에 표시됩니다." />
    {:else}
      <div class="grid h-full min-h-0 gap-4 grid-rows-[minmax(0,1fr)_320px]">
        <LeafletMap markers={markers} heightClass="h-full" />

        <div class="overflow-hidden rounded-2xl border border-slate-200 bg-slate-50">
          <div class="border-b border-slate-200 px-4 py-3 text-sm font-semibold text-slate-900">Locations</div>
          <div class="h-full overflow-y-auto divide-y divide-slate-200">
            {#each markers as marker}
              <a href={marker.url} class="block px-4 py-3 transition hover:bg-white">
                <div class="flex items-center justify-between gap-3">
                  <div class="min-w-0">
                    <div class="truncate text-sm font-semibold text-slate-900">{marker.title}</div>
                    {#if marker.subtitle}
                      <div class="mt-1 truncate text-xs text-slate-500">{marker.subtitle}</div>
                    {/if}
                  </div>
                  <span class="shrink-0 rounded-full bg-slate-900 px-2.5 py-1 text-[11px] font-semibold text-white">{marker.kind}</span>
                </div>
                <div class="mt-2 text-xs text-slate-500">{marker.latitude.toFixed(4)}, {marker.longitude.toFixed(4)}</div>
              </a>
            {/each}
          </div>
        </div>
      </div>
    {/if}
  </div>
</section>
