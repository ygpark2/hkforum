<script>
  export let title = 'Nothing here yet.';
  export let description = '';
</script>

<div class="flex h-full flex-col items-center justify-center px-6 text-center">
  <div class="max-w-md rounded-2xl border border-dashed border-slate-300 bg-slate-50 px-6 py-10">
    <h2 class="text-xl font-semibold text-slate-900">{title}</h2>
    {#if description}
      <p class="mt-2 text-sm text-slate-500">{description}</p>
    {/if}
  </div>
</div>
