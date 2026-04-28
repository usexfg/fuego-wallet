import 'package:flutter/material.dart';
import '../../utils/theme.dart';

class CDPage extends StatelessWidget {
  const CDPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Certificates of Deposit'),
      ),
      body: const Center(
        child: Text('CD UI – deposit XFG, earn interest, view lock periods.'),
      ),
    );
  }
}
