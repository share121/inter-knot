import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher_string.dart';

import '../data.dart';

const githubLink = 'https://github.com/$owner/$repo';

class GithubButton extends StatelessWidget {
  const GithubButton({super.key});

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: () => launchUrlString(githubLink),
      child: const Text('Github'),
    );
  }
}
