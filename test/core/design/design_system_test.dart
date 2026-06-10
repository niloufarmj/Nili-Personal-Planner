import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_planner/core/design/design.dart';

Widget _wrap(Widget child, {bool dark = false}) => MaterialApp(
  theme: dark ? AppTheme.dark : AppTheme.light,
  home: Scaffold(body: child),
);

void main() {
  // ── AppCard ──────────────────────────────────────────────────────

  group('AppCard', () {
    testWidgets('renders in light mode', (tester) async {
      await tester.pumpWidget(_wrap(const AppCard(child: Text('hello'))));
      expect(find.text('hello'), findsOneWidget);
    });

    testWidgets('renders in dark mode', (tester) async {
      await tester.pumpWidget(
        _wrap(const AppCard(child: Text('dark')), dark: true),
      );
      expect(find.text('dark'), findsOneWidget);
    });

    testWidgets('fires onTap', (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        _wrap(AppCard(onTap: () => tapped = true, child: const Text('tap'))),
      );
      await tester.tap(find.text('tap'));
      expect(tapped, isTrue);
    });
  });

  // ── StatusChip ───────────────────────────────────────────────────

  group('StatusChip', () {
    for (final status in [
      'open',
      'done',
      'planned',
      'blocked',
      'in_progress',
    ]) {
      testWidgets('renders status=$status in light', (tester) async {
        await tester.pumpWidget(_wrap(StatusChip(status: status)));
        expect(find.byType(StatusChip), findsOneWidget);
      });

      testWidgets('renders status=$status in dark', (tester) async {
        await tester.pumpWidget(_wrap(StatusChip(status: status), dark: true));
        expect(find.byType(StatusChip), findsOneWidget);
      });
    }
  });

  // ── PriorityBadge ────────────────────────────────────────────────

  group('PriorityBadge', () {
    for (final prio in [1, 2, 3]) {
      testWidgets('renders priority=$prio in light', (tester) async {
        await tester.pumpWidget(_wrap(PriorityBadge(priority: prio)));
        expect(find.byType(PriorityBadge), findsOneWidget);
      });

      testWidgets('renders priority=$prio in dark', (tester) async {
        await tester.pumpWidget(
          _wrap(PriorityBadge(priority: prio), dark: true),
        );
        expect(find.byType(PriorityBadge), findsOneWidget);
      });
    }

    testWidgets('shows High label for priority 1', (tester) async {
      await tester.pumpWidget(_wrap(const PriorityBadge(priority: 1)));
      expect(find.textContaining('High'), findsOneWidget);
    });

    testWidgets('shows Low label for priority 3', (tester) async {
      await tester.pumpWidget(_wrap(const PriorityBadge(priority: 3)));
      expect(find.textContaining('Low'), findsOneWidget);
    });
  });

  // ── EmptyState ───────────────────────────────────────────────────

  group('EmptyState', () {
    testWidgets('renders message in light mode', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const EmptyState(
            icon: Icons.inbox,
            message: 'Nothing here yet',
            hint: 'Add your first item to get started.',
          ),
        ),
      );
      expect(find.text('Nothing here yet'), findsOneWidget);
      expect(find.text('Add your first item to get started.'), findsOneWidget);
    });

    testWidgets('renders in dark mode without exceptions', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const EmptyState(icon: Icons.inbox, message: 'Nothing here yet'),
          dark: true,
        ),
      );
      expect(find.byType(EmptyState), findsOneWidget);
    });

    testWidgets('shows action button when provided', (tester) async {
      var pressed = false;
      await tester.pumpWidget(
        _wrap(
          EmptyState(
            icon: Icons.add,
            message: 'Empty',
            action: () => pressed = true,
            actionLabel: 'Add',
          ),
        ),
      );
      await tester.tap(find.text('Add'));
      expect(pressed, isTrue);
    });

    testWidgets('omits hint when null', (tester) async {
      await tester.pumpWidget(
        _wrap(const EmptyState(icon: Icons.inbox, message: 'Nothing')),
      );
      expect(find.byType(EmptyState), findsOneWidget);
    });
  });

  // ── SectionHeader ────────────────────────────────────────────────

  group('SectionHeader', () {
    testWidgets('renders title in light mode', (tester) async {
      await tester.pumpWidget(_wrap(const SectionHeader(title: 'Events')));
      expect(find.textContaining('EVENTS'), findsOneWidget);
    });

    testWidgets('renders in dark mode without exceptions', (tester) async {
      await tester.pumpWidget(
        _wrap(const SectionHeader(title: 'Habits'), dark: true),
      );
      expect(find.byType(SectionHeader), findsOneWidget);
    });

    testWidgets('renders trailing widget', (tester) async {
      await tester.pumpWidget(
        _wrap(const SectionHeader(title: 'Tasks', trailing: Icon(Icons.add))),
      );
      expect(find.byIcon(Icons.add), findsOneWidget);
    });
  });

  // ── ConfirmDialog ────────────────────────────────────────────────

  group('ConfirmDialog', () {
    testWidgets('renders title and message', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const ConfirmDialog(
            title: 'Delete?',
            message: 'This cannot be undone.',
          ),
        ),
      );
      expect(find.text('Delete?'), findsOneWidget);
      expect(find.text('This cannot be undone.'), findsOneWidget);
    });

    testWidgets('renders in dark mode without exceptions', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const ConfirmDialog(
            title: 'Delete?',
            message: 'Are you sure?',
            isDestructive: true,
          ),
          dark: true,
        ),
      );
      expect(find.byType(ConfirmDialog), findsOneWidget);
    });

    testWidgets('cancel returns false', (tester) async {
      bool? result;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (ctx) => TextButton(
              onPressed: () async {
                result = await ConfirmDialog.show(
                  ctx,
                  title: 'Confirm',
                  message: 'Are you sure?',
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(result, isFalse);
    });

    testWidgets('confirm returns true', (tester) async {
      bool? result;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (ctx) => TextButton(
              onPressed: () async {
                result = await ConfirmDialog.show(
                  ctx,
                  title: 'Confirm',
                  message: 'Are you sure?',
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Confirm'));
      await tester.pumpAndSettle();
      expect(result, isTrue);
    });
  });
}
