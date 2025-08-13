import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class LevelSelectorScreen2 extends StatefulWidget {
  const LevelSelectorScreen2({super.key});
  @override
  State<LevelSelectorScreen2> createState() => _LevelSelectorScreen2State();
}

class _LevelSelectorScreen2State extends State<LevelSelectorScreen2> {
  final int totalLevels = 5;
  final List<double> levelXPositions = [0.2, 0.8, 0.2, 0.8, 0.5];

  void _onLevelTap(BuildContext context, int level, int highestUnlockedLevel) {
    if (level <= highestUnlockedLevel) {
      Navigator.pushNamed(context, '/level$level');
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('Not logged in', style: TextStyle(fontFamily: 'Jua'))),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('user_progress')
            .doc(user.uid)
            .snapshots(),
        builder: (context, snapshot) {
          int highestUnlockedLevel = 6;
          if (snapshot.hasData && snapshot.data!.exists) {
            int highest = snapshot.data!.get('highestLevel') ?? 1;
            if (highest >= 6) {
              highestUnlockedLevel = highest > 10 ? 10 : highest;
            } else {
              highestUnlockedLevel = 5; 
            }
          } else {
            highestUnlockedLevel = 5; 
          }

          return SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 24),
                const Text(
                  "IF",
                  style: TextStyle(
                    color: Colors.black,
                    fontFamily: 'Jua',
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 60, vertical: 8),
                  child: Divider(
                    color: Color.fromARGB(255, 156, 156, 156),
                    thickness: 2,
                  ),
                ),
                const SizedBox(height: 32),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final double width = constraints.maxWidth;
                      final double height = constraints.maxHeight;
                      final double verticalSpacing = height / (totalLevels + 1);

                      final List<Offset> levelPositions = List.generate(
                        totalLevels,
                        (i) => Offset(
                          levelXPositions[i] * width,
                          verticalSpacing * (i + 1),
                        ),
                      );

                      return Stack(
                        children: [
                          CustomPaint(
                            size: Size(width, height),
                            painter: _ZigzagLinePainter(levelPositions),
                          ),
                          ...List.generate(totalLevels, (i) {
                            int levelNum = i + 6;
                            bool isUnlocked = highestUnlockedLevel >= levelNum;
                            bool isCurrent = highestUnlockedLevel == levelNum;
                            bool isFinished = highestUnlockedLevel > levelNum;
                            Color blueColor = const Color.fromRGBO(121, 195, 255, 1);

                            if (levelNum == 6 && highestUnlockedLevel < 6) {
                              isUnlocked = false;
                            }

                            return Positioned(
                              left: levelPositions[i].dx - 40,
                              top: levelPositions[i].dy - 40,
                              child: GestureDetector(
                                onTap: isUnlocked
                                    ? () => _onLevelTap(context, levelNum, highestUnlockedLevel)
                                    : null,
                                child: Container(
                                  width: 80,
                                  height: 80,
                                  decoration: BoxDecoration(
                                    color: isCurrent
                                        ? blueColor
                                        : isFinished
                                            ? blueColor
                                            : Colors.grey[300],
                                    borderRadius: BorderRadius.circular(35),
                                    border: isCurrent
                                        ? Border.all(color: blueColor, width: 4)
                                        : null,
                                    boxShadow: [
                                      if (isUnlocked)
                                        BoxShadow(
                                          color: const Color.fromARGB(255, 0, 0, 0).withOpacity(0.08),
                                          blurRadius: 8,
                                          offset: const Offset(0, 4),
                                        ),
                                    ],
                                  ),
                                  child: Center(
                                    child: Icon(
                                      Icons.star,
                                      color: isCurrent
                                          ? Colors.white
                                          : isFinished
                                              ? const Color.fromARGB(255, 253, 255, 115)
                                              : Colors.black26,
                                      size: 36,
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }),
                        ],
                      );
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      ElevatedButton(
                        onPressed: () => Navigator.pop(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.grey[300],
                          textStyle: const TextStyle(fontFamily: 'Jua'),
                        ),
                        child: const Text("Back?", style: TextStyle(fontFamily: 'Jua', color: Colors.black)),
                      ),
                      const SizedBox(width: 90),
                      ElevatedButton(
                        onPressed: highestUnlockedLevel < 10
                            ? () => _onLevelTap(context, highestUnlockedLevel + 1, highestUnlockedLevel)
                            : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFDEDEDF),
                          textStyle: const TextStyle(fontFamily: 'Jua'),
                        ),
                        child: const Text("Next", style: TextStyle(fontFamily: 'Jua', color: Colors.black)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _ZigzagLinePainter extends CustomPainter {
  final List<Offset> points;
  _ZigzagLinePainter(this.points);

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;
    final paint = Paint()
      ..color = const Color.fromARGB(255, 156, 156, 156)
      ..strokeWidth = 5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    for (int i = 0; i < points.length - 1; i++) {
      final p1 = points[i];
      final p2 = points[i + 1];
      final controlPoint = Offset(
        (p1.dx + p2.dx) / 2,
        (p1.dy + p2.dy) / 2 + 40 * ((i % 2 == 0) ? 1 : -1), 
      );
      final path = Path()
        ..moveTo(p1.dx, p1.dy)
        ..quadraticBezierTo(controlPoint.dx, controlPoint.dy, p2.dx, p2.dy);
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}