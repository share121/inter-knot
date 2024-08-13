<template>
  <div class="go-top" @click="goTop" v-show="show">
    <svg
      t="1723520305414"
      class="icon"
      viewBox="0 0 1000 1000"
      version="1.1"
      xmlns="http://www.w3.org/2000/svg"
      p-id="3306"
      width="32"
      height="32"
    >
      <path
        d="M796.014 439.312l-257.492-257.492c-20.11-20.11-52.709-20.11-72.819 0l-257.492 257.492c-20.11 20.11-20.11 52.709 0 72.819s52.709 20.11 72.819 0l169.585-169.585v493.664c0 28.453 23.046 51.499 51.499 51.499s51.499-23.046 51.499-51.499v-493.664l169.585 169.585c10.042 10.043 23.226 15.089 36.41 15.089s26.367-5.021 36.41-15.089c20.11-20.11 20.11-52.709 0-72.819z"
        p-id="3307"
        fill="#ffffff"
      ></path>
    </svg>
  </div>
</template>

<script lang="ts" setup>
import { ref, watch, onMounted } from "vue";

const show = ref(false);

const goTop = () => {
  window.scrollTo({ top: 0, behavior: "smooth" });
};

const handleScroll = () => {
  const scrollDistance = window.scrollY;
  show.value = scrollDistance > 800;
};

onMounted(() => {
  window.addEventListener("scroll", handleScroll);
});
</script>

<style scoped lang="less">
.go-top {
  position: fixed;
  bottom: 160px;
  right: 40px;
  color: unset;
  background: #222222;
  border-radius: 50%;
  width: 48px;
  height: 48px;
  box-shadow:
    inset 0 2px 2px #313431,
    inset 0 -2px 2px #181818,
    0 2px 20px #313431;
  z-index: 50;
  display: flex;
  justify-content: center;
  align-items: center;
  padding: 10px;
  cursor: pointer;

  svg {
    height: 24px;
    width: 24px;
  }
}
</style>
