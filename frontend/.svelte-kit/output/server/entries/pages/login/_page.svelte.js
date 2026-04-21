import { G as escape_html, U as attr } from "../../../chunks/dev.js";
import "../../../chunks/api.js";
//#region src/routes/login/+page.svelte
function _page($$renderer, $$props) {
	$$renderer.component(($$renderer) => {
		let username = "";
		let password = "";
		let loading = false;
		$$renderer.push(`<section class="w-full max-w-md rounded-[2rem] border border-slate-200 bg-white p-8 shadow-sm"><div class="text-sm font-semibold uppercase tracking-[0.2em] text-slate-500">HKForum</div> <h1 class="mt-3 text-3xl font-semibold text-slate-900">Login</h1> <p class="mt-2 text-sm text-slate-600">Sign in to continue into the SvelteKit frontend.</p> <div class="mt-6 space-y-4"><div><label for="login-username" class="text-xs font-semibold uppercase tracking-[0.18em] text-slate-500">Username</label> <input id="login-username"${attr("value", username)} class="mt-2 w-full rounded-xl border border-slate-200 bg-slate-50 px-4 py-3 text-sm text-slate-900"/></div> <div><label for="login-password" class="text-xs font-semibold uppercase tracking-[0.18em] text-slate-500">Password</label> <input id="login-password" type="password"${attr("value", password)} class="mt-2 w-full rounded-xl border border-slate-200 bg-slate-50 px-4 py-3 text-sm text-slate-900"/></div> `);
		$$renderer.push("<!--[-1-->");
		$$renderer.push(`<!--]--> <button type="button" class="w-full rounded-xl bg-slate-900 px-4 py-3 text-sm font-semibold text-white"${attr("disabled", loading, true)}>${escape_html("Sign In")}</button></div> <div class="mt-6 text-sm text-slate-500">No account yet? <a href="/register" class="font-semibold text-slate-900 underline underline-offset-4">Register</a></div></section>`);
	});
}
//#endregion
export { _page as default };
