<script>
  import { onMount } from 'svelte';
  import AppShell from '$lib/components/AppShell.svelte';
  import { refreshBootstrap } from '$lib/utils/api';

  let shellLoading = true;

  onMount(async () => {
    try {
      await refreshBootstrap();
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
