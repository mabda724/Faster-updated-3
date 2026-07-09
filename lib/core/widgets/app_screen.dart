import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../theme/design_tokens.dart';
import 'app_app_bar.dart';
import 'app_empty_state.dart';
import 'app_skeleton.dart';

/// Unified screen Scaffold for the Faster app.
/// Provides: adaptive background, optional AppBar, loading & empty states,
/// pull‑to‑refresh, and safe‑area padding.
///
/// **USAGE:**
/// ```dart
/// AppScreen(
///   title: 'Orders',
///   isLoading: _isLoading,
///   emptyState: _orders.isEmpty ? AppEmptyState(...) : null,
///   onRefresh: _load,
///   body: ListView.builder(...),
/// )
/// ```
class AppScreen extends StatelessWidget {
  final String? title;
  final Widget body;
  final bool? resizeToAvoidBottomInset;
  final Color? backgroundColor;
  final Widget? floatingActionButton;
  final Widget? bottomNavigationBar;
  final List<Widget>? actions;
  final PreferredSizeWidget? customAppBar;
  final bool isLoading;
  final AppEmptyState? emptyState;
  final Future<void> Function()? onRefresh;
  final bool showBackButton;

  const AppScreen({
    super.key,
    this.title,
    required this.body,
    this.resizeToAvoidBottomInset,
    this.backgroundColor,
    this.floatingActionButton,
    this.bottomNavigationBar,
    this.actions,
    this.customAppBar,
    this.isLoading = false,
    this.emptyState,
    this.onRefresh,
    this.showBackButton = true,
  });

  @override
  Widget build(BuildContext context) {
    Widget content = body;

    if (isLoading) {
      content = const Center(child: AppSkeletonLoader());
    } else if (emptyState != null) {
      content = emptyState!;
    }

    if (onRefresh != null && !isLoading) {
      content = RefreshIndicator(
        onRefresh: onRefresh!,
        color: AppTheme.primaryColor,
        backgroundColor: AppTheme.adaptiveSurface(context),
        child: content is ScrollView ? content : SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: MediaQuery.of(context).size.height - kToolbarHeight),
            child: content,
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: backgroundColor ?? AppTheme.adaptiveBackground(context),
      resizeToAvoidBottomInset: resizeToAvoidBottomInset ?? true,
      appBar: customAppBar ?? (title != null
          ? AppAppBar(
              title: title!,
              actions: actions,
              automaticallyImplyLeading: showBackButton,
            )
          : null),
      body: SafeArea(child: content),
      floatingActionButton: isLoading ? null : floatingActionButton,
      bottomNavigationBar: bottomNavigationBar,
    );
  }
}
