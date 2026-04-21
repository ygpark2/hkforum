

export const index = 0;
let component_cache;
export const component = async () => component_cache ??= (await import('../entries/pages/_layout.svelte.js')).default;
export const universal = {
  "ssr": false,
  "prerender": true
};
export const universal_id = "src/routes/+layout.js";
export const imports = ["_app/immutable/nodes/0.dnQPLXeh.js","_app/immutable/chunks/DdSGHZTi.js","_app/immutable/chunks/0ZFPsTf4.js","_app/immutable/chunks/DbnfyUES.js","_app/immutable/chunks/C9fgg_jh.js","_app/immutable/chunks/CjMuXmxc.js","_app/immutable/chunks/CuyqONxg.js","_app/immutable/chunks/P7zVOZyv.js","_app/immutable/chunks/B05vM52L.js","_app/immutable/chunks/0YTdTIZv.js","_app/immutable/chunks/C3ucOgke.js"];
export const stylesheets = [];
export const fonts = [];
