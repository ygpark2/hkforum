import "../../../chunks/index-server.js";
import "../../../chunks/dev.js";
import "../../../chunks/api.js";
import "../../../chunks/PageEmpty.js";
import "../../../chunks/PostCard.js";
//#region src/routes/bookmarks/+page.svelte
function _page($$renderer, $$props) {
	$$renderer.component(($$renderer) => {
		$$renderer.push(`<section class="flex min-h-full flex-col bg-white"><div class="border-b border-slate-200 px-5 py-4"><h1 class="text-2xl font-semibold text-slate-900">Bookmarks</h1> <p class="mt-1 text-sm text-slate-500">Saved posts from your account.</p></div> <div class="flex-1 overflow-y-auto">`);
		$$renderer.push("<!--[0-->");
		$$renderer.push(`<div class="px-5 py-6 text-sm text-slate-500">Loading bookmarks…</div>`);
		$$renderer.push(`<!--]--></div></section>`);
	});
}
//#endregion
export { _page as default };
