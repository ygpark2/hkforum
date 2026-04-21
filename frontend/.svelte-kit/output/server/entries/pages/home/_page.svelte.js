import "../../../chunks/index-server.js";
import { G as escape_html, U as attr, d as unsubscribe_stores, n as attr_class, o as ensure_array_like, u as store_get } from "../../../chunks/dev.js";
import { t as page } from "../../../chunks/stores.js";
import { t as bootstrap } from "../../../chunks/bootstrap.js";
import { t as apiFetch } from "../../../chunks/api.js";
import { t as PageEmpty } from "../../../chunks/PageEmpty.js";
import { t as PostCard } from "../../../chunks/PostCard.js";
//#region src/routes/home/+page.svelte
function _page($$renderer, $$props) {
	$$renderer.component(($$renderer) => {
		var $$store_subs;
		let activeTab, activeTag, localRegionNotice;
		const tabs = [
			{
				key: "everything",
				label: "Everything"
			},
			{
				key: "trends",
				label: "Trending"
			},
			{
				key: "unread",
				label: "Unread"
			},
			{
				key: "following",
				label: "Following"
			},
			{
				key: "local",
				label: "Local"
			},
			{
				key: "interests",
				label: "Interests"
			}
		];
		let items = [];
		let loading = true;
		let customTabs = [];
		function getLocalRegionNotice() {
			if (activeTab !== "local") return null;
			if (!store_get($$store_subs ??= {}, "$bootstrap", bootstrap).site?.localRegionFilterEnabled) return "내지역 기능이 현재 비활성화되어 있습니다.";
			if (!store_get($$store_subs ??= {}, "$bootstrap", bootstrap).auth?.isAuthenticated) return "로그인해야 내지역 탭을 사용할 수 있습니다.";
			if (!store_get($$store_subs ??= {}, "$bootstrap", bootstrap).viewer?.countryCode || !store_get($$store_subs ??= {}, "$bootstrap", bootstrap).viewer?.state) return "프로필에 국가와 주를 저장해야 내지역 탭을 사용할 수 있습니다.";
			return `내 지역 필터 적용 중: ${store_get($$store_subs ??= {}, "$bootstrap", bootstrap).viewer.state}, ${store_get($$store_subs ??= {}, "$bootstrap", bootstrap).viewer.countryCode}`;
		}
		async function loadFeed() {
			loading = true;
			try {
				items = (await apiFetch(`/api/v1/feed?${new URLSearchParams(store_get($$store_subs ??= {}, "$page", page).url.searchParams).toString()}`)).items || [];
			} finally {
				loading = false;
			}
		}
		$: activeTab = store_get($$store_subs ??= {}, "$page", page).url.searchParams.get("tab") || "everything";
		$: activeTag = store_get($$store_subs ??= {}, "$page", page).url.searchParams.get("tag") || "";
		$: localRegionNotice = getLocalRegionNotice();
		$: if (store_get($$store_subs ??= {}, "$page", page).url.search) loadFeed();
		$$renderer.push(`<section class="flex h-full min-h-0 flex-col bg-[#f6f7f8]"><div class="shrink-0 border-b border-slate-200 bg-white px-4 py-2.5"><div class="mb-2"><h1 class="text-xl font-semibold text-slate-900">Home</h1></div> <div class="flex items-center justify-between gap-3"><nav class="flex items-center gap-5 overflow-x-auto whitespace-nowrap text-[15px] font-semibold text-slate-500 no-scrollbar"><!--[-->`);
		const each_array = ensure_array_like(tabs);
		for (let $$index = 0, $$length = each_array.length; $$index < $$length; $$index++) {
			let tab = each_array[$$index];
			$$renderer.push(`<a${attr("href", `/home?tab=${tab.key}`)}${attr_class(`pb-2 transition ${activeTab === tab.key ? "border-b-2 border-slate-900 text-slate-900" : "text-slate-500 hover:text-slate-900"}`)}>${escape_html(tab.label)}</a>`);
		}
		$$renderer.push(`<!--]--> <!--[-->`);
		const each_array_1 = ensure_array_like(customTabs);
		for (let $$index_1 = 0, $$length = each_array_1.length; $$index_1 < $$length; $$index_1++) {
			let tab = each_array_1[$$index_1];
			$$renderer.push(`<a${attr("href", `/home?tag=${encodeURIComponent(tab.tag)}`)}${attr_class(`pb-2 transition ${activeTag === tab.tag ? "border-b-2 border-slate-900 text-slate-900" : "text-slate-500 hover:text-slate-900"}`)}>${escape_html(tab.label)}</a>`);
		}
		$$renderer.push(`<!--]--></nav> <button type="button" class="inline-flex h-8 w-8 items-center justify-center rounded-lg text-slate-700 transition hover:bg-slate-100 hover:text-slate-900">+</button></div> `);
		if (localRegionNotice) {
			$$renderer.push("<!--[0-->");
			$$renderer.push(`<div class="mt-2"><span class="inline-flex rounded-full border border-sky-200 bg-sky-50 px-3 py-1 text-xs font-semibold text-sky-700">${escape_html(localRegionNotice)}</span></div>`);
		} else $$renderer.push("<!--[-1-->");
		$$renderer.push(`<!--]--></div> <div class="min-h-0 flex-1 overflow-y-auto no-scrollbar bg-white">`);
		if (loading) {
			$$renderer.push("<!--[0-->");
			$$renderer.push(`<div class="flex h-full items-center justify-center px-6 text-center text-slate-500">Loading feed…</div>`);
		} else if (!items.length) {
			$$renderer.push("<!--[1-->");
			PageEmpty($$renderer, {
				title: "No posts yet.",
				description: "Feed results will appear here."
			});
		} else {
			$$renderer.push("<!--[-1-->");
			$$renderer.push(`<ul class="divide-y divide-slate-200"><!--[-->`);
			const each_array_2 = ensure_array_like(items);
			for (let $$index_2 = 0, $$length = each_array_2.length; $$index_2 < $$length; $$index_2++) {
				let post = each_array_2[$$index_2];
				$$renderer.push(`<li class="px-4 py-4">`);
				PostCard($$renderer, { post });
				$$renderer.push(`<!----></li>`);
			}
			$$renderer.push(`<!--]--></ul>`);
		}
		$$renderer.push(`<!--]--></div></section> `);
		$$renderer.push("<!--[-1-->");
		$$renderer.push(`<!--]-->`);
		if ($$store_subs) unsubscribe_stores($$store_subs);
	});
}
//#endregion
export { _page as default };
