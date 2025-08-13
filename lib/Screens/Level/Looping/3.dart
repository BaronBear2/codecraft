import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

DateTime? _levelEnterTime;
enum BlockType { move, moveBack, moveDown, repeat }

class Block {
  final BlockType type;
  int repeatCount;
  List<Block> children;

  Block({
    required this.type,
    this.repeatCount = 2,
    List<Block>? children,
  }) : children = children ?? [];
}

class LevelThreeScreen extends StatefulWidget {
  const LevelThreeScreen({super.key});

  @override
  State<LevelThreeScreen> createState() => _LevelThreeScreenState();
}

class _LevelThreeScreenState extends State<LevelThreeScreen> with TickerProviderStateMixin {
  static const int maxProgramBlocks = 15;
  static const int goalBlockCount = 6;

  List<Block> program = [];
  int penguinRow = 0;
  int penguinCol = 0;
  bool isRunning = false;
  bool showFail = false;
  bool showSuccess = false;
  bool trashActive = false;
  bool showTutorial = true;
  bool showHint = false;
  List<int>? runningBlockPath;

  late AnimationController _controller;
  late Animation<double> _penguinScale;
  final ScrollController _scrollController = ScrollController();
  final PageController _pageController = PageController();

  // Level 3's active tiles (not a full grid)
  final List<List<int>> activeTiles = [
    [0, 0], [0, 1], [0, 2], [0, 3], [0, 4], [0, 5],
    [1, 5],
    [2, 0], [2, 1], [2, 2], [2, 3], [2, 4], [2, 5],
  ];

