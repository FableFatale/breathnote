import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../widgets/shared_widgets.dart';

class PracticeScreen extends StatefulWidget {
  const PracticeScreen({super.key});

  @override
  State<PracticeScreen> createState() => _PracticeScreenState();
}

class _PracticeScreenState extends State<PracticeScreen> {
  bool _playing = false;
  bool _loop = true;
  double _speed = 0.8;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: const Text('单音练习'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Center(child: Pill(label: '${_speed.toStringAsFixed(1)}×')),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            children: [
              const SectionLabel('目标音'),
              const Spacer(),
              Container(
                width: 214,
                height: 214,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.surface,
                  border: Border.all(
                    color: _playing ? AppColors.success : AppColors.outline,
                    width: 2,
                  ),
                  boxShadow: _playing
                      ? [
                          BoxShadow(
                            color: AppColors.success.withValues(alpha: 0.15),
                            blurRadius: 36,
                            spreadRadius: 10,
                          ),
                        ]
                      : null,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      'C',
                      style: TextStyle(
                        color: AppColors.text,
                        fontSize: 80,
                        height: 1,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      _playing ? '正在聆听' : '4 孔 · 吹气',
                      style: TextStyle(
                        color: _playing ? AppColors.success : AppColors.muted,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Text(
                '保持轻柔、均匀的气息',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 10),
              Text(
                '含住第 4 孔，轻轻吹气。不要用力，\n让气息自然流过。',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const Spacer(),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _RoundAction(
                    icon: Icons.repeat_rounded,
                    label: '循环',
                    active: _loop,
                    onTap: () => setState(() => _loop = !_loop),
                  ),
                  FilledButton(
                    onPressed: () => setState(() => _playing = !_playing),
                    style: FilledButton.styleFrom(
                      fixedSize: const Size(74, 74),
                      shape: const CircleBorder(),
                    ),
                    child: Icon(
                      _playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                      size: 40,
                    ),
                  ),
                  _RoundAction(
                    icon: Icons.speed_rounded,
                    label: '${_speed.toStringAsFixed(1)}×',
                    onTap: () {
                      setState(() {
                        _speed = _speed == 0.8 ? 1 : 0.8;
                      });
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoundAction extends StatelessWidget {
  const _RoundAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.active = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        IconButton.filledTonal(
          onPressed: onTap,
          style: IconButton.styleFrom(
            fixedSize: const Size(52, 52),
            backgroundColor: active
                ? AppColors.primary.withValues(alpha: 0.2)
                : AppColors.surfaceHigh,
            foregroundColor: active ? AppColors.primary : AppColors.text,
          ),
          icon: Icon(icon),
        ),
        const SizedBox(height: 7),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}
