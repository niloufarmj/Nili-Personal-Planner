import 'package:flutter/material.dart';
import 'design.dart';
import 'tokens.dart';

class StyleguideScreen extends StatelessWidget {
  const StyleguideScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Styleguide & Tokens QA')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(
            'Personal Planner Design System',
            style: Theme.of(context).textTheme.displayMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'Calm Pastel Wellness Aesthetic',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const Divider(height: 40),
          _buildThemeSection(
            context,
            'Light Theme',
            AppTheme.light,
            Colors.white,
          ),
          const SizedBox(height: 40),
          _buildThemeSection(
            context,
            'Dark Theme',
            AppTheme.dark,
            const Color(0xFF1E1E26),
          ),
        ],
      ),
    );
  }

  Widget _buildThemeSection(
    BuildContext context,
    String title,
    ThemeData theme,
    Color background,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: background,
        border: Border.all(color: theme.colorScheme.outline, width: 2),
        borderRadius: BorderRadius.circular(DesignTokens.radiusCard),
      ),
      padding: const EdgeInsets.all(24),
      child: Theme(
        data: theme,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: theme.textTheme.displaySmall),
            const SizedBox(height: 24),

            // ── Colors Section ──
            const SectionHeader(title: 'Color Palette'),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _ColorBlock(name: 'Accent', color: theme.colorScheme.primary),
                _ColorBlock(
                  name: 'Paper',
                  color: theme.scaffoldBackgroundColor,
                ),
                _ColorBlock(name: 'Surface', color: theme.colorScheme.surface),
                _ColorBlock(
                  name: 'Divider',
                  color: theme.dividerTheme.color ?? Colors.grey,
                ),
                _ColorBlock(name: 'Success', color: DesignTokens.success),
                _ColorBlock(name: 'Warning', color: DesignTokens.warning),
                _ColorBlock(name: 'Danger', color: DesignTokens.danger),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'Pastel Fills (resolved for theme):',
              style: theme.textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _ColorBlock(
                  name: 'Rose',
                  color: DesignTokens.resolvePastelFill(
                    color: DesignTokens.rose,
                    isDark: theme.brightness == Brightness.dark,
                  ),
                ),
                _ColorBlock(
                  name: 'Blush',
                  color: DesignTokens.resolvePastelFill(
                    color: DesignTokens.blush,
                    isDark: theme.brightness == Brightness.dark,
                  ),
                ),
                _ColorBlock(
                  name: 'Lavender',
                  color: DesignTokens.resolvePastelFill(
                    color: DesignTokens.lavender,
                    isDark: theme.brightness == Brightness.dark,
                  ),
                ),
                _ColorBlock(
                  name: 'Sage',
                  color: DesignTokens.resolvePastelFill(
                    color: DesignTokens.sage,
                    isDark: theme.brightness == Brightness.dark,
                  ),
                ),
                _ColorBlock(
                  name: 'Dusty Blue',
                  color: DesignTokens.resolvePastelFill(
                    color: DesignTokens.dustyBlue,
                    isDark: theme.brightness == Brightness.dark,
                  ),
                ),
                _ColorBlock(
                  name: 'Butter',
                  color: DesignTokens.resolvePastelFill(
                    color: DesignTokens.butter,
                    isDark: theme.brightness == Brightness.dark,
                  ),
                ),
                _ColorBlock(
                  name: 'Peach',
                  color: DesignTokens.resolvePastelFill(
                    color: DesignTokens.peach,
                    isDark: theme.brightness == Brightness.dark,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),

            // ── Typography Section ──
            const SectionHeader(title: 'Typography'),
            const SizedBox(height: 12),
            Text(
              'Display Text (Fraunces)',
              style: theme.textTheme.displayMedium,
            ),
            const SizedBox(height: 8),
            Text('Title Large (Fraunces)', style: theme.textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              'Section Heading (Nunito Sans)',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Body Text standard layout (Nunito Sans)',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Caption style (Nunito Sans)',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            const SectionHeader(
              title: 'Overline Style (Letter-Spaced Small Caps)',
            ),
            const SizedBox(height: 32),

            // ── DayWash Signature Element ──
            const SectionHeader(title: 'Signature: DayWashDecoration'),
            const SizedBox(height: 12),
            Container(
              height: 80,
              width: double.infinity,
              decoration: DayWashDecoration(
                tagColors: const [DesignTokens.butter],
                isDark: theme.brightness == Brightness.dark,
              ),
              alignment: Alignment.center,
              child: Text(
                'Linz (Butter Wash)',
                style: theme.textTheme.titleMedium,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              height: 80,
              width: double.infinity,
              decoration: DayWashDecoration(
                tagColors: const [DesignTokens.butter, DesignTokens.lavender],
                isDark: theme.brightness == Brightness.dark,
              ),
              alignment: Alignment.center,
              child: Text(
                'Multi-tag (Butter + Lavender)',
                style: theme.textTheme.titleMedium,
              ),
            ),
            const SizedBox(height: 32),

            // ── Widgets Section ──
            const SectionHeader(title: 'Custom Widgets'),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'AppCard (Radius 20, soft shadow)',
                          style: theme.textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Custom iOS-style squircle corner cards with 1px border lines.',
                          style: theme.textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                const StatusChip(status: 'done'),
                const StatusChip(status: 'blocked'),
                const StatusChip(status: 'planned'),
                const StatusChip(status: 'open'),
                const PriorityBadge(priority: 1),
                const PriorityBadge(priority: 2),
                const PriorityBadge(priority: 3),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: const InputDecoration(
                      labelText: 'Sample Text Input',
                      hintText: 'Enter text here...',
                    ),
                    controller: TextEditingController(text: 'Hello World'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                FilledButton(
                  onPressed: () {},
                  child: const Text('Primary Button'),
                ),
                const SizedBox(width: 12),
                OutlinedButton(
                  onPressed: () {},
                  child: const Text('Secondary Button'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ColorBlock extends StatelessWidget {
  const _ColorBlock({required this.name, required this.color});

  final String name;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 100,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color,
        border: Border.all(color: Colors.grey.withAlpha(50)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 40,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            name,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: Colors.black, // Dark text always on colors for readability
            ),
          ),
          Text(
            '#${color.value.toRadixString(16).substring(2).toUpperCase()}',
            style: const TextStyle(fontSize: 9, color: Colors.black54),
          ),
        ],
      ),
    );
  }
}
