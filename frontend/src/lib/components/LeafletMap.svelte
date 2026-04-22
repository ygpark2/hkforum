<script>
  import { onMount } from 'svelte';
  import { bootstrap } from '$lib/stores/bootstrap';

  export let latitude = null;
  export let longitude = null;
  export let zoom = null;
  export let markers = [];
  export let interactive = false;
  export let heightClass = 'h-72';

  let mapElement;
  let map;
  let markerLayer;
  let selectedMarker = null;

  const LEAFLET_CSS_ID = 'leaflet-css-cdn';
  const LEAFLET_SCRIPT_ID = 'leaflet-js-cdn';

  function defaultCenter() {
    return [
      latitude ?? $bootstrap.site?.defaultMapLatitude ?? 37.5665,
      longitude ?? $bootstrap.site?.defaultMapLongitude ?? 126.978
    ];
  }

  async function loadLeaflet() {
    if (window.L) return window.L;

    if (!document.getElementById(LEAFLET_CSS_ID)) {
      const link = document.createElement('link');
      link.id = LEAFLET_CSS_ID;
      link.rel = 'stylesheet';
      link.href = 'https://unpkg.com/leaflet@1.9.4/dist/leaflet.css';
      document.head.appendChild(link);
    }

    const existingScript = document.getElementById(LEAFLET_SCRIPT_ID);
    if (existingScript) {
      await waitForLeaflet();
      return window.L;
    }

    const script = document.createElement('script');
    script.id = LEAFLET_SCRIPT_ID;
    script.src = 'https://unpkg.com/leaflet@1.9.4/dist/leaflet.js';
    script.async = true;
    document.body.appendChild(script);

    await new Promise((resolve, reject) => {
      script.onload = resolve;
      script.onerror = reject;
    });

    return window.L;
  }

  async function waitForLeaflet() {
    await new Promise((resolve, reject) => {
      let attempts = 0;
      const timer = window.setInterval(() => {
        if (window.L) {
          window.clearInterval(timer);
          resolve();
          return;
        }
        attempts += 1;
        if (attempts > 100) {
          window.clearInterval(timer);
          reject(new Error('Failed to load Leaflet.'));
        }
      }, 50);
    });
  }

  function clearLayers() {
    markerLayer?.clearLayers();
    selectedMarker = null;
  }

  function renderSelectedMarker() {
    if (!map || !interactive || latitude == null || longitude == null) return;
    const L = window.L;
    selectedMarker = L.marker([latitude, longitude]).addTo(markerLayer);
  }

  function renderMarkers() {
    if (!map || interactive) return;
    const L = window.L;
    for (const item of markers) {
      if (item.latitude == null || item.longitude == null) continue;
      const marker = L.marker([item.latitude, item.longitude]).addTo(markerLayer);
      const detail = item.subtitle ? `<div class="text-xs text-slate-500">${item.subtitle}</div>` : '';
      const link = item.url ? `<a href="${item.url}" class="mt-2 inline-flex text-sm font-semibold text-slate-700 underline underline-offset-2">Open</a>` : '';
      marker.bindPopup(`<div class="min-w-[160px]"><div class="font-semibold text-slate-900">${item.title || 'Untitled'}</div>${detail}${link}</div>`);
    }
  }

  function syncView() {
    if (!map) return;
    const center = defaultCenter();
    const nextZoom = zoom ?? $bootstrap.site?.defaultMapZoom ?? (interactive ? 12 : 6);
    map.setView(center, nextZoom);
  }

  async function initializeMap() {
    const L = await loadLeaflet();
    if (!mapElement || map) return;

    map = L.map(mapElement, {
      zoomControl: true,
      scrollWheelZoom: true
    });

    L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
      maxZoom: 19,
      attribution: '&copy; OpenStreetMap contributors'
    }).addTo(map);

    markerLayer = L.layerGroup().addTo(map);
    syncView();

    if (interactive) {
      map.on('click', (event) => {
        latitude = Number(event.latlng.lat.toFixed(6));
        longitude = Number(event.latlng.lng.toFixed(6));
        clearLayers();
        renderSelectedMarker();
      });
      renderSelectedMarker();
    } else {
      renderMarkers();
      if (markers.length > 0) {
        const bounds = L.latLngBounds(markers.map((item) => [item.latitude, item.longitude]));
        if (bounds.isValid()) {
          map.fitBounds(bounds.pad(0.15));
        }
      }
    }

    window.setTimeout(() => map.invalidateSize(), 0);
  }

  onMount(() => {
    initializeMap();

    return () => {
      if (map) {
        map.remove();
        map = null;
      }
    };
  });

  $: if (map) {
    clearLayers();
    if (interactive) {
      renderSelectedMarker();
      syncView();
    } else {
      renderMarkers();
    }
    window.setTimeout(() => map?.invalidateSize(), 0);
  }
</script>

<div class={`overflow-hidden rounded-2xl border border-slate-200 bg-slate-100 ${heightClass}`}>
  <div bind:this={mapElement} class="h-full w-full" aria-label="Map"></div>
</div>
