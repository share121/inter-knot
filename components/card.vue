<template>
  <div class="card" :class="{ 'is-pinned': article.isPinned }">
    <div class="cover-container">
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
      <div class="comments-count">
        <comments-icon />
        {{ article.commentsCount }}
      </div>
    </div>
    <div class="info-container">
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
    </div>
  </div>
</template>

<script lang="ts" setup>
import defaultCover from "~/assets/svg/default-cover.svg?url";

const props = defineProps<{ article: Article }>();
const { article } = toRefs(props);

const emits = defineEmits(["resize"]);

const isCoverErr = ref(false);
const isCoverLoaded = ref(false);
const cover = ref<HTMLImageElement | undefined>();

const { height } = useElementSize(cover);
watch(height, () => emits("resize"));
</script>

<style scoped lang="less">
.card {
  display: flex;
  flex-direction: column;
  border: solid 4px #000;
  border-radius: 20px 20px 0 20px;
  background: #222;
  overflow: hidden;
  cursor: pointer;
  transition: border-color 0.3s ease;
  position: relative;

  &.is-pinned {
    border-color: #00aaff;

    &::after {
      color: #fff;
      position: absolute;
      content: "置顶";
      right: 16px;
      top: 8px;
      mix-blend-mode: difference;
    }
  }

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
      max-height: 600px;
      object-fit: cover;
    }

    .comments-count {
      display: flex;
      position: absolute;
      top: 8px;
      left: 16px;
      align-items: center;
      gap: 4px;
      font-weight: bold;
      mix-blend-mode: difference;

      svg {
        width: 24px;
        height: 24px;
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
      line-clamp: 2;
      -webkit-box-orient: vertical;
      overflow: hidden;
      margin-top: 4px;
      font-size: 18px;
      font-weight: bold;
    }

    .content {
      display: -webkit-box;
      -webkit-line-clamp: 2;
      line-clamp: 2;
      -webkit-box-orient: vertical;
      overflow: hidden;
      margin-top: 4px;
      font-size: 14px;
      color: #b3b3b1;
    }
  }
}
</style>
