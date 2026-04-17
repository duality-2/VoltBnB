void openRazorpayWeb({
  required String options,
  required Function(String) onSuccess,
  required Function(String) onFailure,
}) {
  // No-op for mobile/desktop
  throw UnsupportedError('Razorpay Web is not supported on this platform');
}
