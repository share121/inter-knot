<template>
  <NuxtPwaManifest />
  <header-bar />
  <main-container />
  <write-btn />
  <refresh-btn @refresh="refresh" />
</template>

<script setup lang="ts">
const store = useConfigStore();

async function refresh() {
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
}
</script>
