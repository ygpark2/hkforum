import "../../chunks/index-server.js";
import { G as escape_html, U as attr, d as unsubscribe_stores, et as fallback, i as bind_props, l as slot, n as attr_class, o as ensure_array_like, s as head, u as store_get } from "../../chunks/dev.js";
import "../../chunks/navigation.js";
import { t as page } from "../../chunks/stores.js";
import { t as bootstrap } from "../../chunks/bootstrap.js";
import "../../chunks/api.js";
import { t as RichEditor } from "../../chunks/RichEditor.js";
//#region src/lib/components/GlobalPostModal.svelte
function GlobalPostModal($$renderer, $$props) {
	$$renderer.component(($$renderer) => {
		var $$store_subs;
		let open = fallback($$props["open"], false);
		let onClose = fallback($$props["onClose"], () => {});
		let boardId = "";
		let title = "";
		let tags = "";
		let content = "";
		let submitting = false;
		$: if (store_get($$store_subs ??= {}, "$bootstrap", bootstrap).boards?.length && !boardId) boardId = String(store_get($$store_subs ??= {}, "$bootstrap", bootstrap).boards[0].id);
		let $$settled = true;
		let $$inner_renderer;
		function $$render_inner($$renderer) {
			if (open) {
				$$renderer.push("<!--[0-->");
				$$renderer.push(`<div class="fixed inset-0 z-40 flex items-center justify-center bg-slate-900/40 px-4" role="button" tabindex="0" aria-label="Close new post dialog"><div class="w-[min(90vw,42rem)] rounded-2xl bg-white p-6 shadow-xl" role="dialog" tabindex="-1" aria-modal="true"><div class="flex items-center justify-between"><h2 class="text-lg font-semibold text-slate-900">New post</h2> <button type="button" class="rounded-xl border border-slate-200 px-3 py-1 text-xs font-semibold uppercase tracking-[0.2em] text-slate-600">Close</button></div> <form class="mt-4 space-y-4"><div class="space-y-1"><label class="text-sm font-semibold text-slate-700" for="global-board">Board</label> `);
				$$renderer.select({
					id: "global-board",
					value: boardId,
					class: "w-full rounded-xl border border-slate-200 bg-slate-50 px-3 py-2 text-sm text-slate-900"
				}, ($$renderer) => {
					$$renderer.push(`<!--[-->`);
					const each_array = ensure_array_like(store_get($$store_subs ??= {}, "$bootstrap", bootstrap).boards);
					for (let $$index = 0, $$length = each_array.length; $$index < $$length; $$index++) {
						let board = each_array[$$index];
						$$renderer.option({ value: String(board.id) }, ($$renderer) => {
							$$renderer.push(`${escape_html(board.name)}`);
						});
					}
					$$renderer.push(`<!--]-->`);
				});
				$$renderer.push(`</div> <div class="space-y-1"><label class="text-sm font-semibold text-slate-700" for="global-title">Title</label> <input id="global-title" name="title"${attr("value", title)} class="w-full rounded-xl border border-slate-200 bg-slate-50 px-3 py-2 text-slate-900" placeholder="Optional"/></div> <div class="space-y-1"><div class="text-sm font-semibold text-slate-700">Content</div> `);
				RichEditor($$renderer, {
					name: "content",
					placeholder: "Share your thoughts",
					get value() {
						return content;
					},
					set value($$value) {
						content = $$value;
						$$settled = false;
					}
				});
				$$renderer.push(`<!----></div> <div class="space-y-1"><label class="text-sm font-semibold text-slate-700" for="global-tags">Tags</label> <input id="global-tags" name="tags"${attr("value", tags)} class="w-full rounded-xl border border-slate-200 bg-white px-3 py-2 text-sm text-slate-900" placeholder="tag1, tag2"/></div> <div class="flex justify-end gap-2"><button type="submit" class="rounded-xl bg-slate-900 px-4 py-2 text-xs font-semibold uppercase tracking-[0.2em] text-white"${attr("disabled", submitting, true)}>${escape_html("Post")}</button> <button type="button" class="rounded-xl border border-slate-200 px-4 py-2 text-xs font-semibold uppercase tracking-[0.2em] text-slate-600">Cancel</button></div></form></div></div>`);
			} else $$renderer.push("<!--[-1-->");
			$$renderer.push(`<!--]-->`);
		}
		do {
			$$settled = true;
			$$inner_renderer = $$renderer.copy();
			$$render_inner($$inner_renderer);
		} while (!$$settled);
		$$renderer.subsume($$inner_renderer);
		if ($$store_subs) unsubscribe_stores($$store_subs);
		bind_props($$props, {
			open,
			onClose
		});
	});
}
//#endregion
//#region src/lib/components/AppShell.svelte
function AppShell($$renderer, $$props) {
	$$renderer.component(($$renderer) => {
		var $$store_subs;
		let pathname, isAuthPage, isAdminPage;
		let loading = fallback($$props["loading"], false);
		let globalPostOpen = false;
		let logoutLoading = false;
		const adminLinks = [
			{
				href: "/admin",
				label: "Overview"
			},
			{
				href: "/admin/boards",
				label: "Boards"
			},
			{
				href: "/admin/companies",
				label: "Companies"
			},
			{
				href: "/admin/company-categories",
				label: "Categories"
			},
			{
				href: "/admin/users",
				label: "Users"
			},
			{
				href: "/admin/settings",
				label: "Settings"
			},
			{
				href: "/admin/ads",
				label: "Ads"
			},
			{
				href: "/admin/moderation",
				label: "Moderation"
			},
			{
				href: "/admin/moderation/logs",
				label: "Logs"
			}
		];
		function isActive(currentPath, href) {
			return currentPath === href || currentPath.startsWith(`${href}/`);
		}
		$: pathname = store_get($$store_subs ??= {}, "$page", page).url.pathname;
		$: isAuthPage = pathname === "/login" || pathname === "/register";
		$: isAdminPage = pathname === "/admin" || pathname.startsWith("/admin/");
		head("whg6dh", $$renderer, ($$renderer) => {
			$$renderer.title(($$renderer) => {
				$$renderer.push(`<title>${escape_html(store_get($$store_subs ??= {}, "$bootstrap", bootstrap).site?.title || "HKForum")}</title>`);
			});
			if (store_get($$store_subs ??= {}, "$bootstrap", bootstrap).site?.description) {
				$$renderer.push("<!--[0-->");
				$$renderer.push(`<meta name="description"${attr("content", store_get($$store_subs ??= {}, "$bootstrap", bootstrap).site.description)}/>`);
			} else $$renderer.push("<!--[-1-->");
			$$renderer.push(`<!--]-->`);
		});
		$$renderer.push(`<div class="min-h-screen">`);
		if (isAuthPage) {
			$$renderer.push("<!--[0-->");
			$$renderer.push(`<main class="mx-auto flex min-h-[calc(100vh-4rem)] w-full max-w-5xl items-center justify-center px-4 py-10">`);
			if (loading) {
				$$renderer.push("<!--[0-->");
				$$renderer.push(`<div class="rounded-2xl border border-slate-200 bg-white px-8 py-10 text-sm text-slate-500">Loading shell…</div>`);
			} else {
				$$renderer.push("<!--[-1-->");
				$$renderer.push(`<!--[-->`);
				slot($$renderer, $$props, "default", {}, null);
				$$renderer.push(`<!--]-->`);
			}
			$$renderer.push(`<!--]--></main>`);
		} else if (isAdminPage) {
			$$renderer.push("<!--[1-->");
			$$renderer.push(`<main class="mx-auto w-full max-w-[1280px] px-3 py-3">`);
			if (store_get($$store_subs ??= {}, "$bootstrap", bootstrap).ready) {
				$$renderer.push("<!--[0-->");
				$$renderer.push(`<div class="grid min-h-[calc(100vh-2.5rem)] grid-cols-1 overflow-hidden rounded-2xl border border-slate-200 bg-white min-[960px]:grid-cols-[240px_minmax(0,1fr)]"><aside class="border-b border-slate-200 bg-slate-950 px-5 py-6 text-slate-200 min-[960px]:border-b-0 min-[960px]:border-r min-[960px]:border-slate-800"><a href="/admin" class="block text-xl font-semibold text-white">Admin Console</a> <div class="mt-2 text-sm text-slate-400">${escape_html(store_get($$store_subs ??= {}, "$bootstrap", bootstrap).site?.title || "HKForum")}</div> <nav class="mt-6 space-y-1.5"><!--[-->`);
				const each_array = ensure_array_like(adminLinks);
				for (let $$index = 0, $$length = each_array.length; $$index < $$length; $$index++) {
					let link = each_array[$$index];
					$$renderer.push(`<a${attr("href", link.href)}${attr_class(`block rounded-xl px-3 py-2 text-sm font-medium transition ${isActive(pathname, link.href) ? "bg-white text-slate-900" : "text-slate-300 hover:bg-slate-900 hover:text-white"}`)}>${escape_html(link.label)}</a>`);
				}
				$$renderer.push(`<!--]--></nav> <div class="mt-8 rounded-xl border border-slate-800 bg-slate-900 px-3 py-3"><div class="text-sm font-semibold text-white">${escape_html(store_get($$store_subs ??= {}, "$bootstrap", bootstrap).viewer?.name || store_get($$store_subs ??= {}, "$bootstrap", bootstrap).viewer?.ident || "Admin")}</div> <div class="mt-1 text-xs uppercase tracking-[0.16em] text-slate-500">${escape_html(store_get($$store_subs ??= {}, "$bootstrap", bootstrap).viewer?.role || "admin")}</div> <div class="mt-4 flex flex-col gap-2"><a href="/home" class="text-sm text-slate-300 hover:text-white">Back to forum</a> <button type="button" class="text-left text-sm text-slate-300 hover:text-white">Log out</button></div></div></aside> <div class="min-w-0 bg-slate-50">`);
				if (loading) {
					$$renderer.push("<!--[0-->");
					$$renderer.push(`<div class="flex h-full items-center justify-center px-6 text-sm text-slate-500">Loading admin…</div>`);
				} else {
					$$renderer.push("<!--[-1-->");
					$$renderer.push(`<!--[-->`);
					slot($$renderer, $$props, "default", {}, null);
					$$renderer.push(`<!--]-->`);
				}
				$$renderer.push(`<!--]--></div></div>`);
			} else {
				$$renderer.push("<!--[-1-->");
				$$renderer.push(`<div class="flex min-h-[70vh] items-center justify-center rounded-2xl border border-slate-200 bg-white text-sm text-slate-500">Loading shell…</div>`);
			}
			$$renderer.push(`<!--]--></main>`);
		} else {
			$$renderer.push("<!--[-1-->");
			$$renderer.push(`<main class="mx-auto w-full max-w-[1216px] px-2 py-3 md:px-3">`);
			if (store_get($$store_subs ??= {}, "$bootstrap", bootstrap).ready) {
				$$renderer.push("<!--[0-->");
				$$renderer.push(`<div class="forum-layout-grid grid min-h-[calc(100vh-7rem)] grid-cols-1 overflow-hidden rounded-xl border border-slate-200 bg-[#f4f5f6] min-[1000px]:h-[calc(100vh-2.5rem)] min-[1000px]:grid-cols-[280px_minmax(0,1fr)_280px]"><aside class="border-b border-slate-200 bg-[#f4f5f6] px-6 py-6 min-[1000px]:h-full min-[1000px]:overflow-y-auto min-[1000px]:border-b-0 min-[1000px]:border-r"><div class="flex h-full flex-col"><a href="/home" class="mx-auto mb-6 inline-flex items-center justify-center">`);
				if (store_get($$store_subs ??= {}, "$bootstrap", bootstrap).site?.logoUrl) {
					$$renderer.push("<!--[0-->");
					$$renderer.push(`<img${attr("src", store_get($$store_subs ??= {}, "$bootstrap", bootstrap).site.logoUrl)}${attr("alt", store_get($$store_subs ??= {}, "$bootstrap", bootstrap).site.title)} class="max-h-12 w-auto rounded-lg"/>`);
				} else {
					$$renderer.push("<!--[-1-->");
					$$renderer.push(`<div class="text-2xl font-semibold text-slate-900">${escape_html(store_get($$store_subs ??= {}, "$bootstrap", bootstrap).site?.title || "HKForum")}</div>`);
				}
				$$renderer.push(`<!--]--></a> <nav class="mx-auto w-full max-w-[186px] space-y-1.5"><a href="/home"${attr_class(`flex items-center gap-3 rounded-xl px-3 py-2.5 text-[16px] font-medium transition ${isActive(pathname, "/home") ? "bg-white text-slate-900 shadow-sm" : "text-slate-700 hover:bg-white hover:text-slate-900"}`)}>Home</a> <a href="/boards"${attr_class(`flex items-center gap-3 rounded-xl px-3 py-2.5 text-[16px] font-medium transition ${isActive(pathname, "/boards") ? "bg-white text-slate-900 shadow-sm" : "text-slate-700 hover:bg-white hover:text-slate-900"}`)}>Boards</a> `);
				if (store_get($$store_subs ??= {}, "$bootstrap", bootstrap).site?.showCompaniesNav) {
					$$renderer.push("<!--[0-->");
					$$renderer.push(`<a href="/companies"${attr_class(`flex items-center gap-3 rounded-xl px-3 py-2.5 text-[16px] font-medium transition ${isActive(pathname, "/companies") ? "bg-white text-slate-900 shadow-sm" : "text-slate-700 hover:bg-white hover:text-slate-900"}`)}>Company</a>`);
				} else $$renderer.push("<!--[-1-->");
				$$renderer.push(`<!--]--> `);
				if (store_get($$store_subs ??= {}, "$bootstrap", bootstrap).site?.showJobsNav) {
					$$renderer.push("<!--[0-->");
					$$renderer.push(`<a href="/jobs"${attr_class(`flex items-center gap-3 rounded-xl px-3 py-2.5 text-[16px] font-medium transition ${isActive(pathname, "/jobs") ? "bg-white text-slate-900 shadow-sm" : "text-slate-700 hover:bg-white hover:text-slate-900"}`)}>Jobs</a>`);
				} else $$renderer.push("<!--[-1-->");
				$$renderer.push(`<!--]--> <a href="/chats"${attr_class(`flex items-center gap-3 rounded-xl px-3 py-2.5 text-[16px] font-medium transition ${isActive(pathname, "/chats") ? "bg-white text-slate-900 shadow-sm" : "text-slate-700 hover:bg-white hover:text-slate-900"}`)}>Chats</a> `);
				if (store_get($$store_subs ??= {}, "$bootstrap", bootstrap).auth?.isAuthenticated) {
					$$renderer.push("<!--[0-->");
					$$renderer.push(`<a href="/notifications"${attr_class(`flex items-center justify-between gap-2 rounded-xl px-3 py-2.5 text-[16px] font-medium transition ${isActive(pathname, "/notifications") ? "bg-white text-slate-900 shadow-sm" : "text-slate-700 hover:bg-white hover:text-slate-900"}`)}><span>Notifications</span> `);
					if (store_get($$store_subs ??= {}, "$bootstrap", bootstrap).unreadNotificationCount > 0) {
						$$renderer.push("<!--[0-->");
						$$renderer.push(`<span class="rounded-full bg-slate-900 px-2 py-0.5 text-[11px] font-semibold text-white">${escape_html(store_get($$store_subs ??= {}, "$bootstrap", bootstrap).unreadNotificationCount)}</span>`);
					} else $$renderer.push("<!--[-1-->");
					$$renderer.push(`<!--]--></a> <a href="/bookmarks"${attr_class(`flex items-center gap-3 rounded-xl px-3 py-2.5 text-[16px] font-medium transition ${isActive(pathname, "/bookmarks") ? "bg-white text-slate-900 shadow-sm" : "text-slate-700 hover:bg-white hover:text-slate-900"}`)}>Bookmarks</a>`);
				} else {
					$$renderer.push("<!--[-1-->");
					$$renderer.push(`<a href="/login"${attr_class(`flex items-center gap-3 rounded-xl px-3 py-2.5 text-[16px] font-medium transition ${isActive(pathname, "/login") ? "bg-white text-slate-900 shadow-sm" : "text-slate-700 hover:bg-white hover:text-slate-900"}`)}>Login</a>`);
				}
				$$renderer.push(`<!--]--></nav> `);
				if (store_get($$store_subs ??= {}, "$bootstrap", bootstrap).auth?.isAuthenticated) {
					$$renderer.push("<!--[0-->");
					$$renderer.push(`<button type="button" class="mx-auto mt-5 inline-flex w-full max-w-[170px] items-center justify-center gap-2 rounded-full bg-slate-900 px-5 py-2 text-sm font-semibold text-white transition hover:bg-slate-800">New Post</button>`);
				} else {
					$$renderer.push("<!--[-1-->");
					$$renderer.push(`<a href="/login" class="mx-auto mt-5 inline-flex w-full max-w-[170px] items-center justify-center gap-2 rounded-full bg-slate-900 px-5 py-2 text-sm font-semibold text-white transition hover:bg-slate-800">New Post</a>`);
				}
				$$renderer.push(`<!--]--> `);
				if (store_get($$store_subs ??= {}, "$bootstrap", bootstrap).viewer) {
					$$renderer.push("<!--[0-->");
					$$renderer.push(`<div class="mx-auto mt-auto w-full max-w-[170px] rounded-xl border border-slate-200 bg-white px-2.5 py-2"><div class="truncate text-sm font-semibold text-slate-900">${escape_html(store_get($$store_subs ??= {}, "$bootstrap", bootstrap).viewer.name || store_get($$store_subs ??= {}, "$bootstrap", bootstrap).viewer.ident)}</div> <div class="truncate text-xs text-slate-500">@${escape_html(store_get($$store_subs ??= {}, "$bootstrap", bootstrap).viewer.ident)}</div> <div class="mt-3 flex flex-col gap-2"><a href="/profile" class="text-sm text-slate-700 hover:text-slate-900">Profile</a> <a href="/settings" class="text-sm text-slate-700 hover:text-slate-900">Settings</a> `);
					if (store_get($$store_subs ??= {}, "$bootstrap", bootstrap).viewer.role === "admin") {
						$$renderer.push("<!--[0-->");
						$$renderer.push(`<a href="/admin" class="text-sm text-slate-700 hover:text-slate-900">Admin</a>`);
					} else $$renderer.push("<!--[-1-->");
					$$renderer.push(`<!--]--> <button type="button" class="text-left text-sm text-slate-700 hover:text-slate-900"${attr("disabled", logoutLoading, true)}>${escape_html("Log Out")}</button></div></div>`);
				} else {
					$$renderer.push("<!--[-1-->");
					$$renderer.push(`<a href="/login" class="mx-auto mt-auto flex w-full max-w-[170px] items-center gap-2 rounded-xl border border-slate-200 bg-white px-2.5 py-2 transition hover:border-slate-300"><div class="flex h-8 w-8 shrink-0 items-center justify-center rounded-full bg-slate-200 text-xs font-semibold text-slate-700">G</div> <div class="min-w-0 flex-1"><div class="truncate text-sm font-semibold text-slate-900">Guest</div> <div class="truncate text-xs text-slate-500">Sign in to personalize</div></div></a>`);
				}
				$$renderer.push(`<!--]--></div></aside> <div class="feed-shell min-w-0 border-b border-slate-200 bg-white min-[1000px]:h-full min-[1000px]:overflow-y-auto min-[1000px]:border-b-0 min-[1000px]:border-r">`);
				if (loading) {
					$$renderer.push("<!--[0-->");
					$$renderer.push(`<div class="flex h-full items-center justify-center text-sm text-slate-500">Loading…</div>`);
				} else {
					$$renderer.push("<!--[-1-->");
					$$renderer.push(`<!--[-->`);
					slot($$renderer, $$props, "default", {}, null);
					$$renderer.push(`<!--]-->`);
				}
				$$renderer.push(`<!--]--></div> <aside class="bg-[#f4f5f6] p-3 min-[1000px]:h-full min-[1000px]:overflow-y-auto"><div class="mx-auto w-full max-w-[292px] space-y-3"><form method="get" action="/home" class="relative rounded-xl border border-slate-200 bg-white p-2"><input type="search" name="q" placeholder="Type '/' to search" class="w-full rounded-lg border border-slate-200 py-2 pl-3 pr-3 text-sm text-slate-700 placeholder:text-slate-400 focus:border-slate-400 focus:outline-none"/></form> `);
				if (store_get($$store_subs ??= {}, "$bootstrap", bootstrap).sidebarAds?.length) {
					$$renderer.push("<!--[0-->");
					$$renderer.push(`<div class="space-y-3"><!--[-->`);
					const each_array_1 = ensure_array_like(store_get($$store_subs ??= {}, "$bootstrap", bootstrap).sidebarAds);
					for (let $$index_1 = 0, $$length = each_array_1.length; $$index_1 < $$length; $$index_1++) {
						let ad = each_array_1[$$index_1];
						$$renderer.push(`<div class="rounded-xl border border-slate-200 bg-white p-4"><div class="text-base font-semibold text-slate-900">${escape_html(ad.title)}</div> <div class="mt-2 whitespace-pre-wrap text-sm text-slate-600">${escape_html(ad.body)}</div> `);
						if (ad.link) {
							$$renderer.push("<!--[0-->");
							$$renderer.push(`<a${attr("href", ad.link)} target="_blank" rel="noreferrer" class="mt-3 inline-flex text-sm font-semibold text-slate-700 underline underline-offset-2 hover:text-slate-900">Learn more</a>`);
						} else $$renderer.push("<!--[-1-->");
						$$renderer.push(`<!--]--></div>`);
					}
					$$renderer.push(`<!--]--></div>`);
				} else $$renderer.push("<!--[-1-->");
				$$renderer.push(`<!--]--> <div class="rounded-xl border border-slate-200 bg-white p-4"><div class="mb-3 text-xl font-semibold text-slate-900">Who to follow</div> <div class="space-y-3.5">`);
				if (!store_get($$store_subs ??= {}, "$bootstrap", bootstrap).suggestedUsers?.length) {
					$$renderer.push("<!--[0-->");
					$$renderer.push(`<div class="text-sm text-slate-500">No user suggestion yet.</div>`);
				} else {
					$$renderer.push("<!--[-1-->");
					$$renderer.push(`<!--[-->`);
					const each_array_2 = ensure_array_like(store_get($$store_subs ??= {}, "$bootstrap", bootstrap).suggestedUsers);
					for (let $$index_2 = 0, $$length = each_array_2.length; $$index_2 < $$length; $$index_2++) {
						let user = each_array_2[$$index_2];
						$$renderer.push(`<div class="flex items-center justify-between gap-3"><div class="flex min-w-0 items-center gap-2.5"><div class="flex h-9 w-9 items-center justify-center rounded-full bg-slate-200 text-xs font-semibold text-slate-700">${escape_html((user.ident || "U").slice(0, 1).toUpperCase())}</div> <div class="min-w-0"><div class="truncate text-sm font-semibold text-slate-900">${escape_html(user.name || user.ident)}</div> <div class="truncate text-xs text-slate-500">@${escape_html(user.ident.toLowerCase())}</div></div></div> `);
						if (store_get($$store_subs ??= {}, "$bootstrap", bootstrap).auth?.isAuthenticated) {
							$$renderer.push("<!--[0-->");
							$$renderer.push(`<button type="button" class="rounded-lg bg-slate-900 px-3 py-1.5 text-xs font-semibold text-white">${escape_html(user.isFollowing ? "Following" : "Follow")}</button>`);
						} else {
							$$renderer.push("<!--[-1-->");
							$$renderer.push(`<a href="/login" class="rounded-lg bg-slate-900 px-3 py-1.5 text-xs font-semibold text-white">Follow</a>`);
						}
						$$renderer.push(`<!--]--></div>`);
					}
					$$renderer.push(`<!--]-->`);
				}
				$$renderer.push(`<!--]--></div></div> <div class="rounded-xl border border-slate-200 bg-white p-4"><div class="mb-3 text-xl font-semibold text-slate-900">Boards</div> <div class="space-y-3.5"><!--[-->`);
				const each_array_3 = ensure_array_like(store_get($$store_subs ??= {}, "$bootstrap", bootstrap).boards.slice(0, 3));
				for (let $$index_3 = 0, $$length = each_array_3.length; $$index_3 < $$length; $$index_3++) {
					let board = each_array_3[$$index_3];
					$$renderer.push(`<a${attr("href", `/board/${board.id}`)} class="flex items-center justify-between gap-2 rounded-lg px-1 py-1.5 transition hover:bg-slate-50"><div class="flex min-w-0 items-center gap-2.5"><div class="h-9 w-9 rounded-full bg-slate-200"></div> <div class="min-w-0"><div class="truncate text-sm font-semibold text-slate-900">${escape_html(board.name)}</div> <div class="truncate text-xs text-slate-500">${escape_html(board.postCount)} posts</div></div></div></a>`);
				}
				$$renderer.push(`<!--]--></div> <a href="/boards" class="mt-3 inline-flex text-sm font-semibold text-slate-700 hover:text-slate-900">Show more</a></div> <div class="px-1 text-xs text-slate-500"><span>Built by ${escape_html(store_get($$store_subs ??= {}, "$bootstrap", bootstrap).site?.title)}</span> `);
				if (store_get($$store_subs ??= {}, "$bootstrap", bootstrap).site?.subtitle) {
					$$renderer.push("<!--[0-->");
					$$renderer.push(`<div class="mt-1">${escape_html(store_get($$store_subs ??= {}, "$bootstrap", bootstrap).site.subtitle)}</div>`);
				} else $$renderer.push("<!--[-1-->");
				$$renderer.push(`<!--]--></div></div></aside></div> `);
				GlobalPostModal($$renderer, {
					open: globalPostOpen,
					onClose: () => globalPostOpen = false
				});
				$$renderer.push(`<!---->`);
			} else {
				$$renderer.push("<!--[-1-->");
				$$renderer.push(`<div class="flex min-h-[60vh] items-center justify-center rounded-xl border border-slate-200 bg-white text-sm text-slate-500">Loading shell…</div>`);
			}
			$$renderer.push(`<!--]--></main>`);
		}
		$$renderer.push(`<!--]--> `);
		if (store_get($$store_subs ??= {}, "$bootstrap", bootstrap).site?.footerText) {
			$$renderer.push("<!--[0-->");
			$$renderer.push(`<footer class="mx-auto w-full max-w-[1216px] px-2 py-4 text-center text-xs text-slate-500 md:px-3">${escape_html(store_get($$store_subs ??= {}, "$bootstrap", bootstrap).site.footerText)}</footer>`);
		} else $$renderer.push("<!--[-1-->");
		$$renderer.push(`<!--]--></div>`);
		if ($$store_subs) unsubscribe_stores($$store_subs);
		bind_props($$props, { loading });
	});
}
//#endregion
//#region src/routes/+layout.svelte
function _layout($$renderer, $$props) {
	$$renderer.component(($$renderer) => {
		AppShell($$renderer, {
			loading: true,
			children: ($$renderer) => {
				$$renderer.push(`<!--[-->`);
				slot($$renderer, $$props, "default", {}, null);
				$$renderer.push(`<!--]-->`);
			},
			$$slots: { default: true }
		});
	});
}
//#endregion
export { _layout as default };
