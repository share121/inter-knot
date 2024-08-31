import 'dart:async';
import 'package:dio/dio.dart';

import 'common.dart';

Future<Response<Map<String, dynamic>>> addDiscussionComment(
        String discussionId, String body) =>
    graphql(
        'mutation { addDiscussionComment(input: { discussionId: "$discussionId", body: "${encode(body)}" }) { clientMutationId } }');
