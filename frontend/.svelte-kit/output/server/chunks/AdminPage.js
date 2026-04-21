import "./index-server.js";
import { G as escape_html, d as unsubscribe_stores, u as store_get } from "./dev.js";
import "./navigation.js";
import { t as page } from "./stores.js";
import "./bootstrap.js";
import "./api.js";
import "./time.js";
//#region src/lib/pages/AdminPage.svelte
function AdminPage($$renderer, $$props) {
	$$renderer.component(($$renderer) => {
		var $$store_subs;
		let parts, segments, section, selectedId;
		let data = null;
		function keyLabel(key) {
			return key.split("_").map((chunk) => chunk.charAt(0).toUpperCase() + chunk.slice(1)).join(" ");
		}
		$: parts = store_get($$store_subs ??= {}, "$page", page).url.pathname.split("/").filter(Boolean);
		$: segments = parts.slice(1);
		$: section = segments[0] || "overview";
		$: selectedId = segments[1] && segments[2] === "view" ? Number(segments[1]) : null;
		$: segments[1];
		$: data?.boards?.find((item) => item.id === selectedId);
		$: data?.companies?.find((item) => item.id === selectedId);
		$: data?.companyCategories?.find((item) => item.id === selectedId);
		$: data?.users?.find((item) => item.id === selectedId);
		$: data?.ads?.find((item) => item.id === selectedId);
		$$renderer.push(`<section class="min-h-full"><div class="border-b border-slate-200 bg-white px-6 py-4"><div class="text-sm font-semibold uppercase tracking-[0.18em] text-slate-500">Admin</div> <h1 class="mt-2 text-2xl font-semibold text-slate-900">${escape_html(section === "overview" ? "Overview" : keyLabel(section))}</h1></div> `);
		$$renderer.push("<!--[0-->");
		$$renderer.push(`<div class="px-6 py-6 text-sm text-slate-500">Loading admin data…</div>`);
		$$renderer.push(`<!--]--></section>`);
		if ($$store_subs) unsubscribe_stores($$store_subs);
	});
}
//#endregion
export { AdminPage as t };
