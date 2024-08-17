<template>
  <main>
    <div class="center" v-if="needUpdata">
      <a href="https://greasyfork.org/zh-CN/scripts/502874" class="link">
        请更新“绳网小助手”，最新版本为 1.14.1
      </a>
    </div>
    <div class="center" v-else-if="needInstall">
      <a href="https://greasyfork.org/zh-CN/scripts/502874" class="link">
        请安装“绳网小助手”
      </a>
    </div>
    <ClientOnly v-else>
      <Waterfall
        :list="list"
        row-key="number"
        background-color="transparent"
        :width="256"
        img-selector="img"
        ref="waterfall"
        :breakpoints="[
          { width: 256, cols: 1 },
          { width: 512, cols: 2 },
          { width: 768, cols: 3 },
          { width: 1024, cols: 4 },
          { width: 1280, cols: 5 },
          { width: 1440, cols: 6 },
          { width: 1600, cols: 7 },
          { width: 1920, cols: 8 },
        ]"
      >
        <template #item="{ item }: { item: { article: Article } }">
          <Card
            :key="item.article.url"
            :article="item.article"
            @click="clickHandle(item.article)"
            @resize="waterfall.renderer()"
          />
        </template>
      </Waterfall>
    </ClientOnly>
    <popup-article
      @close="closeHandle"
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
const showPopup = ref(false);
const curArticle = ref<Article>();
const list = computed(() =>
  data.value
    .filter(
      (e) =>
        [store.owner, ...store.collaborators].includes(e.author.login) ||
        (store.reports[e.number]?.length ?? 0) < 5
    )
    .map((e) => ({
      src: e.cover,
      article: e,
      number: e.number,
    }))
);
const waterfall = ref();

onMounted(async () => {
  window.addEventListener("popstate", async function () {
    const url = new URL(location.href);
    if (url.searchParams.has("article")) {
      const number = +url.searchParams.get("article")!;
      if (curArticle.value?.number === number) {
        if (showPopup.value === false) showPopup.value = true;
        return;
      }
      showPopup.value = true;
      try {
        const res = await getDiscussion(number);
        curArticle.value = res;
        this.document.title = res.title;
      } catch (e) {
        useNuxtApp().$toast.error("获取文章失败");
      }
    } else {
      showPopup.value = false;
    }
  });
  const url = new URL(location.href);
  if (url.searchParams.has("article")) {
    showPopup.value = true;
    const str = url.searchParams.get("article")!;
    try {
      const res = await getDiscussion(parseInt(str));
      curArticle.value = res;
      document.title = res.title;
    } catch (e) {
      useNuxtApp().$toast.error("获取文章失败");
    }
  }
});

function clickHandle(article: Article) {
  curArticle.value = article;
  showPopup.value = true;
  const url = new URL(location.href);
  url.searchParams.set("article", article.number + "");
  history.pushState(null, "", url);
  document.title = article.title;
}

function closeHandle() {
  showPopup.value = false;
  const url = new URL(location.href);
  url.searchParams.delete("article");
  history.pushState(null, "", url);
  document.title = "绳网";
}

onMounted(async () => {
  setTimeout(() => {
    if (typeof window.getUserInfo !== "function") {
      needInstall.value = true;
    } else if (window.version !== "1.14.1") {
      needUpdata.value = true;
    }
  }, 2000);
  if (typeof window.run === "undefined") window.run = [];
  window.run.push(async () => {
    if (window.version !== "1.14.1") {
      needUpdata.value = true;
      return;
    }
    getAllReports(store.reportNumber).then((reports) => {
      store.reports = transformReports(reports);
    });
    useInfiniteScroll(
      window,
      async () => {
        if (store.hasNextPage === false) return;
        try {
          const res = await getAllDiscussions();
          store.hasNextPage = res.hasNextPage;
          data.value.push(...res.discussions);
          removeDuplicateArticle(data.value);
        } catch (e) {
          console.error(e);
          useNuxtApp().$toast.error("获取文章失败");
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

  @media (max-width: 1300px) {
    & {
      margin-top: 80px;
      min-height: calc(100vh - 80px);
    }
  }

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
