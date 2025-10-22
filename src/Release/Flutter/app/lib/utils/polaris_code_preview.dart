import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:ionicons/ionicons.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'dart:html' as html;
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:animated_tree_view/animated_tree_view.dart';
import 'package:app/utils/polariscode_util.dart';
import 'package:app/utils/polaris_code_language.dart';




abstract class MyExpansionIndicator extends ExpansionIndicator {
  MyExpansionIndicator({
    super.key,
    required super.tree,
    super.alignment = Alignment.topRight,
    super.padding = EdgeInsets.zero,
    super.curve = Curves.easeOut,
    super.color,
  });
}

abstract class MyExpansionIndicatorState<T extends MyExpansionIndicator>
    extends State<T> with TickerProviderStateMixin {
  Duration animationDuration = Duration(milliseconds: 300);
  late final AnimationController _controller = AnimationController(
    duration: animationDuration,
    vsync: this,
  );

  @override
  void initState() {
    super.initState();
    widget.tree.expansionNotifier.addListener(_onExpandedChangeListener);
    if (widget.tree.isExpanded) _controller.value = 1;
  }

  void _onExpandedChangeListener() {
    if (!mounted) return;

    if (widget.tree.isExpanded)
      _controller.animateTo(1, curve: widget.curve);
    else
      _controller.animateBack(0, curve: widget.curve);
  }

  @override
  void dispose() {
    _controller.dispose();
    widget.tree.removeListener(_onExpandedChangeListener);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container();
  }
}

class MyPlusMinusIndicator extends MyExpansionIndicator {
  MyPlusMinusIndicator({
    required super.tree,
    super.key,
    super.alignment,
    super.padding,
    super.curve = Curves.ease,
    super.color,
    required this.size,
  });

  double size = 24;

  @override
  State<StatefulWidget> createState() => _MyPlusMinusIndicatorState();
}

class _MyPlusMinusIndicatorState
    extends MyExpansionIndicatorState<MyPlusMinusIndicator> {
  late final tween = Tween<double>(begin: 0, end: 0.25);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(
            color: widget.color ?? Theme.of(context).colorScheme.onSurface,
            width: 1,
          ),
        ),
        width: widget.size,
        height: widget.size,
        constraints:
            BoxConstraints(maxWidth: widget.size, maxHeight: widget.size),
        child: Stack(
          alignment: Alignment.center,
          children: [
            RotationTransition(
              turns: tween.animate(_controller),
              child: RotatedBox(
                  quarterTurns: 1,
                  child: Icon(
                    Icons.remove,
                    color: widget.color,
                    size: widget.size - 2,
                  )),
            ),
            Icon(
              Icons.remove,
              color: widget.color,
              size: widget.size - 2,
            ),
          ],
        ),
      ),
    );
  }
}
