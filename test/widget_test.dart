import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:family_docs_app/main.dart';

void main() {
  testWidgets('Family Docs app smoke test and lock screen render', (
    WidgetTester tester,
  ) async {
    // Build our app wrapped with ProviderScope
    await tester.pumpWidget(const ProviderScope(child: FamilyDocsApp()));

    // Pump a single frame
    await tester.pump();

    // Verify that the Sanctuary Vault Lock branding and security badge are visible
    expect(find.text('Family Docs'), findsOneWidget);
    expect(find.text('ENCRYPTED SANCTUARY'), findsOneWidget);

    // Verify the security badge / footnote is rendered
    expect(
      find.text('Local Enclave • Zero-Knowledge Architecture'),
      findsOneWidget,
    );
  });
}
