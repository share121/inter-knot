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
                id: string;
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
                  id: string;
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
    addDiscussionComment(
      id: string,
      body: string
    ): Promise<{
      response: {
        data: {
          addDiscussionComment: {
            clientMutationId: string | null;
          };
        };
      };
    }>;
    deleteDiscussion(id: string): Promise<{
      response: {
        data: {
          deleteDiscussion: {
            clientMutationId: string | null;
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
    getDiscussionId(number: number): Promise<{
      response: {
        data: {
          repository: {
            discussion: {
              id: string;
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
    id: string;
  }

  interface MyComment {
    author: Actor;
    bodyHTML: string;
  }
}
