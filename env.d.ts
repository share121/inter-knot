export declare global {
  interface Window {
    run?: Function[];
    version?: string;
    getUserInfo(): Promise<{
      response: {
        data: {
          viewer: {
            login: string;
            avatarUrl: string;
            repositories: {
              totalCount: number;
            };
          };
        };
      };
    }>;
    getDiscussions(endCursor: string | null): Promise<{
      response: {
        data: {
          repository: {
            discussions: {
              nodes: {
                author: {
                  avatarUrl: string;
                  login: string;
                  url: string;
                };
                bodyHTML: string;
                bodyText: string;
                title: string;
                url: string;
                number: number;
                comments: {
                  totalCount: number;
                };
              }[];
              pageInfo: { hasNextPage: boolean; endCursor: string };
            };
          };
        };
      };
    }>;
    getPinnedDiscussions(endCursor: string | null): Promise<{
      response: {
        data: {
          repository: {
            pinnedDiscussions: {
              nodes: {
                discussion: {
                  author: {
                    avatarUrl: string;
                    login: string;
                    url: string;
                  };
                  bodyHTML: string;
                  bodyText: string;
                  title: string;
                  url: string;
                  number: number;
                  comments: {
                    totalCount: number;
                  };
                };
              }[];
              pageInfo: { hasNextPage: boolean; endCursor: string };
            };
          };
        };
      };
    }>;
    getComments(
      number: number,
      endCursor: string | null
    ): Promise<{
      response: {
        data: {
          repository: {
            discussion: {
              comments: {
                nodes: {
                  author: {
                    avatarUrl: string;
                    login: string;
                    url: string;
                  };
                  bodyHTML: string;
                }[];
                pageInfo: { hasNextPage: boolean; endCursor: string };
              };
            };
          };
        };
      };
    }>;
    getRepositoriesCount(login: string): Promise<{
      response: {
        data: {
          user: {
            repositories: {
              totalCount: number;
            };
          };
        };
      };
    }>;
  }

  declare module "*?url";

  interface Actor {
    avatarUrl: string;
    login: string;
    url: string;
    repositoriesCount: number | undefined;
  }

  interface Article {
    title: string;
    url: string;
    author: Actor;
    bodyHTML: string;
    bodyText: string;
    cover: string;
    comments: MyComment[];
    commentsCount: number;
    isPinned: boolean;
    number: number;
    hasNextPage: boolean;
    endCursor: string | null;
  }

  interface MyComment {
    author: Actor;
    bodyHTML: string;
  }
}
