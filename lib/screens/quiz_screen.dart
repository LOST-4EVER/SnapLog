import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

enum QuizDifficulty { normal, hard }

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

  @override
  void initState() {
    super.initState();
    _generateQuiz();
  }

  void _generateQuiz() {
    final random = Random();
    if (widget.difficulty == QuizDifficulty.hard) {
      // Hard mode: three numbers and mixed operations
      _num1 = random.nextInt(20) + 10;
      _num2 = random.nextInt(15) + 5;
      _num3 = random.nextInt(10) + 2;
      
      final op1 = random.nextInt(2); // 0: +, 1: *
      final op2 = random.nextInt(2); // 0: -, 1: +
      
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
    } else {
      // Normal mode: two numbers addition
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
      HapticFeedback.mediumImpact();
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) Navigator.of(context).pop(true);
      });
    } else {
      HapticFeedback.vibrate();
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

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
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
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: (isHard ? Colors.red : colorScheme.primary).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isHard ? Icons.lock_outline : Icons.psychology_outlined, 
                  size: 48, 
                  color: isHard ? Colors.red : colorScheme.primary
                ),
              ),
              const SizedBox(height: 24),
              Text(
                isHard ? "Critical Verification" : "Security Check",
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                isHard 
                  ? "Solve this complex equation to proceed with deletion." 
                  : "Prove you're human to continue",
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 48),
              FittedBox(
                child: Text(
                  isHard ? "($_num1 $_operation1 $_num2) $_operation2 $_num3" : "$_num1 + $_num2",
                  style: Theme.of(context).textTheme.displayMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: isHard ? Colors.red : colorScheme.primary,
                  ),
                ),
              ),
              const SizedBox(height: 48),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 16,
                  crossAxisSpacing: 16,
                  childAspectRatio: 1.5,
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
                      borderRadius: BorderRadius.circular(24),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        decoration: BoxDecoration(
                          color: isCorrect 
                              ? Colors.green.withOpacity(0.2)
                              : isWrong
                                  ? Colors.red.withOpacity(0.2)
                                  : colorScheme.surfaceVariant.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: isCorrect 
                                ? Colors.green 
                                : isWrong 
                                    ? Colors.red 
                                    : Colors.transparent,
                            width: 2,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            "$option",
                            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: isCorrect ? Colors.green : isWrong ? Colors.red : colorScheme.onSurface,
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
