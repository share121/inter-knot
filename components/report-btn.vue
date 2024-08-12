<template>
  <a
    target="_blank"
    :href="`https://github.com/${store.owner}/inter-knot/discussions/1685#new_comment_form`"
    title="举报"
  >
    <img src="~/assets/svg/report.svg" alt="" width="62px" />
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

svg {
  height: 36px;
  width: 36px;
  color: #ab7373;
}
</style>
