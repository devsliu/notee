import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:markdown/markdown.dart' as md;

class CustomMarkdownCodeBlockParser extends CustomMarkdownParser {
  const CustomMarkdownCodeBlockParser();

  @override
  List<Node> transform(
    md.Node element,
    List<CustomMarkdownParser> parsers, {
    MarkdownListType listType = MarkdownListType.unknown,
    int? startNumber,
  }) {
    if (element is! md.Element) {
      return [];
    }

    if (element.tag != 'pre') {
      return [];
    }

    final codeElement = _findCodeElement(element);
    final language = _extractLanguage(codeElement);
    final content = element.textContent;

    final delta = Delta()..insert(content);

    return [
      Node(type: 'code', attributes: {'delta': delta.toJson(), if (language.isNotEmpty) 'language': language}),
    ];
  }

  md.Element? _findCodeElement(md.Element preElement) {
    final children = preElement.children;
    if (children == null) {
      return null;
    }
    for (final child in children) {
      if (child is md.Element && child.tag == 'code') {
        return child;
      }
    }
    return null;
  }

  String _extractLanguage(md.Element? codeElement) {
    if (codeElement == null) {
      return '';
    }
    final classes = codeElement.attributes['class'];
    if (classes == null) {
      return '';
    }
    for (final cls in classes.split(' ')) {
      if (cls.startsWith('language-')) {
        return cls.substring('language-'.length);
      }
    }
    return '';
  }
}
