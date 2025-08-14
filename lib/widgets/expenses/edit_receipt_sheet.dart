import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:ui';

// The EditedReceipt class remains the same.
class EditedReceipt {
  final List<String> items;
  final List<double> prices;
  final String category;
  final DateTime date;

  EditedReceipt({
    required this.items,
    required this.prices,
    required this.category,
    required this.date,
  });
}

// The top-level function remains the same.
Future<EditedReceipt?> showEditReceiptSheet({
  required BuildContext context,
  required List<String> items,
  required List<num> prices,
  required String category,
  required DateTime? date,
}) {
  return showModalBottomSheet<EditedReceipt>(
    context: context,
    isScrollControlled: true,
    showDragHandle: false,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withOpacity(0.7),
    builder: (ctx) => _EditReceiptSheet(
      initialItems: items,
      initialPrices: prices,
      initialCategory: category,
      initialDate: date ?? DateTime.now(),
    ),
  );
}

class _EditReceiptSheet extends StatefulWidget {
  const _EditReceiptSheet({
    required this.initialItems,
    required this.initialPrices,
    required this.initialCategory,
    required this.initialDate,
  });

  final List<String> initialItems;
  final List<num> initialPrices;
  final String initialCategory;
  final DateTime initialDate;

  @override
  State<_EditReceiptSheet> createState() => _EditReceiptSheetState();
}

