// export declare global {
//   function run();
//   function getAccessToken(code: string): Promise<{
//     response: {
//       access_token: string;
//       expires_in: number;
//       refresh_token: string;
//       refresh_token_expires_in: number;
//       scope: "";
//       token_type: "bearer";
//     };
//   }>;
//   function refreshAccessToken(refresh_token: string): Promise<{
//     response: {
//       access_token: string;
//       expires_in: number;
//       refresh_token: string;
//       refresh_token_expires_in: number;
//       scope: "";
//       token_type: "bearer";
//     };
//   }>;
//   function getUserInfo(access_token: string): Promise<{
//     data: {
//       viewer: {
//         login: string;
//         avatarUrl: string;
//         repositories: {
//           totalCount: number;
//         };
//       };
//     };
//   }>;
//   function getDiscussions(access_token: string): Promise<{
//     data: {
//       repository: {
//         discussions: {
//           nodes: {
//             author: {
//               avatarUrl: string;
//               login: string;
//               url: string;
//             };
//             bodyHTML: string;
//             bodyText: string;
//             title: string;
//             url: string;
//             comments: {
//               nodes: {
//                 author: {
//                   avatarUrl: string;
//                   login: string;
//                   url: string;
//                 };
//                 bodyHTML: string;
//               }[];
//             };
//           }[];
//         };
//       };
//     };
//   }>;
// }

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
}

interface MyComment {
  author: Actor;
  bodyHTML: string;
}
