import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

class PaymentService {
  static final String _baseUrl = dotenv.env['API_BASE_URL']!;
  static final String _publishableKey = dotenv.env['STRIPE_PUBLISHABLE_KEY']!;

  static void initStripe() {
    Stripe.publishableKey = _publishableKey;
  }

  static Future<String?> makePayment(double amount) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    if (token == null) {
      return "❌ User token not found";
    }

    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/api/payment/create'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode({'amount': amount}),
      );

      if (response.statusCode != 201) {
        return "❌ Failed to create payment intent";
      }

      final data = json.decode(response.body);
      final clientSecret = data['data']?['client_secret'];

      print('Client secret: $clientSecret');

      await Stripe.instance.initPaymentSheet(
        paymentSheetParameters: SetupPaymentSheetParameters(
          paymentIntentClientSecret: clientSecret,
          merchantDisplayName: 'Blurred',
        ),
      );

      await Stripe.instance.presentPaymentSheet();

      return null; // no error
    } catch (e) {
      print("Payment error: $e");
      return "❌ Payment failed";
    }
  }
}
