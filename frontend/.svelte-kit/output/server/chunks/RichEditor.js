import "./index-server.js";
import { U as attr, et as fallback, i as bind_props, r as attr_style } from "./dev.js";
import "./api.js";
//#endregion
//#region src/lib/components/RichEditor.svelte
function RichEditor($$renderer, $$props) {
	$$renderer.component(($$renderer) => {
		let value = fallback($$props["value"], "");
		let name = fallback($$props["name"], "content");
		let placeholder = fallback($$props["placeholder"], "Write here");
		let uploadUrl = fallback($$props["uploadUrl"], "/api/v1/uploads");
		let minHeight = fallback($$props["minHeight"], "220px");
		$$renderer.push("<!--[-1-->");
		$$renderer.push(`<input type="hidden"${attr("name", name)}${attr("value", value)}/> <div class="overflow-hidden rounded-2xl border border-slate-200"><div><span class="ql-formats"><select class="ql-header">`);
		$$renderer.option({ selected: true }, ($$renderer) => {});
		$$renderer.option({ value: "2" }, ($$renderer) => {});
		$$renderer.option({ value: "3" }, ($$renderer) => {});
		$$renderer.push(`</select> <select class="ql-align"></select></span> <span class="ql-formats"><button type="button" class="ql-bold" aria-label="Bold"></button> <button type="button" class="ql-italic" aria-label="Italic"></button> <button type="button" class="ql-underline" aria-label="Underline"></button></span> <span class="ql-formats"><button type="button" class="ql-list" value="ordered" aria-label="Ordered list"></button> <button type="button" class="ql-list" value="bullet" aria-label="Bullet list"></button> <button type="button" class="ql-blockquote" aria-label="Blockquote"></button> <button type="button" class="ql-link" aria-label="Link"></button> <button type="button" class="ql-image" aria-label="Image"></button></span></div> <div class="bg-white"${attr_style(`min-height:${minHeight}`)}></div></div>`);
		$$renderer.push(`<!--]-->`);
		bind_props($$props, {
			value,
			name,
			placeholder,
			uploadUrl,
			minHeight
		});
	});
}
//#endregion
export { RichEditor as t };
