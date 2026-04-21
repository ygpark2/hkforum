import "./index-server.js";
import { G as escape_html, U as attr, d as unsubscribe_stores, n as attr_class, o as ensure_array_like, u as store_get } from "./dev.js";
import { t as page } from "./stores.js";
import { t as bootstrap } from "./bootstrap.js";
import { t as apiFetch } from "./api.js";
import { n as relativeTime, t as formatDate } from "./time.js";
//#region src/lib/pages/SettingsPage.svelte
function SettingsPage($$renderer, $$props) {
	$$renderer.component(($$renderer) => {
		var $$store_subs;
		let section, viewer, githubProfileUrl, providers, currentProvider, currentProviderLabel;
		let loading = false;
		let blockedLoading = false;
		let securityEvents = [];
		let blockedUsers = [];
		let blockingUserId = null;
		function getSection(pathname) {
			return pathname.split("/").filter(Boolean)[1] || "index";
		}
		async function loadSecurityEvents() {
			if (section !== "security-events" || !store_get($$store_subs ??= {}, "$bootstrap", bootstrap).auth?.isAuthenticated) return;
			loading = true;
			try {
				securityEvents = (await apiFetch("/api/v1/me/security-events")).items || [];
			} catch (error) {
				window.alert(error.message);
			} finally {
				loading = false;
			}
		}
		async function loadBlockedUsers() {
			if (section !== "blocked-accounts" || !store_get($$store_subs ??= {}, "$bootstrap", bootstrap).auth?.isAuthenticated) return;
			blockedLoading = true;
			try {
				blockedUsers = (await apiFetch("/api/v1/me/blocked-users")).items || [];
			} catch (error) {
				window.alert(error.message);
			} finally {
				blockedLoading = false;
			}
		}
		function providerLabel(key) {
			if (key === "google") return "Google";
			if (key === "kakao") return "Kakao";
			if (key === "naver") return "Naver";
			return "Password";
		}
		const links = [
			{
				href: "/settings",
				key: "index",
				label: "Overview"
			},
			{
				href: "/settings/account",
				key: "account",
				label: "Account"
			},
			{
				href: "/settings/connections",
				key: "connections",
				label: "Connections"
			},
			{
				href: "/settings/blocked-accounts",
				key: "blocked-accounts",
				label: "Blocked Accounts"
			},
			{
				href: "/settings/security-events",
				key: "security-events",
				label: "Security Events"
			},
			{
				href: "/settings/about",
				key: "about",
				label: "About"
			}
		];
		$: section = getSection(store_get($$store_subs ??= {}, "$page", page).url.pathname);
		$: viewer = store_get($$store_subs ??= {}, "$bootstrap", bootstrap).viewer;
		$: githubProfileUrl = viewer ? `https://github.com/${viewer.ident}` : "";
		$: providers = store_get($$store_subs ??= {}, "$bootstrap", bootstrap).auth?.providers || [];
		$: currentProvider = viewer?.authProvider || "password";
		$: currentProviderLabel = providerLabel(currentProvider);
		$: if (section === "security-events" && store_get($$store_subs ??= {}, "$bootstrap", bootstrap).ready) loadSecurityEvents();
		$: if (section === "blocked-accounts" && store_get($$store_subs ??= {}, "$bootstrap", bootstrap).ready) loadBlockedUsers();
		$$renderer.push(`<section class="min-h-full bg-slate-50"><div class="border-b border-slate-200 bg-white px-5 py-4"><h1 class="text-2xl font-semibold text-slate-900">Settings</h1> <p class="mt-1 text-sm text-slate-500">Manage your account, profile, and site preferences.</p></div> <div class="grid gap-5 px-5 py-5 lg:grid-cols-[220px_minmax(0,1fr)]"><aside class="space-y-1"><!--[-->`);
		const each_array = ensure_array_like(links);
		for (let $$index = 0, $$length = each_array.length; $$index < $$length; $$index++) {
			let link = each_array[$$index];
			$$renderer.push(`<a${attr("href", link.href)}${attr_class(`block rounded-xl px-3 py-2 text-sm font-medium transition ${section === link.key ? "bg-slate-900 text-white" : "bg-white text-slate-700 hover:bg-slate-100 hover:text-slate-900"}`)}>${escape_html(link.label)}</a>`);
		}
		$$renderer.push(`<!--]--></aside> <div class="space-y-4">`);
		if (section === "index") {
			$$renderer.push("<!--[0-->");
			$$renderer.push(`<div class="rounded-2xl border border-slate-200 bg-white p-6"><div class="text-lg font-semibold text-slate-900">Account summary</div> <div class="mt-4 grid gap-3 md:grid-cols-3"><div class="rounded-xl bg-slate-50 p-4"><div class="text-xs uppercase tracking-[0.18em] text-slate-500">Handle</div> <div class="mt-2 text-base font-semibold text-slate-900">@${escape_html(viewer?.ident || "guest")}</div></div> <div class="rounded-xl bg-slate-50 p-4"><div class="text-xs uppercase tracking-[0.18em] text-slate-500">Region</div> <div class="mt-2 text-base font-semibold text-slate-900">${escape_html(viewer?.state || "Unset")}${escape_html(viewer?.countryCode ? `, ${viewer.countryCode}` : "")}</div></div> <div class="rounded-xl bg-slate-50 p-4"><div class="text-xs uppercase tracking-[0.18em] text-slate-500">Role</div> <div class="mt-2 text-base font-semibold text-slate-900">${escape_html(viewer?.role || "user")}</div></div></div></div> <div class="rounded-2xl border border-slate-200 bg-white p-6"><div class="text-lg font-semibold text-slate-900">Quick actions</div> <div class="mt-4 flex flex-wrap gap-3"><a href="/profile" class="rounded-xl bg-slate-900 px-4 py-2 text-sm font-semibold text-white">Edit Profile</a> <a href="/settings/security-events" class="rounded-xl border border-slate-200 px-4 py-2 text-sm font-semibold text-slate-700">Security Events</a> <a href="/bookmarks" class="rounded-xl border border-slate-200 px-4 py-2 text-sm font-semibold text-slate-700">Bookmarks</a></div></div>`);
		} else if (section === "account") {
			$$renderer.push("<!--[1-->");
			$$renderer.push(`<div class="rounded-2xl border border-slate-200 bg-white p-6"><div class="text-lg font-semibold text-slate-900">Account</div> <dl class="mt-5 grid gap-4 md:grid-cols-2"><div class="rounded-xl bg-slate-50 p-4"><dt class="text-xs uppercase tracking-[0.18em] text-slate-500">Username</dt> <dd class="mt-2 text-base font-semibold text-slate-900">${escape_html(viewer?.ident)}</dd></div> <div class="rounded-xl bg-slate-50 p-4"><dt class="text-xs uppercase tracking-[0.18em] text-slate-500">Display name</dt> <dd class="mt-2 text-base font-semibold text-slate-900">${escape_html(viewer?.name || "Unset")}</dd></div> <div class="rounded-xl bg-slate-50 p-4"><dt class="text-xs uppercase tracking-[0.18em] text-slate-500">Description</dt> <dd class="mt-2 whitespace-pre-wrap text-sm text-slate-700">${escape_html(viewer?.description || "No bio yet.")}</dd></div> <div class="rounded-xl bg-slate-50 p-4"><dt class="text-xs uppercase tracking-[0.18em] text-slate-500">Region</dt> <dd class="mt-2 text-sm text-slate-700">${escape_html(viewer?.state || "Unset")}${escape_html(viewer?.countryCode ? `, ${viewer.countryCode}` : "")}</dd></div></dl> <a href="/profile" class="mt-5 inline-flex rounded-xl bg-slate-900 px-4 py-2 text-sm font-semibold text-white">Update profile</a></div>`);
		} else if (section === "connections") {
			$$renderer.push("<!--[2-->");
			$$renderer.push(`<div class="rounded-2xl border border-slate-200 bg-white p-6"><div class="text-lg font-semibold text-slate-900">Connections</div> <div class="mt-4 rounded-xl bg-slate-50 p-4"><div class="text-sm text-slate-500">Current sign-in method</div> <div class="mt-2 text-base font-semibold text-slate-900">${escape_html(currentProviderLabel)}</div></div> <div class="mt-4 rounded-xl bg-slate-50 p-4"><div class="text-sm text-slate-500">Primary profile link</div> <a${attr("href", githubProfileUrl)} target="_blank" rel="noreferrer" class="mt-2 inline-flex text-base font-semibold text-slate-900 underline underline-offset-4">${escape_html(githubProfileUrl)}</a></div> <div class="mt-4"><div class="text-sm font-semibold text-slate-900">Available social providers</div> `);
			if (providers.length) {
				$$renderer.push("<!--[0-->");
				$$renderer.push(`<div class="mt-3 flex flex-wrap gap-3"><!--[-->`);
				const each_array_1 = ensure_array_like(providers);
				for (let $$index_1 = 0, $$length = each_array_1.length; $$index_1 < $$length; $$index_1++) {
					let provider = each_array_1[$$index_1];
					$$renderer.push(`<a${attr("href", provider.url)} class="rounded-xl border border-slate-200 bg-white px-4 py-2 text-sm font-semibold text-slate-700 transition hover:border-slate-300 hover:text-slate-900">Continue with ${escape_html(provider.label)}</a>`);
				}
				$$renderer.push(`<!--]--></div>`);
			} else {
				$$renderer.push("<!--[-1-->");
				$$renderer.push(`<p class="mt-3 text-sm text-slate-600">No external OAuth providers are configured in this environment.</p>`);
			}
			$$renderer.push(`<!--]--></div></div>`);
		} else if (section === "blocked-accounts") {
			$$renderer.push("<!--[3-->");
			$$renderer.push(`<div class="rounded-2xl border border-slate-200 bg-white p-6"><div class="text-lg font-semibold text-slate-900">Blocked accounts</div> `);
			if (blockedLoading) {
				$$renderer.push("<!--[0-->");
				$$renderer.push(`<p class="mt-3 text-sm text-slate-600">Loading blocked accounts…</p>`);
			} else if (!blockedUsers.length) {
				$$renderer.push("<!--[1-->");
				$$renderer.push(`<p class="mt-3 text-sm text-slate-600">No blocked accounts.</p>`);
			} else {
				$$renderer.push("<!--[-1-->");
				$$renderer.push(`<div class="mt-4 space-y-3"><!--[-->`);
				const each_array_2 = ensure_array_like(blockedUsers);
				for (let $$index_2 = 0, $$length = each_array_2.length; $$index_2 < $$length; $$index_2++) {
					let user = each_array_2[$$index_2];
					$$renderer.push(`<div class="flex items-center justify-between gap-4 rounded-xl bg-slate-50 p-4"><div><div class="font-semibold text-slate-900">${escape_html(user.name || user.ident)}</div> <div class="mt-1 text-sm text-slate-500">@${escape_html(user.ident)}</div> `);
					if (user.description) {
						$$renderer.push("<!--[0-->");
						$$renderer.push(`<div class="mt-2 text-sm text-slate-600">${escape_html(user.description)}</div>`);
					} else $$renderer.push("<!--[-1-->");
					$$renderer.push(`<!--]--> <div class="mt-2 text-xs text-slate-400">Blocked ${escape_html(relativeTime(user.createdAt))}</div></div> <button type="button" class="rounded-xl border border-slate-200 bg-white px-4 py-2 text-sm font-semibold text-slate-700 transition hover:border-slate-300 hover:text-slate-900"${attr("disabled", blockingUserId === user.id, true)}>${escape_html(blockingUserId === user.id ? "Unblocking…" : "Unblock")}</button></div>`);
				}
				$$renderer.push(`<!--]--></div>`);
			}
			$$renderer.push(`<!--]--></div>`);
		} else if (section === "security-events") {
			$$renderer.push("<!--[4-->");
			$$renderer.push(`<div class="rounded-2xl border border-slate-200 bg-white p-6"><div class="flex items-center justify-between gap-3"><div><div class="text-lg font-semibold text-slate-900">Security events</div> <p class="mt-1 text-sm text-slate-500">Recent account activity inferred from your interactions.</p></div></div> `);
			if (loading) {
				$$renderer.push("<!--[0-->");
				$$renderer.push(`<div class="mt-6 text-sm text-slate-500">Loading events…</div>`);
			} else if (!securityEvents.length) {
				$$renderer.push("<!--[1-->");
				$$renderer.push(`<div class="mt-6 text-sm text-slate-500">No events available.</div>`);
			} else {
				$$renderer.push("<!--[-1-->");
				$$renderer.push(`<div class="mt-6 space-y-3"><!--[-->`);
				const each_array_3 = ensure_array_like(securityEvents);
				for (let $$index_3 = 0, $$length = each_array_3.length; $$index_3 < $$length; $$index_3++) {
					let event = each_array_3[$$index_3];
					$$renderer.push(`<div class="rounded-xl bg-slate-50 p-4"><div class="flex items-center justify-between gap-4"><div class="font-semibold text-slate-900">${escape_html(event.label)}</div> <div class="text-xs uppercase tracking-[0.16em] text-slate-500">${escape_html(event.platform)}</div></div> <div class="mt-2 text-sm text-slate-600">${escape_html(relativeTime(event.createdAt))} · ${escape_html(formatDate(event.createdAt))}</div></div>`);
				}
				$$renderer.push(`<!--]--></div>`);
			}
			$$renderer.push(`<!--]--></div>`);
		} else if (section === "about") {
			$$renderer.push("<!--[5-->");
			$$renderer.push(`<div class="rounded-2xl border border-slate-200 bg-white p-6"><div class="text-lg font-semibold text-slate-900">About ${escape_html(store_get($$store_subs ??= {}, "$bootstrap", bootstrap).site?.title || "HKForum")}</div> <p class="mt-3 text-sm text-slate-600">${escape_html(store_get($$store_subs ??= {}, "$bootstrap", bootstrap).site?.description || store_get($$store_subs ??= {}, "$bootstrap", bootstrap).site?.subtitle)}</p> <dl class="mt-5 grid gap-3 md:grid-cols-2"><div class="rounded-xl bg-slate-50 p-4"><dt class="text-xs uppercase tracking-[0.18em] text-slate-500">Default locale</dt> <dd class="mt-2 text-sm font-semibold text-slate-900">${escape_html(store_get($$store_subs ??= {}, "$bootstrap", bootstrap).site?.defaultLocale || "en")}</dd></div> <div class="rounded-xl bg-slate-50 p-4"><dt class="text-xs uppercase tracking-[0.18em] text-slate-500">Footer</dt> <dd class="mt-2 text-sm text-slate-700">${escape_html(store_get($$store_subs ??= {}, "$bootstrap", bootstrap).site?.footerText || "Not configured")}</dd></div></dl></div>`);
		} else $$renderer.push("<!--[-1-->");
		$$renderer.push(`<!--]--></div></div></section>`);
		if ($$store_subs) unsubscribe_stores($$store_subs);
	});
}
//#endregion
export { SettingsPage as t };