  Future<void> _updateProgress(int level) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final doc = FirebaseFirestore.instance.collection('user_progress').doc(user.uid);
      final snapshot = await doc.get();
      final currentLevel = snapshot.exists ? (snapshot.data()?['highestLevel'] ?? 1) : 1;
      if (level > currentLevel) {
        await doc.set({'highestLevel': level}, SetOptions(merge: true));
      }
    }
  }

  Future<void> _incrementAttempt() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final doc = FirebaseFirestore.instance.collection('user_progress').doc(user.uid);
      await doc.set({'totalAttempt': FieldValue.increment(1)}, SetOptions(merge: true));
    }
  }

  Future<void> _addTimeSpent(int seconds) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final doc = FirebaseFirestore.instance.collection('user_progress').doc(user.uid);
      await doc.set({'totalTimeSpent': FieldValue.increment(seconds)}, SetOptions(merge: true));
    }
  }

  Future<void> _saveLevelTimeSpent() async {
    if (_levelEnterTime != null) {
      final secondsSpent = DateTime.now().difference(_levelEnterTime!).inSeconds;
      await _addTimeSpent(secondsSpent);
    }
  }

  @override
  void initState() {
    super.initState();
    isRunning = false;
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
      lowerBound: 0.9,
      upperBound: 1.1,
    );
    _penguinScale = Tween<double>(begin: 1, end: 1.1).animate(_controller);
    _levelEnterTime = DateTime.now();
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    _pageController.dispose();
    _saveLevelTimeSpent();
    super.dispose();
  }

  void runProgram() async {
    if (isRunning) return;
    await _incrementAttempt();
    _pageController.animateToPage(
      0,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOut,
    );
    setState(() {
      isRunning = true;
      showFail = false;
      showSuccess = false;
      penguinRow = 0;
      penguinCol = 0;
    });
    await _execute(program);
    setState(() {
      isRunning = false;
      if (penguinRow == 2 && penguinCol == 0 && _countBlocks(program) <= goalBlockCount) {
        showSuccess = true;
      } else {
        showFail = true;
      }
    });
  }

  Future<void> _execute(List<Block> blocks, [List<int> parentPath = const []]) async {
    for (int i = 0; i < blocks.length; i++) {
      final block = blocks[i];
      final currentPath = [...parentPath, i];
      setState(() {
        runningBlockPath = currentPath;
      });
      await Future.delayed(const Duration(milliseconds: 200));

      if (block.type == BlockType.move) {
        if (penguinCol < 5 && activeTiles.any((pos) => pos[0] == penguinRow && pos[1] == penguinCol + 1)) {
          await _controller.forward();
          await Future.delayed(const Duration(milliseconds: 200));
          await _controller.reverse();
          setState(() => penguinCol++);
          await Future.delayed(const Duration(milliseconds: 300));
        }
      } else if (block.type == BlockType.moveBack) {
        if (penguinCol > 0 && activeTiles.any((pos) => pos[0] == penguinRow && pos[1] == penguinCol - 1)) {
          await _controller.forward();
          await Future.delayed(const Duration(milliseconds: 200));
          await _controller.reverse();
          setState(() => penguinCol--);
          await Future.delayed(const Duration(milliseconds: 300));
        }
      } else if (block.type == BlockType.moveDown) {
        if (penguinRow < 2 && activeTiles.any((pos) => pos[0] == penguinRow + 1 && pos[1] == penguinCol)) {
          await _controller.forward();
          await Future.delayed(const Duration(milliseconds: 200));
          await _controller.reverse();
          setState(() => penguinRow++);
          await Future.delayed(const Duration(milliseconds: 300));
        }
      } else if (block.type == BlockType.repeat) {
        for (int j = 0; j < block.repeatCount; j++) {
          await _execute(block.children, currentPath);
        }
      }
    }
    setState(() {
      runningBlockPath = null;
    });
  }

  void _showLimitMessage() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Maksimum jumlah blok tercapai!')),
    );
  }

  int _countBlocks(List<Block> blocks) {
    int count = 0;
    for (var block in blocks) {
      count++;
      if (block.type == BlockType.repeat) {
        count += _countBlocks(block.children);
      }
    }
    return count;
  }

  Block _getBlockByPath(List<Block> root, List<int> path) {
    Block current = root[path[0]];
    for (int i = 1; i < path.length; i++) {
      current = current.children[path[i]];
    }
    return current;
  }

  void _removeBlockByPath(List<Block> root, List<int> path) {
    if (path.length == 1) {
      root.removeAt(path[0]);
    } else {
      List<int> parentPath = path.sublist(0, path.length - 1);
      Block parent = _getBlockByPath(root, parentPath);
      parent.children.removeAt(path.last);
    }
  }

  void _insertBlockByPath(List<Block> root, List<int> path, int insertAt, Block block) {
    if (path.isEmpty) {
      root.insert(insertAt, block);
    } else {
      Block parent = _getBlockByPath(root, path);
      parent.children.insert(insertAt, block);
    }
  }

  bool _isDescendant(List<int> ancestor, List<int> descendant) {
    if (ancestor.length >= descendant.length) return false;
    for (int i = 0; i < ancestor.length; i++) {
      if (ancestor[i] != descendant[i]) return false;
    }
    return true;
  }

  Widget buildBlock(Block block, List<int> path, {int indent = 0}) {
    final isRunning = runningBlockPath != null && runningBlockPath!.join(',') == path.join(',');
    final isLoopActive = runningBlockPath != null &&
        runningBlockPath!.length > path.length &&
        List.generate(path.length, (i) => runningBlockPath![i] == path[i]).every((e) => e);

    return Padding(
      padding: EdgeInsets.only(left: indent * 20.0, bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LongPressDraggable<List<int>>(
            data: path,
            delay: const Duration(milliseconds: 100),
            feedback: Material(
              color: Colors.transparent,
              child: _blockChip(block, dragging: true, highlight: isRunning),
            ),
            childWhenDragging: Opacity(opacity: 0.3, child: _blockChip(block, highlight: isRunning)),
            child: DragTarget<List<int>>(
              onWillAccept: (fromPath) {
                if (fromPath == null) return false;
                if (fromPath.toString() == path.toString()) return false;
                if (_isDescendant(fromPath, path)) return false;
                return true;
              },
              onAccept: (fromPath) {
                setState(() {
                  Block moved = _getBlockByPath(program, fromPath);
                  _removeBlockByPath(program, fromPath);
                  _insertBlockByPath(program, path.sublist(0, path.length - 1), path.last, moved);
                });
              },
              builder: (context, candidateData, rejectedData) {
                if (block.type == BlockType.move || block.type == BlockType.moveBack || block.type == BlockType.moveDown) {
                  return _blockChip(block, highlight: isRunning);
                } else {
                  // Loop block UI
                  return Container(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    decoration: BoxDecoration(
                      color: isLoopActive
                          ? Colors.green[200]
                          : (isRunning ? Colors.green[300] : Colors.green[50]),
                      border: Border.all(
                        color: isLoopActive || isRunning ? Colors.green : Colors.green,
                        width: isLoopActive ? 3 : 2.5,
                      ),
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.green.withOpacity(0.08),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(10.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _blockChip(block, highlight: isRunning),
                              const SizedBox(width: 8),
                              IconButton(
                                icon: const Icon(Icons.remove, size: 18, color: Colors.green),
                                onPressed: block.repeatCount > 2 && !isRunning
                                    ? () => setState(() => block.repeatCount--)
                                    : null,
                                splashRadius: 18,
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                              ),
                              Text(
                                "${block.repeatCount}",
                                style: const TextStyle(fontFamily: 'Jua', fontWeight: FontWeight.bold),
                              ),
                              IconButton(
                                icon: const Icon(Icons.add, size: 18, color: Colors.green),
                                onPressed: !isRunning
                                    ? () => setState(() => block.repeatCount++)
                                    : null,
                                splashRadius: 18,
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                              ),
                            ],
                          ),
                          for (int i = 0; i < block.children.length; i++)
                            buildBlock(block.children[i], [...path, i], indent: indent + 1),
                          DragTarget<List<int>>(
                            onWillAccept: (fromPath) {
                              if (fromPath == null) return false;
                              if (_isDescendant(fromPath, [...path, block.children.length])) return false;
                              return true;
                            },
                            onAccept: (fromPath) {
                              setState(() {
                                Block moved = _getBlockByPath(program, fromPath);
                                _removeBlockByPath(program, fromPath);
                                block.children.add(moved);
                              });
                            },
                            builder: (context, candidateData, rejectedData) => Container(
                              margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
                              decoration: BoxDecoration(
                                color: candidateData.isNotEmpty ? Colors.green[100] : Colors.green[50],
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: candidateData.isNotEmpty ? Colors.green : Colors.green[200]!,
                                  width: 1.5,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.arrow_downward, color: Colors.green, size: 16),
                                  const SizedBox(width: 4),
                                  Text(
                                    "Drop block here",
                                    style: TextStyle(
                                      fontFamily: 'Jua',
                                      fontSize: 12,
                                      color: Colors.green[700],
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _blockChip(Block block, {bool dragging = false, bool highlight = false}) {
    Color? chipColor;
    Color? borderColor;
    Color? avatarColor;

    if (block.type == BlockType.move) {
      chipColor = highlight ? Colors.blue[300] : (dragging ? Colors.blue[200] : Colors.blue[100]);
      borderColor = Colors.blueAccent;
      avatarColor = Colors.blue;
    } else if (block.type == BlockType.moveBack) {
      chipColor = highlight ? Colors.purple[300] : (dragging ? Colors.purple[200] : Colors.purple[100]);
      borderColor = Colors.purple;
      avatarColor = Colors.purple;
    } else if (block.type == BlockType.moveDown) {
      chipColor = highlight ? Colors.orange[300] : (dragging ? Colors.orange[200] : Colors.orange[100]);
      borderColor = Colors.orange;
      avatarColor = Colors.orange;
    } else {
      chipColor = highlight ? Colors.green[400] : (dragging ? Colors.green[200] : Colors.green[100]);
      borderColor = Colors.green;
      avatarColor = Colors.green;
    }

    return Chip(
      label: Text(
        block.type == BlockType.move
            ? "Move"
            : block.type == BlockType.moveBack
                ? "Move Back"
                : block.type == BlockType.moveDown
                    ? "Move Down"
                    : "Loop x${block.repeatCount}",
        style: const TextStyle(fontFamily: 'Jua', fontSize: 16),
      ),
      backgroundColor: chipColor,
      avatar: CircleAvatar(
        backgroundColor: avatarColor,
        child: Icon(
          block.type == BlockType.move
              ? Icons.arrow_forward
              : block.type == BlockType.moveBack
                  ? Icons.arrow_back
                  : block.type == BlockType.moveDown
                      ? Icons.arrow_downward
                      : Icons.repeat,
          color: Colors.white,
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      side: BorderSide(color: borderColor, width: 2),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PageView(
      controller: _pageController,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        // Page 0: Main game
        Stack(
          children: [
            Container(
              decoration: const BoxDecoration(
                image: DecorationImage(
                  image: AssetImage('assets/igloo3.png'),
                  fit: BoxFit.cover,
                ),
              ),
            ),
            Scaffold(
              backgroundColor: Colors.transparent,
              appBar: AppBar(
                title: Row(
                  children: [
                    const Text("Level 3", style: TextStyle(fontFamily: 'Jua', color: Colors.black)),
                    const SizedBox(width: 100),
                    ElevatedButton.icon(
                      onPressed: () {
                        setState(() {
                          showHint = true;
                        });
                      },
                      icon: const Icon(Icons.lightbulb, color: Colors.amber, size: 22),
                      label: const Text("Hint", style: TextStyle(fontFamily: 'Jua', color: Colors.black)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.yellow[200],
                        foregroundColor: Colors.black,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        textStyle: const TextStyle(fontFamily: 'Jua', fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                backgroundColor: Colors.white,
                elevation: 0,
                iconTheme: const IconThemeData(color: Colors.black),
              ),
              body: Column(
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 32, bottom: 4),
                    child: Text(
                      "Sekarang penguin bisa mundur!\nAyo coba dapatkan ikan dengan cara baru!",
                      style: TextStyle(
                        color: Colors.black87,
                        fontFamily: 'Jua',
                        fontSize: 18,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      "Goal: Raih ikan dengan maksimum $goalBlockCount blok!",
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Jua',
                        fontSize: 14,
                        color: Color.fromRGBO(204, 0, 0, 1),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24.0),
                      child: GridView.builder(
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 6,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                        ),
                        itemCount: 18, // 3 rows x 6 columns
                        itemBuilder: (context, index) {
                          int row = index ~/ 6;
                          int col = index % 6;
                          bool isActive = activeTiles.any((pos) => pos[0] == row && pos[1] == col);
                          if (row == penguinRow && col == penguinCol) {
                            return ScaleTransition(
                              scale: _penguinScale,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.blue[50],
                                  borderRadius: BorderRadius.circular(18),
                                  border: Border.all(color: Colors.blueAccent, width: 2),
                                ),
                                child: Center(
                                  child: Image.asset(
                                    'assets/penguin2.png',
                                    width: 100,
                                    height: 100,
                                    fit: BoxFit.contain,
                                  ),
                                ),
                              ),
                            );
                          } else if (row == 2 && col == 0) {
                            return Container(
                              decoration: BoxDecoration(
                                color: Colors.blue[50],
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(color: Colors.blue, width: 2),
                              ),
                              child: Image.asset(
                                'assets/fish.png',
                                width: 60,
                                height: 60,
                                fit: BoxFit.contain,
                              ),
                            );
                          } else if (isActive) {
                            return Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(color: Colors.grey[400]!),
                              ),
                            );
                          } else {
                            return const SizedBox.shrink();
                          }
                        },
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 40),
                        child: ElevatedButton(
                          onPressed: () {
                            _pageController.animateToPage(
                              1,
                              duration: const Duration(milliseconds: 400),
                              curve: Curves.easeInOut,
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color.fromRGBO(186, 252, 255, 1),
                            foregroundColor: const Color.fromARGB(255, 0, 0, 0),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                            elevation: 0,
                            minimumSize: const Size(100, 30),
                          ),
                          child: const Text(
                            "Program Area",
                            style: TextStyle(fontFamily: 'Jua', fontSize: 18),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Overlays (showFail, showSuccess, showTutorial, showHint)
            if (showFail)
              Positioned.fill(
                child: Container(
                  color: Colors.black54,
                  child: Center(
                    child: Card(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                      color: Colors.white,
                      elevation: 2,
                      child: Padding(
                        padding: const EdgeInsets.all(32.0),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Image.asset(
                              'assets/penguin_sad.png',
                              width: 120,
                              height: 120,
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              "Kamu kekurangan atau kelebihan blok",
                              style: TextStyle(fontFamily: 'Jua', fontSize: 20, color: Color.fromARGB(255, 54, 158, 244)),
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: () {
                                setState(() {
                                  penguinRow = 0;
                                  penguinCol = 0;
                                  showFail = false;
                                  isRunning = false;
                                });
                              },
                              child: const Text("Coba Lagi", style: TextStyle(fontFamily: 'Jua')),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            if (showSuccess)
              Positioned.fill(
                child: Container(
                  color: Colors.black54,
                  child: Center(
                    child: Card(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                      color: Colors.white,
                      elevation: 2,
                      child: Padding(
                        padding: const EdgeInsets.all(32.0),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Image.asset(
                              'assets/penguin1.png',
                              width: 120,
                              height: 120,
                              fit: BoxFit.contain,
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              "Berhasil!",
                              style: TextStyle(fontFamily: 'Jua', fontSize: 28, color: Colors.green),
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: () async {
                                await _updateProgress(4);
                                Navigator.pushReplacementNamed(context, '/level4');
                              },
                              child: const Text("Next Level", style: TextStyle(fontFamily: 'Jua')),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            if (showTutorial)
              Positioned.fill(
                child: GestureDetector(
                  onTap: () => setState(() => showTutorial = false),
                  child: Container(
                    color: Colors.black54,
                    child: Center(
                      child: Card(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                        color: Colors.white,
                        elevation: 4,
                        child: Padding(
                          padding: const EdgeInsets.all(32.0),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Image.asset(
                                'assets/penguin2.png',
                                width: 100,
                                height: 100,
                              ),
                              const SizedBox(height: 16),
                              const Text(
                                "Level 3",
                                style: TextStyle(
                                  fontFamily: 'Jua',
                                  fontSize: 24,
                                  color: Colors.blueAccent,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 12),
                              const Text(
                                "1. Buka area program di bawah!\n"
                                "2. Klik tombol Move, Move Back, Move Down, dan Loop!\n"
                                "3. Susun blok agar penguin bisa ke bawah, ke kanan, atau mundur!\n"
                                "4. Jalankan program untuk menggerakkan penguin ke arah ikan!\n"
                                "5. Coba gunakan Loop untuk lebih efisien!",
                                style: TextStyle(
                                  fontFamily: 'Jua',
                                  fontSize: 16,
                                  color: Colors.black87,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 20),
                              const Text(
                                "Tap di mana saja untuk mulai!",
                                style: TextStyle(
                                  fontFamily: 'Jua',
                                  fontSize: 14,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            if (showHint)
              Positioned.fill(
                child: Container(
                  color: Colors.black54,
                  child: Center(
                    child: Card(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                      color: Colors.white,
                      elevation: 2,
                      child: Padding(
                        padding: const EdgeInsets.all(32.0),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.lightbulb, color: Colors.amber, size: 60),
                            const SizedBox(height: 16),
                            const Text(
                              "Hint",
                              style: TextStyle(fontFamily: 'Jua', fontSize: 24, color: Colors.amber, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              "Gunakan 1 Move, 1 Move Back, 2 Move Down dan 2 Loop!\nCoba gunakan Loop untuk menghemat blok.",
                              style: TextStyle(fontFamily: 'Jua', fontSize: 18, color: Colors.black87),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: () {
                                setState(() {
                                  showHint = false;
                                });
                              },
                              style: ElevatedButton.styleFrom(
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              child: const Text("Tutup", style: TextStyle(fontFamily: 'Jua')),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
        // Page 1: Program area (terminal)
        Scaffold(
          backgroundColor: Colors.white,
          appBar: AppBar(
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.black),
              onPressed: () {
                _pageController.animateToPage(
                  0,
                  duration: const Duration(milliseconds: 400),
                  curve: Curves.easeInOut,
                );
              },
            ),
            title: const Text("Your Program", style: TextStyle(fontFamily: 'Jua', color: Colors.black)),
            backgroundColor: Colors.white,
            elevation: 0,
            iconTheme: const IconThemeData(color: Colors.black),
          ),
          body: Column(
            children: [
              const SizedBox(height: 8),
              const Opacity(
                opacity: 0.5,
                child: Text(
                  "Tekan, tahan, dan geser",
                  style: TextStyle(fontFamily: 'Jua', fontSize: 13, color: Color.fromARGB(255, 255, 53, 53)),
                ),
              ),
              Expanded(
                child: Scrollbar(
                  controller: _scrollController,
                  thumbVisibility: true,
                  child: SingleChildScrollView(
                    controller: _scrollController,
                    scrollDirection: Axis.horizontal,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(minWidth: 600),
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: List.generate(
                            program.length,
                            (i) => buildBlock(program[i], [i]),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    height: 40,
                    child: ElevatedButton.icon(
                      onPressed: isRunning
                          ? null
                          : () {
                              setState(() {
                                program.clear();
                              });
                            },
                      icon: const Icon(Icons.refresh, color: Colors.blue, size: 20),
                      label: const Text("Reset", style: TextStyle(fontFamily: 'Jua', fontSize: 14)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue[50],
                        foregroundColor: Colors.blue[900],
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        minimumSize: const Size(80, 40),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        textStyle: const TextStyle(fontFamily: 'Jua'),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    height: 40,
                    child: DragTarget<List<int>>(
                      onWillAccept: (fromPath) => true,
                      onMove: (_) => setState(() => trashActive = true),
                      onLeave: (_) => setState(() => trashActive = false),
                      onAccept: (fromPath) {
                        setState(() {
                          _removeBlockByPath(program, fromPath);
                          trashActive = false;
                        });
                      },
                      builder: (context, candidateData, rejectedData) => AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        curve: Curves.ease,
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        decoration: BoxDecoration(
                          color: trashActive || candidateData.isNotEmpty
                              ? Colors.red[200]
                              : Colors.red[50],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.red[300]!,
                            width: 2,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.delete,
                              size: 22,
                              color: trashActive || candidateData.isNotEmpty
                                  ? Colors.red[800]
                                  : Colors.red[400],
                            ),
                            const SizedBox(width: 6),
                            const Text(
                              "Trash",
                              style: TextStyle(
                                fontFamily: 'Jua',
                                fontSize: 14,
                                color: Colors.red,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      height: 40,
                      child: ElevatedButton.icon(
                        onPressed: isRunning
                            ? null
                            : _countBlocks(program) < maxProgramBlocks
                                ? () => setState(() => program.add(Block(type: BlockType.move)))
                                : _showLimitMessage,
                        icon: const Icon(Icons.arrow_forward, color: Colors.blue, size: 22),
                        label: const Text("Move", style: TextStyle(fontFamily: 'Jua', fontSize: 16)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue[100],
                          foregroundColor: Colors.blue[900],
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          minimumSize: const Size(0, 40),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    SizedBox(
                      height: 40,
                      child: ElevatedButton.icon(
                        onPressed: isRunning
                            ? null
                            : _countBlocks(program) < maxProgramBlocks
                                ? () => setState(() => program.add(Block(type: BlockType.moveBack)))
                                : _showLimitMessage,
                        icon: const Icon(Icons.arrow_back, color: Colors.purple, size: 22),
                        label: const Text("Move Back", style: TextStyle(fontFamily: 'Jua', fontSize: 16)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.purple[100],
                          foregroundColor: Colors.purple[900],
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          minimumSize: const Size(0, 40),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    SizedBox(
                      height: 40,
                      child: ElevatedButton.icon(
                        onPressed: isRunning
                            ? null
                            : _countBlocks(program) < maxProgramBlocks
                                ? () => setState(() => program.add(Block(type: BlockType.moveDown)))
                                : _showLimitMessage,
                        icon: const Icon(Icons.arrow_downward, color: Colors.orange, size: 22),
                        label: const Text("Move Down", style: TextStyle(fontFamily: 'Jua', fontSize: 16)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange[100],
                          foregroundColor: Colors.orange[900],
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          minimumSize: const Size(0, 40),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    SizedBox(
                      height: 40,
                      child: ElevatedButton.icon(
                        onPressed: isRunning
                            ? null
                            : _countBlocks(program) < maxProgramBlocks
                                ? () => setState(() => program.add(Block(type: BlockType.repeat)))
                                : _showLimitMessage,
                        icon: const Icon(Icons.repeat, color: Colors.green, size: 22),
                        label: const Text("Loop", style: TextStyle(fontFamily: 'Jua', fontSize: 16)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green[100],
                          foregroundColor: Colors.green[900],
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          minimumSize: const Size(0, 40),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: isRunning ? null : runProgram,
                  icon: const Icon(Icons.play_arrow, color: Colors.white, size: 28),
                  label: const Text("Run", style: TextStyle(fontFamily: 'Jua', fontSize: 18, color: Colors.white)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.all(12),
                    elevation: 0,
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ],
    );
  }
}