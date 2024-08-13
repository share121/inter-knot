<template>
  <span class="identity-tag">Lv{{ author?.repositoriesCount ?? 0 }}</span>
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
