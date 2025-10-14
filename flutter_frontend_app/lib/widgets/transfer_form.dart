import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class TransferForm extends StatefulWidget {
  final String beneficiaryName;
  final double initialAmount;
  final Function(double, DateTime) onSubmit;

  const TransferForm({
    super.key,
    required this.beneficiaryName,
    required this.onSubmit,
    this.initialAmount = 0.0,
  });

  @override
  State<TransferForm> createState() => _TransferFormWidgetState();
}

class _TransferFormWidgetState extends State<TransferForm> {
  double _amount = 5000;
  DateTime _selectedDate = DateTime.now();
  bool _submitted = false;
  final _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    _amount = widget.initialAmount > 0 ? widget.initialAmount : 100;
    _controller.text = _amount.toStringAsFixed(0);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: now,
      lastDate: DateTime(now.year, now.month + 2, now.day),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() => _selectedDate = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      margin: const EdgeInsets.symmetric(vertical: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 🧾 Header: show name and current amount
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Transfer to ${widget.beneficiaryName}",
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                Text(
                  "USD ${_amount.toStringAsFixed(0)}",
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                    color: Colors.green,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // 🏦 Amount input
            TextField(
              decoration: const InputDecoration(
                labelText: "Amount (\$)",
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
              controller: _controller,
              enabled: !_submitted,
              onChanged: (value) {
                final parsed = double.tryParse(value);
                if (parsed != null) setState(() => _amount = parsed);
              },
            ),
            const SizedBox(height: 16),

            // 📅 Date picker
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Transfer date: ${DateFormat('dd MMM yyyy').format(_selectedDate)}",
                  style: const TextStyle(fontSize: 14),
                ),
                TextButton.icon(
                  onPressed: _submitted ? null : _pickDate,
                  icon: const Icon(Icons.calendar_today, size: 18),
                  label: const Text("Change"),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // 🚀 Submit button
            Center(
              child: ElevatedButton.icon(
                icon: const Icon(Icons.send),
                label:
                    Text(_submitted ? "Transfer Scheduled" : "Submit Transfer"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _submitted ? Colors.grey : Colors.blue,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: _submitted
                    ? null
                    : () {
                        widget.onSubmit(_amount, _selectedDate);
                        setState(() => _submitted = true);
                      },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
