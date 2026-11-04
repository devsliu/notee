import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:flutter/material.dart';

class CodeBlockKeys {
  const CodeBlockKeys._();
  static const String type = 'code';
  static const String language = 'language';
}

class CodeBlockComponentBuilder extends BlockComponentBuilder {
  CodeBlockComponentBuilder({super.configuration, this.backgroundColor, this.textStyle, this.showLanguage = true});

  final Color? backgroundColor;
  final TextStyle? textStyle;
  final bool showLanguage;

  @override
  BlockComponentWidget build(BlockComponentContext blockComponentContext) {
    final node = blockComponentContext.node;

    return CodeBlockComponentWidget(
      key: node.key,
      node: node,
      configuration: configuration,
      backgroundColor: backgroundColor,
      textStyle: textStyle,
      showLanguage: showLanguage,
      showActions: showActions(node),
      actionBuilder: (context, state) => actionBuilder(blockComponentContext, state),
      actionTrailingBuilder: (context, state) => actionTrailingBuilder(blockComponentContext, state),
    );
  }

  @override
  BlockComponentValidate get validate =>
      (node) => node.delta != null;
}

class CodeBlockComponentWidget extends BlockComponentStatefulWidget {
  const CodeBlockComponentWidget({
    super.key,
    required super.node,
    super.showActions,
    super.actionBuilder,
    super.actionTrailingBuilder,
    super.configuration = const BlockComponentConfiguration(),
    this.backgroundColor,
    this.textStyle,
    this.showLanguage = true,
  });

  final Color? backgroundColor;
  final TextStyle? textStyle;
  final bool showLanguage;

  @override
  State<CodeBlockComponentWidget> createState() => _CodeBlockComponentWidgetState();
}

class _CodeBlockComponentWidgetState extends State<CodeBlockComponentWidget>
    with
        SelectableMixin,
        DefaultSelectableMixin,
        BlockComponentConfigurable,
        BlockComponentBackgroundColorMixin,
        NestedBlockComponentStatefulWidgetMixin,
        BlockComponentTextDirectionMixin,
        BlockComponentAlignMixin {
  @override
  final forwardKey = GlobalKey(debugLabel: 'code_rich_text');

  @override
  GlobalKey<State<StatefulWidget>> get containerKey => widget.node.key;

  @override
  GlobalKey<State<StatefulWidget>> blockComponentKey = GlobalKey(debugLabel: CodeBlockKeys.type);

  @override
  BlockComponentConfiguration get configuration => widget.configuration;

  @override
  Node get node => widget.node;

  @override
  Widget buildComponent(BuildContext context, {bool withBackgroundColor = true}) {
    final textDirection = calculateTextDirection(layoutDirection: Directionality.maybeOf(context));

    final language = node.attributes[CodeBlockKeys.language] ?? '';
    final effectiveBgColor =
        widget.backgroundColor ??
        (Theme.of(context).brightness == Brightness.dark ? Colors.white.withAlpha(25) : Colors.black.withAlpha(12));

    Widget richText = AppFlowyRichText(
      key: forwardKey,
      delegate: this,
      node: widget.node,
      editorState: editorState,
      textAlign: alignment?.toTextAlign ?? textAlign,
      placeholderText: '',
      textSpanDecorator: (textSpan) {
        final baseStyle =
            widget.textStyle ??
            TextStyle(fontFamily: 'monospace', fontSize: 14, color: Theme.of(context).colorScheme.onSurface);
        return textSpan.updateTextStyle(baseStyle).updateTextStyle(textStyleWithTextSpan(textSpan: textSpan));
      },
      textDirection: textDirection,
      cursorColor: editorState.editorStyle.cursorColor,
      selectionColor: editorState.editorStyle.selectionColor,
      cursorWidth: editorState.editorStyle.cursorWidth,
    );

    Widget child = Container(
      width: double.infinity,
      decoration: BoxDecoration(color: effectiveBgColor, borderRadius: BorderRadius.circular(4)),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        textDirection: textDirection,
        children: [
          if (widget.showLanguage && language.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                language,
                style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurface.withAlpha(128)),
              ),
            ),
          richText,
        ],
      ),
    );

    child = BlockSelectionContainer(
      key: blockComponentKey,
      node: node,
      delegate: this,
      listenable: editorState.selectionNotifier,
      remoteSelection: editorState.remoteSelections,
      blockColor: editorState.editorStyle.selectionColor,
      supportTypes: const [BlockSelectionType.block],
      child: Padding(padding: padding, child: child),
    );

    if (widget.showActions && widget.actionBuilder != null) {
      child = BlockComponentActionWrapper(
        node: node,
        actionBuilder: widget.actionBuilder!,
        actionTrailingBuilder: widget.actionTrailingBuilder,
        child: child,
      );
    }

    return child;
  }
}
