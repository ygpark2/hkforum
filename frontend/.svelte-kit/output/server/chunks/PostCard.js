import { G as escape_html, U as attr, W as clsx, d as unsubscribe_stores, et as fallback, f as html, i as bind_props, n as attr_class, o as ensure_array_like, u as store_get } from "./dev.js";
import { t as bootstrap } from "./bootstrap.js";
import "./api.js";
import { n as relativeTime } from "./time.js";
//#region src/lib/components/PostCard.svelte
function PostCard($$renderer, $$props) {
	$$renderer.component(($$renderer) => {
		var $$store_subs;
		let post = $$props["post"];
		let showBoard = fallback($$props["showBoard"], true);
		let compact = fallback($$props["compact"], false);
		$$renderer.push(`<article${attr_class(clsx(compact ? "rounded-2xl border border-slate-200 bg-slate-50/60 p-4" : ""))}><div class="flex items-start justify-between gap-3"><div class="flex min-w-0 flex-1 gap-3"><div class="mt-0.5 flex h-10 w-10 shrink-0 items-center justify-center rounded-full bg-slate-200 text-sm font-semibold text-slate-700">${escape_html((post.author?.name || post.author?.ident || "U").slice(0, 1).toUpperCase())}</div> <div class="min-w-0 flex-1"><div class="flex flex-wrap items-center gap-x-2 gap-y-0.5 text-sm"><span class="font-semibold text-slate-900">${escape_html(post.author?.name || post.author?.ident || "Unknown")}</span> <span class="text-slate-500">@${escape_html((post.author?.ident || "unknown").toLowerCase())}</span> <span class="text-slate-400">${escape_html(relativeTime(post.createdAt))}</span></div> `);
		if (post.title) {
			$$renderer.push("<!--[0-->");
			$$renderer.push(`<a${attr("href", `/post/${post.id}`)} class="mt-1 block text-lg font-semibold text-slate-900 hover:text-slate-700">${escape_html(post.title)}</a>`);
		} else $$renderer.push("<!--[-1-->");
		$$renderer.push(`<!--]--> <a${attr("href", `/post/${post.id}`)} class="ql-editor forum-content-wrap mt-1 block break-words text-[17px] leading-7 text-slate-800 hover:text-slate-900">${html(post.content)}</a> `);
		if (post.tags?.length) {
			$$renderer.push("<!--[0-->");
			$$renderer.push(`<div class="mt-2 flex flex-wrap gap-1.5"><!--[-->`);
			const each_array = ensure_array_like(post.tags.slice(0, compact ? 99 : 3));
			for (let $$index = 0, $$length = each_array.length; $$index < $$length; $$index++) {
				let tag = each_array[$$index];
				$$renderer.push(`<span class="rounded-full border border-slate-200 bg-slate-50 px-2 py-0.5 text-[11px] font-semibold text-slate-600">#${escape_html(tag)}</span>`);
			}
			$$renderer.push(`<!--]--></div>`);
		} else $$renderer.push("<!--[-1-->");
		$$renderer.push(`<!--]--> `);
		if (showBoard && post.board) {
			$$renderer.push("<!--[0-->");
			$$renderer.push(`<div class="mt-2 text-xs text-slate-500">${escape_html(post.board.name)}</div>`);
		} else $$renderer.push("<!--[-1-->");
		$$renderer.push(`<!--]--></div></div> <details class="relative"><summary class="cursor-pointer list-none rounded-lg px-2 py-1 text-slate-500 hover:bg-slate-100">...</summary> <div class="absolute right-0 z-20 mt-2 w-48 rounded-xl border border-slate-200 bg-white p-2 shadow-lg"><button type="button" class="flex w-full items-center gap-2 rounded-lg px-3 py-2 text-left text-sm text-slate-700 hover:bg-slate-50"><span>🔗</span> <span>Copy link</span></button> `);
		if (store_get($$store_subs ??= {}, "$bootstrap", bootstrap).auth?.isAuthenticated) {
			$$renderer.push("<!--[0-->");
			$$renderer.push(`<button type="button" class="flex w-full items-center gap-2 rounded-lg px-3 py-2 text-left text-sm text-slate-700 hover:bg-slate-50"><span>${escape_html(post.isWatching ? "👁" : "👁‍🗨")}</span> <span>${escape_html(post.isWatching ? "Watching" : "Watch")}</span></button> <button type="button" class="flex w-full items-center gap-2 rounded-lg px-3 py-2 text-left text-sm text-slate-700 hover:bg-slate-50"><span>⚑</span> <span>Flag</span></button> <button type="button" class="flex w-full items-center gap-2 rounded-lg px-3 py-2 text-left text-sm text-slate-700 hover:bg-slate-50"><span>✕</span> <span>Hide post</span></button> `);
			if (store_get($$store_subs ??= {}, "$bootstrap", bootstrap).site?.allowUserBlocking && post.author?.id && post.author?.id !== store_get($$store_subs ??= {}, "$bootstrap", bootstrap).viewer?.id) {
				$$renderer.push("<!--[0-->");
				$$renderer.push(`<button type="button" class="flex w-full items-center gap-2 rounded-lg px-3 py-2 text-left text-sm text-slate-700 hover:bg-slate-50"><span>⛔</span> <span>Block user</span></button>`);
			} else $$renderer.push("<!--[-1-->");
			$$renderer.push(`<!--]-->`);
		} else $$renderer.push("<!--[-1-->");
		$$renderer.push(`<!--]--></div></details></div> <div class="mt-3 flex items-center justify-between text-sm"><div class="flex items-center gap-4 text-slate-500"><a${attr("href", `/post/${post.id}`)} class="inline-flex items-center gap-1.5 hover:text-slate-700"><span>💬</span> <span>${escape_html(post.commentCount)}</span></a> `);
		if (store_get($$store_subs ??= {}, "$bootstrap", bootstrap).auth?.isAuthenticated) {
			$$renderer.push("<!--[0-->");
			$$renderer.push(`<div class="relative"><button type="button" class="inline-flex items-center gap-1.5 rounded-md px-1 py-0.5 hover:bg-slate-100 hover:text-slate-800"><span>🙂</span></button> `);
			$$renderer.push("<!--[-1-->");
			$$renderer.push(`<!--]--></div>`);
		} else $$renderer.push("<!--[-1-->");
		$$renderer.push(`<!--]--> `);
		if (post.reactions?.length) {
			$$renderer.push("<!--[0-->");
			$$renderer.push(`<div class="flex items-center gap-1.5"><!--[-->`);
			const each_array_2 = ensure_array_like(post.reactions);
			for (let $$index_2 = 0, $$length = each_array_2.length; $$index_2 < $$length; $$index_2++) {
				let reaction = each_array_2[$$index_2];
				$$renderer.push(`<span class="inline-flex items-center gap-1 rounded-full border border-slate-200 px-2 py-0.5 text-sm text-slate-700"><span>${escape_html(reaction.emoji)}</span> <span>${escape_html(reaction.count)}</span></span>`);
			}
			$$renderer.push(`<!--]--></div>`);
		} else $$renderer.push("<!--[-1-->");
		$$renderer.push(`<!--]--></div> <div class="flex items-center gap-2">`);
		if (store_get($$store_subs ??= {}, "$bootstrap", bootstrap).auth?.isAuthenticated) {
			$$renderer.push("<!--[0-->");
			$$renderer.push(`<button type="button" class="rounded-lg border border-slate-200 px-2.5 py-1 text-xs font-semibold uppercase tracking-[0.2em] text-slate-700 hover:border-slate-900 hover:text-slate-900"><span>${escape_html(post.isLiked ? "♥" : "♡")}</span> <span class="ml-1">${escape_html(post.likeCount)}</span></button> <button type="button" class="inline-flex h-7 w-7 items-center justify-center rounded-md text-slate-500 transition hover:bg-slate-100 hover:text-slate-800" aria-label="Bookmark"><svg viewBox="0 0 24 24" class="h-4 w-4"${attr("fill", post.isBookmarked ? "currentColor" : "none")} stroke="currentColor" stroke-width="2"><path d="M7 4h10a1 1 0 0 1 1 1v15l-6-3-6 3V5a1 1 0 0 1 1-1z"></path></svg></button>`);
		} else $$renderer.push("<!--[-1-->");
		$$renderer.push(`<!--]--></div></div></article>`);
		if ($$store_subs) unsubscribe_stores($$store_subs);
		bind_props($$props, {
			post,
			showBoard,
			compact
		});
	});
}
//#endregion
export { PostCard as t };
