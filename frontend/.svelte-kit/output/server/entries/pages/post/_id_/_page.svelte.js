import "../../../../chunks/index-server.js";
import { G as escape_html, U as attr, d as unsubscribe_stores, f as html, n as attr_class, o as ensure_array_like, r as attr_style, u as store_get } from "../../../../chunks/dev.js";
import "../../../../chunks/navigation.js";
import { t as page } from "../../../../chunks/stores.js";
import { t as bootstrap } from "../../../../chunks/bootstrap.js";
import { t as apiFetch } from "../../../../chunks/api.js";
import { n as relativeTime } from "../../../../chunks/time.js";
import { t as PageEmpty } from "../../../../chunks/PageEmpty.js";
//#region src/routes/post/[id]/+page.svelte
function _page($$renderer, $$props) {
	$$renderer.component(($$renderer) => {
		var $$store_subs;
		let comments, post;
		let payload = null;
		let loading = true;
		let commentContent = "";
		let commentSubmitting = false;
		let deleting = false;
		function orderedComments(comments) {
			const children = /* @__PURE__ */ new Map();
			const byId = /* @__PURE__ */ new Map();
			for (const comment of comments) {
				byId.set(comment.id, comment);
				const key = comment.parentCommentId || 0;
				const list = children.get(key) || [];
				list.push(comment);
				children.set(key, list);
			}
			const result = [];
			function walk(parentId = 0, depth = 0) {
				for (const comment of children.get(parentId) || []) {
					result.push({
						...comment,
						depth,
						parent: comment.parentCommentId ? byId.get(comment.parentCommentId) : null
					});
					walk(comment.id, depth + 1);
				}
			}
			walk();
			return result;
		}
		async function loadPost() {
			loading = true;
			try {
				payload = await apiFetch(`/api/v1/posts/${store_get($$store_subs ??= {}, "$page", page).params.id}`);
			} finally {
				loading = false;
			}
		}
		$: if (store_get($$store_subs ??= {}, "$page", page).params.id) loadPost();
		$: comments = orderedComments(payload?.data?.comments || []);
		$: post = payload?.data?.post;
		$$renderer.push(`<section class="bg-white border border-slate-200 shadow-sm rounded-2xl p-6 space-y-6">`);
		if (loading) {
			$$renderer.push("<!--[0-->");
			$$renderer.push(`<div class="text-sm text-slate-500">Loading post…</div>`);
		} else if (!post) {
			$$renderer.push("<!--[1-->");
			PageEmpty($$renderer, { title: "Post not found." });
		} else {
			$$renderer.push("<!--[-1-->");
			$$renderer.push(`<header class="space-y-2"><p class="text-xs uppercase tracking-[0.3em] text-slate-400">Post</p> <h1 class="text-2xl font-bold text-slate-900">${escape_html(post.title)}</h1> <p class="text-sm text-slate-500">In <a${attr("href", `/board/${post.board?.id}`)} class="font-semibold text-slate-700 hover:text-slate-900">${escape_html(post.board?.name)}</a> · By @${escape_html(post.author?.ident)}
        · ${escape_html(relativeTime(post.createdAt))}</p> <p class="text-xs text-slate-500">${escape_html(post.likeCount)} likes · ${escape_html(post.viewCount)} views</p> `);
			if (post.tags?.length) {
				$$renderer.push("<!--[0-->");
				$$renderer.push(`<div class="flex flex-wrap gap-1.5"><!--[-->`);
				const each_array = ensure_array_like(post.tags);
				for (let $$index = 0, $$length = each_array.length; $$index < $$length; $$index++) {
					let tag = each_array[$$index];
					$$renderer.push(`<span class="rounded-full border border-slate-200 bg-slate-50 px-2 py-0.5 text-[11px] font-semibold text-slate-600">#${escape_html(tag)}</span>`);
				}
				$$renderer.push(`<!--]--></div>`);
			} else $$renderer.push("<!--[-1-->");
			$$renderer.push(`<!--]--></header> <div class="ql-editor forum-content-wrap rounded-2xl border border-slate-200 bg-slate-50/60 p-4 text-sm text-slate-700">${html(post.content)}</div> `);
			if (store_get($$store_subs ??= {}, "$bootstrap", bootstrap).viewer && (store_get($$store_subs ??= {}, "$bootstrap", bootstrap).viewer.id === post.author?.id || store_get($$store_subs ??= {}, "$bootstrap", bootstrap).viewer.role === "admin")) {
				$$renderer.push("<!--[0-->");
				$$renderer.push(`<div class="flex items-center gap-2"><button type="button" class="rounded-lg border border-rose-200 px-3 py-1 text-xs font-semibold uppercase tracking-[0.2em] text-rose-700"${attr("disabled", deleting, true)}>${escape_html("Delete post")}</button></div>`);
			} else $$renderer.push("<!--[-1-->");
			$$renderer.push(`<!--]--> <section class="space-y-3"><div class="flex items-center justify-between"><h2 class="text-lg font-semibold text-slate-900">Comments</h2> <span class="text-xs uppercase tracking-[0.3em] text-slate-400">${escape_html(comments.length)}</span></div> `);
			if (!comments.length) {
				$$renderer.push("<!--[0-->");
				$$renderer.push(`<p class="text-sm text-slate-500">No comments yet.</p>`);
			} else {
				$$renderer.push("<!--[-1-->");
				$$renderer.push(`<div class="space-y-2"><!--[-->`);
				const each_array_1 = ensure_array_like(comments);
				for (let $$index_1 = 0, $$length = each_array_1.length; $$index_1 < $$length; $$index_1++) {
					let comment = each_array_1[$$index_1];
					$$renderer.push(`<div class="relative"${attr_style(`margin-left:${Math.min(comment.depth, 8) * 18}px;`)}><article${attr_class(`rounded-xl border p-3 text-sm text-slate-700 ${comment.depth === 0 ? "border-slate-200 bg-slate-50/70" : comment.depth === 1 ? "border-slate-300 bg-white" : "border-slate-300 bg-slate-100/60"}`)}>`);
					if (comment.parent) {
						$$renderer.push("<!--[0-->");
						$$renderer.push(`<p class="mb-1 text-xs text-slate-500">↳ reply to @${escape_html(comment.parent.author?.ident)}</p>`);
					} else $$renderer.push("<!--[-1-->");
					$$renderer.push(`<!--]--> <div class="forum-content-wrap whitespace-pre-wrap">${escape_html(comment.content)}</div> <div class="mt-2 flex items-center gap-2 text-xs text-slate-500"><span>@${escape_html(comment.author?.ident)}</span> <span>· ${escape_html(relativeTime(comment.createdAt))}</span> `);
					if (store_get($$store_subs ??= {}, "$bootstrap", bootstrap).auth?.isAuthenticated) {
						$$renderer.push("<!--[0-->");
						$$renderer.push(`<button type="button" class="rounded-lg border border-slate-200 px-2 py-1 font-semibold uppercase tracking-[0.2em] text-slate-600 hover:border-slate-900 hover:text-slate-900">Reply</button>`);
					} else $$renderer.push("<!--[-1-->");
					$$renderer.push(`<!--]--></div></article></div>`);
				}
				$$renderer.push(`<!--]--></div>`);
			}
			$$renderer.push(`<!--]--></section> <section>`);
			if (store_get($$store_subs ??= {}, "$bootstrap", bootstrap).auth?.isAuthenticated) {
				$$renderer.push("<!--[0-->");
				$$renderer.push(`<form class="space-y-3"><textarea required="" rows="5" class="w-full rounded-xl border border-slate-200 bg-slate-50 px-3 py-2 text-sm text-slate-900"${attr("placeholder", "Add a comment…")}>`);
				const $$body = escape_html(commentContent);
				if ($$body) $$renderer.push(`${$$body}`);
				$$renderer.push(`</textarea> <div class="flex justify-end gap-2">`);
				$$renderer.push("<!--[-1-->");
				$$renderer.push(`<!--]--> <button type="submit" class="rounded-xl bg-slate-900 px-4 py-2 text-xs font-semibold uppercase tracking-[0.2em] text-white"${attr("disabled", commentSubmitting, true)}>${escape_html("Add comment")}</button></div></form>`);
			} else {
				$$renderer.push("<!--[-1-->");
				$$renderer.push(`<a href="/login" class="inline-flex rounded-lg border border-slate-900 px-3 py-1.5 text-xs font-semibold uppercase tracking-[0.2em] text-slate-900 transition hover:bg-slate-900 hover:text-white">Login to comment</a>`);
			}
			$$renderer.push(`<!--]--></section>`);
		}
		$$renderer.push(`<!--]--></section>`);
		if ($$store_subs) unsubscribe_stores($$store_subs);
	});
}
//#endregion
export { _page as default };
