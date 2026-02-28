import 'dart:async';
import 'package:flutter/material.dart';
import 'streak_badge.dart';

class ConnectedSettingsIcon extends StatefulWidget {
  final bool isSelected;
  const ConnectedSettingsIcon({super.key, required this.isSelected});

  @override
  State<ConnectedSettingsIcon> createState() => _ConnectedSettingsIconState();
}

class _ConnectedSettingsIconState extends State<ConnectedSettingsIcon> {
  bool _showStreak = true;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startCycle();
  }

  void _startCycle() {
    _timer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (mounted) {
        setState(() {
          _showStreak = !_showStreak;
        });
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 24,
      height: 24,
      child: AnimatedCrossFade(
        firstChild: const StreakBadge(size: 18),
        secondChild: Icon(
          widget.isSelected ? Icons.tune_rounded : Icons.tune_outlined,
          size: 22,
        ),
        crossFadeState: _showStreak ? CrossFadeState.showFirst : CrossFadeState.showSecond,
        duration: const Duration(milliseconds: 800),
      ),
    );
  }
}
