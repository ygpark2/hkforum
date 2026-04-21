import { j as writable } from "./dev.js";
import "./index-server2.js";
//#region src/lib/stores/bootstrap.js
var bootstrap = writable({
	ready: false,
	loading: true,
	site: null,
	auth: null,
	viewer: null,
	boards: [],
	suggestedUsers: [],
	sidebarAds: [],
	unreadNotificationCount: 0,
	companyCategories: []
});
//#endregion
export { bootstrap as t };
