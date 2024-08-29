import 'package:inter_knot/api/common.dart';
import 'package:inter_knot/data.dart';

Future<bool> isDiscussionAvailable(int number) async {
  final res = await graphql(
      '{ repository(owner: "$owner", name: "$repo") { discussion(number: $number) { number } } }');
  return res.data?['data']['repository']['discussion'] != null;
}
