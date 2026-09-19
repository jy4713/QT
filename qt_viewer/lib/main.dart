import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

void main() => runApp(const QtApp());

class QtApp extends StatelessWidget {
  const QtApp({super.key});
  @override
  Widget build(BuildContext context) => const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: QtViewerPage(),
      );
}

class QtViewerPage extends StatefulWidget {
  const QtViewerPage({super.key});
  @override
  State<QtViewerPage> createState() => _QtViewerPageState();
}

class _QtViewerPageState extends State<QtViewerPage> {
  static const _base = 'https://qtland.com/data/meditation/';

  DateTime _date = DateTime.now();
  String _edition = 'A';
  Uint8List? _bytes;
  Size? _imgSize;
  bool _loading = false;
  bool _fromCache = false;
  double _zoom = 1.0; // 1.0 = 화면에 맞춘 기본 크기
  final PageController _pageController = PageController();
  final List<TransformationController> _viewerControllers =
      List.generate(2, (_) => TransformationController());
  bool _pinchZoomed = false; // 핀치로 확대 중이면 페이지 스와이프 비활성화
  int _currentPage = 0;
  String _todayKey() => _key(_date, _edition);

  static String _key(DateTime d, String e) =>
      '$e${d.year.toString().padLeft(4, '0')}${d.month.toString().padLeft(2, '0')}${d.day.toString().padLeft(2, '0')}';

  @override
  void initState() {
    super.initState();
    for (final c in _viewerControllers) {
      c.addListener(_onTransform);
    }
    _pageController.addListener(_onPage);
    _load();
  }

  @override
  void dispose() {
    _pageController.removeListener(_onPage);
    _pageController.dispose();
    for (final c in _viewerControllers) {
      c.removeListener(_onTransform);
      c.dispose();
    }
    super.dispose();
  }

  void _onPage() {
    final p = _pageController.page?.round() ?? 0;
    if (p != _currentPage) setState(() => _currentPage = p);
  }

  void _onTransform() {
    var maxScale = 1.0;
    for (final c in _viewerControllers) {
      final s = c.value.getMaxScaleOnAxis();
      if (s > maxScale) maxScale = s;
    }
    final zoomed = maxScale > 1.01;
    if (zoomed != _pinchZoomed) setState(() => _pinchZoomed = zoomed);
  }

