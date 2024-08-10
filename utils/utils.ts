import DOMPurify from "dompurify";

export async function handleErr(fn: Function) {
  try {
    await fn();
  } catch (e) {
    console.error(e);
    try {
      await refreshAccessToken(localStorage.getItem("refresh_token")!);
      await fn();
    } catch (e) {
      console.error(e);
      getCode();
    }
  }
}

export function getLoginHref() {
  return location.hostname === "localhost"
    ? "https://github.com/login/oauth/authorize?client_id=Iv23li8gf1MxGAgvw5lU&redirect_uri=http://localhost:5173/inter-knot/"
    : "https://github.com/login/oauth/authorize?client_id=Iv23li8gf1MxGAgvw5lU";
}

export function xss(html: string) {
  return DOMPurify.sanitize(html);
}

export function getCode() {
  location.href = getLoginHref();
}

export async function getAccessToken(code: string): Promise<{
  access_token: string;
  expires_in: number;
  refresh_token: string;
  refresh_token_expires_in: number;
  scope: "";
  token_type: "bearer";
}> {
  // @ts-ignore
  const { response: res } = await window.getAccessToken(code);
  localStorage.setItem("access_token", res.access_token);
  localStorage.setItem("refresh_token", res.refresh_token);
  return res;
}

export async function refreshAccessToken(refresh_token: string): Promise<{
  access_token: string;
  expires_in: number;
  refresh_token: string;
  refresh_token_expires_in: number;
  scope: "";
  token_type: "bearer";
}> {
  // @ts-ignore
  const { response: res } = await window.refreshAccessToken(refresh_token);
  localStorage.setItem("access_token", res.access_token);
  localStorage.setItem("refresh_token", res.refresh_token);
  return res;
}

export async function getUserInfo(access_token: string): Promise<Actor> {
  // @ts-ignore
  const { data } = await window.getUserInfo(access_token);
  return {
    login: data.viewer.login,
    avatarUrl: data.viewer.avatarUrl,
    url: `https://github.com/${encodeURIComponent(data.viewer.login)}`,
    repositoriesCount: data.viewer.repositories.totalCount,
  };
}

export async function tryGet(fn: (access_token: string) => Promise<any>) {
  const access_token = localStorage.getItem("access_token");
  if (access_token?.startsWith("ghu_")) {
    handleErr(() => fn(access_token));
  } else if (new URL(location.href).searchParams.has("code")) {
    handleErr(async () => {
      const { access_token } = await getAccessToken(
        new URL(location.href).searchParams.get("code")!
      );
      await fn(access_token);
    });
  }
}

export async function getDiscussions(access_token: string): Promise<
  {
    author: {
      login: string;
      avatarUrl: string;
      url: string;
    };
    title: string;
    bodyHTML: string;
    bodyText: string;
    comments: {
      nodes: {
        author: {
          login: string;
          avatarUrl: string;
          url: string;
        };
        bodyHTML: string;
      }[];
    };
    url: string;
  }[]
> {
  const {
    data: {
      repository: {
        discussions: { nodes },
      },
    },
    // @ts-ignore
  } = await window.getDiscussions(access_token);
  return (
    nodes
      // @ts-ignore
      .map((e) => {
        try {
          return {
            ...e,
            bodyHTML: xss(e.bodyHTML),
            comments: {
              nodes: e.comments.nodes.map((e: any) => ({
                ...e,
                bodyHTML: xss(e.bodyHTML),
              })),
            },
          };
        } catch (e) {
          console.error(e);
          return null;
        }
      })
      .filter((e: any) => e !== null)
  );
}

/** 不含最大值，含最小值 */
export function getRandomInt(min: number, max: number) {
  min = Math.ceil(min);
  max = Math.floor(max);
  return Math.floor(Math.random() * (max - min) + min);
}

export function html2dom(html: string) {
  let template = document.createElement("template");
  template.innerHTML = html;
  return template;
}
