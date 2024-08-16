<template>
  <header>
    <user-info :curExp="6380" :totalExp="10000" />
    <tab-container v-model="tab" />
    <github-btn />
    <discord-btn />
    <docs-btn />
    <popup-input-box
      :show="show"
      @close="(show = false), (tab = old)"
      @cancel="(show = false), (tab = old)"
      @submit="submitSearch"
      title="搜索"
      placeholder="请输入搜索内容"
      :disabled="text.length === 0"
      v-model="text"
    />
  </header>
</template>

<script setup lang="ts">
const store = useConfigStore();
const show = ref(false);
const text = ref("");
const tab = ref(0);
const old = ref(0);
watch(tab, async (tab, oldVal) => {
  old.value = oldVal;
  if (tab === 0) {
    try {
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
  } else if (tab === 2) {
    show.value = true;
  }
});
async function submitSearch() {
  show.value = false;
  store.data.length = 0;
  document.documentElement.scrollTop = 0;
  try {
    const res = await search(text.value, null);
    let hasNextPage = res.hasNextPage;
    let endCursor = res.endCursor;
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
      if (hasNextPage === false) break;
      const res = await search(text.value, endCursor);
      hasNextPage = res.hasNextPage;
      endCursor = res.endCursor;
      store.data.push(...res.discussions);
      removeDuplicateArticle(store.data);
    }
  } catch (e) {
    console.error(e);
    useNuxtApp().$toast.error("搜索失败");
  }
}
</script>

<style scoped lang="less">
header {
  z-index: 5;
  position: fixed;
  top: 0;
  left: 0;
  right: 0;
  display: flex;
  padding: 22px 68px;
  height: 100px;
  background: #000;
  align-items: center;
  gap: 16px;

  @media (max-width: 1300px) {
    & {
      padding: 12px 24px;
      height: 80px;
    }
  }
  @media (max-width: 470px) {
    & {
      justify-content: center;
    }
  }
}
</style>
