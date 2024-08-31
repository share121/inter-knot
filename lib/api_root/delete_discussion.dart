part of 'api_root.dart';

Future<Response<Map<String, dynamic>>> deleteDiscussion(String id) => graphql(
    'mutation { deleteDiscussion(input: { id: "$id" }) { clientMutationId } }');
