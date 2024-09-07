/// GENERATED CODE - DO NOT MODIFY BY HAND
/// *****************************************************
///  FlutterGen
/// *****************************************************

// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: directives_ordering,unnecessary_import,implicit_dynamic_list_literal,deprecated_member_use

import 'package:flutter/widgets.dart';

class $AssetsImagesGen {
  const $AssetsImagesGen();

  /// File path: assets/images/bh3.webp
  AssetGenImage get bh3 => const AssetGenImage('assets/images/bh3.webp');

  /// File path: assets/images/default-cover.webp
  AssetGenImage get defaultCover =>
      const AssetGenImage('assets/images/default-cover.webp');

  /// File path: assets/images/drawer-cover.webp
  AssetGenImage get drawerCover =>
      const AssetGenImage('assets/images/drawer-cover.webp');

  /// File path: assets/images/github.svg
  String get github => 'assets/images/github.svg';

  /// File path: assets/images/profile-photo.webp
  AssetGenImage get profilePhoto =>
      const AssetGenImage('assets/images/profile-photo.webp');

  /// File path: assets/images/sr.webp
  AssetGenImage get sr => const AssetGenImage('assets/images/sr.webp');

  /// File path: assets/images/yuanshen.webp
  AssetGenImage get yuanshen =>
      const AssetGenImage('assets/images/yuanshen.webp');

  /// File path: assets/images/zzz.webp
  AssetGenImage get zzz => const AssetGenImage('assets/images/zzz.webp');

  /// List of all assets
  List<dynamic> get values =>
      [bh3, defaultCover, drawerCover, github, profilePhoto, sr, yuanshen, zzz];
}

class Assets {
  Assets._();

  static const $AssetsImagesGen images = $AssetsImagesGen();
  static const String privateKey = 'assets/private_key.pem';

  /// List of all assets
  static List<String> get values => [privateKey];
}

class AssetGenImage {
  const AssetGenImage(
    this._assetName, {
    this.size,
    this.flavors = const {},
  });

  final String _assetName;

  final Size? size;
  final Set<String> flavors;

  Image image({
    Key? key,
    AssetBundle? bundle,
    ImageFrameBuilder? frameBuilder,
    ImageErrorWidgetBuilder? errorBuilder,
    String? semanticLabel,
    bool excludeFromSemantics = false,
    double? scale,
    double? width,
    double? height,
    Color? color,
    Animation<double>? opacity,
    BlendMode? colorBlendMode,
    BoxFit? fit,
    AlignmentGeometry alignment = Alignment.center,
    ImageRepeat repeat = ImageRepeat.noRepeat,
    Rect? centerSlice,
    bool matchTextDirection = false,
    bool gaplessPlayback = false,
    bool isAntiAlias = false,
    String? package,
    FilterQuality filterQuality = FilterQuality.low,
    int? cacheWidth,
    int? cacheHeight,
  }) {
    return Image.asset(
      _assetName,
      key: key,
      bundle: bundle,
      frameBuilder: frameBuilder,
      errorBuilder: errorBuilder,
      semanticLabel: semanticLabel,
      excludeFromSemantics: excludeFromSemantics,
      scale: scale,
      width: width,
      height: height,
      color: color,
      opacity: opacity,
      colorBlendMode: colorBlendMode,
      fit: fit,
      alignment: alignment,
      repeat: repeat,
      centerSlice: centerSlice,
      matchTextDirection: matchTextDirection,
      gaplessPlayback: gaplessPlayback,
      isAntiAlias: isAntiAlias,
      package: package,
      filterQuality: filterQuality,
      cacheWidth: cacheWidth,
      cacheHeight: cacheHeight,
    );
  }

  ImageProvider provider({
    AssetBundle? bundle,
    String? package,
  }) {
    return AssetImage(
      _assetName,
      bundle: bundle,
      package: package,
    );
  }

  String get path => _assetName;

  String get keyName => _assetName;
}
