<template>
  <svg
    xmlns="http://www.w3.org/2000/svg"
    viewBox="0 0 24 24"
    fill="currentColor"
    @click="show = true"
  >
    <title>删除帖子</title>
    <path
      fill="currentColor"
      d="M7 21q-.825 0-1.412-.587T5 19V6H4V4h5V3h6v1h5v2h-1v13q0 .825-.587 1.413T17 21zM17 6H7v13h10zM9 17h2V8H9zm4 0h2V8h-2zM7 6v13z"
    />
  </svg>
  <popup-input-box
    :show="show"
    @close="show = false"
    @cancel="show = false"
    @submit="reportArticle"
    v-model="text"
    title="确定删除"
    placeholder="请输入 yes 删除"
    :disabled="text !== 'yes'"
  />
</template>

<script lang="ts" setup>
const props = defineProps<{
  article: Article;
}>();

const show = ref(false);

const text = ref("");

let flag = false;
async function reportArticle() {
  show.value = false;
  if (flag) return;
  flag = true;
  try {
    deleteDiscussion(props.article.id);
    useNuxtApp().$toast.success("删除成功");
  } catch (e) {
    console.error(e);
    useNuxtApp().$toast.error("删除失败");
  }
  flag = false;
}
</script>

<style scoped lang="less">
svg {
  width: 36px;
  height: 36px;
  cursor: pointer;
}
</style>
