export const useConfigStore = defineStore("config", () => {
  const author = ref<Actor>();
  const data = ref<Article[]>([]);
  const hasNextPage = ref(true);
  const endCursor = ref<string | null>(null);
  return {
    author,
    data,
    hasNextPage,
    endCursor,
  };
});
