import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class TunerScreen extends StatefulWidget {
  const TunerScreen({super.key});

  @override
  State<TunerScreen> createState() => _TunerScreenState();
}

class _TunerScreenState extends State<TunerScreen> {
  double _sensitivity = 0.68;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      key: const PageStorageKey('tuner'),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '音准',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
              ),
              IconButton.filledTonal(
                onPressed: () {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(const SnackBar(content: Text('当前为 UI 演示模式')));
                },
                icon: const Icon(Icons.tune_rounded),
              ),
            ],
          ),
          const SizedBox(height: 38),
          const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _PulseDot(),
              SizedBox(width: 8),
              Text(
                '演示数据',
                style: TextStyle(
                  color: AppColors.success,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          const Stack(
            alignment: Alignment.topRight,
            children: [
              Text(
                'F',
                style: TextStyle(
                  color: AppColors.text,
                  fontSize: 112,
                  height: 1,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                '4',
                style: TextStyle(
                  color: AppColors.muted,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          const Text(
            '4 孔 · 吹气',
            style: TextStyle(
              color: AppColors.muted,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 43),
          const _PitchScale(cents: 3),
          const SizedBox(height: 24),
          Text('气息很稳，保持住', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 32),
          Card(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 13),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          '检测灵敏度',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                      Text(
                        '${(_sensitivity * 100).round()}%',
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                  Slider(
                    value: _sensitivity,
                    min: 0.2,
                    max: 1,
                    onChanged: (value) {
                      setState(() => _sensitivity = value);
                    },
                  ),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '环境较吵时可适当调低',
                      style: TextStyle(color: AppColors.muted, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            '首版本只实现界面。麦克风与真实音高检测将在后续版本接入。',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.muted, fontSize: 11, height: 1.4),
          ),
        ],
      ),
    );
  }
}

class _PitchScale extends StatelessWidget {
  const _PitchScale({required this.cents});

  final int cents;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('偏低', style: TextStyle(color: AppColors.muted, fontSize: 12)),
            Text(
              '准确',
              style: TextStyle(color: AppColors.success, fontSize: 12),
            ),
            Text('偏高', style: TextStyle(color: AppColors.muted, fontSize: 12)),
          ],
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 48,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(21, (index) {
                  final major = index % 5 == 0;
                  return Container(
                    width: major ? 2 : 1,
                    height: major ? 22 : 11,
                    color: index == 10 ? AppColors.success : AppColors.outline,
                  );
                }),
              ),
              Align(
                alignment: Alignment(cents / 50, -1),
                child: const Icon(
                  Icons.arrow_drop_down_rounded,
                  color: AppColors.primary,
                  size: 36,
                ),
              ),
            ],
          ),
        ),
        Text.rich(
          TextSpan(
            text: '+ $cents ',
            style: const TextStyle(
              color: AppColors.text,
              fontSize: 26,
              fontWeight: FontWeight.w800,
            ),
            children: const [
              TextSpan(
                text: '音分',
                style: TextStyle(
                  color: AppColors.muted,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PulseDot extends StatelessWidget {
  const _PulseDot();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 9,
      height: 9,
      decoration: const BoxDecoration(
        color: AppColors.success,
        shape: BoxShape.circle,
      ),
    );
  }
}
