import 'package:flutter/material.dart';

class PillToast {
  static void show(
    BuildContext context, {
    required String message,
    required IconData icon,
    Duration duration = const Duration(milliseconds: 1800),
  }) {
    // Safely look up the OverlayState using the context
    final overlayState = Overlay.of(context);
    
    late OverlayEntry entry;
    final ValueNotifier<double> opacityNotifier = ValueNotifier<double>(0.0);
    const Color localPurple = Color(0xFF6B46C1);

    entry = OverlayEntry(
      builder: (BuildContext context) => Positioned(
        bottom: MediaQuery.of(context).size.height * 0.12, 
        left: 0,
        right: 0,
        child: IgnorePointer(
          child: Align(
            alignment: Alignment.bottomCenter,
            child: ValueListenableBuilder<double>(
              valueListenable: opacityNotifier,
              builder: (BuildContext context, double opacityValue, Widget? child) {
                return AnimatedOpacity(
                  opacity: opacityValue,
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                  child: child,
                );
              },
              child: Material(
                color: Colors.transparent,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(100),
                    border: Border.all(color: const Color(0xFFEDE9FA), width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: localPurple.withOpacity(0.08),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(icon, color: localPurple, size: 15),
                      const SizedBox(width: 6),
                      Text(
                        message,
                        style: const TextStyle(
                          color: localPurple,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
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
    );

    overlayState.insert(entry);
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      opacityNotifier.value = 1.0;
    });

    Future.delayed(duration, () {
      opacityNotifier.value = 0.0;
      Future.delayed(const Duration(milliseconds: 300), () {
        entry.remove();
        opacityNotifier.dispose();
      });
    });
  }
}