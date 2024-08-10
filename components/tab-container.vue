<template>
  <div class="tab-container">
    <div @click="index = 0" :class="{ active: index === 0 }" class="tab">
      <span>推送</span>
    </div>
    <div @click="index = 1" :class="{ active: index === 1 }" class="tab">
      <span>日程</span>
    </div>
    <div @click="index = 2" :class="{ active: index === 2 }" class="tab">
      <span>绳网等级</span>
    </div>
  </div>
</template>

<script setup lang="ts">
const index = ref(0);
</script>

<style scoped lang="less">
// 媒体查询
@media (max-width: 1150px) {
  .tab-container {
    display: none !important;
  }
}

.tab-container {
  display: flex;
  align-items: center;
  width: 500px;
  height: 100%;
  border-radius: @max-radius;
  border: solid 4px #313131;
  font-size: 24px;
  font-style: italic;
  line-height: 1;
  background: url("~/assets/svg/bg-point-tab.svg") 0 0 / 7px;
  margin-left: auto;

  .tab {
    display: flex;
    align-items: center;
    justify-content: center;
    height: 100%;
    flex: 1;
    user-select: none;
    cursor: pointer;

    & > span {
      z-index: 2;
    }

    &.active {
      position: relative;
      color: #000;

      &:nth-child(1) {
        &::before {
          content: "";
          position: absolute;
          inset: 0;
          left: 15px;
          right: 50px;
          border-radius: @max-radius;
        }
        &::after {
          content: "";
          position: absolute;
          inset: 0;
          left: 50px;
          right: 15px;
          border-radius: 16px;
          transform: skewX(-27deg);
        }
      }

      &:nth-child(2) {
        &::after {
          content: "";
          position: absolute;
          inset: 0;
          left: 30px;
          right: 30px;
          border-radius: 16px;
          transform: skewX(-27deg);
        }
      }

      &:nth-child(3) {
        &::before {
          content: "";
          position: absolute;
          inset: 0;
          left: 15px;
          right: 50px;
          border-radius: 16px;
          transform: skewX(-27deg);
        }
        &::after {
          content: "";
          position: absolute;
          inset: 0;
          left: 50px;
          right: 15px;
          border-radius: @max-radius;
        }
      }

      @keyframes tab-size {
        0% {
          scale: 1.3;
        }
        100% {
          scale: 1.5;
        }
      }
      @keyframes tab-color {
        0% {
          background: #fbfe00;
        }
        100% {
          background: #dcfe00;
        }
      }

      &::before,
      &::after {
        animation: tab-color 1s linear infinite alternate,
          tab-size 0.3s cubic-bezier(0.35, 0.7, 0, 0.8) infinite alternate;
      }
    }
  }
}
</style>
