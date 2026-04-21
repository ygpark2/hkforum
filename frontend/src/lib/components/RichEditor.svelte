<script>
  import { onMount } from 'svelte';
  import { mountQuill } from '$lib/utils/quill';

  export let value = '';
  export let name = 'content';
  export let placeholder = 'Write here';
  export let uploadUrl = '/api/v1/uploads';
  export let minHeight = '220px';

  let shell;
  let toolbar;
  let editor;
  let textareaFallback = false;
  let quill;

  onMount(async () => {
    try {
      quill = await mountQuill({
        root: editor,
        toolbar,
        value,
        placeholder,
        uploadUrl,
        onChange: (nextValue) => {
          value = nextValue;
        }
      });
    } catch (error) {
      textareaFallback = true;
    }

    return () => {
      if (quill) {
        quill.off?.('text-change');
      }
    };
  });
</script>

{#if textareaFallback}
  <textarea
    bind:value
    name={name}
    rows="10"
    class="w-full rounded-2xl border border-slate-200 bg-white px-3 py-3 text-sm text-slate-900"
    placeholder={placeholder}
  ></textarea>
{:else}
  <input type="hidden" {name} value={value} />
  <div bind:this={shell} class="overflow-hidden rounded-2xl border border-slate-200">
    <div bind:this={toolbar}>
      <span class="ql-formats">
        <select class="ql-header">
          <option selected></option>
          <option value="2"></option>
          <option value="3"></option>
        </select>
        <select class="ql-align"></select>
      </span>
      <span class="ql-formats">
        <button type="button" class="ql-bold" aria-label="Bold"></button>
        <button type="button" class="ql-italic" aria-label="Italic"></button>
        <button type="button" class="ql-underline" aria-label="Underline"></button>
      </span>
      <span class="ql-formats">
        <button type="button" class="ql-list" value="ordered" aria-label="Ordered list"></button>
        <button type="button" class="ql-list" value="bullet" aria-label="Bullet list"></button>
        <button type="button" class="ql-blockquote" aria-label="Blockquote"></button>
        <button type="button" class="ql-link" aria-label="Link"></button>
        <button type="button" class="ql-image" aria-label="Image"></button>
      </span>
    </div>
    <div bind:this={editor} class="bg-white" style={`min-height:${minHeight}`}></div>
  </div>
{/if}
