import 'package:flutter/material.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import 'package:get/get.dart';
import 'package:html/dom.dart' as dom;
import 'package:inter_knot/components/iframe_player.dart';
import 'package:inter_knot/controllers/data.dart';
import 'package:inter_knot/helpers/iframe_policy.dart';

class InterKnotHtmlFactory extends WidgetFactory {
  @override
  bool get webView => false;
}

class MyHtmlWidget extends StatelessWidget {
  const MyHtmlWidget({
    super.key,
    required this.html,
    this.textStyle,
    this.inDiscussionDetail = false,
  });

  final String html;
  final TextStyle? textStyle;
  final bool inDiscussionDetail;

  double _iframeAspectRatio(dom.Element element) {
    final widthRaw = element.attributes['width'];
    final heightRaw = element.attributes['height'];
    final width = double.tryParse(widthRaw ?? '');
    final height = double.tryParse(heightRaw ?? '');
    if (width == null || height == null || width <= 0 || height <= 0) {
      return 16 / 9;
    }
    return width / height;
  }

  Map<String, String>? _customStylesBuilder(dom.Element element) {
    final tagName = element.localName?.toLowerCase();

    // 代码块样式：不换行
    if (tagName == 'code' || tagName == 'pre') {
      return {
        'white-space': 'nowrap',
      };
    }

    return null;
  }

  /// 构建表格的自定义样式，适配深色主题
  Map<String, String>? _tableStylesBuilder(dom.Element element) {
    final tagName = element.localName?.toLowerCase();

    // 表格样式：添加边框 + 不换行 + 宽度自适应
    if (tagName == 'table') {
      return {
        'border': '1px solid #555',
        'border-collapse': 'collapse',
        'white-space': 'nowrap',
        'width': 'auto',
        'min-width': '100%',
      };
    }
    if (tagName == 'tr') {
      return {
        'white-space': 'nowrap',
      };
    }
    if (tagName == 'td' || tagName == 'th') {
      // 读取 align 属性支持 Markdown 表格对齐语法
      final align = element.attributes['align']?.toLowerCase();
      final isHeader = tagName == 'th';

      final styles = <String, String>{
        'border': '1px solid #555',
        'padding': '10px 14px',
        'white-space': 'nowrap',
      };

      if (isHeader) {
        styles['background-color'] = '#2a2a2a';
        styles['font-weight'] = 'bold';
        styles['color'] = '#ffffff';
      } else {
        styles['color'] = '#e0e0e0';
      }

      // 处理对齐：优先使用 align 属性，表头默认居中，数据单元格默认左对齐
      if (align == 'center') {
        styles['text-align'] = 'center';
      } else if (align == 'right') {
        styles['text-align'] = 'right';
      } else if (align == 'left') {
        styles['text-align'] = 'left';
      } else if (isHeader) {
        styles['text-align'] = 'center'; // 表头默认居中
      } else {
        styles['text-align'] = 'left'; // 数据单元格默认左对齐
      }

      return styles;
    }

    // 其他元素使用默认样式
    return _customStylesBuilder(element);
  }

  @override
  Widget build(BuildContext context) {
    final c = Get.find<Controller>();
    return HtmlWidget(
      html,
      factoryBuilder: () => InterKnotHtmlFactory(),
      customStylesBuilder: _customStylesBuilder,
      customWidgetBuilder: (element) {
        // 处理 iframe 视频嵌入
        if (element.localName == 'iframe') {
          final rawSrc =
              element.attributes['src'] ?? element.attributes['data-src'] ?? '';
          final src = rawSrc.startsWith('//') ? 'https:$rawSrc' : rawSrc;
          if (src.isEmpty) return const SizedBox.shrink();
          final decision = c.getIframeLoadDecision(
            src,
            inDiscussionDetail: inDiscussionDetail,
          );
          return _IframeGate(
            url: src,
            aspectRatio: _iframeAspectRatio(element),
            active: inDiscussionDetail,
            decision: decision,
            textStyle: textStyle,
          );
        }

        // 处理表格：添加横向滚动容器
        if (element.localName == 'table') {
          return _ScrollableTable(
            tableHtml: element.outerHtml,
            textStyle: textStyle,
            tableStylesBuilder: _tableStylesBuilder,
          );
        }

        return null;
      },
      textStyle: textStyle,
    );
  }
}

class _IframeGate extends StatefulWidget {
  const _IframeGate({
    required this.url,
    required this.aspectRatio,
    required this.active,
    required this.decision,
    required this.textStyle,
  });

  final String url;
  final double aspectRatio;
  final bool active;
  final IframeLoadDecision decision;
  final TextStyle? textStyle;

