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
        dom.content
          .querySelectorAll<HTMLAnchorElement>('a:not([href^="#"])')
          .forEach((e) => (e.target = "_blank"));
        dom.content.querySelectorAll("a").forEach((e) => {
          const mat =
            /https:\/\/github.com\/share121\/inter-knot\/discussions\/(\d+)/.exec(
              e.href
            );
          if (mat === null) return;
          e.href = `?article=${mat[1]}`;
          e.target = "_self";
        });
        return {
          ...e,
          cover,
          author: {
            ...e.author,
            repositoriesCount: undefined,
          },
          bodyHTML: dom.innerHTML,
          comments: [],
          commentsCount: e.comments.totalCount,
          hasNextPage: true,
          endCursor: null,
          isPinned: false,
        };
      }),
    hasNextPage,
    endCursor: newEndCursor,
  };
}

export async function getDiscussion(number: number): Promise<Article> {
  const {
    response: {
      data: {
        repository: { discussion },
      },
    },
  } = await window.getDiscussion(number);
  const dom = html2dom(xss(discussion.bodyHTML));
  const firstImg = dom.content?.querySelector("img");
  const cover = firstImg?.src ?? defaultCover;
  let parent = firstImg?.parentElement;
  firstImg?.remove();
  while (parent instanceof HTMLElement && parent.children.length == 0) {
    parent?.remove();
    parent = parent.parentElement;
  }
  dom.content
    .querySelectorAll<HTMLAnchorElement>('a:not([href^="#"])')
    .forEach((e) => (e.target = "_blank"));
  dom.content.querySelectorAll("a").forEach((e) => {
    const mat =
      /https:\/\/github.com\/share121\/inter-knot\/discussions\/(\d+)/.exec(
        e.href
      );
    if (mat === null) return;
    e.href = `?article=${mat[1]}`;
    e.target = "_self";
  });
  return {
    ...discussion,
    cover,
    author: {
      ...discussion.author,
      repositoriesCount: undefined,
    },
    bodyHTML: dom.innerHTML,
    comments: [],
    commentsCount: discussion.comments.totalCount,
    hasNextPage: true,
    endCursor: null,
    isPinned: false,
  };
}

export async function getPinnedDiscussions(endCursor: string | null) {
  const {
    response: {
      data: {
        repository: {
          pinnedDiscussions: {
            nodes,
            pageInfo: { hasNextPage, endCursor: newEndCursor },
          },
        },
      },
    },
  } = await window.getPinnedDiscussions(endCursor);
  return {
    discussions: nodes
      .map((e) => e.discussion)
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
        dom.content
          .querySelectorAll<HTMLAnchorElement>('a:not([href^="#"])')
          .forEach((e) => (e.target = "_blank"));
        dom.content.querySelectorAll("a").forEach((e) => {
          const mat =
            /https:\/\/github.com\/share121\/inter-knot\/discussions\/(\d+)/.exec(
              e.href
            );
          if (mat === null) return;
          e.href = `?article=${mat[1]}`;
          e.target = "_self";
        });
        return {
          ...e,
          cover,
          author: {
            ...e.author,
            repositoriesCount: undefined,
          },
          bodyHTML: dom.innerHTML,
          comments: [],
          commentsCount: e.comments.totalCount,
          hasNextPage: true,
          endCursor: null,
          isPinned: true,
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
      .filter((e) => e !== null)
      .map((e) => {
        const dom = html2dom(e.bodyHTML);
        dom.content
          .querySelectorAll<HTMLAnchorElement>('a:not([href^="#"])')
          .forEach((e) => (e.target = "_blank"));
        dom.content.querySelectorAll("a").forEach((e) => {
          const mat =
            /https:\/\/github.com\/share121\/inter-knot\/discussions\/(\d+)/.exec(
              e.href
            );
          if (mat === null) return;
          e.href = `?article=${mat[1]}`;
          e.target = "_self";
        });
        return {
          ...e,
          bodyHTML: dom.innerHTML,
        };
      }),
    hasNextPage,
    endCursor: newEndCursor,
  };
}

export async function getRepositoriesCount(login: string) {
  const {
    response: {
      data: {
        user: {
          repositories: { totalCount },
        },
      },
    },
  } = await window.getRepositoriesCount(login);
  return totalCount;
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

export function delay(ms: number) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

export async function* genDiscussions() {
  let res = await getPinnedDiscussions(null);
  yield res.discussions;
  while (res.hasNextPage) {
    res = await getPinnedDiscussions(res.endCursor);
    yield res.discussions;
  }
  res = await getDiscussions(null);
  yield res.discussions;
  while (res.hasNextPage) {
    res = await getDiscussions(res.endCursor);
    yield res.discussions;
  }
}

let gen = genDiscussions();
export async function getAllDiscussions(reset = false) {
  if (reset) {
    gen = genDiscussions();
  }
  const { value, done } = await gen.next();
  return {
    discussions: value as Article[],
    hasNextPage: !done,
  };
}

export async function addDiscussionComment(id: string, body: string) {
  const {
    response: {
      data: {
        addDiscussionComment: { clientMutationId },
      },
    },
  } = await window.addDiscussionComment(id, body);
  return clientMutationId;
}

export async function deleteDiscussion(id: string) {
  const {
    response: {
      data: {
        deleteDiscussion: { clientMutationId },
      },
    },
  } = await window.deleteDiscussion(id);
  return clientMutationId;
}

export async function getDiscussionId(number: number) {
  const {
    response: {
      data: {
        repository: {
          discussion: { id },
        },
      },
    },
  } = await window.getDiscussionId(number);
  return id;
}
