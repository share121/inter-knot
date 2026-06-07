import 'package:flutter_test/flutter_test.dart';
import 'package:inter_knot/helpers/iframe_policy.dart';

const validBilibili =
    'https://player.bilibili.com/player.html?isOutside=true&bvid=BV1xx411c7mD&cid=123456&p=1';
const missingPBilibili =
    'https://player.bilibili.com/player.html?isOutside=true&bvid=BV1xx411c7mD&cid=123456';
const duplicateCidBilibili =
    'https://player.bilibili.com/player.html?isOutside=true&bvid=BV1xx411c7mD&cid=123456&cid=123457&p=1';

void main() {
  group('decideIframeLoad', () {
    const trustedYoutube = 'https://www.youtube.com/embed/abc123';
    const trustedYoutubeShort = 'https://youtu.be/abc123';
    const trustedTwitter = 'https://platform.twitter.com/embed/Tweet.html?id=1';
    const untrustedHttps = 'https://example.com/embed';
    const invalidScheme = 'http://example.com/embed';
    const invalidUrl = 'not a url';

    test('denyAll masks all iframe URLs without manual load', () {
      expect(
        decideIframeLoad(
          validBilibili,
          policy: IframeLoadPolicy.denyAll,
        ),
        IframeLoadDecision.maskWithoutManualLoad,
      );
      expect(
        decideIframeLoad(
          trustedYoutube,
          policy: IframeLoadPolicy.denyAll,
        ),
        IframeLoadDecision.maskWithoutManualLoad,
      );
      expect(
        decideIframeLoad(
          untrustedHttps,
          policy: IframeLoadPolicy.denyAll,
        ),
        IframeLoadDecision.maskWithoutManualLoad,
      );
    });

    test('allowBilibiliStrict only loads strict bilibili embed directly', () {
      expect(
        decideIframeLoad(
          validBilibili,
          policy: IframeLoadPolicy.allowBilibiliStrict,
        ),
        IframeLoadDecision.loadDirectly,
      );
      expect(
        decideIframeLoad(
          trustedYoutube,
          policy: IframeLoadPolicy.allowBilibiliStrict,
        ),
        IframeLoadDecision.maskWithoutManualLoad,
      );
      expect(
        decideIframeLoad(
          untrustedHttps,
          policy: IframeLoadPolicy.allowBilibiliStrict,
        ),
        IframeLoadDecision.maskWithoutManualLoad,
      );
    });

    test('allowAllRisky loads trusted https directly', () {
      expect(
        decideIframeLoad(
          validBilibili,
          policy: IframeLoadPolicy.allowAllRisky,
        ),
        IframeLoadDecision.loadDirectly,
      );
      expect(
        decideIframeLoad(
          trustedYoutube,
          policy: IframeLoadPolicy.allowAllRisky,
        ),
        IframeLoadDecision.loadDirectly,
      );
      expect(
        decideIframeLoad(
          trustedTwitter,
          policy: IframeLoadPolicy.allowAllRisky,
        ),
        IframeLoadDecision.loadDirectly,
      );
      expect(
        decideIframeLoad(
          trustedYoutubeShort,
          policy: IframeLoadPolicy.allowAllRisky,
        ),
        IframeLoadDecision.loadDirectly,
      );
    });

    test('allowAllRisky masks untrusted https with manual load', () {
      expect(
        decideIframeLoad(
          untrustedHttps,
          policy: IframeLoadPolicy.allowAllRisky,
        ),
        IframeLoadDecision.maskWithManualLoad,
      );
    });

    test('invalid and non-https URLs are always masked without manual load', () {
      expect(
        decideIframeLoad(
          invalidScheme,
          policy: IframeLoadPolicy.allowAllRisky,
        ),
        IframeLoadDecision.maskWithoutManualLoad,
      );
      expect(
        decideIframeLoad(
          invalidUrl,
          policy: IframeLoadPolicy.allowAllRisky,
        ),
        IframeLoadDecision.maskWithoutManualLoad,
      );
    });

    test('legal trusted URL does not depend on detail page context', () {
      expect(
        decideIframeLoad(
          trustedYoutube,
          policy: IframeLoadPolicy.allowAllRisky,
        ),
        IframeLoadDecision.loadDirectly,
      );
      expect(
        decideIframeLoad(
          validBilibili,
          policy: IframeLoadPolicy.allowBilibiliStrict,
        ),
        IframeLoadDecision.loadDirectly,
      );
    });
  });

  group('isTrustedIframeHost', () {
    test('supports trusted subdomains by suffix rules', () {
      expect(
        isTrustedIframeHost(Uri.parse('https://www.youtube.com/embed/id')),
        isTrue,
      );
      expect(
        isTrustedIframeHost(Uri.parse('https://m.youtube.com/embed/id')),
        isTrue,
      );
      expect(
        isTrustedIframeHost(
          Uri.parse('https://sub.youtube-nocookie.com/embed/id'),
        ),
        isTrue,
      );
      expect(
        isTrustedIframeHost(Uri.parse('https://youtu.be/id')),
        isTrue,
      );
      expect(
        isTrustedIframeHost(Uri.parse('https://www.youtu.be/id')),
        isTrue,
      );
      expect(
        isTrustedIframeHost(Uri.parse('https://video.example.com/embed')),
        isFalse,
      );
    });
  });

  group('isStrictBilibiliPlayerEmbed', () {
    test('rejects missing required p and duplicate query keys', () {
      expect(isStrictBilibiliPlayerEmbed(Uri.parse(missingPBilibili)), isFalse);
      expect(
        isStrictBilibiliPlayerEmbed(Uri.parse(duplicateCidBilibili)),
        isFalse,
      );
      expect(isStrictBilibiliPlayerEmbed(Uri.parse(validBilibili)), isTrue);
    });
  });
}
