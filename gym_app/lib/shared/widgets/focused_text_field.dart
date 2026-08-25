import 'package:flutter/material.dart';

class FocusedTextField extends StatefulWidget {
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final InputDecoration decoration;
  final Color focusedFillColor;
  final TextStyle? style;
  final int? maxLines;
  final int? minLines;
  final TextInputAction? textInputAction;
  final TextCapitalization textCapitalization;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final TextInputType? keyboardType;
  final bool obscureText;
  final bool readOnly;
  final GestureTapCallback? onTap;
  final VoidCallback? onEditingComplete;
  final TextAlign textAlign;
  final int? maxLength;
  final bool autofocus;

  const FocusedTextField({
    super.key,
    this.controller,
    this.focusNode,
    required this.decoration,
    required this.focusedFillColor,
    this.style,
    this.maxLines = 1,
    this.minLines,
    this.textInputAction,
    this.textCapitalization = TextCapitalization.none,
    this.onChanged,
    this.onSubmitted,
    this.keyboardType,
    this.obscureText = false,
    this.readOnly = false,
    this.onTap,
    this.onEditingComplete,
    this.textAlign = TextAlign.start,
    this.maxLength,
    this.autofocus = false,
  });

  @override
  State<FocusedTextField> createState() => _FocusedTextFieldState();
}

class FocusedTextFormField extends StatefulWidget {
  final Key? fieldKey;
  final String? initialValue;
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final InputDecoration decoration;
  final Color focusedFillColor;
  final TextStyle? style;
  final int? maxLines;
  final int? minLines;
  final TextInputAction? textInputAction;
  final TextCapitalization textCapitalization;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onFieldSubmitted;
  final TextInputType? keyboardType;
  final bool obscureText;
  final bool autofocus;
  final bool readOnly;
  final GestureTapCallback? onTap;
  final TextAlign textAlign;
  final int? maxLength;

  const FocusedTextFormField({
    super.key,
    this.fieldKey,
    this.initialValue,
    this.controller,
    this.focusNode,
    required this.decoration,
    required this.focusedFillColor,
    this.style,
    this.maxLines = 1,
    this.minLines,
    this.textInputAction,
    this.textCapitalization = TextCapitalization.none,
    this.onChanged,
    this.onFieldSubmitted,
    this.keyboardType,
    this.obscureText = false,
    this.autofocus = false,
    this.readOnly = false,
    this.onTap,
    this.textAlign = TextAlign.start,
    this.maxLength,
  });

  @override
  State<FocusedTextFormField> createState() => _FocusedTextFormFieldState();
}

class _FocusedTextFormFieldState extends State<FocusedTextFormField> {
  late final FocusNode _focusNode;
  late final bool _ownsFocusNode;
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    _ownsFocusNode = widget.focusNode == null;
    _focusNode = widget.focusNode ?? FocusNode();
    _focusNode.addListener(_handleFocusChanged);
    _focused = _focusNode.hasFocus;
  }

  @override
  void dispose() {
    _focusNode.removeListener(_handleFocusChanged);
    if (_ownsFocusNode) _focusNode.dispose();
    super.dispose();
  }

  void _handleFocusChanged() {
    if (mounted) setState(() => _focused = _focusNode.hasFocus);
  }

  @override
  Widget build(BuildContext context) {
    final decoration = widget.decoration.copyWith(
      filled: true,
      fillColor: _focused
          ? widget.focusedFillColor
          : widget.decoration.fillColor,
    );
    return TextFormField(
      key: widget.fieldKey,
      initialValue: widget.initialValue,
      controller: widget.controller,
      focusNode: _focusNode,
      decoration: decoration,
      style: widget.style,
      maxLines: widget.maxLines,
      minLines: widget.minLines,
      textInputAction: widget.textInputAction,
      textCapitalization: widget.textCapitalization,
      onChanged: widget.onChanged,
      onFieldSubmitted: widget.onFieldSubmitted,
      keyboardType: widget.keyboardType,
      obscureText: widget.obscureText,
      autofocus: widget.autofocus,
      readOnly: widget.readOnly,
      onTap: widget.onTap,
      textAlign: widget.textAlign,
      maxLength: widget.maxLength,
    );
  }
}

class _FocusedTextFieldState extends State<FocusedTextField> {
  late final FocusNode _focusNode;
  late final bool _ownsFocusNode;
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    _ownsFocusNode = widget.focusNode == null;
    _focusNode = widget.focusNode ?? FocusNode();
    _focusNode.addListener(_handleFocusChanged);
    _focused = _focusNode.hasFocus;
  }

  @override
  void dispose() {
    _focusNode.removeListener(_handleFocusChanged);
    if (_ownsFocusNode) _focusNode.dispose();
    super.dispose();
  }

  void _handleFocusChanged() {
    if (mounted) setState(() => _focused = _focusNode.hasFocus);
  }

  @override
  Widget build(BuildContext context) {
    final decoration = widget.decoration.copyWith(
      filled: true,
      fillColor: _focused
          ? widget.focusedFillColor
          : widget.decoration.fillColor,
    );
    return TextField(
      controller: widget.controller,
      focusNode: _focusNode,
      decoration: decoration,
      style: widget.style,
      maxLines: widget.maxLines,
      minLines: widget.minLines,
      textInputAction: widget.textInputAction,
      textCapitalization: widget.textCapitalization,
      onChanged: widget.onChanged,
      onSubmitted: widget.onSubmitted,
      keyboardType: widget.keyboardType,
      obscureText: widget.obscureText,
      readOnly: widget.readOnly,
      onTap: widget.onTap,
      onEditingComplete: widget.onEditingComplete,
      textAlign: widget.textAlign,
      maxLength: widget.maxLength,
      autofocus: widget.autofocus,
    );
  }
}
