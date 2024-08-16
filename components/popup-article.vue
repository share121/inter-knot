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
              {{ article?.author.login ?? "传奇绳匠" }}
              <level-tag :author="article?.author" />
              <span
                class="identity-tag"
                v-if="article?.author.login === store.owner"
              >
                绳网创始人
              </span>
              <span
                class="identity-tag"
                v-else-if="
                  store.collaborators.includes(article?.author.login ?? '')
                "
              >
                绳网管理员
              </span>
            </a>
            <div class="comments-count">
              <svg
                xmlns="http://www.w3.org/2000/svg"
                width="32"
                height="32"
                viewBox="0 0 24 24"
              >
                <path
                  fill="currentColor"
                  d="M9 22a1 1 0 0 1-1-1v-3H4a2 2 0 0 1-2-2V4a2 2 0 0 1 2-2h16a2 2 0 0 1 2 2v12a2 2 0 0 1-2 2h-6.1l-3.7 3.71c-.2.19-.45.29-.7.29zm1-6v3.08L13.08 16H20V4H4v12zm7-5h-2V9h2zm-4 0h-2V9h2zm-4 0H7V9h2z"
                />
              </svg>
              {{ article?.commentsCount ?? 0 }}
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
            <p v-if="article">
              <div>
                发布时间：{{ new Date(article.createdAt).toLocaleString() }}
              </div>
              <div v-if="article.lastEditedAt">
                更新时间：{{ new Date(article.lastEditedAt).toLocaleString() }}
              </div>
            </p>
            <div
              class="text markdown-body"
              v-html="article?.bodyHTML ?? '空'"
            ></div>
            <div class="action" v-if="article">
              <reply-btn :url="article?.url" />
              <report-article-btn
                v-if="
                  ![store.owner, ...store.collaborators].includes(
                    article.author.login
                  )
                "
                :article="article"
              />
              <rm-article-btn
                v-if="
                  store.author &&
                  [
                    store.owner,
                    ...store.collaborators,
                    article.author.login,
                  ].includes(store.author?.login)
                "
                :article="article"
              />
            </div>
            <div class="comments">
              <template v-for="comment of article?.comments ?? []">
                <section
                  class="comment"
                  v-if="
                    article?.number !== store.reportNumber ||
                    hasLink(comment.bodyHTML) && comment.bodyHTML.includes('违规原因')
                  "
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
                        <level-tag :author="comment.author" />
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
                          v-if="comment?.author.login === store.owner"
                        >
                          绳网创始人
                        </span>
                        <span
                          class="identity-tag"
                          v-else-if="
                            store.collaborators.includes(comment?.author.login)
                          "
                        >
                          绳网管理员
                        </span>
                      </a>
                    </div>
                    <div
                      class="text markdown-body"
                      v-html="comment.bodyHTML"
                    ></div>
                    <div class="replies">
                      <section class="reply" v-for="reply of comment.replies">
                        <a target="_blank" :href="reply.author.url">
                          <img
                            class="profile-photo"
                            :src="reply.author.avatarUrl"
                            alt="头像"
                            loading="lazy"
                          />
                        </a>
                        <div>
                          <div class="name">
                            <a target="_blank" :href="reply.author.url">
                              {{ reply.author.login }}
                              <level-tag :author="reply.author" />
                              <span
                                v-if="
                                  reply?.author.login === store.author?.login
                                "
                                class="identity-tag"
                              >
                                自己
                              </span>
                              <span
                                v-else-if="
                                  reply.author.login === article?.author.login
                                "
                                class="identity-tag"
                              >
                                楼主
                              </span>
                              <span
                                class="identity-tag"
                                v-if="reply?.author.login === store.owner"
                              >
                                绳网创始人
                              </span>
                              <span
                                class="identity-tag"
                                v-else-if="
                                  store.collaborators.includes(
                                    reply?.author.login
                                  )
                                "
                              >
                                绳网管理员
                              </span>
                            </a>
                          </div>
                          <div
                            class="text markdown-body"
                            v-html="reply.bodyHTML"
                          ></div>
                        </div>
                      </section>
                    </div>
                  </div>
                </section>
              </template>
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
const emit = defineEmits(["close"]);

