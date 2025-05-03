import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../constants/colors.dart';

List<String> _categories = ['All'];

class Sidebar extends StatelessWidget {
  final Function(String) onSearchChanged;
  final Function(String?) onFilterChanged;
  final VoidCallback? onClose;

  const Sidebar({
    super.key,
    required this.onSearchChanged,
    required this.onFilterChanged,
    this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 220,
      color: AppColors.white, // 💡 use your custom background
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (onClose != null)
            Padding(
              padding: const EdgeInsets.only(top: 5, left: 8),
              child: IconButton(
                icon: const Icon(
                  Icons.arrow_back_ios,
                  color: AppColors.primaryRed,
                ),
                onPressed: onClose,
              ),
            ),

          const Divider(color: AppColors.primaryRed, thickness: 1),
          const SizedBox(height: 10),

          // 🔍 Search Field
          TextField(
            decoration: InputDecoration(
              hintText: 'Search...',
              filled: true,
              fillColor: AppColors.darkInteract,
              hintStyle: const TextStyle(color: AppColors.textLight),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            style: const TextStyle(color: AppColors.white),
            onChanged: onSearchChanged,
          ),

          const SizedBox(height: 16),

          // ⬇️ Dropdown Filter category
          DropdownButtonFormField<String>(
            value: 'All',
            items: const [
              DropdownMenuItem(value: 'All', child: Text('All')),
              DropdownMenuItem(value: 'Games', child: Text('Games')),
              DropdownMenuItem(value: 'Karaoke', child: Text('Karaoke')),
              DropdownMenuItem(value: 'Live Music', child: Text('Live Music')),
              DropdownMenuItem(value: 'Market', child: Text('Market')),
              DropdownMenuItem(value: 'Sport', child: Text('Sport')),
              DropdownMenuItem(
                value: 'Themed Night',
                child: Text('Themed Night'),
              ),
            ],
            onChanged: onFilterChanged,
            decoration: InputDecoration(
              filled: true,
              fillColor: AppColors.darkInteract,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            dropdownColor: AppColors.darkInteract,
            style: const TextStyle(color: AppColors.textLight),
          ),

          const SizedBox(height: 16),
          const Divider(color: AppColors.primaryRed, thickness: 1),
          const SizedBox(height: 16),

          // 🔗 Social Media Icons
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              FaIcon(
                FontAwesomeIcons.linkedin,
                size: 32,
                color: AppColors.darkInteract,
              ),
              SizedBox(width: 16),
              FaIcon(
                FontAwesomeIcons.github,
                size: 32,
                color: AppColors.darkInteract,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
