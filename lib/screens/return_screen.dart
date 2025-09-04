import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/database_provider.dart';
import '../providers/item_provider.dart';
import '../providers/borrow_record_provider.dart';
import '../models/student.dart' as models;
import '../models/borrow_record.dart' as models;
import '../core/design_system.dart';
import '../shared/widgets/app_scaffold.dart';
import '../shared/widgets/app_card.dart';

class ReturnScreen extends ConsumerStatefulWidget {
  const ReturnScreen({super.key});

  @override
  ConsumerState<ReturnScreen> createState() => _ReturnScreenState();
}

class _ReturnScreenState extends ConsumerState<ReturnScreen> {
  final _studentIdController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  
  models.Student? _selectedStudent;
  List<models.BorrowRecord> _activeBorrows = [];
  Map<int, models.ItemCondition> _itemConditions = {};
  Map<int, List<models.ItemCondition>> _quantityConditions = {};

  @override
  void dispose() {
    _studentIdController.dispose();
    super.dispose();
  }

  Future<void> _searchStudent() async {
    if (!_formKey.currentState!.validate()) return;

    try {
      final databaseService = ref.read(databaseServiceProvider);
      final student = await databaseService.getStudentByStudentId(_studentIdController.text.trim());
      
      if (student != null) {
        final activeBorrows = await databaseService.getActiveBorrowsByStudent(student.id);
        setState(() {
          _selectedStudent = student;
          _activeBorrows = activeBorrows;
          _itemConditions.clear();
          _quantityConditions.clear();
          
          for (final record in activeBorrows) {
            for (final item in record.items) {
              _itemConditions[item.itemId] = models.ItemCondition.good;
              
              if (item.quantityConditions.isNotEmpty) {
                final conditions = item.quantityConditions.map((qc) => qc.condition).toList();
                _quantityConditions[item.id] = conditions;
              } else {
                _quantityConditions[item.id] = List.filled(item.quantity, models.ItemCondition.good);
              }
            }
          }
        });
      } else {
        setState(() {
          _selectedStudent = null;
          _activeBorrows = [];
          _itemConditions.clear();
          _quantityConditions.clear();
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Student not found or has no active borrows.')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error searching student: $e')),
        );
      }
    }
  }

  Future<void> _returnItems() async {
    if (_selectedStudent == null || _activeBorrows.isEmpty) return;

    try {
      final databaseService = ref.read(databaseServiceProvider);
      
      for (final record in _activeBorrows) {
        final itemConditions = record.items.map((item) {
          final quantityConditions = _quantityConditions[item.id] ?? [];
          final List<models.QuantityCondition> conditions = [];
          
          for (int i = 0; i < quantityConditions.length; i++) {
            conditions.add(models.QuantityCondition(
              id: 0,
              borrowItemId: item.id,
              quantityUnit: i + 1,
              condition: quantityConditions[i],
            ));
          }
          
          return (
            borrowItemId: item.id,
            quantityConditions: conditions,
          );
        }).toList();

        await databaseService.returnBorrowRecordWithQuantityConditions(
          borrowRecordId: record.id,
          itemConditions: itemConditions,
        );
      }

      ref.invalidate(itemNotifierProvider);
      ref.invalidate(activeBorrowCountNotifierProvider);
      ref.invalidate(allItemsProvider);
      ref.invalidate(activeBorrowRecordsCountProvider);
      ref.invalidate(recentBorrowRecordsWithNamesNotifierProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Items returned successfully!')),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error returning items: $e')),
        );
      }
    }
  }

  Future<String> _getItemName(int itemId) async {
    try {
      final databaseService = ref.read(databaseServiceProvider);
      final items = await databaseService.getAllItems();
      final item = items.firstWhere((item) => item.id == itemId);
      return item.name;
    } catch (e) {
      return 'Unknown Item';
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Return Items',
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.screenPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildStudentSearchSection(),
            
            const SizedBox(height: AppSpacing.lg),
            
            if (_activeBorrows.isNotEmpty) ...[ 
              _buildActiveBorrowsSection(),
            ],
            
            const SizedBox(height: 100),
          ],
        ),
      ),
      floatingActionButton: _activeBorrows.isNotEmpty 
        ? FloatingActionButton.extended(
            onPressed: _returnItems,
            backgroundColor: AppColors.accent,
            foregroundColor: AppColors.onPrimary,
            icon: const Icon(Icons.assignment_return_rounded),
            label: Text('Return ${_activeBorrows.fold(0, (sum, record) => sum + record.items.fold(0, (itemSum, item) => itemSum + item.quantity))} Items'),
          )
        : null,
    );
  }

  Widget _buildStudentSearchSection() {
    return AppCard(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.person_search, color: AppColors.accent, size: 24),
                  const SizedBox(width: AppSpacing.sm),
                  Text('Find Student', style: AppTypography.h6),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _studentIdController,
                      decoration: InputDecoration(
                        labelText: 'Student ID',
                        border: const OutlineInputBorder(),
                        hintText: 'Enter student ID',
                        prefixIcon: const Icon(Icons.badge),
                        filled: true,
                        fillColor: AppColors.surface,
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter student ID';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  ElevatedButton.icon(
                    onPressed: _searchStudent,
                    icon: const Icon(Icons.search),
                    label: const Text('Search'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accent,
                      foregroundColor: AppColors.onPrimary,
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                        vertical: AppSpacing.sm + 4,
                      ),
                    ),
                  ),
                ],
              ),
              if (_selectedStudent != null) ...[ 
                const SizedBox(height: AppSpacing.md),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                    border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.check_circle, color: AppColors.success, size: 20),
                          const SizedBox(width: AppSpacing.xs),
                          Text(
                            'Student Found',
                            style: AppTypography.labelLarge.copyWith(
                              color: AppColors.success,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text('Name: ${_selectedStudent!.name}', style: AppTypography.bodyMedium),
                      Text('Year Level: ${_selectedStudent!.yearLevel}', style: AppTypography.bodyMedium),
                      Text('Section: ${_selectedStudent!.section}', style: AppTypography.bodyMedium),
                      Text('Active Borrows: ${_activeBorrows.length}', 
                        style: AppTypography.bodyMedium.copyWith(
                          color: AppColors.accent,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActiveBorrowsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.inventory_2, color: AppColors.accent, size: 24),
            const SizedBox(width: AppSpacing.sm),
            Text('Borrowed Items', style: AppTypography.h6),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                border: Border.all(color: AppColors.accent.withValues(alpha: 0.3)),
              ),
              child: Text(
                '${_activeBorrows.fold(0, (sum, record) => sum + record.items.fold(0, (itemSum, item) => itemSum + item.quantity))} units total',
                style: AppTypography.labelMedium.copyWith(
                  color: AppColors.accent,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        ..._activeBorrows.map((record) => Container(
          margin: const EdgeInsets.only(bottom: AppSpacing.md),
          child: AppCard(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                        border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
                      ),
                      child: Text(
                        'ID: ${record.borrowId}',
                        style: AppTypography.labelMedium.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Text(
                      'Borrowed: ${record.borrowedAt.toLocal().toString().split(' ')[0]}',
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                ...record.items.map((item) => FutureBuilder<String>(
                  future: _getItemName(item.itemId),
                  builder: (context, snapshot) {
                    final itemName = snapshot.data ?? 'Loading...';
                    final quantityConditions = _quantityConditions[item.id] ?? [];
                    
                    return Container(
                      margin: const EdgeInsets.only(bottom: AppSpacing.md),
                      padding: const EdgeInsets.all(AppSpacing.md),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                        border: Border.all(color: AppColors.outline.withValues(alpha: 0.3)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      itemName,
                                      style: AppTypography.bodyLarge.copyWith(
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.textPrimary,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                      maxLines: 2,
                                    ),
                                    const SizedBox(height: AppSpacing.xs),
                                    Text(
                                      'Total Quantity: ${item.quantity}',
                                      style: AppTypography.bodySmall.copyWith(
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.md),
                          Text(
                            'Return Condition per Unit:',
                            style: AppTypography.labelLarge.copyWith(
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          Wrap(
                            spacing: AppSpacing.sm,
                            runSpacing: AppSpacing.sm,
                            children: List.generate(item.quantity, (index) {
                              return Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: AppSpacing.sm,
                                  vertical: AppSpacing.xs,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.background,
                                  borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                                  border: Border.all(color: AppColors.outline.withValues(alpha: 0.3)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      'Unit ${index + 1}:',
                                      style: AppTypography.labelMedium.copyWith(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(width: AppSpacing.sm),
                                    DropdownButton<models.ItemCondition>(
                                      value: quantityConditions.length > index 
                                          ? quantityConditions[index] 
                                          : models.ItemCondition.good,
                                      isDense: true,
                                      underline: const SizedBox.shrink(),
                                      items: models.ItemCondition.values.map((condition) {
                                        Color conditionColor;
                                        switch (condition) {
                                          case models.ItemCondition.good:
                                            conditionColor = AppColors.success;
                                            break;
                                          case models.ItemCondition.damaged:
                                            conditionColor = AppColors.warning;
                                            break;
                                          case models.ItemCondition.lost:
                                            conditionColor = AppColors.error;
                                            break;
                                        }
                                        
                                        return DropdownMenuItem(
                                          value: condition,
                                          child: Text(
                                            condition.name.toUpperCase(),
                                            style: AppTypography.labelSmall.copyWith(
                                              color: conditionColor,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        );
                                      }).toList(),
                                      onChanged: (newCondition) {
                                        if (newCondition != null) {
                                          setState(() {
                                            final conditions = List<models.ItemCondition>.from(_quantityConditions[item.id] ?? []);
                                            
                                            while (conditions.length <= index) {
                                              conditions.add(models.ItemCondition.good);
                                            }
                                            
                                            conditions[index] = newCondition;
                                            _quantityConditions[item.id] = conditions;
                                          });
                                        }
                                      },
                                    ),
                                  ],
                                ),
                              );
                            }),
                          ),
                        ],
                      ),
                    );
                  },
                )).toList(),
              ],
            ),
            ),
          ),
        )).toList(),
        if (_activeBorrows.isEmpty && _selectedStudent != null)
          Center(
            child: Container(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                children: [
                  Icon(
                    Icons.inbox_outlined,
                    size: 48,
                    color: AppColors.textTertiary,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    'No Active Borrows',
                    style: AppTypography.h6.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'This student has no items to return.',
                    style: AppTypography.bodyMedium.copyWith(
                      color: AppColors.textTertiary,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}