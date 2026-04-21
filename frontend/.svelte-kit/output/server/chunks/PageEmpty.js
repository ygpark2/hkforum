import { G as escape_html, et as fallback, i as bind_props } from "./dev.js";
//#region src/lib/components/PageEmpty.svelte
function PageEmpty($$renderer, $$props) {
	let title = fallback($$props["title"], "Nothing here yet.");
	let description = fallback($$props["description"], "");
	$$renderer.push(`<div class="flex h-full flex-col items-center justify-center px-6 text-center"><div class="max-w-md rounded-2xl border border-dashed border-slate-300 bg-slate-50 px-6 py-10"><h2 class="text-xl font-semibold text-slate-900">${escape_html(title)}</h2> `);
	if (description) {
		$$renderer.push("<!--[0-->");
		$$renderer.push(`<p class="mt-2 text-sm text-slate-500">${escape_html(description)}</p>`);
	} else $$renderer.push("<!--[-1-->");
	$$renderer.push(`<!--]--></div></div>`);
	bind_props($$props, {
		title,
		description
	});
}
//#endregion
export { PageEmpty as t };
