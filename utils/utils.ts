import DOMPurify from "dompurify";
import defaultCover from "~/assets/svg/default-cover.svg?url";

export function xss(html: string) {
  return DOMPurify.sanitize(html);
}

export async function getUserInfo(): Promise<Actor> {
  const {
    response: {
      data: {
        viewer: {
          login,
          avatarUrl,
          repositories: { totalCount },
        },
      },
    },
  } = await window.getUserInfo();
  return {
    login,
    avatarUrl,
    url: `https://github.com/${encodeURIComponent(login)}`,
    repositoriesCount: totalCount,
  };
}

export async function getDiscussions(endCursor: string | null) {
  const {
    response: {
      data: {
        repository: {
          discussions: {
            nodes,
            pageInfo: { hasNextPage, endCursor: newEndCursor },
          },
        },
      },
    },
  } = await window.getDiscussions(endCursor);
  return {
    discussions: nodes
      .map((e) => {
        try {
          return {
            ...e,
            bodyHTML: xss(e.bodyHTML),
          };
        } catch (e) {
          console.error(e);
          return null;
        }
      })
      .filter((e) => e !== null)
      .map((e) => {
        const dom = html2dom(e.bodyHTML);
        const firstImg = dom.content?.querySelector("img");
        const cover = firstImg?.src ?? defaultCover;
        let parent = firstImg?.parentElement;
        firstImg?.remove();
        while (parent instanceof HTMLElement && parent.children.length == 0) {
          parent?.remove();
          parent = parent.parentElement;
        }
        dom.content.querySelectorAll("a").forEach((e) => (e.target = "_blank"));
        return {
          ...e,
          cover,
          author: {
            ...e.author,
            repositoriesCount: undefined,
          },
          bodyHTML: dom.innerHTML,
          comments: [],
        };
      }),
    hasNextPage,
    endCursor: newEndCursor,
  };
}

export async function getComments(number: number, endCursor: string | null) {
  const {
    response: {
      data: {
        repository: {
          discussion: {
            comments: {
              nodes,
              pageInfo: { hasNextPage, endCursor: newEndCursor },
            },
          },
        },
      },
    },
  } = await window.getComments(number, endCursor);
  return {
    comments: nodes
      .map((e) => {
        try {
          return {
            ...e,
            bodyHTML: xss(e.bodyHTML),
            author: {
              ...e.author,
              repositoriesCount: undefined,
            },
          };
        } catch (e) {
          console.error(e);
          return null;
        }
      })
      .filter((e) => e !== null),
    hasNextPage,
    endCursor: newEndCursor,
  };
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

export function removeDuplicateArticle(arr: Article[]) {
  let len = arr.length;
  for (let i = 0; i < len; i++) {
    for (let j = i + 1; j < len; j++) {
      if (arr[i].number === arr[j].number) {
        arr.splice(j, 1);
        len--;
        j--;
      }
    }
  }
  return arr;
}
