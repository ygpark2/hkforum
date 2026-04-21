import "../../../chunks/index-server.js";
import { G as escape_html, U as attr, d as unsubscribe_stores, f as html, o as ensure_array_like, u as store_get } from "../../../chunks/dev.js";
import { t as page } from "../../../chunks/stores.js";
import { t as bootstrap } from "../../../chunks/bootstrap.js";
import { t as apiFetch } from "../../../chunks/api.js";
import "../../../chunks/RichEditor.js";
import { n as relativeTime } from "../../../chunks/time.js";
import { t as PageEmpty } from "../../../chunks/PageEmpty.js";
//#region src/routes/companies/+page.svelte
function _page($$renderer, $$props) {
	$$renderer.component(($$renderer) => {
		var $$store_subs;
		let categories, majorGroups, selectedMajor, selectedCategory, filteredCategories;
		let items = [];
		let loading = true;
		let categoryId = "";
		let deletingCompanyId = null;
		async function loadCompanies() {
			loading = true;
			try {
				items = (await apiFetch(`/api/v1/companies?${new URLSearchParams(store_get($$store_subs ??= {}, "$page", page).url.searchParams).toString()}`)).items || [];
			} finally {
				loading = false;
			}
		}
		$: categories = store_get($$store_subs ??= {}, "$bootstrap", bootstrap).companyCategories || [];
		$: majorGroups = Array.from(new Map(categories.filter((item) => item.majorCode).map((item) => [item.majorCode, item.majorName || item.majorCode])).entries()).map(([code, label]) => ({
			code,
			label
		}));
		$: selectedMajor = store_get($$store_subs ??= {}, "$page", page).url.searchParams.get("major") || "";
		$: selectedCategory = store_get($$store_subs ??= {}, "$page", page).url.searchParams.get("category") || "";
		$: filteredCategories = selectedMajor ? categories.filter((item) => item.majorCode === selectedMajor) : categories;
		$: if (!categoryId && filteredCategories[0]) categoryId = String(filteredCategories[0].id);
		$: if (store_get($$store_subs ??= {}, "$page", page).url.search || categories.length) loadCompanies();
		let $$settled = true;
		let $$inner_renderer;
		function $$render_inner($$renderer) {
			$$renderer.push(`<section class="flex h-full min-h-0 flex-col bg-white"><div class="shrink-0 border-b border-slate-200 px-4 py-3.5"><div class="flex flex-wrap items-start justify-between gap-4"><div><h1 class="text-3xl font-semibold text-slate-900">Company</h1> <p class="mt-1 text-sm text-slate-500">대분류와 세부 분류로 회사를 찾고, 최신 등록 기업부터 바로 확인하세요.</p></div> `);
			if (store_get($$store_subs ??= {}, "$bootstrap", bootstrap).auth?.isAuthenticated) {
				$$renderer.push("<!--[0-->");
				$$renderer.push(`<button type="button" class="rounded-lg bg-slate-900 px-3 py-1.5 text-xs font-semibold uppercase tracking-[0.2em] text-white transition hover:bg-slate-800">New Company</button>`);
			} else {
				$$renderer.push("<!--[-1-->");
				$$renderer.push(`<a href="/login" class="rounded-lg border border-slate-900 px-3 py-1.5 text-xs font-semibold uppercase tracking-[0.2em] text-slate-900 transition hover:bg-slate-900 hover:text-white">Login to register</a>`);
			}
			$$renderer.push(`<!--]--></div> <form method="get" action="/companies" class="mt-4 flex flex-wrap items-end gap-3 lg:max-w-3xl"><div class="min-w-[140px] flex-1 space-y-1"><label for="company-major-filter" class="text-sm font-semibold text-slate-700">대분류</label> <select id="company-major-filter" name="major" class="w-full rounded-xl border border-slate-200 bg-slate-50 px-3 py-2 text-sm text-slate-900">`);
			$$renderer.option({ value: "" }, ($$renderer) => {
				$$renderer.push(`전체 대분류`);
			});
			$$renderer.push(`<!--[-->`);
			const each_array = ensure_array_like(majorGroups);
			for (let $$index = 0, $$length = each_array.length; $$index < $$length; $$index++) {
				let major = each_array[$$index];
				$$renderer.option({
					value: major.code,
					selected: selectedMajor === major.code
				}, ($$renderer) => {
					$$renderer.push(`${escape_html(major.label)}`);
				});
			}
			$$renderer.push(`<!--]--></select></div> <div class="min-w-[140px] flex-1 space-y-1"><label for="company-category-filter" class="text-sm font-semibold text-slate-700">분류</label> <select id="company-category-filter" name="category" class="w-full rounded-xl border border-slate-200 bg-slate-50 px-3 py-2 text-sm text-slate-900">`);
			$$renderer.option({ value: "" }, ($$renderer) => {
				$$renderer.push(`전체 분류`);
			});
			$$renderer.push(`<!--[-->`);
			const each_array_1 = ensure_array_like(filteredCategories);
			for (let $$index_1 = 0, $$length = each_array_1.length; $$index_1 < $$length; $$index_1++) {
				let category = each_array_1[$$index_1];
				$$renderer.option({
					value: category.id,
					selected: selectedCategory === String(category.id)
				}, ($$renderer) => {
					$$renderer.push(`${escape_html(category.name)}`);
				});
			}
			$$renderer.push(`<!--]--></select></div> <button type="submit" class="rounded-lg border border-slate-200 px-3 py-2 text-xs font-semibold uppercase tracking-[0.2em] text-slate-700">Apply</button></form></div> <div class="min-h-0 flex-1 overflow-y-auto no-scrollbar"><div class="sticky top-0 z-10 border-b border-slate-200 bg-white/95 px-4 py-2.5 backdrop-blur-sm"><span class="rounded-full bg-slate-100 px-2.5 py-1 text-xs font-semibold text-slate-700">${escape_html(items.length)} companies</span></div> `);
			if (loading) {
				$$renderer.push("<!--[0-->");
				$$renderer.push(`<div class="flex h-full items-center justify-center px-6 text-center text-slate-500">Loading companies…</div>`);
			} else if (!categories.length) {
				$$renderer.push("<!--[1-->");
				PageEmpty($$renderer, {
					title: "회사 분류가 아직 준비되지 않았습니다.",
					description: "시스템 업종 분류가 생성되면 기업을 등록하고 조회할 수 있습니다."
				});
			} else if (!items.length) {
				$$renderer.push("<!--[2-->");
				PageEmpty($$renderer, {
					title: "등록된 회사가 없습니다.",
					description: "첫 회사를 등록하면 최신 등록순으로 목록에 표시됩니다."
				});
			} else {
				$$renderer.push("<!--[-1-->");
				$$renderer.push(`<div class="space-y-4 px-4 py-4"><!--[-->`);
				const each_array_2 = ensure_array_like(items);
				for (let $$index_2 = 0, $$length = each_array_2.length; $$index_2 < $$length; $$index_2++) {
					let company = each_array_2[$$index_2];
					$$renderer.push(`<article class="rounded-2xl border border-slate-200 bg-slate-50/60 p-4"><div class="flex flex-wrap items-start justify-between gap-3"><div class="min-w-0"><div class="flex flex-wrap items-center gap-2 text-[11px] font-semibold uppercase tracking-[0.18em] text-slate-500">`);
					if (company.majorCode) {
						$$renderer.push("<!--[0-->");
						$$renderer.push(`<span class="rounded-full bg-slate-900 px-2.5 py-1 text-white">${escape_html(company.majorCode)}</span>`);
					} else $$renderer.push("<!--[-1-->");
					$$renderer.push(`<!--]--> `);
					if (company.categoryName) {
						$$renderer.push("<!--[0-->");
						$$renderer.push(`<span class="rounded-full bg-slate-100 px-2.5 py-1 text-slate-700">${escape_html(company.categoryName)}</span>`);
					} else $$renderer.push("<!--[-1-->");
					$$renderer.push(`<!--]--></div> <h2 class="mt-3 break-words text-2xl font-semibold text-slate-900">${escape_html(company.name)}</h2> <div class="mt-2 flex flex-wrap items-center gap-x-2 gap-y-1 text-xs text-slate-500">`);
					if (company.size) {
						$$renderer.push("<!--[0-->");
						$$renderer.push(`<span>${escape_html(company.size)}</span>`);
					} else $$renderer.push("<!--[-1-->");
					$$renderer.push(`<!--]--> <span>· 등록 ${escape_html(relativeTime(company.createdAt))}</span></div></div> `);
					if (company.website) {
						$$renderer.push("<!--[0-->");
						$$renderer.push(`<a${attr("href", company.website)} target="_blank" rel="noreferrer" class="shrink-0 rounded-full border border-sky-200 bg-sky-50 px-3 py-1.5 text-xs font-semibold text-sky-700 transition hover:border-sky-300 hover:text-sky-900">Visit website</a>`);
					} else $$renderer.push("<!--[-1-->");
					$$renderer.push(`<!--]--></div> <div class="company-richtext mt-4 rounded-2xl border border-slate-200 bg-white px-4 py-3 text-sm text-slate-700">${html(company.description)}</div> <p class="mt-4 text-xs text-slate-500">@${escape_html(company.author?.ident)} · ${escape_html(company.author?.name || company.author?.ident)}</p> `);
					if (store_get($$store_subs ??= {}, "$bootstrap", bootstrap).viewer && (store_get($$store_subs ??= {}, "$bootstrap", bootstrap).viewer.id === company.author?.id || store_get($$store_subs ??= {}, "$bootstrap", bootstrap).viewer.role === "admin")) {
						$$renderer.push("<!--[0-->");
						$$renderer.push(`<div class="mt-3 flex flex-wrap gap-2"><button type="button" class="rounded-lg border border-slate-200 bg-white px-3 py-1.5 text-xs font-semibold uppercase tracking-[0.15em] text-slate-700 transition hover:bg-slate-50">Edit</button> <button type="button" class="rounded-lg border border-rose-200 bg-white px-3 py-1.5 text-xs font-semibold uppercase tracking-[0.15em] text-rose-700 transition hover:bg-rose-50"${attr("disabled", deletingCompanyId === company.id, true)}>${escape_html(deletingCompanyId === company.id ? "Deleting…" : "Delete")}</button></div>`);
					} else $$renderer.push("<!--[-1-->");
					$$renderer.push(`<!--]--></article>`);
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
