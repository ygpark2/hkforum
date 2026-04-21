import adapter from '@sveltejs/adapter-static';

const config = {
  kit: {
    adapter: adapter({
      pages: '../static/app',
      assets: '../static/app',
      fallback: 'app.html'
    }),
    prerender: {
      entries: ['/'],
      crawl: false,
      handleHttpError: 'warn',
      handleUnseenRoutes: 'ignore'
    }
  }
};

export default config;
