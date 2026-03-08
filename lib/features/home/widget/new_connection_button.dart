import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

enum ConnectionStateStatus { disconnected, connecting, connected, error }

// ============ ADMOB ============
const String _testAdUnitId = 'ca-app-pub-3940256099942544/1033173712'; // тест
const String _prodAdUnitId = 'ca-app-pub-XXXXXXXXXXXXXXXX/XXXXXXXXXX'; // ← замени на свой

// ============ АДМИН ПИН ============
const String _adminPin = "030305";

class CircleDesignWidget extends StatefulWidget {
  @override
  _CircleDesignWidgetState createState() => _CircleDesignWidgetState();
}

class _CircleDesignWidgetState extends State<CircleDesignWidget>
    with SingleTickerProviderStateMixin {
  ConnectionStateStatus _currentState = ConnectionStateStatus.disconnected;
  late AnimationController _controller;
  late Animation<double> _animation;

  // ---- AdMob ----
  InterstitialAd? _interstitialAd;
  bool _isAdLoaded = false;

  // ---- Удержание для админки ----
  bool _isLongPressing = false;

  @override
  void initState() {
    super.initState();

    _controller =
        AnimationController(duration: const Duration(seconds: 4), vsync: this)
          ..repeat(reverse: true);

    _animation = Tween<double>(begin: 0.8, end: 1).animate(_controller)
      ..addListener(() {
        setState(() {});
      });

    // Загружаем рекламу сразу при старте
    _loadAd();
  }

  @override
  void dispose() {
    _controller.dispose();
    _interstitialAd?.dispose();
    super.dispose();
  }

  // ============ ЗАГРУЗКА РЕКЛАМЫ ============
  void _loadAd() {
    InterstitialAd.load(
      adUnitId: _testAdUnitId, // замени на _prodAdUnitId когда будешь публиковать
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitialAd = ad;
          _isAdLoaded = true;
        },
        onAdFailedToLoad: (error) {
          _isAdLoaded = false;
          // Повторная попытка через 30 сек
          Future.delayed(const Duration(seconds: 30), _loadAd);
        },
      ),
    );
  }

  // ============ ПОКАЗАТЬ РЕКЛАМУ → ПОДКЛЮЧИТЬ ============
  void _showAdThenConnect() {
    if (_isAdLoaded && _interstitialAd != null) {
      _interstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
        onAdDismissedFullScreenContent: (ad) {
          ad.dispose();
          _interstitialAd = null;
          _isAdLoaded = false;
          _loadAd(); // грузим следующую
          _doConnect(); // подключаем после просмотра
        },
        onAdFailedToShowFullScreenContent: (ad, error) {
          ad.dispose();
          _interstitialAd = null;
          _isAdLoaded = false;
          _loadAd();
          _doConnect(); // если ошибка — всё равно подключаем
        },
      );
      _interstitialAd!.show();
    } else {
      // Реклама не загружена — подключаем сразу
      _doConnect();
    }
  }

  void _doConnect() {
    changeState(ConnectionStateStatus.connecting);
  }

  // ============ СМЕНА СОСТОЯНИЯ ============
  void changeState(ConnectionStateStatus state) {
    setState(() {
      _currentState = state;
      if (state == ConnectionStateStatus.connecting ||
          state == ConnectionStateStatus.connected) {
        _controller.repeat(reverse: true);
      } else {
        _controller.stop();
      }
    });
  }

  // ============ СКРЫТАЯ АДМИН ПАНЕЛЬ ============
  void _onLongPressStart(LongPressStartDetails details) {
    _isLongPressing = true;
    Future.delayed(const Duration(seconds: 15), () {
      if (_isLongPressing && mounted) {
        HapticFeedback.heavyImpact();
        _showPinDialog();
      }
    });
  }

  void _onLongPressEnd(LongPressEndDetails details) {
    _isLongPressing = false;
  }

  void _showPinDialog() {
    final pinController = TextEditingController();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.black87,
        title: const Text(
          "🔐",
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 32),
        ),
        content: TextField(
          controller: pinController,
          obscureText: true,
          keyboardType: TextInputType.number,
          maxLength: 6,
          style: const TextStyle(color: Colors.white, fontSize: 24),
          textAlign: TextAlign.center,
          decoration: const InputDecoration(
            counterText: "",
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: Colors.white30),
            ),
            focusedBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: Colors.white),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              if (pinController.text == _adminPin) {
                _openAdminPanel();
              }
            },
            child:
                const Text("OK", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _openAdminPanel() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const AdminPanelScreen()),
    );
  }

  // ============ ОБРАБОТКА НАЖАТИЯ ============
  void _onTap() {
    switch (_currentState) {
      case ConnectionStateStatus.disconnected:
      case ConnectionStateStatus.error:
        // Показываем рекламу → потом подключаем
        _showAdThenConnect();
        break;
      case ConnectionStateStatus.connecting:
      case ConnectionStateStatus.connected:
        // Отключение — без рекламы
        changeState(ConnectionStateStatus.disconnected);
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _onTap,
      onLongPressStart: _onLongPressStart,
      onLongPressEnd: _onLongPressEnd,
      child: CustomPaint(
        size: const Size(168, 168),
        painter: CirclePainter(
          currentState: _currentState,
          animationValue: _animation.value,
        ),
      ),
    );
  }
}

