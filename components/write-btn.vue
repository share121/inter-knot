<template>
  <Teleport to="body">
    <a
      class="write"
      target="_blank"
      title="写文章"
      :href="`https://github.com/${store.owner}/inter-knot/discussions/new?category=general`"
    >
      <svg
        xmlns="http://www.w3.org/2000/svg"
        width="32"
        height="32"
        viewBox="0 0 24 24"
      >
        <path
          fill="currentColor"
          d="M9.243 18.997H21v2H3v-4.243l9.9-9.9l4.242 4.243zm5.07-13.557l2.122-2.121a1 1 0 0 1 1.414 0l2.829 2.828a1 1 0 0 1 0 1.415l-2.122 2.121z"
        />
      </svg>
    </a>
  </Teleport>
</template>

<script setup lang="ts">
const store = useConfigStore();
</script>

<style scoped lang="less">
.write {
  position: fixed;
  bottom: 40px;
  right: 40px;
  color: unset;
  background: #222222;
  border-radius: 50%;
  width: 48px;
  height: 48px;
  box-shadow: inset 0 2px 2px #313431, inset 0 -2px 2px #181818,
    0 2px 20px #313431;
  z-index: 50;
  display: flex;
  justify-content: center;
  align-items: center;
  padding: 10px;
}
</style>
