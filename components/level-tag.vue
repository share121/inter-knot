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
  author.value.repositoriesCount = await getRepositoriesCount(
    author.value.login
  );
});

onMounted(async () => {
  if (author.value === undefined) return;
  if (typeof author.value.repositoriesCount === "number") return;
  author.value.repositoriesCount = await getRepositoriesCount(
    author.value.login
  );
});
</script>
