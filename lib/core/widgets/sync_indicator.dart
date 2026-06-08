import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:myhalaqat/core/notifiers/app_notifiers.dart';
import 'package:myhalaqat/core/network/sync_manager.dart';
import 'package:myhalaqat/core/theme/app_theme.dart';

/// أيقونة حالة المزامنة — تضاف كـ Stack أعلى الواجهة
class SyncIndicator extends StatefulWidget {
  final Widget child;
  const SyncIndicator({Key? key, required this.child}) : super(key: key);

  @override
  State<SyncIndicator> createState() => _SyncIndicatorState();
}

class _SyncIndicatorState extends State<SyncIndicator> {
  StreamSubscription? _connectivitySub;
  bool _isOnline = true;
  String _status = 'متصل';
  int _pendingCount = 0;

  @override
  void initState() {
    super.initState();
    _checkConnection();
    _connectivitySub = Connectivity().onConnectivityChanged.listen((results) {
      final online = !results.contains(ConnectivityResult.none) && !results.contains(ConnectivityResult.other);
      setState(() => _isOnline = online);
    });
    pendingCountNotifier.addListener(_onPendingChanged);
  }

  @override
  void dispose() {
    _connectivitySub?.cancel();
    pendingCountNotifier.removeListener(_onPendingChanged);
    super.dispose();
  }

  void _onPendingChanged() => _checkPending();

  Future<void> _checkConnection() async {
    final results = await Connectivity().checkConnectivity();
    if (mounted) setState(() => _isOnline = !results.contains(ConnectivityResult.none) && !results.contains(ConnectivityResult.other));
    _checkPending();
  }

  Future<void> _checkPending() async {
    final count = pendingCountNotifier.value;
    if (mounted) setState(() => _pendingCount = count);
  }

  @override
  Widget build(BuildContext context) {
    Color dotColor;
    String statusText;

    if (_pendingCount > 0) {
      dotColor = AppColors.warning; // 🟡
      statusText = '$_pendingCount معلق';
    } else if (!_isOnline) {
      dotColor = AppColors.danger; // 🔴
      statusText = 'غير متصل';
    } else {
      dotColor = AppColors.success; // 🟢
      statusText = 'مزامن';
    }

    return Stack(
      children: [
        widget.child,
        Positioned(
          top: MediaQuery.of(context).padding.top + 4,
          right: 12,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.6),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8, height: 8,
                  decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
                ),
                const SizedBox(width: 6),
                Text(statusText, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// أيقونة المزامنة لشريط التطبيق العلوي — تُستخدم في actions: داخل AppBar
class SyncAppBarAction extends StatefulWidget {
  const SyncAppBarAction({Key? key}) : super(key: key);

  @override
  State<SyncAppBarAction> createState() => _SyncAppBarActionState();
}

class _SyncAppBarActionState extends State<SyncAppBarAction> {
  bool _isOnline = true;
  StreamSubscription? _connectivitySub;

  @override
  void initState() {
    super.initState();
    _checkConnection();
    _connectivitySub = Connectivity().onConnectivityChanged.listen((results) {
      final online = !results.contains(ConnectivityResult.none) && !results.contains(ConnectivityResult.other);
      if (mounted) setState(() => _isOnline = online);
    });
  }

  @override
  void dispose() {
    _connectivitySub?.cancel();
    super.dispose();
  }

  Future<void> _checkConnection() async {
    final results = await Connectivity().checkConnectivity();
    if (mounted) {
      setState(() => _isOnline = !results.contains(ConnectivityResult.none) && !results.contains(ConnectivityResult.other));
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: pendingCountNotifier,
      builder: (context, _) {
        final count = pendingCountNotifier.value;
        Color color;
        IconData icon;
        String tooltip;
        if (count > 0) {
          color = AppColors.warning;
          icon = Icons.cloud_upload;
          tooltip = 'مزامنة ($count معلق)';
        } else if (!_isOnline) {
          color = AppColors.danger;
          icon = Icons.cloud_off;
          tooltip = 'غير متصل';
        } else {
          color = Colors.white;
          icon = Icons.cloud_done;
          tooltip = 'مزامن';
        }
        return IconButton(
          icon: count > 0
              ? Badge(
                  label: Text('$count'),
                  child: Icon(icon, color: color),
                )
              : Icon(icon, color: color),
          tooltip: tooltip,
          onPressed: () => SyncManager.instance.syncAll(),
        );
      },
    );
  }
}