  @override
  State<_IframeGate> createState() => _IframeGateState();
}

class _IframeGateState extends State<_IframeGate> {
  var _manualAllowed = false;

  @override
  void didUpdateWidget(covariant _IframeGate oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url || oldWidget.decision != widget.decision) {
      _manualAllowed = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final canLoadDirectly = widget.decision == IframeLoadDecision.loadDirectly;
    if ((canLoadDirectly || _manualAllowed) && widget.active) {
      return IframePlayer(
        url: widget.url,
        aspectRatio: widget.aspectRatio,
        active: widget.active,
      );
    }
    if (canLoadDirectly) {
      return _IframeInactivePlaceholder(
        aspectRatio: widget.aspectRatio,
        textStyle: widget.textStyle,
      );
    }
    final canManualLoad =
        widget.decision == IframeLoadDecision.maskWithManualLoad;
    return _IframeMask(
      url: widget.url,
      aspectRatio: widget.aspectRatio,
      warningText: '未经验证的页面，不保证内容安全'.tr,
      extraHintText: widget.active ? null : 'Enter discussion to load iframe'.tr,
      textStyle: widget.textStyle,
      canManualLoad: canManualLoad && widget.active,
      onLoad: () => setState(() => _manualAllowed = true),
    );
  }
}

class _IframeInactivePlaceholder extends StatelessWidget {
  const _IframeInactivePlaceholder({
    required this.aspectRatio,
    required this.textStyle,
  });

  final double aspectRatio;
  final TextStyle? textStyle;

  @override
  Widget build(BuildContext context) {
    final infoTextStyle = textStyle?.copyWith(
          color: const Color(0xff9A9A98),
          fontSize: 12,
        ) ??
        const TextStyle(
          color: Color(0xff9A9A98),
          fontSize: 12,
        );
    return AspectRatio(
      aspectRatio: aspectRatio,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0x331A1A1A),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0x66555555)),
        ),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text(
            'Enter discussion to load iframe'.tr,
            style: infoTextStyle,
          ),
        ),
      ),
    );
  }
}

class _IframeMask extends StatelessWidget {
  const _IframeMask({
    required this.url,
    required this.aspectRatio,
    required this.warningText,
    required this.extraHintText,
    required this.textStyle,
    required this.canManualLoad,
    required this.onLoad,
  });

  final String url;
  final double aspectRatio;
  final String warningText;
  final String? extraHintText;
  final TextStyle? textStyle;
  final bool canManualLoad;
  final VoidCallback onLoad;

  @override
  Widget build(BuildContext context) {
    final primaryTextStyle = textStyle?.copyWith(
          color: const Color(0xffB3B3B1),
          fontSize: 14,
        ) ??
        const TextStyle(
          color: Color(0xffB3B3B1),
          fontSize: 14,
        );
    return AspectRatio(
      aspectRatio: aspectRatio,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0x331A1A1A),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0x66555555)),
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Blocked external iframe'.tr, style: primaryTextStyle),
              const SizedBox(height: 6),
              Text(
                warningText,
                style: primaryTextStyle.copyWith(
                  color: const Color(0xff9A9A98),
                  fontSize: 12,
                ),
              ),
              if (extraHintText != null) ...[
                const SizedBox(height: 6),
                Text(
                  extraHintText!,
                  style: primaryTextStyle.copyWith(
                    color: const Color(0xff8A8A88),
                    fontSize: 12,
                  ),
                ),
              ],
              const SizedBox(height: 8),
              Text(
                '${'原始URL'.tr}: $url',
                style: primaryTextStyle.copyWith(
                  fontSize: 12,
                  color: const Color(0xff8A8A88),
                ),
              ),
              if (canManualLoad) ...[
                const SizedBox(height: 10),
                OutlinedButton(
                  onPressed: onLoad,
                  child: Text('加载内容'.tr),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// 可横向滚动的表格组件
class _ScrollableTable extends StatelessWidget {
  const _ScrollableTable({
    required this.tableHtml,
    this.textStyle,
    required this.tableStylesBuilder,
  });

  final String tableHtml;
  final TextStyle? textStyle;
  final Map<String, String>? Function(dom.Element) tableStylesBuilder;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFF555555)),
        borderRadius: BorderRadius.circular(8),
        color: const Color(0xFF1e1e1e),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(7),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minWidth: MediaQuery.of(context).size.width - 32,
            ),
            child: HtmlWidget(
              tableHtml,
              factoryBuilder: () => InterKnotHtmlFactory(),
              customStylesBuilder: tableStylesBuilder,
              textStyle: textStyle?.copyWith(
                fontSize: 14,
                height: 1.5,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
