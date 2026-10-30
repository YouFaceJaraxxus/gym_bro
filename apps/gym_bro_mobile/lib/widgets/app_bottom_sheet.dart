import 'package:flutter/material.dart';

/// [showModalBottomSheet] that keeps its content clear of the system
/// navigation bar.
///
/// Android draws apps edge-to-edge (enforced from SDK 35), so a sheet's last
/// rows end up behind the back/home/recents buttons. The bar's height comes
/// through `MediaQuery.paddingOf(context).bottom`: ~48dp with 3-button
/// navigation, a thin strip with gesture navigation, 0 when there is no bar
/// or the keyboard is up (the keyboard is `viewInsets`, which sheets handle
/// themselves). Padding inside the sheet keeps its background running under
/// the bar while the content stops above it.
Future<T?> showAppBottomSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool isScrollControlled = false,
  bool? showDragHandle,
  bool useSafeArea = false,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: isScrollControlled,
    showDragHandle: showDragHandle,
    useSafeArea: useSafeArea,
    builder: (ctx) => SafeArea(top: false, child: builder(ctx)),
  );
}
