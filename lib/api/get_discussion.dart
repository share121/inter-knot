import 'dart:async';
import 'package:dio/dio.dart';

import 'common.dart';
import '../data.dart';

Future<Response<Map<String, dynamic>>> getDiscussion(int number) => graphql(
    '{ repository(owner: "$owner", name: "$repo") { discussion(number: $number) { number author { avatarUrl(size: 50) login } createdAt lastEditedAt bodyHTML id bodyText title comments { totalCount } } } }');
