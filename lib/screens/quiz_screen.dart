import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/settings_service.dart';

enum QuizDifficulty { normal, medium, hard }

class QuizScreen extends StatefulWidget {
  final QuizDifficulty difficulty;
  const QuizScreen({super.key, this.difficulty = QuizDifficulty.normal});

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  late int _num1;
  late int _num2;
  late int _num3;
  late String _operation1;
  late String _operation2;
  late int _correctAnswer;
  late List<int> _options;
  bool _isAnswered = false;
  int? _selectedOption;
  bool _hapticEnabled = true;

  @override
  void initState() {
    super.initState();
    _generateQuiz();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final settings = await SettingsService().getSettings();
    if (mounted) {
      setState(() {
        _hapticEnabled = settings['hapticFeedback'] ?? true;
      });
    }
  }

  void _generateQuiz() {
    final random = Random();
    if (widget.difficulty == QuizDifficulty.hard) {
      _num1 = random.nextInt(20) + 10;
      _num2 = random.nextInt(15) + 5;
      _num3 = random.nextInt(10) + 2;
      
      final op1 = random.nextInt(2); 
      final op2 = random.nextInt(2); 
      
      if (op1 == 0) {
        _operation1 = "+";
        if (op2 == 0) {
          _operation2 = "-";
          _correctAnswer = _num1 + _num2 - _num3;
        } else {
          _operation2 = "+";
          _correctAnswer = _num1 + _num2 + _num3;
        }
      } else {
        _operation1 = "×";
        if (op2 == 0) {
          _operation2 = "-";
          _correctAnswer = (_num1 * _num2) - _num3;
        } else {
          _operation2 = "+";
          _correctAnswer = (_num1 * _num2) + _num3;
        }
      }
    } else if (widget.difficulty == QuizDifficulty.medium) {
      final mode = random.nextInt(3);
      if (mode == 0) {
        _num1 = random.nextInt(50) + 20;
        _num2 = random.nextInt(50) + 20;
        _operation1 = "+";
        _operation2 = "";
        _correctAnswer = _num1 + _num2;
      } else if (mode == 1) {
        _num1 = random.nextInt(50) + 30;
        _num2 = random.nextInt(25) + 5;
        _operation1 = "-";
        _operation2 = "";
        _correctAnswer = _num1 - _num2;
      } else {
        _num1 = random.nextInt(10) + 3;
        _num2 = random.nextInt(10) + 3;
        _operation1 = "×";
        _operation2 = "";
        _correctAnswer = _num1 * _num2;
      }
    } else {
      _num1 = random.nextInt(12) + 1;
      _num2 = random.nextInt(12) + 1;
      _operation1 = "+";
      _operation2 = "";
      _correctAnswer = _num1 + _num2;
    }

    _options = [_correctAnswer];
    while (_options.length < 4) {
      int offset = (random.nextBool() ? 1 : -1) * (random.nextInt(10) + 1);
      int wrongAnswer = _correctAnswer + offset;
      if (wrongAnswer != _correctAnswer && !_options.contains(wrongAnswer)) {
        _options.add(wrongAnswer);
      }
    }
    _options.shuffle();
  }

  void _checkAnswer(int answer) {
    if (_isAnswered) return;
    
    setState(() {
      _isAnswered = true;
      _selectedOption = answer;
    });

    if (answer == _correctAnswer) {
      if (_hapticEnabled) HapticFeedback.mediumImpact();
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) Navigator.of(context).pop(true);
      });
    } else {
      if (_hapticEnabled) HapticFeedback.vibrate();
      Future.delayed(const Duration(milliseconds: 1000), () {
        if (mounted) {
          setState(() {
            _isAnswered = false;
            _selectedOption = null;
            _generateQuiz();
          });
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isHard = widget.difficulty == QuizDifficulty.hard;
    final isMedium = widget.difficulty == QuizDifficulty.medium;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: Colors.transparent,
        actions: [
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.pop(context, false),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 500),
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: (isHard ? Colors.red : (isMedium ? Colors.orange : colorScheme.primary)).withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isHard ? Icons.lock_person_outlined : (isMedium ? Icons.shield_outlined : Icons.psychology_outlined), 
                  size: 64, 
                  color: isHard ? Colors.red : (isMedium ? Colors.orange : colorScheme.primary)
                ),
              ),
              const SizedBox(height: 32),
              Text(
                isHard ? "Critical Action" : (isMedium ? "System Security" : "Quick Verification"),
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                isHard 
                  ? "Solve to authorize permanent deletion." 
                  : (isMedium ? "Verify to adjust system limits." : "A quick brain teaser to proceed"),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 64),
              FittedBox(
                child: Text(
                  isHard ? "($_num1 $_operation1 $_num2) $_operation2 $_num3" : "$_num1 $_operation1 $_num2",
                  style: Theme.of(context).textTheme.displayLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: isHard ? Colors.red : (isMedium ? Colors.orange : colorScheme.primary),
                    letterSpacing: -1,
                  ),
                ),
              ),
              const SizedBox(height: 64),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 20,
                  crossAxisSpacing: 20,
                  childAspectRatio: 1.4,
                ),
                itemCount: _options.length,
                itemBuilder: (context, index) {
                  final option = _options[index];
                  bool isCorrect = _isAnswered && option == _correctAnswer;
                  bool isWrong = _isAnswered && option == _selectedOption && option != _correctAnswer;
                  
                  return Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => _checkAnswer(option),
                      borderRadius: BorderRadius.circular(28),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        decoration: BoxDecoration(
                          color: isCorrect 
                              ? Colors.green.withValues(alpha: 0.2)
                              : isWrong
                                  ? Colors.red.withValues(alpha: 0.2)
                                  : colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                          borderRadius: BorderRadius.circular(28),
                          border: Border.all(
                            color: isCorrect 
                                ? Colors.green 
                                : isWrong 
                                    ? Colors.red 
                                    : Colors.transparent,
                            width: 3,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            "$option",
                            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                              fontWeight: FontWeight.w900,
                              color: isCorrect ? Colors.green : isWrong ? Colors.red : colorScheme.onSurface,
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 48),
              if (!isHard && !isMedium)
                TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: Text("SKIP CHECK", style: TextStyle(color: colorScheme.primary.withValues(alpha: 0.5), fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
