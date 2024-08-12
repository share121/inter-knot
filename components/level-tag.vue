<template>
  <span class="identity-tag"> Lv{{ author?.repositoriesCount ?? 0 }} </span>
</template>

<script setup lang="ts">
const props = defineProps<{
  author: Actor | undefined;
}>();
const { author } = toRefs(props);

watch(author, async () => {
  if (author.value === undefined) return;
  if (typeof author.value.repositoriesCount === "number") return;
  try {
    author.value.repositoriesCount = await getRepositoriesCount(
      author.value.login
    );
  } catch (e) {
    console.error(e);
    useNuxtApp().$toast.error("获取用户等级失败");
  }
});

onMounted(async () => {
  if (author.value === undefined) return;
  if (typeof author.value.repositoriesCount === "number") return;
  try {
    author.value.repositoriesCount = await getRepositoriesCount(
      author.value.login
    );
  } catch (e) {
    console.error(e);
    useNuxtApp().$toast.error("获取用户等级失败");
  }
});
</script>

<style scoped lang="less">
.identity-tag {
  display: inline-block;
  color: #070707;
  background: #60605e;
  padding: 2px 8px;
  font-size: 12px;
  border-radius: @max-radius;
  margin-right: 8px;
  margin-left: 8px;
  vertical-align: top;
}
</style>
