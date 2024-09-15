import 'package:flutter/material.dart';

import '../gen/assets.gen.dart';

class Avatar extends StatelessWidget {
  const Avatar(this.src, {super.key, this.size = 40});

  final String? src;
  final double size;

  @override
  Widget build(BuildContext context) {
    return ClipOval(
      child: src == null
          ? Assets.images.profilePhoto.image(
              height: size,
              width: size,
              fit: BoxFit.cover,
            )
          : Image.network(
              src!,
              width: size,
              height: size,
              fit: BoxFit.cover,
              loadingBuilder: (context, child, p) {
                if (p == null) return child;
                return SizedBox.square(
                  dimension: size,
                  child: Center(
                    child: CircularProgressIndicator(
                      value: p.expectedTotalBytes == null
                          ? null
                          : p.cumulativeBytesLoaded / p.expectedTotalBytes!,
                    ),
                  ),
                );
              },
              errorBuilder: (context, e, s) => Assets.images.profilePhoto.image(
                height: size,
                width: size,
                fit: BoxFit.cover,
              ),
            ),
    );
  }
}
