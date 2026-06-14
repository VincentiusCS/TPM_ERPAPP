import 'package:flutter/material.dart';

/// Shows a heads-up success notification banner at the top of the screen.
/// Auto-dismisses after 3 seconds.
void showSuccessPopup(BuildContext context, String message) {
  _showHeadsUpNotification(context, message, isError: false);
}

/// Shows a heads-up error notification banner at the top of the screen.
/// Auto-dismisses after 3 seconds.
void showErrorPopup(BuildContext context, String message) {
  _showHeadsUpNotification(context, message, isError: true);
}

void _showHeadsUpNotification(BuildContext context, String message, {required bool isError}) {
  final overlay = Overlay.of(context);
  late OverlayEntry entry;

  entry = OverlayEntry(
    builder: (context) => _HeadsUpNotification(
      message: message,
      isError: isError,
      onDismiss: () => entry.remove(),
    ),
  );

  overlay.insert(entry);
}

class _HeadsUpNotification extends StatefulWidget {
  final String message;
  final bool isError;
  final VoidCallback onDismiss;

  const _HeadsUpNotification({
    required this.message,
    required this.isError,
    required this.onDismiss,
  });

  @override
  State<_HeadsUpNotification> createState() => _HeadsUpNotificationState();
}

class _HeadsUpNotificationState extends State<_HeadsUpNotification>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(_controller);

    _controller.forward();

    // Auto-dismiss after 3 seconds
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        _controller.reverse().then((_) => widget.onDismiss());
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;

    return Positioned(
      top: topPadding + 8,
      left: 16,
      right: 16,
      child: SlideTransition(
        position: _slideAnimation,
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Material(
            color: Colors.transparent,
            child: GestureDetector(
              onTap: () {
                _controller.reverse().then((_) => widget.onDismiss());
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: widget.isError ? const Color(0xFF1C1B1B) : const Color(0xFF1C1B1B),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.15),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Icon(
                      widget.isError ? Icons.error_outline : Icons.check_circle,
                      color: widget.isError ? const Color(0xFFFFDAD6) : Colors.green.shade300,
                      size: 22,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        widget.message,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
