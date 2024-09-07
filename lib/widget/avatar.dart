import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../gen/assets.gen.dart';

class Avatar extends StatelessWidget {
  const Avatar(this.src, {super.key});

  final String? src;

  @override
  Widget build(BuildContext context) {
    return ClipOval(
      child: src == null
          ? Assets.images.profilePhoto.image(
              height: 50,
              width: 50,
              fit: BoxFit.cover,
            )
          : CachedNetworkImage(
              imageUrl: src!,
              width: 50,
              height: 50,
              fit: BoxFit.cover,
              progressIndicatorBuilder: (context, url, downloadProgress) {
                return Center(
                  child: CircularProgressIndicator(
                    value: downloadProgress.progress,
                  ),
                );
              },
              errorWidget: (context, error, stackTrace) =>
                  Assets.images.profilePhoto.image(),
            ),
    );
  }
}
