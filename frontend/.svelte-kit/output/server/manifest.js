export const manifest = (() => {
function __memo(fn) {
	let value;
	return () => value ??= (value = fn());
}

return {
	appDir: "_app",
	appPath: "_app",
	assets: new Set([]),
	mimeTypes: {},
	_: {
		client: {start:"_app/immutable/entry/start.BSZl8KEe.js",app:"_app/immutable/entry/app.M9fRX3d8.js",imports:["_app/immutable/entry/start.BSZl8KEe.js","_app/immutable/chunks/DfbjyjsO.js","_app/immutable/chunks/DdSGHZTi.js","_app/immutable/chunks/DbnfyUES.js","_app/immutable/entry/app.M9fRX3d8.js","_app/immutable/chunks/DdSGHZTi.js","_app/immutable/chunks/CItELRlb.js","_app/immutable/chunks/CuyqONxg.js"],stylesheets:[],fonts:[],uses_env_dynamic_public:false},
		nodes: [
			__memo(() => import('./nodes/0.js')),
			__memo(() => import('./nodes/1.js'))
		],
		remotes: {
			
		},
		routes: [
			
		],
		prerendered_routes: new Set(["/"]),
		matchers: async () => {
			
			return {  };
		},
		server_assets: {}
	}
}
})();
