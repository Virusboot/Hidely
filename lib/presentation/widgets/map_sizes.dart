import 'package:flutter/material.dart';

extension BuildContextExt on BuildContext {
  double w(double value) => value;
  double h(double value) => value;
  double sp(double value) => value;
  double get bottomPadding => MediaQuery.of(this).padding.bottom;
  double get topPadding => MediaQuery.of(this).padding.top;
}
