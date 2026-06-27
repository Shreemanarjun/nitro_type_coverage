import 'package:flutter/material.dart';

class ApiItem {
  final String name;
  final String code;
  final String description;
  final VoidCallback run;

  ApiItem({
    required this.name,
    required this.code,
    required this.description,
    required this.run,
  });
}

class ApiSection {
  final String title;
  final IconData icon;
  final List<ApiItem> items;

  ApiSection({
    required this.title,
    required this.icon,
    required this.items,
  });
}
