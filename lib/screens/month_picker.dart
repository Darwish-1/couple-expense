import 'package:couple_expenses/providers/month_selection_provider.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:couple_expenses/providers/home_screen_provider.dart';

class MonthButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    // Get current month
    DateTime now = DateTime.now();
    String currentMonth = DateFormat('MMMM yyyy').format(now);

    return ElevatedButton(
      onPressed: () {
        // Open the month picker
        showDialog(
          context: context,
          builder: (BuildContext context) {
            return MonthPickerDialog();
          },
        );
      },
      child: Text(currentMonth),
    );
  }
}

class MonthPickerDialog extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    DateTime now = DateTime.now();
    int currentYear = now.year;

    // List of months
    List<String> months = [
      "January", "February", "March", "April", "May", "June", 
      "July", "August", "September", "October", "November", "December"
    ];

    return Dialog(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Select a Month', style: TextStyle(fontSize: 18)),
            SizedBox(height: 10),
            GridView.builder(
              shrinkWrap: true,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
              ),
              itemCount: 12,
              itemBuilder: (context, index) {
                String month = months[index];
                return ElevatedButton(
                  onPressed: () {
                    // Use the provider to update the selected month and year
                    Provider.of<MonthSelectionProvider>(context, listen: false)
                        .setSelectedMonth(month, currentYear);

                    // Close the dialog
                    Navigator.pop(context);
                  },
                  child: Text(month),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}