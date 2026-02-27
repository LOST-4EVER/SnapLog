import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class QuizScreen extends StatefulWidget {
  const QuizScreen({super.key});

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  late int _num1;
  late int _num2;
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
    _num1 = random.nextInt(12) + 1;
    _num2 = random.nextInt(12) + 1;
    _correctAnswer = _num1 + _num2;

    _options = [_correctAnswer];
    while (_options.length < 4) {
      int wrongAnswer = _correctAnswer + (random.nextBool() ? 1 : -1) * (random.nextInt(5) + 1);
      if (wrongAnswer > 0 && !_options.contains(wrongAnswer)) {
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
                  color: colorScheme.primaryContainer.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.psychology_outlined, size: 48, color: colorScheme.primary),
              ),
              const SizedBox(height: 24),
              Text(
                "Security Check",
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                "Prove you're human to continue",
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 48),
              Text(
                "$_num1 + $_num2",
                style: Theme.of(context).textTheme.displayLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.primary,
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
