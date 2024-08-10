<template>
  <div class="card-wrapper">
    <div class="card">
      <section class="cover-container">
        <div class="cover-wrapper">
          <img
            class="cover"
            alt="封面"
            :src="isCoverErr ? defaultCover : article.cover"
            loading="lazy"
            :style="{
              height: isCoverLoaded || isCoverErr ? 'unset' : '200px',
            }"
            @error="isCoverErr = true"
            @load="isCoverLoaded = true"
            ref="cover"
          />
        </div>
        <div class="visited">
          <svg
            xmlns="http://www.w3.org/2000/svg"
            width="32"
            height="32"
            viewBox="0 0 24 24"
          >
            <path
              fill="currentColor"
              d="M1.182 12C2.122 6.88 6.608 3 12 3s9.878 3.88 10.819 9c-.94 5.12-5.427 9-10.819 9s-9.878-3.88-10.818-9M12 17a5 5 0 1 0 0-10a5 5 0 0 0 0 10m0-2a3 3 0 1 1 0-6a3 3 0 0 1 0 6"
            ></path>
          </svg>
          977
        </div>
      </section>
      <section class="info-container">
        <div class="profile">
          <img
            class="profile-photo"
            :src="article.author.avatarUrl"
            alt="头像"
            loading="lazy"
          />
          <div class="username">{{ article.author.login }}</div>
        </div>
        <div class="title">{{ article.title }}</div>
        <div class="content">{{ article.bodyText }}</div>
      </section>
    </div>
  </div>
</template>

<script lang="ts" setup>
import defaultCover from "~/assets/svg/default-cover.svg?url";

const props = defineProps<{ article: Article }>();
const emits = defineEmits(["resize"]);
const { article } = toRefs(props);
const isCoverErr = ref(false);
const isCoverLoaded = ref(false);
const cover = ref<HTMLImageElement | undefined>();
const { width, height } = useElementSize(cover);
watch(
  () => [width.value, height.value],
  () => {
    emits("resize");
  }
);
</script>

<style scoped lang="less">
.card-wrapper {
  padding: 4px;

  .card {
    display: flex;
    flex-direction: column;
    border: solid 4px #000;
    border-radius: 20px 20px 0 20px;
    background: #222222;
    overflow: hidden;
    cursor: pointer;
    transition: border-color 0.3s ease;

    &:hover {
      border-color: #fbfe00;
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

    .cover-container {
      position: relative;

      .cover {
        width: 100%;
      }

      .visited {
        display: flex;
        position: absolute;
        top: 8px;
        left: 16px;
        align-items: center;
        gap: 4px;
        font-weight: bold;

        svg {
          width: 28px;
          height: 28px;
        }
      }
    }

    .info-container {
      padding: 16px;
      padding-top: 4px;

      .profile {
        display: flex;
        gap: 4px;

        .profile-photo {
          margin-left: -8px;
          margin-top: -31px;
          width: 54px !important;
          height: 54px !important;
          border-radius: 50%;
          border: solid 4px #222222;
          z-index: 1;
          background: #121212;
        }

        .username {
          flex: 1;
          color: #626262;
          padding-bottom: 2px;
          border-bottom: solid 2px #626262;
          white-space: nowrap;
          overflow: hidden;
          text-overflow: ellipsis;
          font-weight: bold;
        }
      }

      .title {
        display: -webkit-box;
        -webkit-line-clamp: 2;
        -webkit-box-orient: vertical;
        overflow: hidden;
        margin-top: 4px;
        font-size: 18px;
        font-weight: bold;
      }

      .content {
        display: -webkit-box;
        -webkit-line-clamp: 2;
        -webkit-box-orient: vertical;
        overflow: hidden;
        margin-top: 4px;
        font-size: 14px;
        color: #b3b3b1;
      }
    }
  }
}
</style>
