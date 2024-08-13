<template>
  <Teleport to="body">
    <div
      class="popup-container"
      @click.self="$emit('close')"
      :class="{
        open: show,
        closed: !show,
      }"
    >
      <div class="popup">
        <header>
          <div>{{ title }}</div>
          <close-btn @click="$emit('close')" />
        </header>
        <main>
          <div>
            <input :placeholder="placeholder" v-model="text" />
            <footer>
              <button @click="$emit('cancel')">取消</button>
              <button @click="$emit('submit')" :disabled="disabled">
                确定
              </button>
            </footer>
          </div>
        </main>
      </div>
    </div>
  </Teleport>
</template>

<script lang="ts" setup>
const props = defineProps<{
  show: boolean;
  title: string;
  modelValue: string;
  placeholder: string;
  disabled?: boolean;
}>();
const emit = defineEmits(["close", "cancel", "submit", "update:modelValue"]);

const { show, title, modelValue, placeholder } = toRefs(props);

const text = ref("");

watch(modelValue, (modelValue) => {
  text.value = modelValue;
});
watch(text, (text) => {
  emit("update:modelValue", text);
});

const isLocked = useScrollLock(window);
watch(show, async (show) => {
  isLocked.value = show;
  if (show) {
    window.addEventListener("keyup", onEsc);
  } else {
    window.removeEventListener("keyup", onEsc);
  }
});

function onEsc(e: KeyboardEvent) {
  if (e.key === "Escape") {
    emit("close");
  }
  e.stopPropagation();
  e.stopImmediatePropagation();
}
</script>

<style scoped lang="less">
.popup-container {
  position: fixed;
  inset: 0;
  background: url("~/assets/svg/bg-lines.svg") 0 0 / 5px, rgba(0, 0, 0, 0.6);
  display: flex;
  align-items: center;
  justify-content: center;
  z-index: 99;
  backdrop-filter: blur(10px);
  transition: opacity 0.3s ease, transform 0.3s ease;

  &.closed {
    opacity: 0;
    pointer-events: none;
    transform: translateX(20px);
  }

  .popup {
    display: flex;
    flex-direction: column;
    background: #000;
    height: 300px;
    width: 500px;
    border-radius: 20px 0 20px 20px;
    overflow: hidden;
    border: solid 4px #000;
    outline: solid 4px #cccccc33;

    header {
      background: url("~/assets/svg/bg-point-header.svg") 0 0 / 7px,
        linear-gradient(#161616, #080808);
      display: flex;
      padding: 8px 24px;
      gap: 12px;
      color: #c5c5c5;
      align-items: center;
      font-weight: bold;
      font-size: 20px;
    }

    main {
      display: flex;
      height: 100%;
      padding: 24px;
      background: #121212;
      gap: 24px;
      overflow: hidden;
      flex-direction: column;
      padding: 28px;

      div {
        width: 100%;
        height: 100%;
        background: #080808;
        border-radius: 16px;
        padding: 24px;
        padding-top: 48px;
        position: relative;

        input {
          width: 100%;
          border-radius: @max-radius;
          line-height: 2;
          text-align: center;
          background: #1c1c1c;
          outline: none;
          color: #fff;
          font-size: 20px;
          padding: 0 16px;
          border: solid 3px #fbfe00;
          animation: border-color 1s 0.3s linear infinite alternate;

          @keyframes border-color {
            0% {
              border-color: #fbfe00;
            }
            100% {
              border-color: #dcfe00;
            }
          }
        }

        footer {
          position: absolute;
          bottom: 0;
          left: 0;
          right: 0;
          display: flex;
          justify-content: space-evenly;
          transform: translateY(50%);

          button {
            color: unset;
            text-decoration: none;
            padding: 8px;
            background: #222;
            border-radius: @max-radius;
            color: #fefefe;
            font-weight: bold;
            border: solid 4px #2d2d2d;
            display: flex;
            justify-content: center;
            align-items: center;
            width: 170px;
            cursor: pointer;
            font-style: italic;

            &:disabled {
              color: #666666;
            }

            svg {
              height: 24px;
              width: 24px;
            }
          }
        }
      }
    }
  }
}
</style>
