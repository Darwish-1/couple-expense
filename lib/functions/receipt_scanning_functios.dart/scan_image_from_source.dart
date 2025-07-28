// // lib/services/receipt_processor.dart
// import 'dart:io';
// import 'package:couple_expenses/services/gpt_parser.dart';
// import 'package:image_picker/image_picker.dart';
// import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
// import 'package:intl/intl.dart';

// class ProcessedReceiptData {
//   final List<Map<String, dynamic>> items;
//   final String dateOfPurchase;
//   final double tax;
//   final double serviceCharge;
//   final double total;
//   final String dominantCategory;
//   final File? scannedImage;
//   final String? error;

//   ProcessedReceiptData({
//     required this.items,
//     required this.dateOfPurchase,
//     required this.tax,
//     required this.serviceCharge,
//     required this.total,
//     required this.dominantCategory,
//     this.scannedImage,
//     this.error,
//   });
// }

// class ReceiptProcessor {
//   final ImagePicker _picker = ImagePicker();

//   Future<ProcessedReceiptData> processImageFromSource(ImageSource source) async {
//     File? imageFile;
//     String? errorMessage;
//     List<Map<String, dynamic>> processedItems = [];
//     String processedDate = DateFormat('yyyy/MM/dd hh:mm a').format(DateTime.now());
//     double processedTax = 0.0;
//     double processedServiceCharge = 0.0;
//     double processedTotal = 0.0;
//     String processedCategory = 'Uncategorized';

//     try {
//       final pickedImage = await _picker.pickImage(source: source);
//       if (pickedImage == null) {
//         return ProcessedReceiptData(
//           items: [], dateOfPurchase: processedDate, tax: 0.0, serviceCharge: 0.0, total: 0.0, dominantCategory: 'N/A',
//           error: 'Image picking cancelled.',
//         );
//       }

//       imageFile = File(pickedImage.path);

//       final inputImage = InputImage.fromFile(imageFile);
//       final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
//       final recognizedText = await textRecognizer.processImage(inputImage);
//       final rawText = recognizedText.text;
//       await textRecognizer.close();

//       if (rawText.isEmpty) {
//         throw Exception('No text could be extracted from the image. Please try another image.');
//       }

//       final structured = await GptParser.extractStructuredData(rawText);

//       if (structured == null || structured.isEmpty) {
//         throw Exception('Could not extract structured data from the receipt. Please try again or manually enter details.');
//       }

//       final itemList = structured['items'];
//       if (itemList is List) {
//         for (var item in itemList) {
//           final name = item['name'] ?? '';
//           final priceStr = item['price'].toString().replaceAll(RegExp(r'[^0-9.]'), '');
//           final price = double.tryParse(priceStr) ?? 0.0;
//           final suggestedCategory = item['category'] ?? 'Other';

//           processedItems.add({
//             'name': name,
//             'price': price,
//             'suggestedCategory': suggestedCategory,
//           });
//         }
//       }

//       processedDate = structured['date_of_purchase'] ?? processedDate;
//       processedTax = structured['tax']?.toDouble() ?? 0.0;
//       processedServiceCharge = structured['service_charge']?.toDouble() ?? 0.0;
//       processedTotal = structured['total']?.toDouble() ?? 0.0;
//       processedCategory = _getDominantCategory(processedItems);

//       print('✅ Parsed from GPT: $structured');

//     } catch (e) {
//       print('❌ Error during scan: $e');
//       errorMessage = 'Error: ${e.toString().contains("Exception:") ? e.toString().split("Exception:")[1].trim() : "Failed to process receipt."}';
//     }

//     return ProcessedReceiptData(
//       items: processedItems,
//       dateOfPurchase: processedDate,
//       tax: processedTax,
//       serviceCharge: processedServiceCharge,
//       total: processedTotal,
//       dominantCategory: processedCategory,
//       scannedImage: imageFile,
//       error: errorMessage,
//     );
//   }

//   String _getDominantCategory(List<Map<String, dynamic>> items) {
//     final categoryCounts = <String, int>{};
//     for (var item in items) {
//       final cat = item['suggestedCategory'] ?? 'Uncategorized';
//       categoryCounts[cat] = (categoryCounts[cat] ?? 0) + 1;
//     }
//     categoryCounts.removeWhere((key, value) => key == 'Uncategorized');
//     return categoryCounts.entries.isEmpty
//         ? 'Uncategorized'
//         : categoryCounts.entries.reduce((a, b) => a.value > b.value ? a : b).key;
//   }
// }