// // lib/utils/date_picker_utils.dart
// import 'package:flutter/material.dart';
// import 'package:intl/intl.dart';

// // You might want to pass these colors as parameters or define them in a common theme file
// // For now, let's assume they are passed or accessible.
// // For demonstration, I'll include them here, but ideally, they come from a central theme.
// const Color _primaryColor = Color(0xFF673AB7); // Deep Purple
// const Color _textColor = Color(0xFF333333); // Dark grey for general text

// /// Shows a date and time picker dialog and returns the selected date/time string.
// ///
// /// [context]: The BuildContext to show the dialogs.
// /// [currentDateString]: The initial date and time string in 'yyyy/MM/dd hh:mm a' format.
// /// [onDateTimeSelected]: A callback function that receives the newly selected formatted date string.
// Future<void> showDateTimePicker({
//   required BuildContext context,
//   required String currentDateString,
//   required Function(String newDateString) onDateTimeSelected,
//   // Optional: Pass colors if they are not globally accessible
//   Color primaryColor = _primaryColor,
//   Color textColor = _textColor,
// }) async {
//   DateTime initialDate;
//   try {
//     initialDate = DateFormat('yyyy/MM/dd hh:mm a').parse(currentDateString);
//   } catch (e) {
//     initialDate = DateTime.now();
//   }

//   final DateTime? pickedDate = await showDatePicker(
//     context: context,
//     initialDate: initialDate,
//     firstDate: DateTime(2000),
//     lastDate: DateTime(2101),
//     builder: (context, child) {
//       return Theme(
//         data: ThemeData.light().copyWith(
//           colorScheme: ColorScheme.light(
//             primary: primaryColor, // Header background color
//             onPrimary: Colors.white, // Header text color
//             onSurface: textColor, // Body text color
//           ),
//           textButtonTheme: TextButtonThemeData(
//             style: TextButton.styleFrom(
//               foregroundColor: primaryColor, // Button text color
//             ),
//           ),
//         ),
//         child: child!,
//       );
//     },
//   );

//   if (pickedDate != null) {
//     final TimeOfDay? pickedTime = await showTimePicker(
//       context: context,
//       initialTime: TimeOfDay.fromDateTime(initialDate),
//       builder: (context, child) {
//         return Theme(
//           data: ThemeData.light().copyWith(
//             colorScheme: ColorScheme.light(
//               primary: primaryColor, // Header background color
//               onPrimary: Colors.white, // Header text color
//               onSurface: textColor, // Body text color
//             ),
//             textButtonTheme: TextButtonThemeData(
//               style: TextButton.styleFrom(
//                 foregroundColor: primaryColor, // Button text color
//               ),
//             ),
//           ),
//           child: child!,
//         );
//       },
//     );

//     if (pickedTime != null) {
//       final DateTime finalDateTime = DateTime(
//         pickedDate.year,
//         pickedDate.month,
//         pickedDate.day,
//         pickedTime.hour,
//         pickedTime.minute,
//       );
//       onDateTimeSelected(DateFormat('yyyy/MM/dd hh:mm a').format(finalDateTime));
//     }
//   }
// }
