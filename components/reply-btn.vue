<template>
  <a class="reply" :href="props.url + '#new_comment_form'" target="_blank">
    <svg
      xmlns="http://www.w3.org/2000/svg"
      width="32"
      height="32"
      viewBox="0 0 24 24"
    >
      <path
        fill="currentColor"
        d="M9.243 18.997H21v2H3v-4.243l9.9-9.9l4.242 4.243zm5.07-13.557l2.122-2.121a1 1 0 0 1 1.414 0l2.829 2.828a1 1 0 0 1 0 1.415l-2.122 2.121z"
      ></path>
    </svg>
    写回复
  </a>
</template>

<script lang="ts" setup>
const props = defineProps<{
  url: string;
}>();
</script>

<style scoped lang="less">
.reply {
  color: unset;
  text-decoration: none;
  padding: 8px;
  background: #222;
  border-radius: @max-radius;
  color: #fff;
  border: solid 4px #2d2d2d;
  display: flex;
  justify-content: center;
  align-items: center;
  flex: 1;

  svg {
    height: 24px;
    width: 24px;
  }
}
</style>
