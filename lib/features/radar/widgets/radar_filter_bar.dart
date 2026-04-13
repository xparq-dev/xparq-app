// lib/features/radar/widgets/radar_filter_bar.dart

import 'package:flutter/material.dart';

class RadarFilterBar extends StatelessWidget {
  final String selectedInterest;
  final bool isExpanded;
  final List<String> interests;
  final ValueChanged<String> onInterestSelected;
  final VoidCallback onToggleExpansion;

  const RadarFilterBar({
    super.key,
    required this.selectedInterest,
    required this.isExpanded,
    required this.interests,
    required this.onInterestSelected,
    required this.onToggleExpansion,
  });

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFF1D9BF0);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textSecondary = isDark
        ? const Color(0xFF71767B)
        : const Color(0xFF536471);

    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: Row(
        children: [
          // Collapsible/Expandable Core
          GestureDetector(
            onTap: onToggleExpansion,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: isExpanded
                    ? Colors.transparent
                    : Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isExpanded
                      ? primaryColor
                      : primaryColor.withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isExpanded ? Icons.close : Icons.filter_list,
                    size: 16,
                    color: primaryColor,
                  ),
                  if (!isExpanded) ...[
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        selectedInterest,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: primaryColor,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),

          // The Expanding List
          Expanded(
            child: AnimatedCrossFade(
              firstChild: const SizedBox.shrink(),
              secondChild: Container(
                height: 32,
                margin: const EdgeInsetsDirectional.only(start: 8),
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  physics: const ClampingScrollPhysics(),
                  itemCount: interests.length,
                  itemBuilder: (context, index) {
                    final interest = interests[index];
                    final isSelected = selectedInterest == interest;
                    return Padding(
                      padding: const EdgeInsetsDirectional.only(end: 8),
                      child: FilterChip(
                        label: Text(
                          interest,
                          style: TextStyle(
                            fontSize: 11,
                            color: isSelected ? Colors.white : textSecondary,
                          ),
                        ),
                        selected: isSelected,
                        onSelected: (val) => onInterestSelected(interest),
                        backgroundColor: Colors.transparent,
                        selectedColor: primaryColor,
                        checkmarkColor: Colors.white,
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                          side: BorderSide(
                            color: isSelected
                                ? primaryColor
                                : textSecondary.withValues(alpha: 0.2),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              crossFadeState: isExpanded
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showFirst,
              duration: const Duration(milliseconds: 300),
            ),
          ),
        ],
      ),
    );
  }
}
