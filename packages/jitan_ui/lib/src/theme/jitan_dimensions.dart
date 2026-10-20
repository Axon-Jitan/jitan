/// Spacing, radii and sizes measured from the Figma web screens
/// (1440 × 1024 frames).
abstract final class JitanDimensions {
  // Web layout
  static const sidebarWidth = 240.0;

  /// Page insets: content is 1120 px wide in a 1200 px main area, so the
  /// right inset is larger than the left.
  static const pagePaddingStart = 32.0;
  static const pagePaddingEnd = 48.0;
  static const pagePaddingVertical = 32.0;

  /// Below this width the sidebar collapses into a drawer.
  static const compactLayoutBreakpoint = 900.0;

  /// Widest a page gets (content 1120 px + page padding 32 + 48), as in
  /// Figma; wider windows centre it.
  static const pageMaxWidth = 1200.0;

  // Sidebar
  static const sidebarHorizontalPadding = 24.0;
  static const sidebarLogoInset = 28.0;
  static const navItemHeight = 42.0;
  static const navItemSpacing = 6.0;
  static const navItemRadius = 10.0;
  static const navItemTextInset = 16.0;

  // Surfaces
  static const toolbarCardRadius = 16.0;
  static const tableCardRadius = 18.0;
  static const inputRadius = 12.0;
  static const controlHeight = 40.0;
  static const toolbarPadding = 12.0;
  static const searchFieldWidth = 380.0;

  /// The labelled search of a filter toolbar (Schedules, Companies, …).
  static const filterSearchWidth = 420.0;

  // Modals and forms
  static const modalRadius = 24.0;
  static const modalPadding = 28.0;
  static const modalWidth = 720.0;
  static const fieldHeight = 44.0;
  static const fieldWidth = 300.0;
  static const fieldColumnGap = 32.0;
  static const fieldRowGap = 30.0;
  static const fieldLabelGap = 8.0;

  // Tables
  static const tableHorizontalPadding = 20.0;
  static const tableHeaderHeight = 46.0;
  static const tableRowHeight = 44.0;
  static const tableMinHeight = 520.0;

  /// Height of a table card's loading, empty or error state; a loaded table
  /// is as tall as its rows instead.
  static const tableStateHeight = 320.0;

  /// From here a long table scrolls its rows under a fixed header.
  static const tableMaxHeight = 640.0;

  // Vertical rhythm on list pages
  static const headerToToolbar = 44.0;
  static const toolbarToTable = 20.0;
}
