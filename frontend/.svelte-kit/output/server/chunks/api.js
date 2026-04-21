import { k as get } from "./dev.js";
import "./index-server2.js";
import { t as bootstrap } from "./bootstrap.js";
//#region src/lib/utils/api.js
async function parsePayload(response) {
	if ((response.headers.get("content-type") || "").includes("application/json")) return response.json();
	return response.text();
}
async function apiFetch(url, options = {}) {
	const response = await fetch(url, {
		credentials: "same-origin",
		headers: {
			Accept: "application/json",
			...options.headers || {}
		},
		...options
	});
	if (response.redirected && response.url.includes("/auth/")) throw new Error("로그인이 필요합니다.");
	const payload = await parsePayload(response);
	if (!response.ok) {
		const message = payload?.message || payload?.error || (typeof payload === "string" ? payload : "Request failed.");
		throw new Error(message);
	}
	return payload;
}
function appendCsrf(formData) {
	const state = get(bootstrap);
	const csrfParam = state?.auth?.csrfParam;
	const csrfToken = state?.auth?.csrfToken;
	if (csrfParam && csrfToken) formData.append(csrfParam, csrfToken);
}
async function uploadFile(url, file) {
	const formData = new FormData();
	formData.append("file", file);
	appendCsrf(formData);
	return apiFetch(url, {
		method: "POST",
		body: formData,
		headers: { "X-Requested-With": "XMLHttpRequest" }
	});
}
//#endregion
export { uploadFile as n, apiFetch as t };
