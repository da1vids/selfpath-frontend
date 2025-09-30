import 'package:flutter/material.dart';
import '../../services/payment_service.dart';
import '../../main.dart';

class PaymentScreen extends StatefulWidget {
  @override
  PaymentScreenState createState() => PaymentScreenState();
}

class PaymentScreenState extends State<PaymentScreen> {
  final TextEditingController _creditsController = TextEditingController();
  final TextEditingController _usdController = TextEditingController();
  bool isCreditMode = true;
  double creditPrice = 0.011;

  @override
  void initState() {
    super.initState();
    PaymentService.initStripe();
  }

  void updateValues() {
    if (isCreditMode) {
      double credits = double.tryParse(_creditsController.text) ?? 0;
      _usdController.text = (credits * creditPrice).toStringAsFixed(2);
    } else {
      double usd = double.tryParse(_usdController.text) ?? 0;
      _creditsController.text = (usd / creditPrice).floor().toString();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Buy Credits")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            ToggleButtons(
              children: [Text("Credits"), Text("USD")],
              isSelected: [isCreditMode, !isCreditMode],
              onPressed: (index) {
                setState(() => isCreditMode = index == 0);
              },
            ),
            SizedBox(height: 20),
            TextField(
              controller: isCreditMode ? _creditsController : _usdController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: isCreditMode ? "Credits" : "USD",
              ),
              onChanged: (val) => setState(updateValues),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: () async {
                final amount = double.tryParse(_usdController.text) ?? 0;
                if (amount <= 0) return;

                final error = await PaymentService.makePayment(amount);
                final message = error ?? "✅ Payment processed";

                if (!mounted) {
                  return; // Prevent using context if widget is disposed
                }
                if (error == null) {
                  // Navigate to home
                  Navigator.pushNamedAndRemoveUntil(
                    context,
                    '/home',
                    (route) => false,
                  );

                  // Delay to allow context rebuild
                  Future.delayed(Duration(milliseconds: 300), () {
                    // Use global key or context from a global scaffold to show the snackbar
                    ScaffoldMessenger.of(
                      navigatorKey.currentContext!,
                    ).showSnackBar(SnackBar(content: Text(message)));
                  });
                } else {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text(message)));
                }
              },
              child: Text("Pay with Card"),
            ),
          ],
        ),
      ),
    );
  }
}
