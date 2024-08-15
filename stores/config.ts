export const useConfigStore = defineStore("config", () => {
  const author = ref<Actor>();
  const data = ref<Article[]>([]);
  const reports = ref<Record<number, string[]>>({});
  const hasNextPage = ref(true);
  const collaborators = ["VacuolePaoo"];
  const owner = "share121";
  const reportNumber = 1685;
  return {
    author,
    data,
    hasNextPage,
    collaborators,
    owner,
    reportNumber,
    reports,
  };
});
