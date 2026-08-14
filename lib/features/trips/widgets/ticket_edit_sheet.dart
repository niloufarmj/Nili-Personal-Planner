import 'package:flutter/material.dart';
import '../../../core/design/design.dart';
import '../models/trip_models.dart';

class TicketEditSheet extends StatefulWidget {
  const TicketEditSheet({
    required this.title,
    required this.initialData,
    required this.onSave,
    super.key,
  });

  final String title;
  final TicketData initialData;
  final ValueChanged<TicketData> onSave;

  @override
  State<TicketEditSheet> createState() => _TicketEditSheetState();
}

class _TicketEditSheetState extends State<TicketEditSheet> {
  late TextEditingController _carrierCtrl;
  late TextEditingController _numberCtrl;
  late TextEditingController _dateCtrl;
  late TextEditingController _timeCtrl;
  late TextEditingController _depAirportCtrl;
  late TextEditingController _arrAirportCtrl;
  late TextEditingController _gateCtrl;
  late TextEditingController _seatCtrl;
  late TextEditingController _pnrCtrl;

  @override
  void initState() {
    super.initState();
    _carrierCtrl = TextEditingController(text: widget.initialData.carrier);
    _numberCtrl = TextEditingController(text: widget.initialData.flightNumber);
    _dateCtrl = TextEditingController(text: widget.initialData.departureDate);
    _timeCtrl = TextEditingController(text: widget.initialData.departureTime);
    _depAirportCtrl = TextEditingController(text: widget.initialData.departureAirport);
    _arrAirportCtrl = TextEditingController(text: widget.initialData.arrivalAirport);
    _gateCtrl = TextEditingController(text: widget.initialData.terminalGate);
    _seatCtrl = TextEditingController(text: widget.initialData.seat);
    _pnrCtrl = TextEditingController(text: widget.initialData.pnrCode);
  }

  @override
  void dispose() {
    _carrierCtrl.dispose();
    _numberCtrl.dispose();
    _dateCtrl.dispose();
    _timeCtrl.dispose();
    _depAirportCtrl.dispose();
    _arrAirportCtrl.dispose();
    _gateCtrl.dispose();
    _seatCtrl.dispose();
    _pnrCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    final ticket = TicketData(
      carrier: _carrierCtrl.text.trim(),
      flightNumber: _numberCtrl.text.trim(),
      departureDate: _dateCtrl.text.trim(),
      departureTime: _timeCtrl.text.trim(),
      departureAirport: _depAirportCtrl.text.trim(),
      arrivalAirport: _arrAirportCtrl.text.trim(),
      terminalGate: _gateCtrl.text.trim(),
      seat: _seatCtrl.text.trim(),
      pnrCode: _pnrCtrl.text.trim(),
    );
    widget.onSave(ticket);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final insets = MediaQuery.viewInsetsOf(context);

    final inkColor = isDark ? DesignTokens.inkDark : DesignTokens.inkLight;

    return Container(
      padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + insets.bottom),
      decoration: BoxDecoration(
        color: isDark ? DesignTokens.paperDark : DesignTokens.paperLight,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.flight_takeoff, color: DesignTokens.accentLight),
                const SizedBox(width: 8),
                Text(
                  widget.title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: inkColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _carrierCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Airline / Carrier',
                      hintText: 'e.g. KLM, Turkish Airlines',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _numberCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Flight / Train #',
                      hintText: 'e.g. KL 1234',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _depAirportCtrl,
                    decoration: const InputDecoration(
                      labelText: 'From (Origin)',
                      hintText: 'e.g. AMS (Amsterdam)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _arrAirportCtrl,
                    decoration: const InputDecoration(
                      labelText: 'To (Destination)',
                      hintText: 'e.g. IKA (Tehran)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _dateCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Departure Date',
                      hintText: 'e.g. 14 Sep 2026',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _timeCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Departure Time',
                      hintText: 'e.g. 14:30',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _gateCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Terminal / Gate',
                      hintText: 'e.g. T2 / Gate B14',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _seatCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Seat Number',
                      hintText: 'e.g. 14A',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            TextFormField(
              controller: _pnrCtrl,
              decoration: const InputDecoration(
                labelText: 'Booking Code / PNR',
                hintText: 'e.g. X789AB',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),

            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: DesignTokens.accentLight,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: _submit,
              child: const Text('Save Ticket Data', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}
