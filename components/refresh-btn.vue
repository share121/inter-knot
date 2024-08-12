<template>
  <Teleport to="body">
    <div class="refresh" title="刷新" @click="$emit('refresh')">
      <svg
        xmlns="http://www.w3.org/2000/svg"
        width="32"
        height="32"
        viewBox="0 0 24 24"
      >
        <path
          fill="currentColor"
          d="M5.463 4.433A9.96 9.96 0 0 1 12 2c5.523 0 10 4.477 10 10c0 2.136-.67 4.116-1.81 5.74L17 12h3A8 8 0 0 0 6.46 6.228zm13.074 15.134A9.96 9.96 0 0 1 12 22C6.477 22 2 17.523 2 12c0-2.136.67-4.116 1.81-5.74L7 12H4a8 8 0 0 0 13.54 5.772z"
        />
      </svg>
    </div>
  </Teleport>
</template>

<script setup lang="ts">
defineEmits(["refresh"]);
const store = useConfigStore();
</script>

<style scoped lang="less">
.refresh {
  position: fixed;
  bottom: 100px;
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
  cursor: pointer;
}
</style>