  bool get _isZoomed => _zoom > 1.001 || _pinchZoomed;

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _fromCache = false;
    });
    final key = _todayKey();
    try {
      final res = await http.get(
        Uri.parse('$_base$key.jpg'),
        headers: const {
          'User-Agent': 'Mozilla/5.0 (Linux; Android 13) AppleWebKit/537.36 '
              '(KHTML, like Gecko) Chrome/120.0 Mobile Safari/537.36',
          'Accept': 'image/avif,image/webp,image/apng,image/*,*/*;q=0.8',
        },
      ).timeout(const Duration(seconds: 20));
      if (res.statusCode == 200 && res.bodyBytes.isNotEmpty) {
        final size = await _decodeSize(res.bodyBytes);
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('qt_last_key', key);
        await prefs.setString('qt_last_img', base64Encode(res.bodyBytes));
        if (!mounted) return;
        setState(() {
          _bytes = res.bodyBytes;
          _imgSize = size;
          _loading = false;
        });
        return;
      }
      throw Exception('HTTP ${res.statusCode}');
    } catch (e) {
      // 오프라인/실패: 마지막으로 본 이미지 사용
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString('qt_last_img');
      if (saved != null) {
        final bytes = base64Decode(saved);
        final size = await _decodeSize(bytes);
        if (!mounted) return;
        setState(() {
          _bytes = bytes;
          _imgSize = size;
          _loading = false;
          _fromCache = true;
        });
        _toast('$_key 로딩 실패($e). 마지막으로 본 이미지를 표시합니다.');
      } else {
        if (!mounted) return;
        setState(() => _loading = false);
        _toast('$_key 로딩 실패($e). 저장된 이미지가 없습니다.');
      }
    }
  }

  Future<Size> _decodeSize(Uint8List bytes) async {
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    final size = Size(frame.image.width.toDouble(), frame.image.height.toDouble());
    frame.image.dispose();
    codec.dispose();
    return size;
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(msg), duration: const Duration(seconds: 3)));
  }

  void _changeDay(int days) {
    final d = _date.add(Duration(days: days));
    setState(() => _date = d);
    _load();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() => _date = picked);
      _load();
    }
  }

  void _setEdition(String e) {
    if (e == _edition) return;
    setState(() => _edition = e);
    _load();
  }

  // 버튼으로 배율 조절 (핀치 줌 대신)
  void _zoomBy(double factor) {
    setState(() {
      _zoom = (_zoom * factor).clamp(1.0, 16.0);
    });
  }

  @override
  Widget build(BuildContext context) {
    final dateStr =
        '${_date.year}-${_date.month.toString().padLeft(2, '0')}-${_date.day.toString().padLeft(2, '0')}';
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 전체 화면 이미지 (좌우 2페이지)
          if (_bytes != null && _imgSize != null)
            PageView(
              controller: _pageController,
              // 확대 상태에서는 이미지 드래그(이동)가 페이지 넘김보다 우선
              physics: _isZoomed
                  ? const NeverScrollableScrollPhysics()
                  : const BouncingScrollPhysics(),
              children: [_page(0), _page(1)],
            )
          else if (!_loading)
            const Center(
              child: Text('표시할 이미지가 없습니다.', style: TextStyle(color: Colors.white70)),
            ),
          if (_loading) const Center(child: CircularProgressIndicator(color: Colors.white)),

          // 상단 컨트롤 (반투명 오버레이)
          SafeArea(
            child: Align(
              alignment: Alignment.topCenter,
              child: Container(
                color: Colors.black54,
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                child: Row(
                  children: [
                    _editionButton('A'),
                    _editionButton('B'),
                    IconButton(
                      icon: const Icon(Icons.chevron_left, color: Colors.white),
                      onPressed: () => _changeDay(-1),
                    ),
                    Expanded(
                      child: TextButton(
                        onPressed: _pickDate,
                        child: FittedBox(
                          child: Text(dateStr,
                              style: const TextStyle(color: Colors.white, fontSize: 16)),
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.chevron_right, color: Colors.white),
                      onPressed: () => _changeDay(1),
                    ),
                    // 줌 컨트롤 (핀치 대신 버튼)
                    IconButton(
                      icon: const Icon(Icons.remove, color: Colors.white),
                      onPressed: () => _zoomBy(1 / 1.25),
                    ),
                    Text(
                      '${_zoom.toStringAsFixed(1)}x',
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                    IconButton(
                      icon: const Icon(Icons.add, color: Colors.white),
                      onPressed: () => _zoomBy(1.25),
                    ),
                    if (_fromCache)
                      const Padding(
                        padding: EdgeInsets.only(right: 6),
                        child: Icon(Icons.wifi_off, size: 16, color: Colors.orangeAccent),
                      ),
                  ],
                ),
              ),
            ),
          ),

          // 페이지 표시점 (탭으로 페이지 이동)
          if (_bytes != null)
            Align(
              alignment: Alignment.bottomCenter,
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: List.generate(2, (i) {
                      final active = _currentPage == i;
                      return GestureDetector(
                        onTap: () => _pageController.animateToPage(
                          i,
                          duration: const Duration(milliseconds: 200),
                          curve: Curves.easeOut,
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 5),
                          child: Icon(
                            Icons.circle,
                            size: active ? 9 : 6,
                            color: active ? Colors.tealAccent : Colors.white54,
                          ),
                        ),
                      );
                    }),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _editionButton(String e) {
    final selected = _edition == e;
    return GestureDetector(
      onTap: () => _setEdition(e),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 2),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? Colors.teal : Colors.white24,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(e, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }

  // index 0 = 왼쪽 반, 1 = 오른쪽 반 (가울데 기준 분할)
  // 원본 비율을 그대로 유지한 채 화면에 맞추고, 줌 버튼으로만 크기 조절.
  // 확대했을 때 손가락 드래그로 위치 이동 (InteractiveViewer pan)
  Widget _page(int index) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = _imgSize!;
        final halfW = size.width / 2;
        final fit = (constraints.biggest.width / halfW) < (constraints.biggest.height / size.height)
            ? constraints.biggest.width / halfW
            : constraints.biggest.height / size.height;
        final w = halfW * fit * _zoom; // 페이지(반쪽) 너비
        final h = size.height * fit * _zoom; // 페이지 높이 (비율 동일 유지)
        return InteractiveViewer(
          transformationController: _viewerControllers[index],
          scaleEnabled: true, // 핀치 줌
          panEnabled: true, // 드래그로 위치 이동
          minScale: 1,
          maxScale: 8,
          child: SizedBox(
            width: w,
            height: h,
            child: ClipRect(
              // 전체 이미지를 (2w x h)로 그린 뒤 한쪽 반만 보이게 클립
              child: OverflowBox(
                alignment: index == 0 ? Alignment.centerRight : Alignment.centerLeft,
                minWidth: w,
                maxWidth: w,
                minHeight: h,
                maxHeight: h,
                child: Image.memory(
                  _bytes!,
                  width: w * 2,
                  height: h,
                  fit: BoxFit.fill, // 2w:h = 원본 전체 비율이라 왜곡 없음
                  gaplessPlayback: true,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
