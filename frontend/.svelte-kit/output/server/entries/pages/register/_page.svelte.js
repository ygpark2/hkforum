import { G as escape_html, U as attr, d as unsubscribe_stores, u as store_get } from "../../../chunks/dev.js";
import { t as bootstrap } from "../../../chunks/bootstrap.js";
import "../../../chunks/api.js";
//#region src/routes/register/+page.svelte
function _page($$renderer, $$props) {
	$$renderer.component(($$renderer) => {
		var $$store_subs;
		let username = "";
		let password = "";
		let loading = false;
		$$renderer.push(`<section class="w-full max-w-md rounded-[2rem] border border-slate-200 bg-white p-8 shadow-sm"><div class="text-sm font-semibold uppercase tracking-[0.2em] text-slate-500">HKForum</div> <h1 class="mt-3 text-3xl font-semibold text-slate-900">Register</h1> <p class="mt-2 text-sm text-slate-600">Create an account to use the migrated forum UI.</p> `);
		if (!store_get($$store_subs ??= {}, "$bootstrap", bootstrap).site?.allowUserRegistration) {
			$$renderer.push("<!--[0-->");
			$$renderer.push(`<div class="mt-6 rounded-xl border border-amber-200 bg-amber-50 px-4 py-3 text-sm text-amber-700">Registration is currently disabled.</div>`);
		} else {
			$$renderer.push("<!--[-1-->");
			$$renderer.push(`<div class="mt-6 space-y-4"><div><label for="register-username" class="text-xs font-semibold uppercase tracking-[0.18em] text-slate-500">Username</label> <input id="register-username"${attr("value", username)} class="mt-2 w-full rounded-xl border border-slate-200 bg-slate-50 px-4 py-3 text-sm text-slate-900"/></div> <div><label for="register-password" class="text-xs font-semibold uppercase tracking-[0.18em] text-slate-500">Password</label> <input id="register-password" type="password"${attr("value", password)} class="mt-2 w-full rounded-xl border border-slate-200 bg-slate-50 px-4 py-3 text-sm text-slate-900"/></div> `);
			$$renderer.push("<!--[-1-->");
			$$renderer.push(`<!--]--> <button type="button" class="w-full rounded-xl bg-slate-900 px-4 py-3 text-sm font-semibold text-white"${attr("disabled", loading, true)}>${escape_html("Create Account")}</button></div>`);
		}
		$$renderer.push(`<!--]--> <div class="mt-6 text-sm text-slate-500">Already registered? <a href="/login" class="font-semibold text-slate-900 underline underline-offset-4">Login</a></div></section>`);
		if ($$store_subs) unsubscribe_stores($$store_subs);
	});
}
//#endregion
export { _page as default };
