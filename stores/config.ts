export const useConfigStore = defineStore("config", () => {
  const author = ref<Actor>();
  const data = ref<Article[]>([]);
  const hasNextPage = ref(true);
  return {
    author,
    data,
    hasNextPage,
  };
});
