import 'package:inter_knot/helpers/chat_mockup_ai_stream_preview.dart';
import 'package:test/test.dart';

void main() {
  group('ChatMockupAiStreamPreview field scan', () {
    test('loose unquoted action with bare value', () {
      const raw = '{ action: hello line }';
      final events = ChatMockupAiStreamPreview.scanDirectorFields(raw);
      expect(events, hasLength(1));
      expect(events[0].kind, ChatMockupAiFieldKind.action);
      expect(events[0].rawValue, 'hello line');
    });

    test('loose single-quoted character key and value', () {
      const raw = "{ 'character': 'hi there' }";
      final events = ChatMockupAiStreamPreview.scanDirectorFields(raw);
      expect(events, hasLength(1));
      expect(events[0].kind, ChatMockupAiFieldKind.character);
      expect(events[0].rawValue, 'hi there');
    });

    test('strict JSON value ends at first closing quote (inner raw quote)', () {
      const raw = '{"character":"他说"你好"}';
      final events = ChatMockupAiStreamPreview.scanDirectorFields(raw);
      expect(events, hasLength(1));
      expect(events[0].kind, ChatMockupAiFieldKind.character);
      expect(events[0].rawValue, '他说');
    });

    test('stream preview emits prefix before closing quote', () {
      const raw = '{"character":"第一句\n第二';
      final stream = ChatMockupAiStreamPreview.scanDirectorFields(
        raw,
        forStreamPreview: true,
      );
      expect(stream, hasLength(1));
      expect(stream[0].kind, ChatMockupAiFieldKind.character);
      expect(stream[0].rawValue, '第一句\n第二');

      final finalizeStyle = ChatMockupAiStreamPreview.scanDirectorFields(raw);
      expect(finalizeStyle, isEmpty);
    });

    test('multiple fields preserve source order', () {
      const raw = '{ action: a\nuser: b\ncharacter: c }';
      final events = ChatMockupAiStreamPreview.scanDirectorFields(raw);
      expect(events.map((e) => e.kind).toList(), [
        ChatMockupAiFieldKind.action,
        ChatMockupAiFieldKind.user,
        ChatMockupAiFieldKind.character,
      ]);
      expect(events.map((e) => e.rawValue).toList(), ['a', 'b', 'c']);
    });

    test('role scan recognizes 用户 then character in order', () {
      const raw = "{'用户':'ignored','character':'left only'}";
      final events = ChatMockupAiStreamPreview.scanRoleOrContinueFields(raw);
      expect(events.map((e) => e.kind).toList(), [
        ChatMockupAiFieldKind.user,
        ChatMockupAiFieldKind.character,
      ]);
    });

    test('mixed strict JSON then loose lines (director)', () {
      const raw = '{"action":"a"\nuser: b\ncharacter: c}';
      final events = ChatMockupAiStreamPreview.scanDirectorFields(raw);
      expect(events.map((e) => e.kind).toList(), [
        ChatMockupAiFieldKind.action,
        ChatMockupAiFieldKind.user,
        ChatMockupAiFieldKind.character,
      ]);
      expect(events.map((e) => e.rawValue).toList(), ['a', 'b', 'c']);
    });

    test('mixed loose then strict then loose (director)', () {
      const raw = 'action: a\n"character":"b"\nuser: c';
      final events = ChatMockupAiStreamPreview.scanDirectorFields(raw);
      expect(events.map((e) => e.kind).toList(), [
        ChatMockupAiFieldKind.action,
        ChatMockupAiFieldKind.character,
        ChatMockupAiFieldKind.user,
      ]);
      expect(events.map((e) => e.rawValue).toList(), ['a', 'b', 'c']);
    });
  });

  group('XML field scan', () {
    test('director two turns preserve action/user/character order', () {
      const raw = '''
<chat>
  <turn>
    <action><![CDATA[动作一]]></action>
    <user><![CDATA[用户一]]></user>
    <character><![CDATA[角色一]]></character>
  </turn>
  <turn>
    <action>动作二</action>
    <user>用户二</user>
    <character>角色二</character>
  </turn>
</chat>''';
      final events = ChatMockupAiStreamPreview.scanDirectorFields(raw);
      expect(events.map((e) => e.kind).toList(), [
        ChatMockupAiFieldKind.action,
        ChatMockupAiFieldKind.user,
        ChatMockupAiFieldKind.character,
        ChatMockupAiFieldKind.action,
        ChatMockupAiFieldKind.user,
        ChatMockupAiFieldKind.character,
      ]);
      expect(events.map((e) => e.rawValue).toList(), [
        '动作一',
        '用户一',
        '角色一',
        '动作二',
        '用户二',
        '角色二',
      ]);
    });

    test('role action and character; user tag does not shift character', () {
      const raw = '''
<chat>
  <action><![CDATA[旁白]]></action>
  <user><![CDATA[不应产出]]></user>
  <character><![CDATA[左气泡]]></character>
</chat>''';
      final events = ChatMockupAiStreamPreview.scanRoleOrContinueFields(raw);
      expect(events.map((e) => e.kind).toList(), [
        ChatMockupAiFieldKind.action,
        ChatMockupAiFieldKind.character,
      ]);
      expect(events.map((e) => e.rawValue).toList(), ['旁白', '左气泡']);
    });

    test('CDATA preserves quotes newlines and angle-bracket-like text', () {
      const raw = '''
<chat>
  <turn>
    <action><![CDATA[他说"你好"
以及 <tag> 不是标签]]></action>
    <user><![CDATA[]]></user>
    <character><![CDATA[中文标点，。！]]></character>
  </turn>
</chat>''';
      final events = ChatMockupAiStreamPreview.scanDirectorFields(raw);
      expect(events[0].rawValue, '他说"你好"\n以及 <tag> 不是标签');
      expect(events[1].rawValue, '');
      expect(events[2].rawValue, '中文标点，。！');
    });

    test('strict stream parser waits for closed character tag', () {
      const partial = '''
<chat>
  <turn>
    <action></action>
    <user></user>
    <character><![CDATA[第一句
第二''';
      final parser = ChatMockupAiXmlStreamFieldParser(directorMode: true);
      expect(
        parser.feed(partial).map((e) => e.kind).toList(),
        [
          ChatMockupAiFieldKind.action,
          ChatMockupAiFieldKind.user,
        ],
      );

      const full = '''
<chat>
  <turn>
    <action></action>
    <user></user>
    <character><![CDATA[第一句
第二]]></character>
  </turn>
</chat>''';
      final events = parser.feed(full);
      expect(events, hasLength(1));
      expect(events.single.kind, ChatMockupAiFieldKind.character);
      expect(events.single.rawValue, '第一句\n第二');
      expect(parser.feed(full), isEmpty);
    });

    test('markdown fence stripped before XML scan', () {
      const raw = '''
```xml
<chat>
  <action><![CDATA[a]]></action>
  <character><![CDATA[b]]></character>
</chat>
```''';
      final events = ChatMockupAiStreamPreview.scanRoleOrContinueFields(raw);
      expect(events.map((e) => e.rawValue).toList(), ['a', 'b']);
    });

    test('plain tag text decodes XML entities', () {
      const raw = '''
<chat>
  <turn>
    <action>&lt;旁白&gt; &amp; 更多</action>
    <user></user>
    <character>角色</character>
  </turn>
</chat>''';
      final events = ChatMockupAiStreamPreview.scanDirectorFields(raw);
      expect(events.first.rawValue, '<旁白> & 更多');
    });
  });

  group('XML strict parse', () {
    test('director returns turns map compatible with JSON builders', () {
      const raw = '''
<chat>
  <turn>
    <action><![CDATA[a1]]></action>
    <user><![CDATA[u1]]></user>
    <character><![CDATA[c1]]></character>
  </turn>
  <turn>
    <action></action>
    <user></user>
    <character>c2</character>
  </turn>
</chat>''';
      final map = ChatMockupAiStreamPreview.tryParseStrictXmlDirector(raw);
      expect(map, isNotNull);
      final turns = map!['turns'] as List;
      expect(turns, hasLength(2));
      expect(turns[0], {
        'action': 'a1',
        'user': 'u1',
        'character': 'c1',
      });
      expect(turns[1], {
        'action': '',
        'user': '',
        'character': 'c2',
      });
    });

    test('role returns action and character map', () {
      const raw = '''
<chat>
  <action><![CDATA[旁白]]></action>
  <character><![CDATA[消息一
消息二]]></character>
</chat>''';
      final map =
          ChatMockupAiStreamPreview.tryParseStrictXmlRoleOrContinue(raw);
      expect(map, {
        'action': '旁白',
        'character': '消息一\n消息二',
      });
    });

    test('malformed XML returns null', () {
      expect(
        ChatMockupAiStreamPreview.tryParseStrictXmlDirector('<chat><turn>'),
        isNull,
      );
    });

    test('strict parse succeeds when explanatory text follows </chat>', () {
      const raw = '''
<chat>
  <turn>
    <action><![CDATA[a]]></action>
    <user><![CDATA[u]]></user>
    <character><![CDATA[c]]></character>
  </turn>
</chat>
以上是生成的对话内容。''';
      final map = ChatMockupAiStreamPreview.tryParseStrictXmlDirector(raw);
      expect(map, isNotNull);
      final turns = map!['turns'] as List;
      expect(turns, hasLength(1));
    });

    test(
        'director two turns with trailing text uses strict parse not field scan bypass',
        () {
      const raw = '''
<chat>
  <turn>
    <action><![CDATA[a1]]></action>
    <user><![CDATA[u1]]></user>
    <character><![CDATA[c1]]></character>
  </turn>
  <turn>
    <action></action>
    <user></user>
    <character>c2</character>
  </turn>
</chat>
说明：共两轮。''';
      final strict = ChatMockupAiStreamPreview.tryParseStrictXmlDirector(raw);
      expect(strict, isNotNull);
      final turns = strict!['turns'] as List;
      expect(turns.length, 2);

      final fieldEvents = ChatMockupAiStreamPreview.scanDirectorFields(raw);
      expect(fieldEvents, isNotEmpty);

      // Strict parse must succeed independently of trailing prose; field scan
      // alone would not enforce turn-count validation during finalize.
      expect(
        ChatMockupAiStreamPreview.preprocessForXmlParse(raw)
            .endsWith('</chat>'),
        isTrue,
      );
      expect(
        ChatMockupAiStreamPreview.preprocessForXmlParse(raw),
        isNot(contains('说明')),
      );
    });
  });

  group('ChatMockupAiXmlStreamFieldParser', () {
    test('complete CDATA character emits one event', () {
      const raw = '''
<chat>
  <turn>
    <action><![CDATA[a]]></action>
    <user><![CDATA[u]]></user>
    <character><![CDATA[c]]></character>
  </turn>
</chat>''';
      final parser = ChatMockupAiXmlStreamFieldParser(directorMode: true);
      final events = parser.feed(raw);
      expect(events.map((e) => e.kind).toList(), [
        ChatMockupAiFieldKind.action,
        ChatMockupAiFieldKind.user,
        ChatMockupAiFieldKind.character,
      ]);
      expect(events.map((e) => e.rawValue).toList(), ['a', 'u', 'c']);
    });

    test('close tag arriving in chunks', () {
      const part1 = '<chat><turn><character>hel';
      const part2 = '<chat><turn><character>hello</character></turn></chat>';
      final parser = ChatMockupAiXmlStreamFieldParser(directorMode: true);
      expect(parser.feed(part1), isEmpty);
      final events = parser.feed(part2);
      expect(events, hasLength(1));
      expect(events.single.rawValue, 'hello');
    });

    test('director two turns preserve order', () {
      const raw = '''
<chat>
  <turn>
    <action><![CDATA[动作一]]></action>
    <user><![CDATA[用户一]]></user>
    <character><![CDATA[角色一]]></character>
  </turn>
  <turn>
    <action>动作二</action>
    <user>用户二</user>
    <character>角色二</character>
  </turn>
</chat>''';
      final parser = ChatMockupAiXmlStreamFieldParser(directorMode: true);
      final events = parser.feed(raw);
      expect(events.map((e) => e.kind).toList(), [
        ChatMockupAiFieldKind.action,
        ChatMockupAiFieldKind.user,
        ChatMockupAiFieldKind.character,
        ChatMockupAiFieldKind.action,
        ChatMockupAiFieldKind.user,
        ChatMockupAiFieldKind.character,
      ]);
    });

    test('role mode skips closed user tag', () {
      const raw = '''
<chat>
  <action><![CDATA[旁白]]></action>
  <user><![CDATA[不应产出]]></user>
  <character><![CDATA[左气泡]]></character>
</chat>''';
      final parser = ChatMockupAiXmlStreamFieldParser(directorMode: false);
      final events = parser.feed(raw);
      expect(events.map((e) => e.kind).toList(), [
        ChatMockupAiFieldKind.action,
        ChatMockupAiFieldKind.character,
      ]);
    });

    test('empty CDATA user still completes field', () {
      const raw = '''
<chat>
  <turn>
    <action><![CDATA[a]]></action>
    <user><![CDATA[]]></user>
    <character><![CDATA[c]]></character>
  </turn>
</chat>''';
      final parser = ChatMockupAiXmlStreamFieldParser(directorMode: true);
      final events = parser.feed(raw);
      expect(events, hasLength(3));
      expect(events[1].kind, ChatMockupAiFieldKind.user);
      expect(events[1].rawValue, '');
    });

    test('duplicate feed does not re-emit', () {
      const raw = '''
<chat>
  <action><![CDATA[a]]></action>
  <character><![CDATA[b]]></character>
</chat>''';
      final parser = ChatMockupAiXmlStreamFieldParser(directorMode: false);
      expect(parser.feed(raw), hasLength(2));
      expect(parser.feed(raw), isEmpty);
    });

    test('CDATA without closing tag emits no event', () {
      const raw = '''
<chat>
  <character><![CDATA[x]]>
</chat>''';
      final parser = ChatMockupAiXmlStreamFieldParser(directorMode: false);
      expect(parser.feed(raw), isEmpty);
    });

    test('CDATA close tag split across chunks emits once', () {
      const part1 = '<chat><character><![CDATA[x]]></charac';
      const part2 = '<chat><character><![CDATA[x]]></character></chat>';
      final parser = ChatMockupAiXmlStreamFieldParser(directorMode: false);
      expect(parser.feed(part1), isEmpty);
      final events = parser.feed(part2);
      expect(events, hasLength(1));
      expect(events.single.kind, ChatMockupAiFieldKind.character);
      expect(events.single.rawValue, 'x');
      expect(parser.feed(part2), isEmpty);
    });

    test('CDATA followed by wrong close tag emits no event', () {
      const raw = '''
<chat>
  <character><![CDATA[x]]></user>
</chat>''';
      final parser = ChatMockupAiXmlStreamFieldParser(directorMode: false);
      expect(parser.feed(raw), isEmpty);
    });

    test('plain text waits for close tag across chunks', () {
      const part1 = '<chat><character>hel';
      const part2 = '<chat><character>hello</character></chat>';
      final parser = ChatMockupAiXmlStreamFieldParser(directorMode: false);
      expect(parser.feed(part1), isEmpty);
      final events = parser.feed(part2);
      expect(events, hasLength(1));
      expect(events.single.rawValue, 'hello');
    });
  });

  group('streamItemDescriptorsFromFieldEvents', () {
    test('multiple events preserve order', () {
      const events = [
        ChatMockupAiFieldEvent(
          kind: ChatMockupAiFieldKind.action,
          rawValue: 'a1',
        ),
        ChatMockupAiFieldEvent(
          kind: ChatMockupAiFieldKind.user,
          rawValue: 'u1',
        ),
        ChatMockupAiFieldEvent(
          kind: ChatMockupAiFieldKind.character,
          rawValue: 'c1',
        ),
      ];
      final items = streamItemDescriptorsFromFieldEvents(
        events,
        startFieldIndex: 0,
        directorMode: true,
      );
      expect(items.map((e) => e.side).toList(), [
        ChatMockupAiStreamItemSide.center,
        ChatMockupAiStreamItemSide.right,
        ChatMockupAiStreamItemSide.left,
      ]);
      expect(items.map((e) => e.text).toList(), ['a1', 'u1', 'c1']);
    });

    test('empty CDATA produces no stream items', () {
      const events = [
        ChatMockupAiFieldEvent(
          kind: ChatMockupAiFieldKind.user,
          rawValue: '',
        ),
      ];
      expect(
        streamItemDescriptorsFromFieldEvents(
          events,
          startFieldIndex: 0,
          directorMode: true,
        ),
        isEmpty,
      );
    });

    test('empty field advances field index but no item', () {
      const events = [
        ChatMockupAiFieldEvent(
          kind: ChatMockupAiFieldKind.action,
          rawValue: 'hello',
        ),
      ];
      final items = streamItemDescriptorsFromFieldEvents(
        events,
        startFieldIndex: 1,
        directorMode: true,
      );
      expect(items, hasLength(1));
      expect(items.single.lineKey, 'f1_a0');
    });

    test('multi-batch quota keeps only first 40 items', () {
      final batch1Events = List.generate(
        25,
        (i) => ChatMockupAiFieldEvent(
          kind: ChatMockupAiFieldKind.character,
          rawValue: 'm$i',
        ),
      );
      final batch2Events = List.generate(
        25,
        (i) => ChatMockupAiFieldEvent(
          kind: ChatMockupAiFieldKind.character,
          rawValue: 'n$i',
        ),
      );
      final batch1 = streamItemDescriptorsFromFieldEvents(
        batch1Events,
        startFieldIndex: 0,
        directorMode: false,
      );
      expect(batch1, hasLength(25));
      final batch2 = streamItemDescriptorsFromFieldEvents(
        batch2Events,
        startFieldIndex: 25,
        directorMode: false,
        totalItemQuotaRemaining: 40 - batch1.length,
      );
      expect(batch2, hasLength(15));
      expect(batch1.length + batch2.length, 40);
    });

    test('continue mode multi-batch keeps only first 5 left messages', () {
      final batch1Events = List.generate(
        3,
        (i) => ChatMockupAiFieldEvent(
          kind: ChatMockupAiFieldKind.character,
          rawValue: 'a$i',
        ),
      );
      final batch2Events = List.generate(
        5,
        (i) => ChatMockupAiFieldEvent(
          kind: ChatMockupAiFieldKind.character,
          rawValue: 'b$i',
        ),
      );
      final batch1 = streamItemDescriptorsFromFieldEvents(
        batch1Events,
        startFieldIndex: 0,
        directorMode: false,
        continueMode: true,
        continueLeftQuotaRemaining: 5,
      );
      expect(batch1, hasLength(3));
      final batch2 = streamItemDescriptorsFromFieldEvents(
        batch2Events,
        startFieldIndex: 3,
        directorMode: false,
        continueMode: true,
        continueLeftQuotaRemaining: 5 - batch1.length,
      );
      expect(batch2, hasLength(2));
      expect(batch1.length + batch2.length, 5);
    });
  });
}
