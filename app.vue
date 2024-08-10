<template>
  <NuxtPwaManifest />
  <header-bar />
  <main-container />
  <write-btn />
</template>

<script setup lang="ts">
onMounted(() => {
  // @ts-ignore
  LA.init({
    id: "3J6dEY8wQU3ZxACy",
    ck: "3J6dEY8wQU3ZxACy",
    autoTrack: true,
    prefix: "inter-knot/event",
  });
});
</script>
