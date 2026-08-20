/// Records a Google Play purchase with the server-side verifier.
///
/// The client only supplies the product ID and opaque Play token. The server
/// contacts Google directly and never trusts a client-provided price.
typedef PurchaseVerifier =
    Future<bool> Function({
      required String productId,
      required String purchaseToken,
    });
