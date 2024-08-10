<template>
  <div class="user-info">
    <ClientOnly>
      <a :href="href" :target="author?.url ? '_blank' : '_self'">
        <img class="profile-photo" :src="cover" alt="我的头像" />
      </a>
    </ClientOnly>
    <div class="user-info-text">
      <ClientOnly>
        <a :href="href" :target="author?.url ? '_blank' : '_self'">
          <div class="username">{{ author?.login ?? "佚名" }}</div>
        </a>
      </ClientOnly>
      <div class="experience">
        <div class="bar" :style="{ width }">
          <span class="curExp">{{ curExp }}</span> /
          <span class="totalExp">{{ totalExp }}</span>
        </div>
      </div>
    </div>
    <div class="level" title="根据你的公开仓库数计算">
      <div class="level-num">{{ author?.repositoriesCount ?? 0 }}</div>
      <div class="level-text">LEVEL</div>
    </div>
  </div>
</template>

<script lang="ts" setup>
import defaultAvatarUrl from "~/assets/svg/profile-photo.svg?url";
const author = ref<Actor>();
const curExp = ref(6850);
const totalExp = ref(10000);
const cover = computed(() => author.value?.avatarUrl ?? defaultAvatarUrl);
const width = computed(() => `${(curExp.value / totalExp.value) * 100}%`);
const href = computed(() => author.value?.url ?? getLoginHref());

onMounted(async () => {
  // @ts-ignore
  if (typeof window.run === "undefined") window.run = [];
  // @ts-ignore
  window.run.push(async () => {
    const access_token = localStorage.getItem("access_token");
    if (!access_token || !access_token.startsWith("ghu_")) return;
    try {
      author.value = await getUserInfo(access_token);
    } catch (e) {
      console.error(e);
    }
  });
});
</script>

<style scoped lang="less">
@media (max-width: 605px) {
  .user-info {
    transform: scale(1) !important;
  }
}

.user-info {
  display: flex;
  gap: 10px;
  padding: 8px;
  padding-right: 20px;
  color: unset;
  text-decoration: none;
  align-items: flex-end;
  min-width: 310px;
  height: 100%;
  border-radius: @max-radius;
  background: linear-gradient(#212121, #141414);
  box-shadow: inset 0 2px 2px #313431, inset 0 -2px 2px #181818;
  transform: scale(1.3);
  transform-origin: left center;

  a {
    height: 100%;

    .profile-photo {
      border-radius: 50%;
      height: 100%;
      aspect-ratio: 1 / 1;
      background: #121212;
    }
  }

  .user-info-text {
    display: flex;
    flex-direction: column;
    flex: 1;
    gap: 4px;

    .experience {
      width: 100%;
      font-size: 12px;
      border-radius: @max-radius;
      background: #222222;
      box-shadow: inset 0 2px 2px #131313, inset 0 -2px 2px #262626;
      font-weight: normal;

      .bar {
        padding: 0 8px;
        max-width: 100%;
        height: 100%;
        border-radius: @max-radius;
        background: linear-gradient(90deg, #4661fd, #10bff0);
      }
    }
  }

  .level {
    display: flex;
    flex-direction: column;
    align-items: center;

    .level-num {
      font-size: 26px;
      line-height: 1;
    }

    .level-text {
      font-size: 10px;
      color: #7b7b7b;
    }
  }
}
</style>
