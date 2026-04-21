import { n as onDestroy } from "./index-server.js";
import { G as escape_html, U as attr, d as unsubscribe_stores, n as attr_class, o as ensure_array_like, u as store_get } from "./dev.js";
import { t as page } from "./stores.js";
import { t as bootstrap } from "./bootstrap.js";
import { t as apiFetch } from "./api.js";
import { n as relativeTime } from "./time.js";
//#region src/lib/pages/ChatsPage.svelte
function ChatsPage($$renderer, $$props) {
	$$renderer.component(($$renderer) => {
		var $$store_subs;
		let parts, mode, roomId, activeRoom;
		let loading = false;
		let rooms = [];
		let messages = [];
		let search = "";
		let users = [];
		let messageContent = "";
		let searchTimer;
		let pollTimer;
		let activeRoomKey = null;
		async function loadMessages() {
			if (!roomId || !store_get($$store_subs ??= {}, "$bootstrap", bootstrap).auth?.isAuthenticated) return;
			loading = true;
			try {
				messages = (await apiFetch(`/api/v1/chats/${roomId}/messages`)).items || [];
			} catch (error) {
				window.alert(error.message);
			} finally {
				loading = false;
			}
		}
		async function searchUsers() {
			if (!store_get($$store_subs ??= {}, "$bootstrap", bootstrap).auth?.isAuthenticated) return;
			if (!search.trim()) {
				users = [];
				return;
			}
			try {
				users = (await apiFetch(`/api/v1/users?q=${encodeURIComponent(search.trim())}`)).items || [];
			} catch (error) {
				window.alert(error.message);
			}
		}
		onDestroy(() => {
			clearTimeout(searchTimer);
			clearInterval(pollTimer);
		});
		$: parts = store_get($$store_subs ??= {}, "$page", page).url.pathname.split("/").filter(Boolean);
		$: mode = parts[1] || "index";
		$: roomId = parts[1] === "room" ? parts[2] : null;
		$: if (mode === "new" && search !== void 0) {
			clearTimeout(searchTimer);
			searchTimer = setTimeout(() => {
				searchUsers();
			}, 200);
		}
		$: if (roomId && store_get($$store_subs ??= {}, "$bootstrap", bootstrap).ready && roomId !== activeRoomKey) {
			activeRoomKey = roomId;
			loadMessages();
		}
		$: if (!roomId) activeRoomKey = null;
		$: activeRoom = roomId ? rooms.find((room) => String(room.id) === String(roomId)) : null;
		$$renderer.push(`<section class="flex min-h-full flex-col bg-slate-50"><div class="border-b border-slate-200 bg-white px-5 py-4"><div class="flex items-center justify-between gap-3"><div><h1 class="text-2xl font-semibold text-slate-900">Chats</h1> <p class="mt-1 text-sm text-slate-500">Direct messages are fully rendered from SvelteKit now.</p></div> `);
		if (store_get($$store_subs ??= {}, "$bootstrap", bootstrap).auth?.isAuthenticated) {
			$$renderer.push("<!--[0-->");
			$$renderer.push(`<a href="/chats/new" class="rounded-xl bg-slate-900 px-4 py-2 text-sm font-semibold text-white">New Chat</a>`);
		} else $$renderer.push("<!--[-1-->");
		$$renderer.push(`<!--]--></div></div> `);
		if (!store_get($$store_subs ??= {}, "$bootstrap", bootstrap).auth?.isAuthenticated) {
			$$renderer.push("<!--[0-->");
			$$renderer.push(`<div class="px-5 py-6 text-sm text-slate-600">Login is required to view chats.</div>`);
		} else {
			$$renderer.push("<!--[-1-->");
			$$renderer.push(`<div class="grid flex-1 gap-5 px-5 py-5 lg:grid-cols-[320px_minmax(0,1fr)]"><aside class="space-y-3"><a href="/chats"${attr_class(`block rounded-xl px-4 py-3 text-sm font-medium ${mode === "index" ? "bg-slate-900 text-white" : "bg-white text-slate-700"}`)}>Inbox</a> <!--[-->`);
			const each_array = ensure_array_like(rooms);
			for (let $$index = 0, $$length = each_array.length; $$index < $$length; $$index++) {
				let room = each_array[$$index];
				$$renderer.push(`<a${attr("href", `/chats/room/${room.id}`)}${attr_class(`block rounded-xl border px-4 py-3 transition ${String(room.id) === String(roomId) ? "border-slate-900 bg-white" : "border-slate-200 bg-white hover:border-slate-300"}`)}><div class="text-sm font-semibold text-slate-900">${escape_html(room.peer?.name || room.peer?.ident)}</div> <div class="mt-1 truncate text-sm text-slate-500">${escape_html(room.preview)}</div> <div class="mt-2 text-xs text-slate-400">${escape_html(relativeTime(room.updatedAt))}</div></a>`);
			}
			$$renderer.push(`<!--]--></aside> <div class="min-h-[32rem] rounded-2xl border border-slate-200 bg-white">`);
			if (mode === "new") {
				$$renderer.push("<!--[0-->");
				$$renderer.push(`<div class="p-5"><label class="text-xs font-semibold uppercase tracking-[0.18em] text-slate-500" for="chat-search">Search users</label> <input id="chat-search"${attr("value", search)} class="mt-2 w-full rounded-xl border border-slate-200 bg-slate-50 px-4 py-3 text-sm text-slate-900" placeholder="Search by handle or name"/> <div class="mt-4 space-y-3"><!--[-->`);
				const each_array_1 = ensure_array_like(users);
				for (let $$index_1 = 0, $$length = each_array_1.length; $$index_1 < $$length; $$index_1++) {
					let user = each_array_1[$$index_1];
					$$renderer.push(`<button type="button" class="flex w-full items-center justify-between rounded-xl border border-slate-200 px-4 py-3 text-left transition hover:border-slate-300"><div><div class="text-sm font-semibold text-slate-900">${escape_html(user.name || user.ident)}</div> <div class="text-sm text-slate-500">@${escape_html(user.ident)}</div></div> <span class="text-xs font-semibold uppercase tracking-[0.18em] text-slate-500">Start</span></button>`);
				}
				$$renderer.push(`<!--]--></div></div>`);
			} else if (mode === "room" && roomId) {
				$$renderer.push("<!--[1-->");
				$$renderer.push(`<div class="flex h-full flex-col"><div class="border-b border-slate-200 px-5 py-4"><div class="text-lg font-semibold text-slate-900">${escape_html(activeRoom?.peer?.name || activeRoom?.peer?.ident || "Chat room")}</div> <div class="mt-1 text-sm text-slate-500">@${escape_html(activeRoom?.peer?.ident || "unknown")}</div></div> <div class="flex-1 space-y-3 overflow-y-auto px-5 py-5">`);
				if (loading) {
					$$renderer.push("<!--[0-->");
					$$renderer.push(`<div class="text-sm text-slate-500">Loading messages…</div>`);
				} else if (!messages.length) {
					$$renderer.push("<!--[1-->");
					$$renderer.push(`<div class="text-sm text-slate-500">No messages yet.</div>`);
				} else {
					$$renderer.push("<!--[-1-->");
					$$renderer.push(`<!--[-->`);
					const each_array_2 = ensure_array_like(messages);
					for (let $$index_2 = 0, $$length = each_array_2.length; $$index_2 < $$length; $$index_2++) {
						let message = each_array_2[$$index_2];
						$$renderer.push(`<div${attr_class(`max-w-[80%] rounded-2xl px-4 py-3 ${message.author?.id === store_get($$store_subs ??= {}, "$bootstrap", bootstrap).viewer?.id ? "ml-auto bg-slate-900 text-white" : "bg-slate-100 text-slate-900"}`)}><div class="text-xs uppercase tracking-[0.18em] opacity-70">${escape_html(message.author?.ident || "unknown")}</div> <div class="mt-2 whitespace-pre-wrap text-sm">${escape_html(message.content)}</div> <div class="mt-2 text-xs opacity-70">${escape_html(relativeTime(message.createdAt))}</div></div>`);
					}
					$$renderer.push(`<!--]-->`);
				}
				$$renderer.push(`<!--]--></div> <div class="border-t border-slate-200 p-4"><div class="flex gap-3"><textarea class="min-h-[96px] flex-1 rounded-xl border border-slate-200 bg-slate-50 px-4 py-3 text-sm text-slate-900" placeholder="Write a message">`);
				const $$body = escape_html(messageContent);
				if ($$body) $$renderer.push(`${$$body}`);
				$$renderer.push(`</textarea> <button type="button" class="rounded-xl bg-slate-900 px-4 py-3 text-sm font-semibold text-white">Send</button></div></div></div>`);
			} else {
				$$renderer.push("<!--[-1-->");
				$$renderer.push(`<div class="flex h-full items-center justify-center px-6 text-center text-sm text-slate-500">Choose a room or start a new chat.</div>`);
			}
			$$renderer.push(`<!--]--></div></div>`);
		}
		$$renderer.push(`<!--]--></section>`);
		if ($$store_subs) unsubscribe_stores($$store_subs);
	});
}
//#endregion
export { ChatsPage as t };
