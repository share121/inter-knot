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
                createdAt: string;
                lastEditedAt: string | null;
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
    getDiscussion(number: number): Promise<{
      response: {
        data: {
          repository: {
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
              createdAt: string;
              lastEditedAt: string | null;
              comments: {
                totalCount: number;
              };
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
                  createdAt: string;
                  lastEditedAt: string | null;
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
                  replies: {
                    nodes: {
                      author: {
                        avatarUrl: string;
                        login: string;
                        url: string;
                      };
                      bodyHTML: string;
                    }[];
                  };
                }[];
                pageInfo: { hasNextPage: boolean; endCursor: string };
              };
            };
          };
        };
      };
    }>;
    getAllReports(number: number): Promise<
      {
        author: {
          login: string;
        };
        bodyHTML: string;
      }[]
    >;
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
    search(
      query: string,
      after: string | null
    ): Promise<{
      response: {
        data: {
          search: {
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
              createdAt: string;
              lastEditedAt: string | null;
              comments: {
                totalCount: number;
              };
            }[];
            pageInfo: { hasNextPage: boolean; endCursor: string };
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

  interface Reports {
    login: string;
    numbers: number[];
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
    createdAt: string;
    lastEditedAt: string | null;
  }

  interface MyComment {
    author: Actor;
    bodyHTML: string;
    replies: {
      author: Actor;
      bodyHTML: string;
    }[];
  }
}
