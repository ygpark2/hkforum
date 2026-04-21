import "../../../chunks/index-server.js";
import "../../../chunks/dev.js";
import "../../../chunks/bootstrap.js";
import "../../../chunks/api.js";
import "../../../chunks/time.js";
//#region src/routes/notifications/+page.svelte
function _page($$renderer, $$props) {
	$$renderer.component(($$renderer) => {
		$$renderer.push(`<section class="min-h-full bg-slate-50"><div class="border-b border-slate-200 bg-white px-5 py-4"><div class="flex items-center justify-between gap-3"><div><h1 class="text-2xl font-semibold text-slate-900">Notifications</h1> <p class="mt-1 text-sm text-slate-500">Recent alerts from follows, comments, and reactions.</p></div> <button type="button" class="rounded-xl border border-slate-200 px-4 py-2 text-sm font-semibold text-slate-700">Mark all read</button></div></div> <div class="px-5 py-5">`);
		$$renderer.push("<!--[0-->");
		$$renderer.push(`<div class="text-sm text-slate-500">Loading notifications…</div>`);
		$$renderer.push(`<!--]--></div></section>`);
	});
}
//#endregion
export { _page as default };
