import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class MoodSelector extends StatelessWidget {
  final List<String> moods;
  final String selectedMood;
  final Function(String) onMoodSelected;
  final bool hapticEnabled;

  const MoodSelector({
    super.key,
    required this.moods,
    required this.selectedMood,
    required this.onMoodSelected,
    required this.hapticEnabled,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return SizedBox(
      height: 75,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: moods.length,
        itemBuilder: (context, index) {
          final mood = moods[index];
          final isSelected = selectedMood == mood;
          return Padding(
            padding: const EdgeInsets.only(right: 12),
            child: InkWell(
              onTap: () {
                onMoodSelected(mood);
                if (hapticEnabled) HapticFeedback.selectionClick();
              },
              borderRadius: BorderRadius.circular(20),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 65,
                decoration: BoxDecoration(
                  color: isSelected ? colorScheme.primaryContainer : colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected ? colorScheme.primary : Colors.transparent,
                    width: 2,
                  ),
                ),
                child: Center(
                  child: Text(mood, style: const TextStyle(fontSize: 32)),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
