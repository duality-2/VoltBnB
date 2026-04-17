// ignore: avoid_web_libraries_in_flutter
import 'dart:js' as js;

void openRazorpayWeb({
  required String options,
  required Function(String) onSuccess,
  required Function(String) onFailure,
}) {
  try {
    js.context.callMethod('razorpayCheckout', [
      options,
      js.allowInterop((paymentId) => onSuccess(paymentId.toString())),
      js.allowInterop((error) => onFailure(error.toString())),
    ]);
  } catch (e) {
    onFailure(e.toString());
  }
}
