<template>
  <header-bar />
  <main-container />
  <write-btn />
  <refresh-btn @refresh="refresh" />
</template>

<script lang="ts" setup>
const store = useConfigStore();

async function refresh() {
  try {
    console.log("refresh");
    store.data.length = 0;
    document.documentElement.scrollTop = 0;
    const res = await getAllDiscussions(true);
    store.hasNextPage = res.hasNextPage;
    store.data.push(...res.discussions);
    removeDuplicateArticle(store.data);
    while (
      document.documentElement.scrollHeight !==
      document.documentElement.clientHeight
    ) {
      await delay(100);
    }
    while (
      document.documentElement.scrollHeight <=
      document.documentElement.clientHeight
    ) {
      console.log("load");
      if (store.hasNextPage === false) break;
      const res = await getAllDiscussions();
      store.hasNextPage = res.hasNextPage;
      store.data.push(...res.discussions);
      removeDuplicateArticle(store.data);
    }
  } catch (e) {
    console.error(e);
    useNuxtApp().$toast.error("刷新失败");
  }
}
</script>
