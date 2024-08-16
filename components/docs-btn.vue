<template>
  <a
    href="http://docs.绳网.top"
    target="_blank"
    rel="noopener noreferrer"
    title="文档"
  >
    <img src="~/assets/svg/docs.svg" alt="" width="62px" />
  </a>
</template>

<script setup lang="ts">
const store = useConfigStore();
</script>

<style scoped lang="less">
@media (max-width: 1300px) {
  img {
    width: 52px;
    height: 52px;
  }
}
@media (max-width: 470px) {
  a {
    display: none;
  }
}
</style>
