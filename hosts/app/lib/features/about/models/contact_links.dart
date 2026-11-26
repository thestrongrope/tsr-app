import 'package:flutter/material.dart';

/// A single external channel shown on the Contact screen.
class ContactLink {
  const ContactLink({
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.url,
    this.background,
    this.foreground,
  });

  final String label;
  final String subtitle;
  final IconData icon;
  final Uri url;
  final Color? background;
  final Color? foreground;
}

/// The official The Strong Rope channels. Order matches the site's footer.
final List<ContactLink> contactLinks = [
  ContactLink(
    label: 'WhatsApp',
    subtitle: '+918070151412',
    icon: Icons.chat_outlined,
    url: _whatsappUri,
  ),
  ContactLink(
    label: 'Telegram',
    subtitle: 't.me/TheStrongRope',
    icon: Icons.send_outlined,
    url: _telegramUri,
  ),
  ContactLink(
    label: 'Website',
    subtitle: 'thestrongrope.com',
    icon: Icons.language_outlined,
    url: _websiteUri,
  ),
  ContactLink(
    label: 'YouTube',
    subtitle: '@TheStrongRope',
    icon: Icons.play_circle_outline_rounded,
    url: _youtubeUri,
  ),
  ContactLink(
    label: 'Instagram',
    subtitle: '@thestrongrope',
    icon: Icons.camera_alt_outlined,
    url: _instagramUri,
  ),
  ContactLink(
    label: 'Facebook',
    subtitle: 'TheStrongRope',
    icon: Icons.thumb_up_outlined,
    url: _facebookUri,
  ),
  ContactLink(
    label: 'X (Twitter)',
    subtitle: '@_TheStrongRope',
    icon: Icons.alternate_email_rounded,
    url: _xUri,
  ),
];

final _whatsappUri = Uri.parse('https://wa.me/918070151412');
final _telegramUri = Uri.parse('https://t.me/TheStrongRope');
final _websiteUri = Uri.parse('https://thestrongrope.com/');
final _youtubeUri = Uri.parse('https://www.youtube.com/@TheStrongRope');
final _instagramUri = Uri.parse('https://www.instagram.com/thestrongrope/');
final _facebookUri = Uri.parse('https://facebook.com/TheStrongRope/');
final _xUri = Uri.parse('https://x.com/_TheStrongRope');
