import { writable } from 'svelte/store';

export const bootstrap = writable({
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
