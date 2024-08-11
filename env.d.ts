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
                pageInfo: { hasNextPage; endCursor: newEndCursor };
              };
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
    number: number;
  }

  interface MyComment {
    author: Actor;
    bodyHTML: string;
  }
}