const { show, article } = toRefs(props);
const store = useConfigStore();

const content = ref<HTMLDivElement>();

let firstLoad = false;

const isLocked = useScrollLock(window);
watch(show, async (show) => {
  isLocked.value = show;
  if (show) {
    window.addEventListener("keyup", onEsc);
  } else {
    window.removeEventListener("keyup", onEsc);
    if (content.value) {
      content.value
        .querySelectorAll<HTMLVideoElement | HTMLAudioElement>("video,audio")
        .forEach((e) => e.pause());
    }
  }
});

function onEsc(e: KeyboardEvent) {
  if (e.key === "Escape") {
    emit("close");
  }
  e.stopPropagation();
  e.stopImmediatePropagation();
}

useInfiniteScroll(
  content,
  async () => {
    if (firstLoad === false) return;
    if (show.value === false) return;
    if (!article.value) return;
    if (article.value.hasNextPage) {
      const art = article.value;
      try {
        const res = await getComments(art.number, art.endCursor);
        art.comments.push(...res.comments);
        art.hasNextPage = res.hasNextPage;
        art.endCursor = res.endCursor;
      } catch (e) {
        useNuxtApp().$toast.error("获取评论失败");
      }
    }
  },
  { distance: 1000 }
);

watch(article, async () => {
  isCoverErr.value = false;
  firstLoad = false;
  if (show.value === false) return;
  if (!article.value) return;
  if (article.value.hasNextPage) {
    const art = article.value;
    try {
      const res = await getComments(art.number, art.endCursor);
      art.comments.push(...res.comments);
      art.hasNextPage = res.hasNextPage;
      art.endCursor = res.endCursor;
    } catch (e) {
      useNuxtApp().$toast.error("获取评论失败");
    }
    firstLoad = true;
  }
});
const isCoverErr = ref(false);
const cover = computed<string>(() =>
  isCoverErr.value ? defaultCover : article.value?.cover ?? defaultCover
);

function hasLink(html: string) {
  return html2dom(html).content.querySelectorAll("a[href]").length > 0;
}
</script>

<style scoped lang="less">
img {
  transition: filter 0.5s;
}

@media (max-width: 992px) {
  .popup-container .popup {
    width: 99% !important;
    height: 99% !important;

    > main {
      padding: 24px 2px !important;
      flex-wrap: wrap !important;
      overflow-y: auto !important;

      > * {
        height: unset !important;
      }

      .cover {
        flex: 1 0 100% !important;
      }
    }
  }
}

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

  .identity-tag {
    display: inline-block;
    color: #070707;
    background: #60605e;
    padding: 2px 8px;
    font-size: 12px;
    border-radius: @max-radius;
    margin-right: 8px;
    margin-left: 8px;
    vertical-align: top;
  }

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

      .comments-count {
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

          :deep(video) {
            max-width: 100% !important;
          }

          :deep(.footnotes > ol) {
            margin: 8px;
          }
        }

        .action {
          display: flex;
          margin: 16px 0;
          gap: 8px;
          align-items: center;
        }

        .comments {
          counter-reset: floor;

          .comment {
            counter-increment: floor;

            &::after {
              content: counter(floor) "F";
            }
          }

          .replies {
            counter-reset: floor-reply;
            margin-right: 8px;

            .reply {
              counter-increment: floor-reply;

              &::after {
                content: counter(floor-reply) "F";
              }
            }
          }

          .comment,
          .reply {
            display: flex;
            margin-top: 12px;
            padding-bottom: 8px;
            border-bottom: solid 4px #1c1c1c;
            position: relative;

            &:last-child {
              border-bottom: none;
              padding-bottom: 0;
            }

            &::after {
              color: #070707;
              background: #60605e;
              padding: 2px 8px;
              border-radius: 0 @max-radius @max-radius @max-radius;
              height: fit-content;
              font-size: 12px;
              // 楼层号使用绝对定位以腾出更多空间给内容
              position: absolute;
              right: 0;
            }

            .email-hidden-toggle,
            .email-hidden-reply{
              display: none;
            }

            > div {
              flex: 1;
              overflow: hidden;
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
