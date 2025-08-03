import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:flutter/material.dart';

import 'package:provider/provider.dart';

import 'package:intl/intl.dart';

import 'package:couple_expenses/providers/auth_provider.dart';

import 'package:couple_expenses/providers/home_screen_provider.dart';

import 'package:google_fonts/google_fonts.dart';

import 'package:fl_chart/fl_chart.dart';

import 'package:flutter_animate/flutter_animate.dart';



class TotalSpendingCard extends StatefulWidget {

final String userId;



const TotalSpendingCard({super.key, required this.userId});



@override

State<TotalSpendingCard> createState() => _TotalSpendingCardState();

}



class _TotalSpendingCardState extends State<TotalSpendingCard> {

late NumberFormat _currencyFormatter;

bool _showPieChart = false;



@override

void initState() {

super.initState();

_currencyFormatter = NumberFormat.currency(

locale: 'en_US',

symbol: 'EGP ',

decimalDigits: 2,

);

WidgetsBinding.instance.addPostFrameCallback((_) {

final provider = Provider.of<HomeScreenProvider>(context, listen: false);

provider.initializeStream(context, widget.userId);

});

}



@override

Widget build(BuildContext context) {

return Selector<HomeScreenProvider, ({

bool showWalletReceipts,

String? selectedUserFilter,

Map<String, double> totalByUser,

bool isLoadingStream

})>(

selector: (_, provider) => (

showWalletReceipts: provider.showWalletReceipts,

selectedUserFilter: provider.selectedUserFilter,

totalByUser: provider.totalByUser,

isLoadingStream: provider.isLoadingStream

),

builder: (context, selectorData, _) {

final authProvider = Provider.of<AuthProvider>(context, listen: false);

final homeScreenProvider = Provider.of<HomeScreenProvider>(context, listen: false);

final walletId = authProvider.walletId;

final currentUserId = authProvider.user?.uid ?? '';



Stream<QuerySnapshot> getExpensesStream() {

Query<Map<String, dynamic>> query;

if (selectorData.showWalletReceipts && walletId != null) {

query = FirebaseFirestore.instance

.collection('receipts')

.where('walletId', isEqualTo: walletId)

.orderBy('created_at', descending: true);

if (selectorData.selectedUserFilter != null) {

query = query.where('userId', isEqualTo: selectorData.selectedUserFilter);

}

} else {

query = FirebaseFirestore.instance

.collection('receipts')

.where('userId', isEqualTo: widget.userId)

.orderBy('created_at', descending: true);

}

return query.snapshots();

}



return Card(

color: Colors.white,

elevation: 1,

shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),

child: Padding(

padding: const EdgeInsets.all(16),

child: Column(

mainAxisSize: MainAxisSize.min,

children: [

// Header

Row(

mainAxisAlignment: MainAxisAlignment.spaceBetween,

children: [

Text(

selectorData.showWalletReceipts

? (selectorData.selectedUserFilter == null

? 'Shared Spending'

: 'Filtered Spending')

: 'My Spending',

style: GoogleFonts.inter(

fontSize: 18,

fontWeight: FontWeight.w600,

color: Colors.indigo.shade700,

),

),

if (selectorData.showWalletReceipts && selectorData.selectedUserFilter == null)

FilterChip(

label: Text(

_showPieChart ? 'Show Segments' : 'Show Chart',

style: GoogleFonts.inter(fontSize: 12, color: Colors.white),

),

backgroundColor: Colors.indigo.shade700,

selected: _showPieChart,

onSelected: (selected) {

setState(() => _showPieChart = selected);

},

tooltip: _showPieChart

? 'Switch to segment view'

: 'Switch to pie chart view',

).animate().scale(duration: 200.ms),

],

),

const SizedBox(height: 12),



// Data area

StreamBuilder<QuerySnapshot>(

stream: getExpensesStream(),

builder: (context, snapshot) {

if (selectorData.isLoadingStream ||

snapshot.connectionState == ConnectionState.waiting) {

return const SizedBox(

height: 150,

child: Center(child: CircularProgressIndicator(color: Colors.indigo)),

);

}

if (snapshot.hasError) {

return const SizedBox(

height: 150,

child: Center(

child: Text('Error loading data', style: TextStyle(fontSize: 14, color: Colors.red)),

),

);

}



// Calculate total & count for personal/filtered view

double totalSpending = 0.0;

int numberOfExpenses = 0;

if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {

final docs = snapshot.data!.docs;

numberOfExpenses = docs.length;

for (var doc in docs) {

final data = doc.data() as Map<String, dynamic>;

totalSpending += HomeScreenProvider.calculateReceiptTotal(data);

}

}



// Shared & no filter → override with full-doc totals

if (selectorData.showWalletReceipts && selectorData.selectedUserFilter == null) {

final docs = snapshot.data!.docs;

final totals = <String, double>{};

for (var doc in docs) {

final data = doc.data() as Map<String, dynamic>;

final uid = data['userId'] as String? ?? 'Unknown';

final amt = HomeScreenProvider.calculateReceiptTotal(data);

totals[uid] = (totals[uid] ?? 0) + amt;

}

final youTotal = totals[currentUserId] ?? 0.0;

final other = totals.entries.firstWhere(

(e) => e.key != currentUserId,

orElse: () => const MapEntry('Unknown', 0.0),

);

final partnerId = other.key;

final partnerTotal = other.value;



// Pie chart with custom colors

if (_showPieChart) {

final hasAny = (youTotal + partnerTotal) > 0;

return SizedBox(

height: 150,

child: hasAny

? PieChart(

PieChartData(

sections: [

PieChartSectionData(

value: youTotal,

color: Colors.indigo.shade700,

title: 'You',

radius: 60,

titleStyle: GoogleFonts.inter(

fontSize: 12,

color: Colors.white,

fontWeight: FontWeight.w600,

),

),

if (partnerTotal > 0)

PieChartSectionData(

value: partnerTotal,

color: Colors.teal.shade400,

title: 'Partner',

radius: 60,

titleStyle: GoogleFonts.inter(

fontSize: 12,

color: Colors.white,

fontWeight: FontWeight.w600,

),

),

],

sectionsSpace: 2,

centerSpaceRadius: 40,

),

)

: const Center(

child: Text(

'No spending data',

style: TextStyle(fontSize: 14, color: Colors.grey),

),

),

);

}



// Segmented view

return ConstrainedBox(

constraints: const BoxConstraints(minHeight: 100, maxHeight: 150),

child: Row(

children: [

Expanded(

child: _buildUserSegment(

context,

label: 'You',

userId: currentUserId,

total: youTotal,

color: Colors.indigo.shade700,

homeScreenProvider: homeScreenProvider,

),

),

const SizedBox(width: 8),

Expanded(

child: FutureBuilder<String>(

future: homeScreenProvider.fetchUserDisplayName(partnerId),

builder: (ctx, nameSnap) {

final label = nameSnap.data ?? 'Partner';

return _buildUserSegment(

context,

label: label,

userId: partnerId,

total: partnerTotal,

color: Colors.teal.shade400,

homeScreenProvider: homeScreenProvider,

);

},

),

),

],

),

);

}



// Personal or filtered fallback

return Column(

mainAxisSize: MainAxisSize.min,

children: [

Text(

_currencyFormatter.format(totalSpending),

style: GoogleFonts.inter(

fontSize: 28,

fontWeight: FontWeight.w700,

color: Colors.indigo.shade700,

),

),

const SizedBox(height: 8),

Text(

'$numberOfExpenses expenses',

style: GoogleFonts.inter(

fontSize: 14,

color: Colors.grey.shade600,

),

),

if (selectorData.selectedUserFilter != null)

Padding(

padding: const EdgeInsets.only(top: 12),

child: GestureDetector(

onTap: () => homeScreenProvider.setUserFilter(null, context),

child: Chip(

label: Text('Clear Filter',

style: GoogleFonts.inter(fontSize: 12, color: Colors.white)),

backgroundColor: Colors.indigo.shade700,

padding: const EdgeInsets.symmetric(horizontal: 8),

),

),

),

],

);

},

),

],

),

),

);

},

);

}



Widget _buildUserSegment(

BuildContext context, {

required String label,

required String userId,

required double total,

required Color color,

required HomeScreenProvider homeScreenProvider,

}) {

return Hero(

tag: 'segment-$userId',

child: GestureDetector(

onTap: () => homeScreenProvider.setUserFilter(userId, context),

child: Card(

color: Colors.white,

elevation: 1,

shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),

child: Padding(

padding: const EdgeInsets.all(6),

child: Column(

mainAxisSize: MainAxisSize.min,

children: [

Text(label,

style: GoogleFonts.inter(

fontSize: 11, fontWeight: FontWeight.w600, color: color)),

const SizedBox(height: 4),

Text(_currencyFormatter.format(total),

style: GoogleFonts.inter(

fontSize: 14, fontWeight: FontWeight.w700, color: color)),

],

),

),

),

),

);

}

}