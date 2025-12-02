// flutter_frontend_app/lib/widgets/spending_summary_bubble.dart

import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

class SpendingSummaryBubble extends StatelessWidget {
  final Map<dynamic, dynamic> data;

  const SpendingSummaryBubble({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final chartData = data["chart_data"] as List? ?? [];
    final breakdown = data["breakdown_merchants"] as List? ?? [];
    final title = data["summary_title"]?.toString() ?? "Spending Summary";
    final totalSpent = data["total_spent"]?.toString() ?? "-";
    final trend = data["trend_insights"] as List? ?? [];

    // Pie chart sections
    List<PieChartSectionData> getSections() {
      final colors = [
        const Color(0xff5B8DEE), // Blue (Starbucks color from image)
        const Color(0xff5DD3A1), // Green (Blue Tokai color from image)
        const Color(0xffFDBA74),
        const Color(0xffF17C67),
        const Color(0xff8B5CF6),
        const Color(0xffFACC15),
        const Color(0xff38BDF8),
        const Color(0xffFB7185)
      ];

      double sum = chartData.fold(
          0.0,
          (tot, item) =>
              tot +
              (item["value"] is num
                  ? item["value"]
                  : double.tryParse(item["value"].toString()) ?? 0));

      int count = 0;
      return chartData.map((item) {
        final value = item["value"] is num
            ? (item["value"] as num).toDouble()
            : double.tryParse(item["value"].toString()) ?? 0.0;
        final color = colors[count % colors.length];
        count++;

        return PieChartSectionData(
          color: color,
          value: value,
          radius: 35,
          title: '', // No title inside segments
          showTitle: false,
        );
      }).toList();
    }

    // Build breakdown widgets
    List<Widget> breakdownWidgets = [];
    int index = 0;
    for (var item in breakdown) {
      final label = item['merchant']?.toString() ?? "";
      final amount = item['amount']?.toString() ?? "";
      final color = [
        const Color(0xff5B8DEE),
        const Color(0xff5DD3A1),
        const Color(0xffFDBA74),
        const Color(0xffF17C67),
        const Color(0xff8B5CF6),
        const Color(0xffFACC15),
        const Color(0xff38BDF8),
        const Color(0xffFB7185)
      ][index % 8];

      breakdownWidgets.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              Container(
                  width: 10,
                  height: 10,
                  decoration:
                      BoxDecoration(color: color, shape: BoxShape.circle)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.black87,
                    fontWeight: FontWeight.w400,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                amount,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
        ),
      );
      index++;
    }

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title section
            Text(
              title,
              style: const TextStyle(
                color: Colors.black87,
                fontWeight: FontWeight.w400,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 20),

            // Chart and breakdown row
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Pie chart
                SizedBox(
                  width: 140,
                  height: 140,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      PieChart(
                        PieChartData(
                          sections: getSections(),
                          centerSpaceRadius: 45,
                          sectionsSpace: 2,
                          startDegreeOffset: -90,
                          borderData: FlBorderData(show: false),
                          centerSpaceColor: Colors.white,
                        ),
                        swapAnimationDuration:
                            const Duration(milliseconds: 350),
                        swapAnimationCurve: Curves.easeOut,
                      ),
                      // Total in center
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            totalSpent.replaceAll('\$', '').trim(),
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                              color: Colors.black87,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 24),

                // Breakdown list
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Your top go-to spots were:",
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                          fontSize: 13,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ...breakdownWidgets,
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            const Divider(),
            const SizedBox(height: 12),
            // "Spending Trend" section
            if (trend.isNotEmpty) ...[
              const Text(
                "Spending Trend",
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              ...trend.map((t) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Text("• $t",
                        style: const TextStyle(
                            color: Colors.black87,
                            fontSize: 13,
                            fontWeight: FontWeight.w400)),
                  )),
            ] else ...[
              const Text(
                "Spending Trend",
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              // "Would you like more details?" section
              const Text(
                "Would you like more details?",
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.black87,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
