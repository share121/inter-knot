// https://nuxt.com/docs/api/configuration/nuxt-config
export default defineNuxtConfig({
  compatibilityDate: "2024-04-03",
  devtools: { enabled: true },

  devServer: {
    port: 5173,
  },

  nitro: {
    compressPublicAssets: true,
  },

  postcss: {
    plugins: {
      "postcss-preset-env": {},
    },
  },

  vite: {
    esbuild: {
      drop: ["debugger", "console"],
    },
    css: {
      preprocessorOptions: {
        less: {
          additionalData: '@import "~/assets/css/common.less";',
        },
      },
    },
  },

  app: {
    baseURL: "/inter-knot/",
    head: {
      title: "绳网",
      meta: [
        {
          name: "description",
          content: "欢迎来到绳网",
        },
        {
          name: "keywords",
          content: "绳网,Inter-Knot,zzz,绝区零,Zenless Zone Zero",
        },
      ],
      script: [
        {
          src: "/inter-knot/plugins/js-sdk-pro.min.js",
          id: "LA_COLLECT",
          defer: true,
        },
      ],
      link: [
        {
          rel: "icon",
          type: "image/svg+xml",
          href: "/inter-knot/icon.svg",
        },
      ],
    },
  },

  css: ["~/assets/css/main.less"],
  modules: ["@vite-pwa/nuxt", "@vueuse/nuxt"],
});
