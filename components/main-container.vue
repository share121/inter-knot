<template>
  <main>
    <div class="loading" v-if="isLoading">加载中……</div>
    <ClientOnly v-else>
      <Waterfall
        :list="list"
        background-color="transparent"
        :width="256"
        img-selector="img"
      >
        <template #item="{ item, url, index }">
          <Card
            :key="item.article.url"
            :article="item.article"
            @click="
              curArticle = item.article;
              showPopup = true;
            "
          />
        </template>
      </Waterfall>
    </ClientOnly>
    <Popup @close="showPopup = false" :show="showPopup" :article="curArticle" />
  </main>
</template>

<script setup lang="ts">
import { Waterfall } from "vue-waterfall-plugin-next";
import "vue-waterfall-plugin-next/dist/style.css";
import defaultCover from "~/assets/svg/default-cover.svg?url";

const isLoading = ref(true);
const showPopup = ref(false);
const curArticle = ref<Article>();
const data = ref<Article[]>([]);
const list = computed(() =>
  data.value.map((e) => ({
    src: e.cover,
    article: e,
  }))
);

onMounted(() => {
  tryGet(async (access_token) => {
    const res = await getDiscussions(access_token);
    data.value.push(
      ...res.map((e) => {
        const dom = html2dom(e.bodyHTML);
        const firstImg = dom.content?.querySelector("img");
        const cover = firstImg?.src ?? defaultCover;
        let parent = firstImg?.parentElement;
        firstImg?.remove();
        while (parent instanceof HTMLElement && parent.children.length == 0) {
          parent?.remove();
          parent = parent.parentElement;
        }
        return {
          ...e,
          cover,
          author: {
            ...e.author,
            repositoriesCount: undefined,
          },
          bodyHTML: dom.innerHTML,
          comments: e.comments.nodes.map((e) => ({
            ...e,
            author: {
              ...e.author,
              repositoriesCount: undefined,
            },
          })),
        };
      })
    );
    isLoading.value = false;
  });
});
</script>

<style scoped lang="less">
main {
  position: relative;
  margin-top: 100px;
  padding: 28px;
  background: #121212;
  min-height: calc(100vh - 100px);
  margin-left: auto;
  margin-right: auto;

  .loading {
    position: absolute;
    top: 50%;
    left: 50%;
    transform: translate(-50%, -50%);
  }
}
</style>
