<template>
  <header>
    <user-info :curExp="6380" :totalExp="10000" />
    <tab-container />
    <github-btn />
  </header>
</template>

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
}
</style>
