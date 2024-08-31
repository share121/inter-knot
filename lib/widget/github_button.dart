import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher_string.dart';

import '../data.dart';
import 'github_icon.dart';

class GithubButton extends StatelessWidget {
  const GithubButton({super.key});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: () => launchUrlString(githubLink),
      tooltip: 'Github',
      icon: const GithubIcon(),
    );
  }
}
