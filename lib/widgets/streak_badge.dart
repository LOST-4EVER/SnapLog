import 'package:flutter/material.dart';
import '../services/database_helper.dart';
import '../services/entries_notifier.dart';

class StreakBadge extends StatefulWidget {
  final double size;
  const StreakBadge({super.key, this.size = 24});

  @override
  State<StreakBadge> createState() => _StreakBadgeState();
}

class _StreakBadgeState extends State<StreakBadge> with SingleTickerProviderStateMixin {
  late Future<int> _streakFuture;
  late Future<int> _todayCountFuture;
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late final EntriesNotifier _notifier;
  late final VoidCallback _listener;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _scaleAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.elasticOut,
    );

    _notifier = EntriesNotifier();
    _listener = () => _refresh();
    _notifier.addListener(_listener);
    _refresh();
  }

  void _refresh() {
    if (mounted) {
      setState(() {
        _streakFuture = DatabaseHelper().calculateStreak();
        _todayCountFuture = DatabaseHelper().getTodaysPhotoCount();
      });
      _todayCountFuture.then((count) {
        if (count > 0 && !_controller.isAnimating) {
          _controller.forward(from: 0);
        }
      });
    }
  }

  @override
  void dispose() {
    _notifier.removeListener(_listener);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<int>>(
      future: Future.wait([_streakFuture, _todayCountFuture]),
      builder: (context, snapshot) {
        final streak = snapshot.data?[0] ?? 0;
        final todayCount = snapshot.data?[1] ?? 0;
        final isLit = todayCount > 0 && streak > 0;

        return AnimatedBuilder(
          animation: _scaleAnimation,
          builder: (context, child) {
            double scale = 1.0 + (_scaleAnimation.value * 0.2);
            return Transform.scale(
              scale: scale,
              child: child,
            );
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: isLit ? Colors.orange.withValues(alpha: 0.1) : Colors.grey.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isLit ? Colors.orange.withValues(alpha: 0.5) : Colors.grey.withValues(alpha: 0.3),
                width: 1.5,
              ),
            ),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.local_fire_department_rounded,
                    color: isLit ? Colors.orange : Colors.grey,
                    size: widget.size,
                  ),
                  if (streak > 0) ...[
                    const SizedBox(width: 4),
                    Text(
                      "$streak",
                      style: TextStyle(
                        color: isLit ? Colors.orange : Colors.grey,
                        fontWeight: FontWeight.w900,
                        fontSize: widget.size * 0.8,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
