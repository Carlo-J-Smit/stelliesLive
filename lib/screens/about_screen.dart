import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../constants/colors.dart';
import '../constants/version.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  void _launchUrl(String url) async {
    final Uri uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      throw Exception('Could not launch $url');
    }
  }

  void _showLicenses(BuildContext context) {
    showLicensePage(
      context: context,
      applicationName: 'StelliesLive',
      applicationVersion: 'v0.4.0 — Updated January 2026',
      applicationLegalese: '© 2025 Carlo J. Smit and Reinardt van Zyl. All rights reserved.',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        title: const Text('About StelliesLive'),
        backgroundColor: AppColors.primaryRed,
        foregroundColor: AppColors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader('About StelliesLive'),
            _buildSectionText(
              'StelliesLive is a free, local discovery platform built to help people in Stellenbosch find nearby events, music, games, markets, and more in real-time. '
                  'It’s designed to connect students, tourists, and locals with the pulse of the town — right here, right now.',
            ),

            _buildDivider(),

            _buildSectionHeader('Founders'),
            _buildSectionText('• Carlo J. Smit — Developer & Creator'),
            _buildSectionText('• Reinhardt van Zyl — Visionary Co-Founder'),

            _buildDivider(),

            _buildSectionHeader('Contact Us'),
            _buildLink('Email: stellieslive.app@gmail.com', 'mailto:stellieslive.app@gmail.com'),


            _buildDivider(),

            _buildSectionHeader('Support Us'),
            _buildSectionText(
              'StelliesLive is completely free to use. To keep the platform running, we rely on donations and occasional ads to cover server and data costs. '
                  'If you find the app valuable, consider supporting us!',
            ),
            _buildLink('Donate via Buy Me a Coffee', 'https://coff.ee/stellieslive'),

            _buildDivider(),

            _buildSectionHeader('Feedback'),
            _buildSectionText(
              'We’d love your thoughts! If you’ve encountered bugs or have suggestions, let us know. Feedback helps us improve StelliesLive for everyone.',
            ),
            _buildLink('Fill Out Feedback Form', 'https://docs.google.com/forms/d/e/1FAIpQLSe1tEAuqDT4VEjqggP633DLwzqsI3xpEKaP_su4AI_K4KqooA/viewform?usp=dialog'),

            _buildDivider(),

            _buildSectionHeader('Terms & Conditions'),
            _buildSectionText(
              '- Event data and crowd levels are estimated and provided as-is.\n'
                  '- Always confirm event details with the venue.\n'
                  '- Users must follow venue rules and age restrictions.\n'
                  '- StelliesLive is not liable for changes or inaccuracies.',
            ),

            _buildDivider(),

            _buildSectionHeader('Privacy Policy'),
            _buildSectionText(
              'We respect your privacy. We only collect minimal, anonymized data (like your location) to provide real-time local insights.\n'
                  'No personal data is sold or shared without your consent.\n'
                  'Anonymous logs are used to generate our activity heatmaps.',
            ),

            _buildDivider(),

            _buildSectionHeader('Legal Notice'),
            _buildSectionText(
              'StelliesLive is independently developed and is not affiliated with Stellenbosch University.\n'
                  'All logos, names, and trademarks belong to their respective owners.',
            ),

            _buildDivider(),

            _buildSectionHeader('Data Deletion & Privacy Details'),
            _buildSectionText(
              'You can view our full privacy policy and request data deletion through the links below. We are committed to transparency and protecting your rights.',
            ),
            _buildLink('View Full Privacy Policy', 'https://stellieslive.web.app/privacy-policy'),
            _buildLink('Request Data Deletion', 'https://stellieslive.web.app/delete-account'),


            _buildDivider(),

            _buildSectionHeader('Open Source Licenses'),
            TextButton.icon(
              onPressed: () => _showLicenses(context),
              icon: const Icon(Icons.article_outlined, color: AppColors.primaryRed),
              label: const Text(
                'View Licenses',
                style: TextStyle(color: AppColors.primaryRed),
              ),
            ),

            const SizedBox(height: 16),
            const Center(
              child: Text(
                AppVersion.appVersion,
                style: TextStyle(color: AppColors.darkInteract, fontSize: 13),
              ),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 4),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: AppColors.primaryRed,
        ),
      ),
    );
  }

  Widget _buildSectionText(String content) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        content,
        style: const TextStyle(fontSize: 15, color: AppColors.darkInteract, height: 1.4),
      ),
    );
  }

  Widget _buildLink(String label, String url) {
    return TextButton(
      onPressed: () => _launchUrl(url),
      style: TextButton.styleFrom(
        foregroundColor: AppColors.darkInteract,
        padding: EdgeInsets.zero,
        alignment: Alignment.centerLeft,
      ),
      child: Text(label),
    );
  }

  Widget _buildDivider() {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 12),
      child: Divider(color: AppColors.primaryRed, thickness: 1),
    );
  }
}
