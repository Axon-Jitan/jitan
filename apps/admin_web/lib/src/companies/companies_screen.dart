import 'package:flutter/material.dart';
import 'package:jitan_api_client/jitan_api_client.dart';
import 'package:jitan_ui/jitan_ui.dart';

import '../common/api_failure_text.dart';
import '../l10n/admin_strings.dart';
import 'companies_controller.dart';
import 'companies_table.dart';

/// HR/Admin "Companies" page (Figma `Admin / Companies` 153:35,
/// `HR / Companies` 153:804).
///
/// "Add company" (Figma) is not shown yet: it arrives with the Add company
/// slice so the page never offers a button that does nothing.
class CompaniesScreen extends StatefulWidget {
  const CompaniesScreen({super.key, required this.api, this.clock = DateTime.now});

  final CompaniesApi api;
  final DateTime Function() clock;

  @override
  State<CompaniesScreen> createState() => _CompaniesScreenState();
}

class _CompaniesScreenState extends State<CompaniesScreen> {
  late final CompaniesController _controller = CompaniesController(widget.api)..load();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
        padding: const EdgeInsetsDirectional.fromSTEB(
          JitanDimensions.pagePaddingStart,
          JitanDimensions.pagePaddingVertical,
          JitanDimensions.pagePaddingEnd,
          JitanDimensions.pagePaddingVertical,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            JitanPageHeader(
              title: AdminStrings.companiesTitle,
              subtitle: AdminStrings.companiesSubtitle,
            ),
            const SizedBox(height: JitanDimensions.headerToToolbar),
            JitanSurfaceCard(
              radius: JitanDimensions.toolbarCardRadius,
              padding: const EdgeInsets.all(JitanDimensions.toolbarPadding),
              child: Align(
                alignment: Alignment.centerLeft,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: JitanDimensions.searchFieldWidth),
                  child: JitanSearchField(
                    hintText: AdminStrings.companiesSearchHint,
                    onChanged: _controller.updateSearch,
                  ),
                ),
              ),
            ),
            const SizedBox(height: JitanDimensions.toolbarToTable),
            JitanSurfaceCard(
              radius: JitanDimensions.tableCardRadius,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: JitanDimensions.tableMinHeight),
                child: ListenableBuilder(
                  listenable: _controller,
                  builder: (context, _) => _content(_controller.state),
                ),
              ),
            ),
          ],
        ),
      );

  Widget _content(CompaniesState state) => switch (state) {
        CompaniesLoading() => _centered(JitanLoadingState(label: AdminStrings.companiesLoading)),
        CompaniesFailed(:final failure) => _centered(_error(failure)),
        CompaniesLoaded(companies: [], search: '') => _centered(
            JitanEmptyState(
              title: AdminStrings.companiesEmptyTitle,
              message: AdminStrings.companiesEmptyMessage,
            ),
          ),
        CompaniesLoaded(companies: [], :final search) => _centered(
            JitanEmptyState(
              title: AdminStrings.companiesNoMatchTitle,
              message: AdminStrings.companiesNoMatchMessage(search),
            ),
          ),
        CompaniesLoaded(:final companies) => CompaniesTable(companies: companies, now: widget.clock()),
      };

  Widget _error(ApiClientException failure) {
    final text = failureTextFor(failure);
    return JitanErrorState(
      title: text.title,
      message: text.message,
      retryLabel: AdminStrings.retry,
      onRetry: _controller.load,
    );
  }

  static Widget _centered(Widget child) =>
      SizedBox(height: JitanDimensions.tableMinHeight, child: child);
}
