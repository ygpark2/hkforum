import "../../../chunks/index-server.js";
import { d as unsubscribe_stores, u as store_get } from "../../../chunks/dev.js";
import { t as bootstrap } from "../../../chunks/bootstrap.js";
import "../../../chunks/api.js";
import "../../../chunks/time.js";
import "../../../chunks/PageEmpty.js";
//#region src/routes/jobs/+page.svelte
function _page($$renderer, $$props) {
	$$renderer.component(($$renderer) => {
		var $$store_subs;
		$$renderer.push(`<section class="flex h-full min-h-0 flex-col bg-white"><div class="shrink-0 border-b border-slate-200 px-4 py-3.5"><div class="flex flex-wrap items-start justify-between gap-4"><div><h1 class="text-3xl font-semibold text-slate-900">Jobs</h1> <p class="mt-1 text-sm text-slate-500">구인/구직 글을 확인하고 새로운 공고를 등록하세요.</p></div> `);
		if (store_get($$store_subs ??= {}, "$bootstrap", bootstrap).auth?.isAuthenticated) {
			$$renderer.push("<!--[0-->");
			$$renderer.push(`<button type="button" class="rounded-lg bg-slate-900 px-3 py-1.5 text-xs font-semibold uppercase tracking-[0.2em] text-white transition hover:bg-slate-800">New Job</button>`);
		} else {
			$$renderer.push("<!--[-1-->");
			$$renderer.push(`<a href="/login" class="rounded-lg border border-slate-900 px-3 py-1.5 text-xs font-semibold uppercase tracking-[0.2em] text-slate-900 transition hover:bg-slate-900 hover:text-white">Login to post</a>`);
		}
		$$renderer.push(`<!--]--></div></div> <div class="min-h-0 flex-1 overflow-y-auto no-scrollbar">`);
		$$renderer.push("<!--[0-->");
		$$renderer.push(`<div class="flex h-full items-center justify-center px-6 text-center text-slate-500">Loading jobs…</div>`);
		$$renderer.push(`<!--]--></div></section> `);
		$$renderer.push("<!--[-1-->");
		$$renderer.push(`<!--]-->`);
		if ($$store_subs) unsubscribe_stores($$store_subs);
	});
}
//#endregion
export { _page as default };