class _EditReceiptSheetState extends State<_EditReceiptSheet>
    with TickerProviderStateMixin {
  late List<TextEditingController> itemCtrls;
  late List<TextEditingController> priceCtrls;
  late TextEditingController catCtrl;
  late DateTime selectedDate;
  late AnimationController _slideController;
  late AnimationController _scaleController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;
  
  // Validation state
  List<String?> itemErrors = [];
  List<String?> priceErrors = [];
  String? categoryError;
  bool get isFormValid => _checkFormValidityWithoutStateChange();

  @override
  void initState() {
    super.initState();
    
    // Initialize controllers
    itemCtrls = widget.initialItems
        .map((s) => TextEditingController(text: s))
        .toList(growable: true);
    priceCtrls = widget.initialPrices
        .map((n) => TextEditingController(text: n.toString()))
        .toList(growable: true);
        
    if (itemCtrls.isEmpty) _addRow(isInitial: true);

    catCtrl = TextEditingController(
      text: (widget.initialCategory.isEmpty ? 'General' : widget.initialCategory),
    );
    selectedDate = widget.initialDate;

    // Initialize validation arrays (growable)
    itemErrors = List.generate(itemCtrls.length, (index) => null, growable: true);
    priceErrors = List.generate(priceCtrls.length, (index) => null, growable: true);

    // Add listeners for real-time validation
    _addValidationListeners();

    // Initialize animations
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.elasticOut,
    ));

    _scaleAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _scaleController,
      curve: Curves.elasticOut,
    ));

    _opacityAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOut,
    ));

    // Start animations
    _slideController.forward();
    Future.delayed(const Duration(milliseconds: 200), () {
      _scaleController.forward();
    });
  }

  @override
  void dispose() {
    for (final c in itemCtrls) c.dispose();
    for (final c in priceCtrls) c.dispose();
    catCtrl.dispose();
    _slideController.dispose();
    _scaleController.dispose();
    super.dispose();
  }

  void _addRow({bool isInitial = false}) {
    itemCtrls.add(TextEditingController());
    priceCtrls.add(TextEditingController());
    itemErrors.add(null);
    priceErrors.add(null);
    
    if (!isInitial) {
      setState(() {});
      // Add validation listeners to new controllers
      _addValidationListenersToIndex(itemCtrls.length - 1);
    }
  }

  void _removeRow(int i) {
    if (itemCtrls.length <= 1) return;
    setState(() {
      itemCtrls.removeAt(i).dispose();
      priceCtrls.removeAt(i).dispose();
      itemErrors.removeAt(i);
      priceErrors.removeAt(i);
    });
  }

  void _addValidationListeners() {
    for (int i = 0; i < itemCtrls.length; i++) {
      _addValidationListenersToIndex(i);
    }
    catCtrl.addListener(_validateCategory);
  }

  void _addValidationListenersToIndex(int index) {
    itemCtrls[index].addListener(() => _validateItem(index));
    priceCtrls[index].addListener(() => _validatePrice(index));
  }

  void _validateItem(int index) {
    final text = itemCtrls[index].text.trim();
    final priceText = priceCtrls[index].text.trim();
    final hasPrice = priceText.isNotEmpty;
    
    setState(() {
      if (text.isEmpty && hasPrice) {
        itemErrors[index] = 'Item name required';
      } else if (text.isEmpty && !hasPrice) {
        itemErrors[index] = null; // Empty row is okay
      } else if (text.length < 2) {
        itemErrors[index] = 'Name too short';
      } else if (text.length > 50) {
        itemErrors[index] = 'Name too long';
      } else {
        itemErrors[index] = null;
      }
    });
  }

  void _validatePrice(int index) {
    final text = priceCtrls[index].text.trim().replaceAll(',', '.');
    final itemText = itemCtrls[index].text.trim();
    final hasItem = itemText.isNotEmpty;
    
    setState(() {
      if (text.isEmpty && hasItem) {
        priceErrors[index] = 'Price required';
      } else if (text.isEmpty && !hasItem) {
        priceErrors[index] = null; // Empty row is okay
      } else {
        final price = double.tryParse(text);
        if (price == null) {
          priceErrors[index] = 'Invalid number';
        } else if (price <= 0) {
          priceErrors[index] = 'Must be > 0';
        } else if (price > 999999) {
          priceErrors[index] = 'Price too high';
        } else {
          priceErrors[index] = null;
        }
      }
    });
  }

  void _validateCategory() {
    final text = catCtrl.text.trim();
    setState(() {
      if (text.isEmpty) {
        categoryError = 'Category required';
      } else if (text.length > 30) {
        categoryError = 'Category too long';
      } else {
        categoryError = null;
      }
    });
  }

  bool _checkFormValidityWithoutStateChange() {
    // Check current state without triggering validation
    bool hasValidCompleteRow = false;
    
    for (int i = 0; i < itemCtrls.length; i++) {
      final itemText = itemCtrls[i].text.trim();
      final priceText = priceCtrls[i].text.trim();
      
      // Check if this row is completely valid
      if (itemText.isNotEmpty && priceText.isNotEmpty) {
        final price = double.tryParse(priceText.replaceAll(',', '.'));
        if (itemText.length >= 2 && itemText.length <= 50 && 
            price != null && price > 0 && price <= 999999) {
          hasValidCompleteRow = true;
        }
      }
    }
    
    // Check category validity
    final catText = catCtrl.text.trim();
    final categoryValid = catText.isNotEmpty && catText.length <= 30;
    
    // Form is valid if:
    // 1. Category is valid
    // 2. We have at least one complete valid row
    // 3. No validation errors exist on any filled fields
    return categoryValid && 
           hasValidCompleteRow && 
           !itemErrors.any((error) => error != null) &&
           !priceErrors.any((error) => error != null);
  }

  void _validateAllFields() {
    // Force validation on all fields
    for (int i = 0; i < itemCtrls.length; i++) {
      _validateItem(i);
      _validatePrice(i);
    }
    _validateCategory();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
              primary: const Color(0xFF6366F1),
              surface: const Color(0xFF1F2937),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != selectedDate) {
      setState(() => selectedDate = picked);
    }
  }

  void _save() async {
    // Force validate all fields first
    _validateAllFields();

    // Check for any validation errors
    if (!isFormValid) {
      // Find the specific issues to show a helpful message
      List<String> issues = [];
      
      if (categoryError != null) {
        issues.add('Fix category error');
      }
      
      bool hasPartialRow = false;
      bool hasValidCompleteRow = false;
      
      for (int i = 0; i < itemCtrls.length; i++) {
        final itemText = itemCtrls[i].text.trim();
        final priceText = priceCtrls[i].text.trim();
        
        if (itemText.isNotEmpty || priceText.isNotEmpty) {
          hasPartialRow = true;
          if (itemErrors[i] == null && priceErrors[i] == null && 
              itemText.isNotEmpty && priceText.isNotEmpty) {
            hasValidCompleteRow = true;
          }
        }
      }
      
      if (!hasValidCompleteRow) {
        if (hasPartialRow) {
          issues.add('Complete all partially filled rows');
        } else {
          issues.add('Add at least one item with name and price');
        }
      }
      
      if (itemErrors.any((error) => error != null) || 
          priceErrors.any((error) => error != null)) {
        issues.add('Fix all field errors shown in red');
      }
      
      _showCustomSnackbar(issues.join('. '));
      return;
    }

    // If we get here, form is valid - collect the data
    final newItems = <String>[];
    final newPrices = <double>[];

    for (var i = 0; i < itemCtrls.length; i++) {
      final name = itemCtrls[i].text.trim();
      final priceRaw = priceCtrls[i].text.trim().replaceAll(',', '.');
      final price = double.tryParse(priceRaw);
      
      if (name.isNotEmpty && price != null && price > 0) {
        newItems.add(name);
        newPrices.add(price);
      }
    }

    // Animate out before closing
    await _slideController.reverse();
    if (mounted) {
      Navigator.of(context).pop(EditedReceipt(
        items: newItems,
        prices: newPrices,
        category: catCtrl.text.trim().isEmpty ? 'General' : catCtrl.text.trim(),
        date: selectedDate,
      ));
    }
  }

  void _showCustomSnackbar(String message) {
    final overlay = Overlay.of(context);
    final overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        top: MediaQuery.of(context).padding.top + 20,
        left: 20,
        right: 20,
        child: Material(
          elevation: 0,
          color: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.red.shade400.withOpacity(0.9),
                  Colors.red.shade600.withOpacity(0.9),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.red.withOpacity(0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Row(
              children: [
                const Icon(Icons.warning_rounded, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    message,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    overlay.insert(overlayEntry);
    Future.delayed(const Duration(seconds: 3), () {
      overlayEntry.remove();
    });
  }

  Widget _buildGlassContainer({required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withOpacity(0.1),
            Colors.white.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Colors.white.withOpacity(0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: child,
        ),
      ),
    );
  }

  Widget _buildCustomTextField({
    required TextEditingController controller,
    required String hintText,
    TextInputType? keyboardType,
    TextAlign? textAlign,
    TextCapitalization? textCapitalization,
    String? labelText,
    String? errorText,
  }) {
    final hasError = errorText != null;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: hasError 
                ? [
                    Colors.red.withOpacity(0.1),
                    Colors.red.withOpacity(0.05),
                  ]
                : [
                    Colors.white.withOpacity(0.1),
                    Colors.white.withOpacity(0.05),
                  ],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: hasError 
                ? Colors.red.withOpacity(0.6)
                : Colors.white.withOpacity(0.2),
              width: hasError ? 1.5 : 1,
            ),
          ),
          child: TextField(
            controller: controller,
            keyboardType: keyboardType,
            textAlign: textAlign ?? TextAlign.start,
            textCapitalization: textCapitalization ?? TextCapitalization.none,
            style: TextStyle(
              color: hasError ? Colors.red.shade200 : Colors.white,
              fontWeight: FontWeight.w500,
            ),
            decoration: InputDecoration(
              hintText: hintText,
              labelText: labelText,
              hintStyle: TextStyle(
                color: hasError 
                  ? Colors.red.withOpacity(0.4)
                  : Colors.white.withOpacity(0.5),
              ),
              labelStyle: TextStyle(
                color: hasError 
                  ? Colors.red.withOpacity(0.7)
                  : Colors.white.withOpacity(0.7),
              ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
          ),
        ),
        if (hasError) ...[
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.only(left: 16),
            child: Text(
              errorText,
              style: TextStyle(
                color: Colors.red.shade300,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _slideAnimation,
      builder: (context, child) {
        return SlideTransition(
          position: _slideAnimation,
          child: FadeTransition(
            opacity: _opacityAnimation,
            child: Container(
              margin: EdgeInsets.only(
                top: MediaQuery.of(context).size.height * 0.1,
                left: 8,
                right: 8,
                bottom: 8,
              ),
              child: _buildGlassContainer(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        const Color(0xFF1F2937).withOpacity(0.95),
                        const Color(0xFF111827).withOpacity(0.95),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Padding(
                    padding: EdgeInsets.only(
                      left: 24,
                      right: 24,
                      top: 24,
                      bottom: MediaQuery.of(context).viewInsets.bottom + 24,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Drag handle
                        Center(
                          child: Container(
                            width: 40,
                            height: 4,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.3),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Header
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            ShaderMask(
                              shaderCallback: (bounds) => const LinearGradient(
                                colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                              ).createShader(bounds),
                              child: const Text(
                                'Edit Receipt',
                                style: TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            ScaleTransition(
                              scale: _scaleAnimation,
                              child: Container(
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                                  ),
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFF6366F1).withOpacity(0.4),
                                      blurRadius: 12,
                                      offset: const Offset(0, 6),
                                    ),
                                  ],
                                ),
                                child: Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(16),
                                    onTap: _addRow,
                                    child: const Padding(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 12,
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.add_circle_outline_rounded,
                                            color: Colors.white,
                                            size: 20,
                                          ),
                                          SizedBox(width: 8),
                                          Text(
                                            'Add Item',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 32),

                        // Items list
                        Flexible(
                          child: ListView.builder(
                            shrinkWrap: true,
                            itemCount: itemCtrls.length,
                            itemBuilder: (ctx, i) => Padding(
                              padding: const EdgeInsets.only(bottom: 16),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    flex: 5,
                                    child: _buildCustomTextField(
                                      controller: itemCtrls[i],
                                      hintText: 'Item Name',
                                      textCapitalization: TextCapitalization.sentences,
                                      errorText: itemErrors.length > i ? itemErrors[i] : null,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    flex: 2,
                                    child: _buildCustomTextField(
                                      controller: priceCtrls[i],
                                      hintText: '0.00',
                                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                      textAlign: TextAlign.end,
                                      errorText: priceErrors.length > i ? priceErrors[i] : null,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Container(
                                    margin: const EdgeInsets.only(top: 0),
                                    decoration: BoxDecoration(
                                      color: Colors.red.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: Colors.red.withOpacity(0.3),
                                      ),
                                    ),
                                    child: IconButton(
                                      onPressed: () => _removeRow(i),
                                      icon: const Icon(
                                        Icons.remove_circle_outline_rounded,
                                        color: Colors.red,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 24),

                        // Category & Date
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: _buildCustomTextField(
                                controller: catCtrl,
                                hintText: 'Category',
                                labelText: 'Category',
                                textCapitalization: TextCapitalization.sentences,
                                errorText: categoryError,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Container(
                              margin: const EdgeInsets.only(top: 0),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Colors.white.withOpacity(0.1),
                                    Colors.white.withOpacity(0.05),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: Colors.white.withOpacity(0.2)),
                              ),
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(16),
                                  onTap: _pickDate,
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 14,
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.calendar_today_rounded,
                                          color: Colors.white.withOpacity(0.8),
                                          size: 20,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          DateFormat.yMMMd().format(selectedDate),
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 32),

                        // Action buttons
                        Row(
                          children: [
                            Expanded(
                              child: Container(
                                height: 56,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: Colors.white.withOpacity(0.3),
                                    width: 1,
                                  ),
                                ),
                                child: Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(16),
                                    onTap: () async {
                                      await _slideController.reverse();
                                      if (mounted) Navigator.of(context).pop();
                                    },
                                    child: const Center(
                                      child: Text(
                                        'Cancel',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 16,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Container(
                                height: 56,
                                decoration: BoxDecoration(
                                  gradient: isFormValid 
                                    ? const LinearGradient(
                                        colors: [Color(0xFF10B981), Color(0xFF059669)],
                                      )
                                    : LinearGradient(
                                        colors: [
                                          Colors.grey.shade700,
                                          Colors.grey.shade800,
                                        ],
                                      ),
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: isFormValid 
                                    ? [
                                        BoxShadow(
                                          color: const Color(0xFF10B981).withOpacity(0.4),
                                          blurRadius: 12,
                                          offset: const Offset(0, 6),
                                        ),
                                      ]
                                    : [],
                                ),
                                child: Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(16),
                                    onTap: isFormValid ? _save : null,
                                    child: Center(
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            Icons.check_circle_rounded,
                                            color: isFormValid ? Colors.white : Colors.grey.shade500,
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            'Save Receipt',
                                            style: TextStyle(
                                              color: isFormValid ? Colors.white : Colors.grey.shade500,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}