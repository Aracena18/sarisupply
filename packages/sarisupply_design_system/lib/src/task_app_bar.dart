import 'package:flutter/material.dart';

/// Allows two title lines at large system text sizes without shrinking text.
AppBar sariSupplyTaskAppBar(BuildContext context,
        {required String title, List<Widget> actions = const []}) =>
    AppBar(
      toolbarHeight: MediaQuery.textScalerOf(context).scale(56).clamp(56, 168),
      title: Text(title, softWrap: true, maxLines: 2),
      actions: actions,
    );
