<script>
  import { onMount } from 'svelte';
  import AppShell from '$lib/components/AppShell.svelte';
  import { refreshBootstrap } from '$lib/utils/api';
  import { applyTheme, getStoredTheme, syncTheme } from '$lib/utils/theme';

  let shellLoading = true;

  onMount(async () => {
    const storedTheme = getStoredTheme();
    applyTheme(storedTheme);

    try {
      const payload = await refreshBootstrap();
      syncTheme(payload?.viewer?.theme || storedTheme || payload?.site?.defaultTheme);
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
