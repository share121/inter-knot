<template>
  <NuxtPwaManifest />
  <header-bar />
  <main-container />
  <write-btn />
  <refresh-btn @refresh="refresh" />
</template>

<script setup lang="ts">
const config = useRuntimeConfig();
const store = useConfigStore();

async function refresh() {
  console.log("refresh");
  store.data.length = 0;
  document.documentElement.scrollTop = 0;
  const res = await getDiscussions(null);
  store.hasNextPage = res.hasNextPage;
  store.endCursor = res.endCursor;
  store.data.push(...res.discussions);
  removeDuplicateArticle(store.data);
}
</script>
