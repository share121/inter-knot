import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher_string.dart';

import '../data.dart';

class DiscordButton extends StatelessWidget {
  const DiscordButton({super.key});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: () => launchUrlString(discordLink),
      tooltip: 'Discord',
      icon: const Icon(Icons.discord),
    );
  }
}