// ============ PAINTER (без изменений) ============
class CirclePainter extends CustomPainter {
  final ConnectionStateStatus currentState;
  final double animationValue;

  CirclePainter({required this.currentState, required this.animationValue});

  @override
  void paint(Canvas canvas, Size size) {
    final double cx = size.width / 2;
    final double cy = size.height / 2;

    Color baseColor;
    var innerCircleColor = [const Color(0xFF455FE9), const Color(0xFF3446A5)];
    if (currentState == ConnectionStateStatus.connected) {
      baseColor = Colors.green.shade900;
    } else if (currentState == ConnectionStateStatus.error) {
      baseColor = Colors.red.shade900;
    } else {
      baseColor = const Color(0xFF3446A5);
    }
    innerCircleColor = [
      baseColor.withAlpha(230),
      baseColor,
    ];

    final Paint outerCirclePaint = Paint()
      ..color = baseColor.withOpacity(0.15)
      ..style = PaintingStyle.fill;
    final double outerRadius = 84 *
        ([
          ConnectionStateStatus.connecting,
          ConnectionStateStatus.connected
        ].contains(currentState)
            ? animationValue
            : 1);
    canvas.drawCircle(Offset(cx, cy), outerRadius, outerCirclePaint);

    final Paint middleCirclePaint = Paint()
      ..color = baseColor.withOpacity(.3)
      ..style = PaintingStyle.fill;
    final double middleRadius = 60 *
        ([
          ConnectionStateStatus.connecting,
          ConnectionStateStatus.connected
        ].contains(currentState)
            ? animationValue + (1 - animationValue) / 3
            : 1);
    canvas.drawCircle(Offset(cx, cy), middleRadius, middleCirclePaint);

    final Paint innerCirclePaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: innerCircleColor,
      ).createShader(Rect.fromCircle(center: Offset(cx, cy), radius: 36));
    canvas.drawCircle(Offset(cx, cy), innerCirclePaint.shader != null ? 36 : 36, innerCirclePaint);

    final Paint pathPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.80952
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final Path curvePath = Path()
      ..moveTo(92.4867, 75.52)
      ..cubicTo(94.1645, 77.1984, 95.307, 79.3366, 95.7697, 81.6643)
      ..cubicTo(96.2324, 83.9919, 95.9946, 86.4045, 95.0862, 88.597)
      ..cubicTo(94.1778, 90.7895, 92.6397, 92.6634, 90.6664, 93.9818)
      ..cubicTo(88.6931, 95.3002, 86.3732, 96.0039, 84, 96.0039)
      ..cubicTo(81.6268, 96.0039, 79.3069, 95.3002, 77.3336, 93.9818)
      ..cubicTo(75.3603, 92.6634, 73.8222, 90.7895, 72.9138, 88.597)
      ..cubicTo(72.0055, 86.4045, 71.7676, 83.9919, 72.2303, 81.6643)
      ..cubicTo(72.693, 79.3366, 73.8355, 77.1984, 75.5133, 75.52);
    canvas.drawPath(curvePath, pathPaint);

