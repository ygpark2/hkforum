import "../../../chunks/dev.js";
import { t as ChatsPage } from "../../../chunks/ChatsPage.js";
//#region src/routes/chats/+page.svelte
function _page($$renderer) {
	ChatsPage($$renderer, {});
}
//#endregion
export { _page as default };
