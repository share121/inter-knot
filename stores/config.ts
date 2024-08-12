export const useConfigStore = defineStore("config", () => {
  const author = ref<Actor>();
  const data = ref<Article[]>([]);
  const hasNextPage = ref(true);
  const collaborators = ["VacuolePaoo"];
  const owner = "share121";
  return {
    author,
    data,
    hasNextPage,
    collaborators,
    owner,
  };
});
