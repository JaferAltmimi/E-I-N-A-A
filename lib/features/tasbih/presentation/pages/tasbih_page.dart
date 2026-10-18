import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../core/widgets/mishkat_widgets.dart';
import '../cubit/tasbih_cubit.dart';
import '../cubit/tasbih_state.dart';

class TasbihPage extends StatelessWidget {
  const TasbihPage({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      leading: IconButton(
        onPressed: () => Navigator.pop(context),
        icon: const Icon(Icons.arrow_forward_rounded),
        tooltip: 'رجوع',
      ),
      title: const Text('السبحة الإلكترونية'),
    ),
    body: BlocBuilder<TasbihCubit, TasbihState>(
      builder: (context, state) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: MishkatSpacing.lg,
            vertical: MishkatSpacing.base,
          ),
          child: Column(
            children: [
              Text(
                'اذكر الله',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'كل تسبيحة تُحفظ تلقائيًا في مجموعك التراكمي.',
                style: TextStyle(
                  fontSize: 13,
                  color: context.mishkat.textSecondary,
                ),
              ),
              const SizedBox(height: MishkatSpacing.lg),
              SegmentedButton<int>(
                segments: const [
                  ButtonSegment(value: 33, label: Text('33')),
                  ButtonSegment(value: 100, label: Text('100')),
                  ButtonSegment(value: 1000, label: Text('1000')),
                ],
                selected: {state.target},
                showSelectedIcon: false,
                onSelectionChanged: (value) =>
                    context.read<TasbihCubit>().setTarget(value.first),
              ),
              const Spacer(),
              Semantics(
                button: true,
                label: 'عدّ التسبيح، ${state.count} من ${state.target}',
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: () {
                    HapticFeedback.mediumImpact();
                    context.read<TasbihCubit>().increment();
                  },
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        width: 250,
                        height: 250,
                        child: CircularProgressIndicator(
                          value: state.progress,
                          strokeWidth: 10,
                          backgroundColor: context.mishkat.border,
                          color: context.mishkat.primary,
                          strokeCap: StrokeCap.round,
                        ),
                      ),
                      Container(
                        width: 215,
                        height: 215,
                        decoration: BoxDecoration(
                          color: context.mishkat.primarySoft,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: context.mishkat.primary.withValues(alpha: 0.3),
                            width: 2,
                          ),
                          boxShadow: MishkatShadows.subtle(context),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              '${state.count}',
                              style: TextStyle(
                                fontSize: 62,
                                fontWeight: FontWeight.w900,
                                color: context.mishkat.primary,
                                height: 1.1,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              state.completed ? 'أتممت الورد' : 'اضغط للتسبيح',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                                color: state.completed
                                    ? context.mishkat.primary
                                    : context.mishkat.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const Spacer(),
              MishkatCard(
                padding: const EdgeInsets.symmetric(
                  horizontal: MishkatSpacing.base,
                  vertical: MishkatSpacing.md,
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.all_inclusive_rounded,
                      color: context.mishkat.primary,
                      size: 22,
                    ),
                    const SizedBox(width: MishkatSpacing.md),
                    const Expanded(
                      child: Text(
                        'المجموع التراكمي',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                    Text(
                      '${state.total}',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: context.mishkat.primary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: MishkatSpacing.sm),
              MishkatSecondaryAction(
                onPressed: context.read<TasbihCubit>().reset,
                icon: const Icon(Icons.refresh_rounded),
                label: 'بدء جولة جديدة',
                isFullWidth: true,
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
