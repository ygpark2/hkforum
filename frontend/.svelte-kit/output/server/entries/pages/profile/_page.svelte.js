import "../../../chunks/index-server.js";
import "../../../chunks/dev.js";
import "../../../chunks/bootstrap.js";
import "../../../chunks/api.js";
//#region src/routes/profile/+page.svelte
function _page($$renderer, $$props) {
	$$renderer.component(($$renderer) => {
		let form = {
			name: "",
			description: "",
			countryCode: "",
			state: "",
			localRegionOnly: false,
			latitude: "",
			longitude: ""
		};
		let states = [];
		$: states.filter((item) => item.countryCode === form.countryCode);
		$$renderer.push(`<section class="min-h-full bg-slate-50"><div class="border-b border-slate-200 bg-white px-5 py-4"><h1 class="text-2xl font-semibold text-slate-900">Edit Profile</h1> <p class="mt-1 text-sm text-slate-500">This page replaces the old Yesod profile form.</p></div> <div class="px-5 py-5"><div class="mx-auto max-w-3xl rounded-2xl border border-slate-200 bg-white p-6">`);
		$$renderer.push("<!--[0-->");
		$$renderer.push(`<div class="text-sm text-slate-500">Loading profile…</div>`);
		$$renderer.push(`<!--]--></div></div></section>`);
	});
}
//#endregion
export { _page as default };
