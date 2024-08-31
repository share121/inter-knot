import 'dart:async';
import 'package:dio/dio.dart';

import 'common.dart';

Future<Response<Map<String, dynamic>>> deleteDiscussion(String id) => graphql(
    'mutation { deleteDiscussion(input: { id: "$id" }) { clientMutationId } }');
