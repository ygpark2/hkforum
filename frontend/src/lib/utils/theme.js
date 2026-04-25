export const THEME_STORAGE_KEY = 'hkforum-theme';
export const DEFAULT_THEME = 'forum';

export const THEMES = [
  {
    key: 'forum',
    label: 'Forum',
    description: 'Clean neutral surfaces with strong contrast.',
    preview: ['#f8fafc', '#ffffff', '#0f172a']
  },
  {
    key: 'forest',
    label: 'Forest',
    description: 'Warm paper surfaces with a moss-green accent.',
    preview: ['#f4efe2', '#fffaf0', '#2d5a45']
  },
  {
    key: 'midnight',
    label: 'Midnight',
    description: 'Dark navy panels with cool high-contrast text.',
    preview: ['#0f172a', '#162033', '#8fb7ff']
  }
];

const THEME_KEYS = new Set(THEMES.map((theme) => theme.key));

export function normalizeTheme(theme) {
  return THEME_KEYS.has(theme) ? theme : DEFAULT_THEME;
}

export function isDarkTheme(theme) {
  return normalizeTheme(theme) === 'midnight';
}

export function getStoredTheme() {
  if (typeof window === 'undefined') return DEFAULT_THEME;
  try {
    return normalizeTheme(window.localStorage.getItem(THEME_STORAGE_KEY));
  } catch (_error) {
    return DEFAULT_THEME;
  }
}

export function applyTheme(theme) {
  if (typeof document === 'undefined') return normalizeTheme(theme);
  const resolvedTheme = normalizeTheme(theme);
  document.documentElement.dataset.theme = resolvedTheme;
  document.documentElement.style.colorScheme = isDarkTheme(resolvedTheme) ? 'dark' : 'light';
  return resolvedTheme;
}

export function persistTheme(theme) {
  if (typeof window === 'undefined') return normalizeTheme(theme);
  const resolvedTheme = normalizeTheme(theme);
  try {
    window.localStorage.setItem(THEME_STORAGE_KEY, resolvedTheme);
  } catch (_error) {
    return resolvedTheme;
  }
  return resolvedTheme;
}

export function syncTheme(theme) {
  const resolvedTheme = applyTheme(theme);
  persistTheme(resolvedTheme);
  return resolvedTheme;
}
