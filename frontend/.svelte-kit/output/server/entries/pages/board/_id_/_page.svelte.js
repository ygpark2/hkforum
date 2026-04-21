import "../../../../chunks/index-server.js";
import { G as escape_html, d as unsubscribe_stores, o as ensure_array_like, u as store_get } from "../../../../chunks/dev.js";
import "../../../../chunks/navigation.js";
import { t as page } from "../../../../chunks/stores.js";
import { t as bootstrap } from "../../../../chunks/bootstrap.js";
import { t as apiFetch } from "../../../../chunks/api.js";
import "../../../../chunks/RichEditor.js";
import { t as PageEmpty } from "../../../../chunks/PageEmpty.js";
import { t as PostCard } from "../../../../chunks/PostCard.js";
//#region src/routes/board/[id]/+page.svelte
function _page($$renderer, $$props) {
	$$renderer.component(($$renderer) => {
		var $$store_subs;
		let localRegionNotice;
		let board;
		let items = [];
		let loading = true;
		async function loadBoard() {
			loading = true;
			try {
				const boardId = store_get($$store_subs ??= {}, "$page", page).params.id;
				board = (store_get($$store_subs ??= {}, "$bootstrap", bootstrap).boards || []).find((item) => String(item.id) === String(boardId));
				items = (await apiFetch(`/api/v1/boards/${boardId}/posts`)).items || [];
			} finally {
				loading = false;
			}
		}
		$: if (store_get($$store_subs ??= {}, "$page", page).params.id) loadBoard();
		$: localRegionNotice = store_get($$store_subs ??= {}, "$bootstrap", bootstrap).viewer?.localRegionOnly && store_get($$store_subs ??= {}, "$bootstrap", bootstrap).viewer?.countryCode && store_get($$store_subs ??= {}, "$bootstrap", bootstrap).viewer?.state ? `내 지역 필터 적용 중: ${store_get($$store_subs ??= {}, "$bootstrap", bootstrap).viewer.state}, ${store_get($$store_subs ??= {}, "$bootstrap", bootstrap).viewer.countryCode}` : store_get($$store_subs ??= {}, "$bootstrap", bootstrap).viewer?.localRegionOnly ? "프로필에 국가와 주를 저장해야 내 지역 필터를 사용할 수 있습니다." : null;
		let $$settled = true;
		let $$inner_renderer;
		function $$render_inner($$renderer) {
			$$renderer.push(`<section class="bg-white border border-slate-200 shadow-sm rounded-2xl p-6 space-y-6"><header class="flex items-start justify-between gap-4"><div class="space-y-2"><p class="text-xs uppercase tracking-[0.3em] text-slate-400">Board</p> <h1 class="text-2xl font-bold text-slate-900">${escape_html(board?.name || "Board")}</h1> `);
			if (board?.description) {
				$$renderer.push("<!--[0-->");
				$$renderer.push(`<p class="text-sm text-slate-500">${escape_html(board.description)}</p>`);
			} else $$renderer.push("<!--[-1-->");
			$$renderer.push(`<!--]--> `);
			if (localRegionNotice) {
				$$renderer.push("<!--[0-->");
				$$renderer.push(`<p class="inline-flex rounded-full border border-sky-200 bg-sky-50 px-3 py-1 text-xs font-semibold text-sky-700">${escape_html(localRegionNotice)}</p>`);
			} else $$renderer.push("<!--[-1-->");
			$$renderer.push(`<!--]--></div> `);
			if (store_get($$store_subs ??= {}, "$bootstrap", bootstrap).auth?.isAuthenticated) {
				$$renderer.push("<!--[0-->");
				$$renderer.push(`<button type="button" class="rounded-lg bg-slate-900 px-3 py-1.5 text-xs font-semibold uppercase tracking-[0.2em] text-white">New post</button>`);
			} else {
				$$renderer.push("<!--[-1-->");
				$$renderer.push(`<a href="/login" class="rounded-lg border border-slate-900 px-3 py-1.5 text-xs font-semibold uppercase tracking-[0.2em] text-slate-900">Login to post</a>`);
			}
			$$renderer.push(`<!--]--></header> <div class="space-y-4"><div class="flex items-center justify-between"><h2 class="text-lg font-semibold text-slate-900">Posts</h2> <span class="text-xs uppercase tracking-[0.3em] text-slate-400">${escape_html(items.length)} total</span></div> `);
			if (loading) {
				$$renderer.push("<!--[0-->");
				$$renderer.push(`<div class="text-sm text-slate-500">Loading posts…</div>`);
			} else if (!items.length) {
				$$renderer.push("<!--[1-->");
				PageEmpty($$renderer, { title: "No posts yet." });
			} else {
				$$renderer.push("<!--[-1-->");
				$$renderer.push(`<div class="space-y-3"><!--[-->`);
				const each_array = ensure_array_like(items);
				for (let $$index = 0, $$length = each_array.length; $$index < $$length; $$index++) {
					let post = each_array[$$index];
					PostCard($$renderer, {
						post,
						showBoard: false,
						compact: true
					});
				}
				$$renderer.push(`<!--]--></div>`);
			}
			$$renderer.push(`<!--]--></div></section> `);
			$$renderer.push("<!--[-1-->");
			$$renderer.push(`<!--]-->`);
		}
		do {
			$$settled = true;
			$$inner_renderer = $$renderer.copy();
			$$render_inner($$inner_renderer);
		} while (!$$settled);
		$$renderer.subsume($$inner_renderer);
		if ($$store_subs) unsubscribe_stores($$store_subs);
	});
}
//#endregion
export { _page as default };
