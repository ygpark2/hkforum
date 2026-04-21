<script>
  import { onMount } from 'svelte';
  import AppShell from '$lib/components/AppShell.svelte';
  import { bootstrap } from '$lib/stores/bootstrap';
  import { apiFetch } from '$lib/utils/api';

  let shellLoading = true;

  onMount(async () => {
    try {
      const payload = await apiFetch('/api/v1/bootstrap');
      bootstrap.set({
        ready: true,
        loading: false,
        ...payload
      });
    } catch (error) {
      window.alert(error.message);
    } finally {
      shellLoading = false;
    }
  });
</script>

<AppShell loading={shellLoading}>
  <slot />
</AppShell>
