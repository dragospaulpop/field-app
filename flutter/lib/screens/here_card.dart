import 'package:flutter/material.dart';

import '../permissions.dart';

/// Step 5: ask in context. Step 6 turns the button into a fix and a heading.
class HereCard extends StatefulWidget {
  const HereCard({super.key});

  @override
  State<HereCard> createState() => _HereCardState();
}

class _HereCardState extends State<HereCard> {
  String _location = 'not asked yet';

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Location: $_location'),
              // No camera line: image_picker hands the shot to the system camera
              // app, and our manifest asks for no CAMERA permission (step 7).
              const SizedBox(height: 8),
              OutlinedButton(
                style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                onPressed: () async {
                  final ok = await ensureLocation(context);
                  setState(() => _location = ok ? 'allowed' : 'not allowed');
                },
                child: const Text('Where am I?'),
              ),
            ],
          ),
        ),
      );
}
