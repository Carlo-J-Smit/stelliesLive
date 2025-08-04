import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../constants/colors.dart';
import 'package:url_launcher/url_launcher.dart';
import '../screens/about_screen.dart';

List<String> _categories = ['All'];

class Sidebar extends StatelessWidget {
  final Function(String) onSearchChanged;
  final Function(String?) onFilterChanged;
  final VoidCallback? onClose;
  final TextEditingController searchController;
  final String selectedFilter;
  final VoidCallback onClearFilters;

  const Sidebar({
    super.key,
    required this.onSearchChanged,
    required this.onFilterChanged,
    required this.onClearFilters,
    required this.searchController,
    required this.selectedFilter,
    this.onClose,
  });

  Future<void> _launchUrl(String url) async {
    final Uri uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      throw Exception('Could not launch $url');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isNarrow = MediaQuery.of(context).size.width < 700;

    return SafeArea(
      child: Container(
        width: 220,
        color: AppColors.white, // 💡 use your custom background
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (onClose != null && isNarrow)
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
              controller: searchController,
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
              value: selectedFilter,
              items: const [
                DropdownMenuItem(value: 'All', child: Text('All')),
                DropdownMenuItem(value: 'Games', child: Text('Games')),
                DropdownMenuItem(value: 'Karaoke', child: Text('Karaoke')),
                DropdownMenuItem(
                  value: 'Live Music',
                  child: Text('Live Music'),
                ),
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

            const SizedBox(height: 5),

            Center(
              child: TextButton.icon(
                onPressed: onClearFilters,
                icon: const Icon(Icons.clear, color: AppColors.primaryRed),
                label: const Text(
                  'Clear Filters',
                  style: TextStyle(color: AppColors.primaryRed),
                ),
              ),
            ),
            const Divider(color: AppColors.primaryRed, thickness: 1),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TextButton.icon(
                  onPressed: () {
                    const url =
                        'https://docs.google.com/forms/d/e/1FAIpQLSe1tEAuqDT4VEjqggP633DLwzqsI3xpEKaP_su4AI_K4KqooA/viewform?usp=dialog';
                    launchUrl(Uri.parse(url));
                  },
                  icon: const Icon(
                    Icons.report_problem_outlined,
                    color: AppColors.primaryRed,
                  ),
                  label: const Text(
                    'Incorrect Event?',
                    style: TextStyle(color: AppColors.primaryRed),
                  ),
                ),
              ],
            ),


            //const SizedBox(height: 5),
            const Divider(color: AppColors.primaryRed, thickness: 1),
            const SizedBox(height: 16),

            // 🔗 Social Media Icons
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                InkWell(
                  onTap:
                      () => _launchUrl(
                        'https://www.linkedin.com/in/your-profile',
                      ),
                  child: const FaIcon(
                    FontAwesomeIcons.linkedin,
                    size: 32,
                    color: AppColors.darkInteract,
                  ),
                ),
                const SizedBox(width: 16),
                InkWell(
                  onTap:
                      () => _launchUrl(
                        'https://github.com/Carlo-J-Smit/stelliesLive',
                      ),
                  child: const FaIcon(
                    FontAwesomeIcons.github,
                    size: 32,
                    color: AppColors.darkInteract,
                  ),
                ),
                const SizedBox(width: 16),
                InkWell(
                  onTap:
                      () =>
                          _launchUrl('https://www.instagram.com/stellieslive/'),
                  child: const FaIcon(
                    FontAwesomeIcons.instagram,
                    size: 32,
                    color: AppColors.darkInteract,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),
            const Divider(color: AppColors.primaryRed, thickness: 1),
            const SizedBox(height: 16),

            const Spacer(), // ⬅️ Pushes the about button to the bottom

            Center(
              child: TextButton.icon(
                onPressed: () {
                  Navigator.pushNamed(context, '/about');
                },
                icon: const Icon(
                  Icons.info_outline,
                  color: AppColors.primaryRed,
                ),
                label: const Text(
                  'About',
                  style: TextStyle(color: AppColors.primaryRed),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
