import 'package:flutter/material.dart';
import '../../services/payment_service.dart';

class PaymentScreen extends StatefulWidget {
  const PaymentScreen({super.key});

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
              isSelected: [isCreditMode, !isCreditMode],
              onPressed: (index) {
                setState(() => isCreditMode = index == 0);
              },
              children: const [Text('Credits'), Text('USD')],
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
                // capture before any await
                final nav = Navigator.of(context, rootNavigator: true);
                final messenger = ScaffoldMessenger.of(context);

                final amount = double.tryParse(_usdController.text) ?? 0;
                if (amount <= 0) return;

                final error = await PaymentService.makePayment(amount);
                final message = error ?? '✅ Payment processed';

                if (error == null) {
                  // Option 1: show first, then navigate
                  messenger.showSnackBar(SnackBar(content: Text(message)));
                  nav.pushNamedAndRemoveUntil('/home', (route) => false);
                } else {
                  messenger.showSnackBar(SnackBar(content: Text(message)));
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