    final Path linePath = Path()
      ..moveTo(84.0066, 72)
      ..lineTo(84.0066, 82.6667);
    canvas.drawPath(linePath, pathPaint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => true;
}

// ============ АДМИН ПАНЕЛЬ ЭКРАН ============
class AdminPanelScreen extends StatefulWidget {
  const AdminPanelScreen({Key? key}) : super(key: key);

  @override
  State<AdminPanelScreen> createState() => _AdminPanelScreenState();
}

class _AdminPanelScreenState extends State<AdminPanelScreen> {
  final _subUrlController = TextEditingController();
  final _messageController = TextEditingController();
  String _statusMessage = "";

  final List<Map<String, dynamic>> _servers = [
    {"name": "🇩🇪 Germany", "enabled": true},
    {"name": "🇳🇱 Netherlands", "enabled": true},
    {"name": "🇫🇮 Finland", "enabled": true},
    {"name": "🇫🇷 France", "enabled": true},
    {"name": "🇺🇸 USA", "enabled": true},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF111111),
        title: const Text("Admin Panel",
            style: TextStyle(color: Colors.white)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionTitle("⚙️ Серверы"),
            const SizedBox(height: 8),
            ...(_servers.map((s) => _serverTile(s)).toList()),
            const SizedBox(height: 24),
            _sectionTitle("🔗 URL подписки"),
            const SizedBox(height: 8),
            _inputField(
              controller: _subUrlController,
              hint: "https://domain.com/sub/...",
              label: "Новый URL",
            ),
            const SizedBox(height: 8),
            _actionButton(
              label: "💾 Сохранить",
              color: Colors.blue,
              onTap: () => setState(
                  () => _statusMessage = "✅ URL обновлён"),
            ),
            const SizedBox(height: 24),
            _sectionTitle("📢 Сообщение пользователям"),
            const SizedBox(height: 8),
            _inputField(
              controller: _messageController,
              hint: "Текст...",
              label: "Сообщение",
              maxLines: 4,
            ),
            const SizedBox(height: 8),
            _actionButton(
              label: "📤 Отправить всем",
              color: Colors.orange,
              onTap: () => setState(
                  () => _statusMessage = "✅ Отправлено"),
            ),
            const SizedBox(height: 16),
            if (_statusMessage.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  border: Border.all(
                      color: Colors.green.withOpacity(0.3)),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(_statusMessage,
                    style:
                        const TextStyle(color: Colors.greenAccent)),
              ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String title) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Text(title,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold)),
      );

  Widget _serverTile(Map<String, dynamic> server) => Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white10),
        ),
        child: ListTile(
          title: Text(server["name"],
              style: const TextStyle(color: Colors.white)),
          subtitle: Text(
            server["enabled"] ? "✅ Активен" : "❌ Выключен",
            style: TextStyle(
                color: server["enabled"]
                    ? Colors.greenAccent
                    : Colors.redAccent,
                fontSize: 12),
          ),
          trailing: Switch(
            value: server["enabled"],
            activeColor: Colors.greenAccent,
            onChanged: (val) =>
                setState(() => server["enabled"] = val),
          ),
        ),
      );

  Widget _inputField({
    required TextEditingController controller,
    required String hint,
    required String label,
    int maxLines = 1,
  }) =>
      TextField(
        controller: controller,
        maxLines: maxLines,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Colors.white54),
          hintText: hint,
          hintStyle: const TextStyle(color: Colors.white24),
          filled: true,
          fillColor: const Color(0xFF1A1A1A),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide:
                  const BorderSide(color: Colors.white10)),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide:
                  const BorderSide(color: Colors.white10)),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Colors.blue)),
        ),
      );

  Widget _actionButton({
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) =>
      SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: onTap,
          style: ElevatedButton.styleFrom(
            backgroundColor: color.withOpacity(0.2),
            side: BorderSide(color: color.withOpacity(0.5)),
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
          ),
          child: Text(label,
              style: TextStyle(color: color, fontSize: 15)),
        ),
      );
}
