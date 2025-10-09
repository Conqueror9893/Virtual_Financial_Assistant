// // import 'package:flutter/material.dart';
// // import 'package:flutter_frontend_app/models/chat_message.dart';
// // import 'package:http/http.dart' as http;
// // import 'dart:convert';

// // class TransferForm extends StatefulWidget {
// //   final String beneficiaryName;
// //   final Function(Map<String, dynamic>) onSubmit;

// //   const TransferForm({
// //     Key? key,
// //     required this.beneficiaryName,
// //     required this.onSubmit,
// //   }) : super(key: key);

// //   @override
// //   State<TransferForm> createState() => _TransferFormState();
// // }

// // class _TransferFormState extends State<TransferForm> {
// //   int _selectedDate = 1;
// //   final TextEditingController _amountController =
// //       TextEditingController(text: "5000");
// //   bool _submitting = false;

// //   @override
// //   Widget build(BuildContext context) {
// //     return AlertDialog(
// //       title: Text("Transfer Details"),
// //       content: Column(
// //         mainAxisSize: MainAxisSize.min,
// //         children: [
// //           TextFormField(
// //             initialValue: widget.beneficiaryName,
// //             readOnly: true,
// //             decoration: const InputDecoration(
// //               labelText: "Beneficiary Name",
// //             ),
// //           ),
// //           const SizedBox(height: 16),
// //           Row(
// //             children: [
// //               const Text("Transfer Date: "),
// //               Expanded(
// //                 child: Row(
// //                   mainAxisAlignment: MainAxisAlignment.spaceEvenly,
// //                   children: [1, 3, 5].map((d) {
// //                     return Row(
// //                       children: [
// //                         Radio<int>(
// //                           value: d,
// //                           groupValue: _selectedDate,
// //                           onChanged: (val) {
// //                             setState(() {
// //                               _selectedDate = val!;
// //                             });
// //                           },
// //                         ),
// //                         Text("$d"),
// //                       ],
// //                     );
// //                   }).toList(),
// //                 ),
// //               ),
// //             ],
// //           ),
// //           const SizedBox(height: 16),
// //           TextFormField(
// //             controller: _amountController,
// //             keyboardType: TextInputType.number,
// //             decoration: const InputDecoration(
// //               labelText: "Transfer Amount (₹)",
// //             ),
// //           ),
// //         ],
// //       ),
// //       actions: [
// //         TextButton(
// //           onPressed: _submitting
// //               ? null
// //               : () {
// //                   Navigator.of(context).pop(); // Cancel form
// //                 },
// //           child: const Text("Cancel"),
// //         ),
// //         ElevatedButton(
// //           onPressed: _submitting
// //               ? null
// //               : () async {
// //                   setState(() {
// //                     _submitting = true;
// //                   });

// //                   final formData = {
// //                     "beneficiary": widget.beneficiaryName,
// //                     "transfer_date": _selectedDate,
// //                     "amount": int.tryParse(_amountController.text) ?? 5000,
// //                   };

// //                   // Call the onSubmit callback (send to backend)
// //                   await widget.onSubmit(formData);

// //                   if (mounted) {
// //                     Navigator.of(context).pop();
// //                   }
// //                 },
// //           child: _submitting
// //               ? const CircularProgressIndicator()
// //               : const Text("Submit"),
// //         ),
// //       ],
// //     );
// //   }
// // }

// import 'package:flutter/material.dart';

// class TransferForm extends StatefulWidget {
//   final String? beneficiaryName;
//   final Function(double, int) onSubmit;

//   const TransferForm({
//     super.key,
//     this.beneficiaryName,
//     required this.onSubmit,
//   });

//   @override
//   State<TransferForm> createState() => _TransferFormWidgetState();
// }

// class _TransferFormWidgetState extends State<TransferForm> {
//   double _amount = 5000;
//   int _selectedDays = 1;

//   @override
//   Widget build(BuildContext context) {
//     return Card(
//       elevation: 4,
//       margin: const EdgeInsets.symmetric(vertical: 12),
//       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
//       child: Padding(
//         padding: const EdgeInsets.all(16.0),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             Text(
//               "Transfer to ${widget.beneficiaryName ?? "Beneficiary"}",
//               style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
//             ),
//             const SizedBox(height: 12),
//             const Text("Select transfer date (days from now):"),
//             Row(
//               mainAxisAlignment: MainAxisAlignment.spaceEvenly,
//               children: [1, 3, 5].map((days) {
//                 return ChoiceChip(
//                   label: Text("$days days"),
//                   selected: _selectedDays == days,
//                   onSelected: (selected) {
//                     if (selected) setState(() => _selectedDays = days);
//                   },
//                 );
//               }).toList(),
//             ),
//             const SizedBox(height: 16),
//             TextField(
//               decoration: const InputDecoration(
//                 labelText: "Amount (₹)",
//                 border: OutlineInputBorder(),
//               ),
//               keyboardType: TextInputType.number,
//               controller: TextEditingController(
//                 text: _amount.toStringAsFixed(0),
//               ),
//               onChanged: (value) {
//                 final parsed = double.tryParse(value);
//                 if (parsed != null) setState(() => _amount = parsed);
//               },
//             ),
//             const SizedBox(height: 16),
//             Center(
//               child: ElevatedButton.icon(
//                 icon: const Icon(Icons.send),
//                 label: const Text("Submit Transfer"),
//                 style: ElevatedButton.styleFrom(
//                   padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
//                   shape: RoundedRectangleBorder(
//                     borderRadius: BorderRadius.circular(12),
//                   ),
//                 ),
//                 onPressed: () {
//                   widget.onSubmit(_amount, _selectedDays);
//                 },
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }

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
                  "₹${_amount.toStringAsFixed(0)}",
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
                labelText: "Amount (₹)",
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
