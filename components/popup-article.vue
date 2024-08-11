<template>
  <Teleport to="body">
    <div
      class="popup-container"
      :class="{
        open: show,
        closed: !show,
      }"
      @click.self="$emit('close')"
    >
      <div class="popup">
        <header>
          <a target="_blank" :href="article?.author.url ?? '#'">
            <img
              class="profile-photo"
              :src="article?.author.avatarUrl ?? defaultAvatarUrl"
              alt="头像"
              loading="lazy"
            />
          </a>
          <div>
            <a target="_blank" :href="article?.author.url ?? '#'">
              {{ article?.author.login ?? "佚名" }}
              <span
                class="identity-tag"
                v-if="article?.author.login === 'share121'"
              >
                绳网创始人
              </span>
              <span
                class="identity-tag"
                v-else-if="article?.author.login === 'VacuolePaoo'"
              >
                绳网管理员
              </span>
            </a>
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
              114514
            </div>
          </div>
          <close-btn @click="$emit('close')" />
        </header>
        <main>
          <div class="cover">
            <img
              :src="cover"
              alt="封面"
              loading="lazy"
              @error="isCoverErr = true"
            />
          </div>
          <div class="content" ref="content">
            <div class="title">{{ article?.title ?? "未知" }}</div>
            <div
              class="text markdown-body"
              v-html="article?.bodyHTML ?? '空'"
            ></div>
            <reply-btn v-if="article?.url" :url="article?.url" />
            <div class="comments">
              <section
                class="comment"
                v-for="comment of article?.comments ?? []"
              >
                <a target="_blank" :href="comment.author.url">
                  <img
                    class="profile-photo"
                    :src="comment.author.avatarUrl"
                    alt="头像"
                    loading="lazy"
                  />
                </a>
                <div>
                  <div class="name">
                    <a target="_blank" :href="comment.author.url">
                      {{ comment.author.login }}
                      <span
                        v-if="comment?.author.login === store.author?.login"
                        class="identity-tag"
                      >
                        自己
                      </span>
                      <span
                        v-else-if="
                          comment.author.login === article?.author.login
                        "
                        class="identity-tag"
                      >
                        楼主
                      </span>
                      <span
                        class="identity-tag"
                        v-if="comment?.author.login === 'share121'"
                      >
                        绳网创始人
                      </span>
                      <span
                        class="identity-tag"
                        v-else-if="comment?.author.login === 'VacuolePaoo'"
                      >
                        绳网管理员
                      </span>
                    </a>
                  </div>
                  <div
                    class="text markdown-body"
                    v-html="comment.bodyHTML"
                  ></div>
                </div>
              </section>
            </div>
          </div>
        </main>
      </div>
    </div>
  </Teleport>
</template>

<script lang="ts" setup>
import defaultAvatarUrl from "~/assets/svg/profile-photo.svg?url";
import defaultCover from "~/assets/svg/default-cover.svg?url";

const props = defineProps<{
  show: boolean;
  article?: Article;
}>();
defineEmits(["close"]);

const { show, article } = toRefs(props);
const store = useConfigStore();

const content = ref<HTMLDivElement>();

const isLocked = useScrollLock(window);
watch(show, (show) => {
  isLocked.value = show;
});

useInfiniteScroll(
  content,
  async () => {
    if (show.value === false) return;
    if (!article.value) return;
    if (article.value.hasNextPage) {
      console.log("my");
      const res = await getComments(
        article.value.number,
        article.value.endCursor
      );
      article.value.comments.push(...res.comments);
      article.value.hasNextPage = res.hasNextPage;
      article.value.endCursor = res.endCursor;
    }
  },
  { distance: 1000 }
);

watch(article, async () => {
  isCoverErr.value = false;
});
const isCoverErr = ref(false);
const cover = computed(() =>
  isCoverErr.value ? defaultCover : article.value?.cover ?? defaultCover
);
</script>

<style scoped lang="less">
.identity-tag {
  color: #ffa500;
}

.popup-container {
  position: fixed;
  inset: 0;
  background: url("~/assets/svg/bg-point-tab.svg") 0 0 / 7px, rgba(0, 0, 0, 0.5);
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
    height: 90%;
    width: 80%;
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
      color: #808080;
      align-items: center;
      font-weight: bold;

      .profile-photo {
        border-radius: 50%;
        border: solid 2px #000;
        outline: 3px solid #2d2d2d;
        height: 40px;
        width: 40px;
        background: #121212;
      }

      .visited {
        display: flex;
        align-items: center;
        font-size: 12px;
        gap: 4px;

        svg {
          height: 18px;
          width: 18px;
        }
      }
    }

    main {
      display: flex;
      height: 100%;
      padding: 24px;
      background: #121212;
      gap: 24px;
      overflow: hidden;

      .cover {
        height: 100%;
        flex: 4;
        border-radius: 15px;
        border: solid 4px #313132;
        overflow: hidden;

        img {
          width: 100%;
          height: 100%;
          object-fit: contain;
        }
      }

      .content {
        flex: 6;
        height: 100%;
        overflow: auto;
        color: #acacac;
        background: #070707;
        padding: 24px;
        border-radius: 15px;

        .title {
          color: #ededed;
          font-size: 18px;
          margin-bottom: 16px;
          font-weight: bold;
        }

        .text {
          :deep(> :first-child) {
            margin-top: 0 !important;
          }

          :deep(> :last-child) {
            margin-bottom: 0 !important;
          }

          :deep(img) {
            width: 100% !important;
          }

          :depp(video) {
            width: 100% !important;
          }
        }

        .comments {
          counter-reset: floor;

          .comment {
            display: flex;
            margin-top: 12px;
            counter-increment: floor;

            > div {
              flex: 1;
              overflow: hidden;
            }

            &::after {
              margin-left: 8px;
              margin-top: 4px;
              content: counter(floor) "F";
              color: #070707;
              background: #60605e;
              padding: 2px 8px;
              border-radius: 0 @max-radius @max-radius @max-radius;
              height: fit-content;
              font-size: 12px;
            }

            .profile-photo {
              width: 40px;
              height: 40px;
              border-radius: 50%;
              border: solid 2px #000;
              outline: 3px solid #2d2d2d;
              margin-left: 3px;
              margin-right: 8px;
              background: #121212;
            }

            .name {
              color: #cccccc;
              margin-bottom: 8px;
            }

            .text {
              color: #888888;
            }
          }
        }
      }
    }
  }
}
</style>
