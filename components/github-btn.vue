<template>
  <a
    target="_blank"
    :href="`https://github.com/${store.owner}/inter-knot`"
    title="GitHub"
  >
    <img src="~/assets/svg/github.svg" alt="" width="62px" />
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
@media (max-width: 986px) {
  a {
    margin-left: auto;
  }
}

@media (max-width: 470px) {
  a {
    display: none;
  }
}
</style>
