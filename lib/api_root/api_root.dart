library ApiRoot;

import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:dio/dio.dart';
import 'package:get/get.dart' hide Response;
import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';

import '../common.dart';
import '../gen/assets.gen.dart';
import '../data.dart';
import '../api_common.dart';
import '../interface.dart';

part 'common.dart';
part 'delete_discussion.dart';
part 'gen_token.dart';
part 'get_access_token.dart';
part 'get_all_reports.dart';
part 'get_comments.dart';
part 'get_discussion.dart';
part 'get_discussions.dart';
part 'get_new_version.dart';
part 'get_pinned_discussions.dart';
part 'get_user_info.dart';
part 'is_discussion_available.dart';
part 'search.dart';
