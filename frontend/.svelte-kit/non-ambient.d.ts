
// this file is generated — do not edit it


declare module "svelte/elements" {
	export interface HTMLAttributes<T> {
		'data-sveltekit-keepfocus'?: true | '' | 'off' | undefined | null;
		'data-sveltekit-noscroll'?: true | '' | 'off' | undefined | null;
		'data-sveltekit-preload-code'?:
			| true
			| ''
			| 'eager'
			| 'viewport'
			| 'hover'
			| 'tap'
			| 'off'
			| undefined
			| null;
		'data-sveltekit-preload-data'?: true | '' | 'hover' | 'tap' | 'off' | undefined | null;
		'data-sveltekit-reload'?: true | '' | 'off' | undefined | null;
		'data-sveltekit-replacestate'?: true | '' | 'off' | undefined | null;
	}
}

export {};


declare module "$app/types" {
	type MatcherParam<M> = M extends (param : string) => param is (infer U extends string) ? U : string;

	export interface AppTypes {
		RouteId(): "/" | "/admin" | "/admin/[...segments]" | "/boards" | "/board" | "/board/[id]" | "/bookmarks" | "/chats" | "/chats/[...segments]" | "/companies" | "/home" | "/jobs" | "/login" | "/notifications" | "/post" | "/post/[id]" | "/profile" | "/register" | "/settings" | "/settings/[...segments]";
		RouteParams(): {
			"/admin/[...segments]": { segments: string };
			"/board/[id]": { id: string };
			"/chats/[...segments]": { segments: string };
			"/post/[id]": { id: string };
			"/settings/[...segments]": { segments: string }
		};
		LayoutParams(): {
			"/": { segments?: string; id?: string };
			"/admin": { segments?: string };
			"/admin/[...segments]": { segments: string };
			"/boards": Record<string, never>;
			"/board": { id?: string };
			"/board/[id]": { id: string };
			"/bookmarks": Record<string, never>;
			"/chats": { segments?: string };
			"/chats/[...segments]": { segments: string };
			"/companies": Record<string, never>;
			"/home": Record<string, never>;
			"/jobs": Record<string, never>;
			"/login": Record<string, never>;
			"/notifications": Record<string, never>;
			"/post": { id?: string };
			"/post/[id]": { id: string };
			"/profile": Record<string, never>;
			"/register": Record<string, never>;
			"/settings": { segments?: string };
			"/settings/[...segments]": { segments: string }
		};
		Pathname(): "/" | "/admin" | `/admin/${string}` & {} | "/boards" | `/board/${string}` & {} | "/bookmarks" | "/chats" | `/chats/${string}` & {} | "/companies" | "/home" | "/jobs" | "/login" | "/notifications" | `/post/${string}` & {} | "/profile" | "/register" | "/settings" | `/settings/${string}` & {};
		ResolvedPathname(): `${"" | `/${string}`}${ReturnType<AppTypes['Pathname']>}`;
		Asset(): string & {};
	}
}