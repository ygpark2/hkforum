import "../../../chunks/dev.js";
import { t as SettingsPage } from "../../../chunks/SettingsPage.js";
//#region src/routes/settings/+page.svelte
function _page($$renderer) {
	SettingsPage($$renderer, {});
}
//#endregion
export { _page as default };
