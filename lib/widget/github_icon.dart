import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../gen/assets.gen.dart';

class GithubIcon extends StatelessWidget {
  const GithubIcon({super.key});

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      Assets.images.github,
      colorFilter: ColorFilter.mode(
        Theme.of(context).colorScheme.onSurfaceVariant,
        BlendMode.srcIn,
      ),
    );
  }
}
