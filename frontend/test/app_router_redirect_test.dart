import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zeitschatz/routing/app_router.dart';
import 'package:zeitschatz/state/app_state.dart';

void main() {
  testWidgets('redirects to role when session clears', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final notifier = container.read(sessionProvider.notifier);
    notifier.setSession(token: 'abc', refreshToken: 'rt1', userId: 1, role: 'parent');

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: Consumer(
          builder: (context, ref, _) {
            final router = ref.watch(appRouterProvider);
            return MaterialApp.router(routerConfig: router);
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    final router = container.read(appRouterProvider);
    router.go('/child');
    await tester.pumpAndSettle();

    expect(find.text('Heute'), findsOneWidget);

    notifier.clear();
    await tester.pumpAndSettle();

    expect(find.text('ZeitSchatz – Rolle wählen'), findsOneWidget);
  });
}
