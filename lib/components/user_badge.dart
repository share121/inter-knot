import 'package:flutter/material.dart';
import 'package:inter_knot/components/avatar.dart';
import 'package:inter_knot/constants/globals.dart';

class UserBadge extends StatelessWidget {
  const UserBadge({
    super.key,
    required this.avatarUrl,
    required this.name,
    required this.contributions,
    required this.level,
  });

  final String? avatarUrl;
  final String name;
  final int contributions;
  final int level;

  @override
  Widget build(BuildContext context) {
    final progress = contributions % 100;
    final ratio = contributions == 0 ? 0.0 : progress / 100;
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xff212121),
            Color(0xff141414),
            Color(0xff181818),
          ],
          stops: [0, 0.9, 1.0],
          begin: Alignment.topLeft,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(maxRadius),
      ),
      child: Row(
        children: [
          Avatar(avatarUrl),
          const SizedBox(width: 4),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                style: const TextStyle(
                  fontSize: 18,
                  height: 1,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Stack(
                alignment: Alignment.centerLeft,
                children: [
                  Container(
                    width: 150,
                    height: 16,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(maxRadius),
                      color: const Color(0xff222222),
                    ),
                    clipBehavior: Clip.antiAlias,
                    alignment: Alignment.topLeft,
                    child: FractionallySizedBox(
                      widthFactor: ratio.clamp(0.0, 1.0),
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(maxRadius),
                          gradient: const LinearGradient(
                            colors: [
                              Color(0xff4661fd),
                              Color(0xff10bff0),
                            ],
                          ),
                        ),
                        clipBehavior: Clip.antiAlias,
                      ),
                    ),
                  ),
                  Positioned(
                    left: 4,
                    child: Text(
                      '$progress/100',
                      style: const TextStyle(fontSize: 12, height: 1),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(width: 4),
          Column(
            children: [
              Text(
                level.toString(),
                style: const TextStyle(
                  fontSize: 24,
                  height: 1,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'LEVEL',
                style: TextStyle(
                  fontSize: 12,
                  height: 1,
                  color: Colors.white54,
                ),
              ),
            ],
          ),
          const SizedBox(width: 8),
        ],
      ),
    );
  }
}
