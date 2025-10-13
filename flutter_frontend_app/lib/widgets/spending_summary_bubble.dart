import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

class SpendingSummaryBubble extends StatelessWidget {
  final Map<String, dynamic> data;
  const SpendingSummaryBubble({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final chartData = data["chart_data"] as List? ?? [];
    final breakdown = data["breakdown_merchants"] as List? ?? [];
    final title = data["summary_title"]?.toString() ?? "Spending Summary";
    final totalSpent = data["total_spent"]?.toString() ?? "-";
    final trend = data["trend_insights"] as List? ?? [];

    // Pie chart data
    List<PieChartSectionData> getSections() {
      final colors = [
        const Color(0xff4E7CF0),
        const Color(0xff31C48D),
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
      return chartData.map<PieChartSectionData>((item) {
        final value = item["value"] is num
            ? (item["value"] as num).toDouble()
            : double.tryParse(item["value"].toString()) ?? 0.0;
        final color = colors[count % colors.length];
        final showTitle = value / (sum == 0 ? 1 : sum) > 0.15;
        count++;
        return PieChartSectionData(
          color: color,
          value: value,
          radius: 38,
          title: showTitle ? value.round().toString() : '',
          titleStyle: const TextStyle(
              fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
        );
      }).toList();
    }

    List<Widget> breakdownWidgets = [];
    int index = 0;
    for (var item in breakdown) {
      final label = item['merchant']?.toString() ?? "";
      final amount = item['amount']?.toString() ?? "";
      final color = [
        const Color(0xff4E7CF0),
        const Color(0xff31C48D),
        const Color(0xffFDBA74),
        const Color(0xffF17C67),
        const Color(0xff8B5CF6),
        const Color(0xffFACC15),
        const Color(0xff38BDF8),
        const Color(0xffFB7185)
      ][index % 4];
      breakdownWidgets.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 2.5, horizontal: 2),
          child: Row(
            children: [
              Container(
                  width: 8,
                  height: 8,
                  decoration:
                      BoxDecoration(color: color, shape: BoxShape.circle)),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(fontSize: 13, color: Colors.black87),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                amount,
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: Colors.black87),
              ),
            ],
          ),
        ),
      );
      index++;
    }
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 12),
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                  color: Colors.black87,
                  fontWeight: FontWeight.w600,
                  fontSize: 14),
            ),
            const SizedBox(height: 10),
            Text(
              'Total spent: $totalSpent',
              style: const TextStyle(
                  fontSize: 13,
                  color: Colors.black87,
                  fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 24), // PAD ABOVE ROW

            Center(
              child: SizedBox(
                width:
                    280, // Constrained total width for both chart and categories
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 108,
                      height: 108,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          PieChart(
                            PieChartData(
                              sections: getSections(),
                              centerSpaceRadius: 35,
                              sectionsSpace: 2,
                              startDegreeOffset: -90,
                              borderData: FlBorderData(show: false),
                              centerSpaceColor: Colors.white,
                            ),
                            swapAnimationDuration:
                                const Duration(milliseconds: 350),
                            swapAnimationCurve: Curves.easeOut,
                          ),
                          Text(
                            totalSpent,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              color: Colors.black87,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 24),
                    // Reduced width for Categories
                    SizedBox(
                      width: 140,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 2),
                          ...breakdownWidgets,
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            if (trend.isNotEmpty)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Spending Trend",
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                        fontStyle: FontStyle.normal,
                        fontSize: 13,
                        color: Colors.black87,
                      )),
                  const SizedBox(height: 7),
                  ...trend.map((t) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Text("• $t",
                            style: const TextStyle(
                                color: Colors.black87,
                                fontSize: 12,
                                fontWeight: FontWeight.w400)),
                      ))
                ],
              ),
          ],
        ),
      ),
    );
  }
}
