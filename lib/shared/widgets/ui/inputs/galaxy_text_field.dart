import 'package:flutter/material.dart';

class GalaxyTextField extends StatefulWidget {
  final TextEditingController controller;
  final String? label;
  final String? hintText;

  final TextInputType? keyboardType;
  final bool obscureText;
  final bool enabled;
  final bool readOnly;

  final int? maxLength;
  final String? Function(String?)? validator;
  final String? errorText;

  final FocusNode? focusNode;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onTap;

  final Widget? prefixIcon;
  final Widget? suffix;

  const GalaxyTextField({
    super.key,
    required this.controller,
    this.label,
    this.hintText,
    this.keyboardType,
    this.obscureText = false,
    this.enabled = true,
    this.readOnly = false,
    this.maxLength,
    this.validator,
    this.errorText,
    this.focusNode,
    this.onChanged,
    this.onTap,
    this.prefixIcon,
    this.suffix,
  });

  @override
  State<GalaxyTextField> createState() => _GalaxyTextFieldState();
}

class _GalaxyTextFieldState extends State<GalaxyTextField> {
  late bool _obscured;

  @override
  void initState() {
    super.initState();
    _obscured = widget.obscureText;
  }

  @override
  void didUpdateWidget(covariant GalaxyTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.obscureText != widget.obscureText) {
      _obscured = widget.obscureText;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    final borderRadius = BorderRadius.circular(12);

    return TextFormField(
      controller: widget.controller,
      focusNode: widget.focusNode,
      onChanged: widget.onChanged,
      onTap: widget.onTap,
      keyboardType: widget.keyboardType,
      obscureText: _obscured,
      enabled: widget.enabled,
      readOnly: widget.readOnly,
      maxLength: widget.maxLength,
      validator: widget.validator,

      style: TextStyle(color: colorScheme.onSurface),

      decoration: InputDecoration(
        labelText: widget.label,
        hintText: widget.hintText,
        errorText: widget.errorText,

        prefixIcon: widget.prefixIcon,

        suffixIcon: widget.obscureText
            ? IconButton(
                icon: Icon(
                  _obscured
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                ),
                onPressed: () =>
                    setState(() => _obscured = !_obscured),
              )
            : widget.suffix,

        enabledBorder: OutlineInputBorder(
          borderRadius: borderRadius,
          borderSide: BorderSide(
            color: colorScheme.outline.withOpacity(0.5),
          ),
        ),

        focusedBorder: OutlineInputBorder(
          borderRadius: borderRadius,
          borderSide: BorderSide(
            color: colorScheme.primary,
            width: 1.5,
          ),
        ),

        errorBorder: OutlineInputBorder(
          borderRadius: borderRadius,
          borderSide: BorderSide(
            color: colorScheme.error.withOpacity(0.5),
          ),
        ),

        focusedErrorBorder: OutlineInputBorder(
          borderRadius: borderRadius,
          borderSide: BorderSide(
            color: colorScheme.error,
            width: 1.5,
          ),
        ),

        filled: true,
        fillColor: Colors.transparent,
      ),
    );
  }
}