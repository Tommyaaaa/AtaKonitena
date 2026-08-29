/// 轻量 Markdown 渲染组件（面向内置文档，避免引入重型依赖）。
/// 支持：标题 #、段落、代码块 ```、无/有序列表、分隔线 ——、行内 `code` 与 **粗体**。
library;

import 'package:flutter/material.dart';

class MarkdownView extends StatefulWidget {
  final String text;
  const MarkdownView({super.key, required this.text});

  @override
  State<MarkdownView> createState() => _MarkdownViewState();
}

class _MarkdownViewState extends State<MarkdownView> {
  @override
  Widget build(BuildContext context) {
    final blocks = _parseBlocks(widget.text);
    final children = <Widget>[];
    for (final b in blocks) {
      children.add(_block(b));
      children.add(const SizedBox(height: 8));
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
      children: children,
    );
  }

  Widget _block(Block b) {
    final scheme = Theme.of(context).colorScheme;
    switch (b) {
      case Heading(:final level, :final text):
        return Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(
            text,
            style: level == 1
                ? const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)
                : level == 2
                    ? const TextStyle(fontSize: 19, fontWeight: FontWeight.bold)
                    : const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w600),
          ),
        );
      case Paragraph(:final text):
        return Text.rich(_inline(text),
            style: TextStyle(color: scheme.onSurface, height: 1.6));
      case CodeBlock(:final code):
        return Container(
          width: double.infinity,
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF12161D),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFF232A34)),
          ),
          child: SelectableText(code,
              style: const TextStyle(
                  fontFamily: 'monospace', fontSize: 12.5, height: 1.5)),
        );
      case BulletList(:final items):
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final it in items)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('•  ', style: TextStyle(color: Color(0xFF8B93A1))),
                    Expanded(child: Text.rich(_inline(it))),
                  ],
                ),
              ),
          ],
        );
      case NumberedList(:final items):
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < items.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${i + 1}.  ',
                        style: const TextStyle(color: Color(0xFF8B93A1))),
                    Expanded(child: Text.rich(_inline(items[i]))),
                  ],
                ),
              ),
          ],
        );
      case Hr():
        return const Divider(height: 20);
    }
  }

  TextSpan _inline(String s) {
    final spans = <TextSpan>[];
    final buf = StringBuffer();
    var i = 0;
    final scheme = Theme.of(context).colorScheme;
    void flush() {
      if (buf.isNotEmpty) {
        spans.add(TextSpan(text: buf.toString()));
        buf.clear();
      }
    }

    while (i < s.length) {
      final c = s[i];
      if (c == '`') {
        flush();
        final end = s.indexOf('`', i + 1);
        if (end == -1) {
          buf.write(s.substring(i));
          break;
        }
        spans.add(TextSpan(
            text: s.substring(i + 1, end),
            style: const TextStyle(
                fontFamily: 'monospace',
                color: Color(0xFF79C0FF),
                backgroundColor: Color(0xFF161B22))));
        i = end + 1;
      } else if (c == '*' && i + 1 < s.length && s[i + 1] == '*') {
        flush();
        final end = s.indexOf('**', i + 2);
        if (end == -1) {
          buf.write(s.substring(i));
          break;
        }
        spans.add(TextSpan(
            text: s.substring(i + 2, end),
            style: const TextStyle(fontWeight: FontWeight.bold)));
        i = end + 2;
      } else {
        buf.write(c);
        i++;
      }
    }
    flush();
    return TextSpan(
        style: TextStyle(color: scheme.onSurface, height: 1.6),
        children: spans);
  }

  List<Block> _parseBlocks(String text) {
    final lines = text.split('\n');
    final blocks = <Block>[];
    final paragraph = <String>[];
    final bullets = <String>[];
    final numbered = <String>[];
    var inCode = false;
    final codeBuffer = StringBuffer();

    void flushParagraph() {
      if (paragraph.isNotEmpty) {
        blocks.add(Paragraph(paragraph.join('\n')));
        paragraph.clear();
      }
    }

    void flushLists() {
      if (bullets.isNotEmpty) {
        blocks.add(BulletList(List.of(bullets)));
        bullets.clear();
      }
      if (numbered.isNotEmpty) {
        blocks.add(NumberedList(List.of(numbered)));
        numbered.clear();
      }
    }

    for (final raw in lines) {
      final line = raw.endsWith('\r') ? raw.substring(0, raw.length - 1) : raw;
      final t = line.trim();
      if (t.startsWith('```')) {
        if (!inCode) {
          flushParagraph();
          flushLists();
          inCode = true;
          codeBuffer.clear();
        } else {
          blocks.add(CodeBlock(codeBuffer.toString()));
          codeBuffer.clear();
          inCode = false;
        }
        continue;
      }
      if (inCode) {
        codeBuffer.writeln(line);
        continue;
      }
      if (t.isEmpty) {
        flushParagraph();
        flushLists();
        continue;
      }
      if (t.startsWith('---') || t.startsWith('***')) {
        flushParagraph();
        flushLists();
        blocks.add(const Hr());
        continue;
      }
      if (t.startsWith('#') && t.length > 1 && t[1] == ' ') {
        flushParagraph();
        flushLists();
        final match = RegExp(r'^#+').firstMatch(t);
        final level = match == null ? 1 : match[0]!.length;
        blocks.add(Heading(level, t.substring(level).trim()));
        continue;
      }
      if (t.startsWith('> ')) {
        flushParagraph();
        flushLists();
        paragraph.add(t.substring(2));
        continue;
      }
      if (t.startsWith('- ') || t.startsWith('* ')) {
        flushParagraph();
        numbered.clear();
        bullets.add(t.substring(2));
        continue;
      }
      if (RegExp(r'^\d+\.\s').hasMatch(t)) {
        flushParagraph();
        bullets.clear();
        numbered.add(t.replaceFirst(RegExp(r'^\d+\.\s'), ''));
        continue;
      }
      flushLists();
      paragraph.add(line);
    }
    flushParagraph();
    flushLists();
    if (inCode && codeBuffer.isNotEmpty) {
      blocks.add(CodeBlock(codeBuffer.toString()));
    }
    return blocks;
  }
}

sealed class Block {
  const Block();
}

class Heading extends Block {
  final int level;
  final String text;
  Heading(this.level, this.text);
}

class Paragraph extends Block {
  final String text;
  Paragraph(this.text);
}

class CodeBlock extends Block {
  final String code;
  CodeBlock(this.code);
}

class BulletList extends Block {
  final List<String> items;
  BulletList(this.items);
}

class NumberedList extends Block {
  final List<String> items;
  NumberedList(this.items);
}

class Hr extends Block {
  const Hr();
}