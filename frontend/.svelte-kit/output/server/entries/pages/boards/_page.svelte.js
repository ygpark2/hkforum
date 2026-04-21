import { G as escape_html, U as attr, d as unsubscribe_stores, o as ensure_array_like, u as store_get } from "../../../chunks/dev.js";
import { t as bootstrap } from "../../../chunks/bootstrap.js";
import { t as PageEmpty } from "../../../chunks/PageEmpty.js";
//#region src/routes/boards/+page.svelte
function _page($$renderer, $$props) {
	$$renderer.component(($$renderer) => {
		var $$store_subs;
		let boards, localRegionNotice;
		$: boards = store_get($$store_subs ??= {}, "$bootstrap", bootstrap).boards || [];
		$: localRegionNotice = store_get($$store_subs ??= {}, "$bootstrap", bootstrap).viewer?.localRegionOnly && !store_get($$store_subs ??= {}, "$bootstrap", bootstrap).viewer?.countryCode ? "프로필에 국가와 주를 저장해야 내 지역 필터를 사용할 수 있습니다." : store_get($$store_subs ??= {}, "$bootstrap", bootstrap).viewer?.localRegionOnly && store_get($$store_subs ??= {}, "$bootstrap", bootstrap).viewer?.countryCode && store_get($$store_subs ??= {}, "$bootstrap", bootstrap).viewer?.state ? `내 지역 필터 적용 중: ${store_get($$store_subs ??= {}, "$bootstrap", bootstrap).viewer.state}, ${store_get($$store_subs ??= {}, "$bootstrap", bootstrap).viewer.countryCode}` : null;
		$$renderer.push(`<section class="flex h-full min-h-0 flex-col bg-white"><div class="shrink-0 border-b border-slate-200 px-4 py-3.5"><h1 class="text-3xl font-semibold text-slate-900">All Boards</h1> <p class="mt-1 text-sm text-slate-500">Browse every board and its latest posts.</p> `);
		if (localRegionNotice) {
			$$renderer.push("<!--[0-->");
			$$renderer.push(`<p class="mt-2 inline-flex rounded-full border border-sky-200 bg-sky-50 px-3 py-1 text-xs font-semibold text-sky-700">${escape_html(localRegionNotice)}</p>`);
		} else $$renderer.push("<!--[-1-->");
		$$renderer.push(`<!--]--></div> <div class="min-h-0 flex-1 overflow-y-auto no-scrollbar">`);
		if (!boards.length) {
			$$renderer.push("<!--[0-->");
			PageEmpty($$renderer, { title: "No boards yet." });
		} else {
			$$renderer.push("<!--[-1-->");
			$$renderer.push(`<ul class="divide-y divide-slate-200"><!--[-->`);
			const each_array = ensure_array_like(boards);
			for (let $$index = 0, $$length = each_array.length; $$index < $$length; $$index++) {
				let board = each_array[$$index];
				$$renderer.push(`<li class="px-4 py-4"><div class="flex items-start justify-between gap-4"><div class="min-w-0"><a${attr("href", `/board/${board.id}`)} class="text-xl font-semibold text-slate-900 transition hover:text-slate-700">${escape_html(board.name)}</a> `);
				if (board.description) {
					$$renderer.push("<!--[0-->");
					$$renderer.push(`<p class="mt-1 text-sm text-slate-500">${escape_html(board.description)}</p>`);
				} else $$renderer.push("<!--[-1-->");
				$$renderer.push(`<!--]--> <p class="mt-1 text-xs text-slate-400">${escape_html(board.postCount)} posts · ${escape_html(board.commentCount)} comments</p></div> <a${attr("href", `/board/${board.id}`)} class="shrink-0 rounded-lg border border-slate-200 px-3 py-1.5 text-xs font-semibold text-slate-700 transition hover:border-slate-400 hover:text-slate-900">Open</a></div></li>`);
			}
			$$renderer.push(`<!--]--></ul>`);
		}
		$$renderer.push(`<!--]--></div></section>`);
		if ($$store_subs) unsubscribe_stores($$store_subs);
	});
}
//#endregion
export { _page as default };
