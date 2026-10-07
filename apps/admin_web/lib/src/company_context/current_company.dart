import 'package:flutter/widgets.dart';
import 'package:jitan_models/jitan_models.dart';

/// The company HR/Admin is currently working in.
///
/// Company-scoped pages (Employees, …) show data for this company only and
/// never mix companies. `null` until a company is chosen; nothing picks one
/// automatically. Today only the development selector sets it. The final
/// company switcher is not designed yet (PRODUCT-CLARIFY-EMPLOYEES-LIST).
class CurrentCompanyController extends ChangeNotifier {
  CompanySummary? _company;
  CompanySummary? get company => _company;

  void select(CompanySummary? company) {
    if (company?.id == _company?.id) return;
    _company = company;
    notifyListeners();
  }
}

/// Makes the [CurrentCompanyController] available below it.
class CurrentCompanyScope extends InheritedNotifier<CurrentCompanyController> {
  const CurrentCompanyScope({super.key, required CurrentCompanyController controller, required super.child})
    : super(notifier: controller);

  /// The controller, rebuilding [context] when the company changes.
  static CurrentCompanyController of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<CurrentCompanyScope>();
    assert(scope != null, 'No CurrentCompanyScope above this widget.');
    return scope!.notifier!;
  }
}
