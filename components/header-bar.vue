<template>
  <header>
    <user-info :curExp="6380" :totalExp="10000" />
    <tab-container v-model="tab" />
    <github-btn title="Github" />
    <report-btn title="举报" />
    <popup-input-box
      :show="show"
      @close="(show = false), (tab = old)"
      @cancel="(show = false), (tab = old)"
      @submit="(show = false), (tab = old)"
      title="搜索"
      placeholder="请输入搜索内容"
      :disabled="text.length === 0"
      v-model="text"
    />
  </header>
</template>

<script setup lang="ts">
const show = ref(false);
const text = ref("");
const tab = ref(0);
const old = ref(0);
watch(tab, (tab, oldVal) => {
  old.value = oldVal;
  if (tab === 2) {
    show.value = true;
  }
});
</script>

<style scoped lang="less">
header {
  z-index: 5;
  position: fixed;
  top: 0;
  left: 0;
  right: 0;
  display: flex;
  padding: 22px 68px;
  height: 100px;
  background: #000;
  align-items: center;
  gap: 16px;

  @media (max-width: 1150px) {
    & {
      padding: 12px 24px;
      height: 80px;
    }
  }
  @media (max-width: 470px) {
    & {
      justify-content: center;
    }
  }
}
</style>
