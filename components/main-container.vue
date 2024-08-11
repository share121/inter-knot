<template>
  <main>
    <div class="center" v-if="needUpdata">
      <a href="https://greasyfork.org/zh-CN/scripts/502874" class="link">
        请更新“绳网小助手”，最新版本为 1.5.0
      </a>
    </div>
    <div class="center" v-else-if="needInstall">
      <a href="https://greasyfork.org/zh-CN/scripts/502874" class="link">
        请安装“绳网小助手”
      </a>
    </div>
    <div class="center" v-else-if="isLoading">加载中……</div>
    <ClientOnly v-else>
      <Waterfall
        :list="list"
        background-color="transparent"
        :width="256"
        img-selector="img"
        ref="waterfall"
      >
        <template #item="{ item }">
          <Card
            :key="item.article.url"
            :article="item.article"
            @click="
              curArticle = item.article;
              showPopup = true;
            "
            @resize="waterfall.renderer()"
          />
        </template>
      </Waterfall>
    </ClientOnly>
    <popup-article
      @close="showPopup = false"
      :show="showPopup"
      :article="curArticle"
    />
  </main>
</template>

<script setup lang="ts">
import { Waterfall } from "vue-waterfall-plugin-next";
import "vue-waterfall-plugin-next/dist/style.css";

const store = useConfigStore();
const { data } = storeToRefs(store);
const needUpdata = ref(false);
const needInstall = ref(false);
const isLoading = ref(true);
const showPopup = ref(false);
const curArticle = ref<Article>();
const list = computed(() =>
  data.value.map((e) => ({
    src: e.cover,
    article: e,
  }))
);
const waterfall = ref();

onMounted(async () => {
  setTimeout(() => {
    if (typeof window.getUserInfo !== "function") {
      needInstall.value = true;
    } else if (window.version !== "1.5.0") {
      needUpdata.value = true;
    }
  }, 2000);
  if (typeof window.run === "undefined") window.run = [];
  window.run.push(async () => {
    if (window.version !== "1.5.0") {
      needUpdata.value = true;
      return;
    }
    useInfiniteScroll(
      window,
      async () => {
        if (store.hasNextPage === false) return;
        console.log("scroll");
        try {
          const res = await getDiscussions(store.endCursor);
          store.hasNextPage = res.hasNextPage;
          store.endCursor = res.endCursor;
          data.value.push(...res.discussions);
          removeDuplicateArticle(data.value);
          isLoading.value = false;
        } catch (e) {
          console.error(e);
        }
      },
      { distance: 1000 }
    );
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

  .link {
    color: #66ccff;
  }

  .center {
    position: absolute;
    top: 50%;
    left: 50%;
    transform: translate(-50%, -50%);
    font-size: 24px;
  }
}
</style>
