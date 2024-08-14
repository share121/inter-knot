<template>
  <a target="_blank" :href="`https://discord.gg/Cx83Dw9X9E`" title="Discord">
    <img src="~/assets/svg/discord.svg" alt="" width="62px" />
  </a>
</template>

<script setup lang="ts">
const store = useConfigStore();
</script>

<style scoped lang="less">
@media (max-width: 470px) {
  a {
    display: none;
  }
}
</style>
