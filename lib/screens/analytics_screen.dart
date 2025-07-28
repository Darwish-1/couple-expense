import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart'; // Ensure fl_chart is added to your pubspec.yaml

// Reusing the modern and appealing color palette
const Color primaryColor = Color(0xFF673AB7); // Deep Purple
const Color accentColor = Color(0xFF9C27B0); // Purple Accent
const Color backgroundColor = Color(0xFFF3F4F6); // Light Grey for background
const Color cardColor = Colors.white; // White for cards
const Color textColor = Color(0xFF333333); // Dark grey for general text
const Color lightTextColor = Color(0xFF666666); // Medium grey for secondary text
const Color successColor = Color(0xFF4CAF50); // Green for success indicators
const Color errorColor = Color(0xFFF44336); // Red for error indicators

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  Map<String, double> categoryTotals = {};
  // Removed monthTotals as it's no longer needed
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchAnalytics();
  }

  double safeParsePrice(dynamic price) {
    if (price is num) return price.toDouble();
    if (price is String) {
      return double.tryParse(price.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0.0;
    }
    return 0.0;
  }

  Future<void> fetchAnalytics() async {
    setState(() {
      isLoading = true;
    });

    try {
      final snapshot = await FirebaseFirestore.instance.collection('receipts').get();

      final tempCategoryTotals = <String, double>{};
      // Removed tempMonthTotals as it's no longer needed

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final category = data['category'] ?? 'Uncategorized';
        // Removed dateStr and parsedDate as month grouping is removed
        final prices = data['unit_price'];

        double totalPrice = 0.0;

        if (prices is List) {
          totalPrice = prices.fold(0.0, (currentSum, p) => currentSum + safeParsePrice(p));
        } else {
          totalPrice = safeParsePrice(prices);
        }

        if (totalPrice.isNaN || !totalPrice.isFinite) continue;

        tempCategoryTotals[category] = (tempCategoryTotals[category] ?? 0.0) + totalPrice;
        // Removed monthTotals population
      }

      setState(() {
        categoryTotals = tempCategoryTotals;
        // Removed monthTotals assignment
        isLoading = false;
      });
    } catch (e) {
      print("Error fetching analytics: $e"); // Kept print for debugging in development
      setState(() {
        isLoading = false;
        // Optionally, show an error message to the user
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor, // Apply light grey background
      appBar: AppBar(
        title: const Text(
          "Spending Analytics",
          style: TextStyle(
            color: textColor,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 2,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: lightTextColor),
            tooltip: 'Refresh Data',
            onPressed: isLoading ? null : fetchAnalytics,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: primaryColor))
          : Padding(
              padding: const EdgeInsets.all(20.0),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch, // Stretch to fill width
                  children: [
                    // Spending by Category Card
                    _buildChartCard(
                      context,
                      title: "Spending by Category",
                      isEmpty: categoryTotals.isEmpty,
                      emptyMessage: "No category data available. Scan some receipts!",
                      chartWidget: SizedBox(
                        height: 300,
                        child: CategoryBarChart(data: categoryTotals),
                      ),
                    ),
                    // Removed SizedBox and Spending by Month Card
                  ],
                ),
              ),
            ),
    );
  }

  // Helper to build consistent chart cards
  Widget _buildChartCard(
    BuildContext context, {
    required String title,
    required bool isEmpty,
    required String emptyMessage,
    required Widget chartWidget,
  }) {
    return Card(
      elevation: 6,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
      ),
      color: cardColor,
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            
            Text(
              title,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
            const Divider(height: 25, thickness: 0.5, color: lightTextColor),
            SizedBox(height: 30),
            isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 40.0),
                      child: Column(
                        children: [
                          Icon(Icons.bar_chart_outlined, size: 60, color: Colors.grey.shade400),
                          const SizedBox(height: 10),
                          Text(
                            emptyMessage,
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 16, color: lightTextColor),
                          ),
                        ],
                      ),
                    ),
                  )
                : chartWidget,
          ],
        ),
      ),
    );
  }
}

class CategoryBarChart extends StatelessWidget {
  final Map<String, double> data;
  const CategoryBarChart({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final sortedEntries = data.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value)); // Sort by value descending

    final barGroups = sortedEntries.asMap().entries.map((entry) {
      final index = entry.key;
      final value = entry.value.value;
      return BarChartGroupData(
        x: index,
        barRods: [
          BarChartRodData(
            toY: value,
            color: primaryColor, // Use primary color for bars
            width: 14, // Thicker bars
            borderRadius: BorderRadius.circular(4), // Rounded bar tops
          ),
        ],
        showingTooltipIndicators: [0], // Show tooltip for each bar (if enabled in touch data)
      );
    }).toList();

    return BarChart(
      BarChartData(
        barGroups: barGroups,
        alignment: BarChartAlignment.spaceAround,
        maxY: data.values.isEmpty ? 100 : data.values.reduce(
                (value, element) => value > element ? value : element) * 1.2, // Auto-scale Y-axis
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false, // Only horizontal grid lines
          getDrawingHorizontalLine: (value) => FlLine(
            color: Colors.grey.withOpacity(0.2),
            strokeWidth: 1,
          ),
        ),
        borderData: FlBorderData(
          show: false, // No border around the chart
        ),
        titlesData: FlTitlesData(
          show: true,
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, _) { // Removed 'meta' from signature
                final index = value.toInt();
                if (index >= 0 && index < sortedEntries.length) {
                  final category = sortedEntries[index].key;
                  return Transform.rotate( // Directly returning Transform.rotate
                    angle: -0.7, // Rotate labels for better fit
                    child: Column(
                      children: [
                        SizedBox(height: 10,),
                        Text(
                          category,
                          style: const TextStyle(
                            color: lightTextColor,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  );
                }
                return const SizedBox();
              },
              reservedSize: 40, // Space for rotated labels
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, _) { // Removed 'meta' from signature
                return Text(
                  '\$${value.toStringAsFixed(0)}', // Format as currency
                  style: const TextStyle(color: lightTextColor, fontSize: 12),
                );
              },
              reservedSize: 40,
            ),
          ),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              final category = sortedEntries[group.x.toInt()].key;
              return BarTooltipItem(
                '$category\n',
                const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                children: [
                  TextSpan(
                    text: '\$${rod.toY.toStringAsFixed(2)}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

