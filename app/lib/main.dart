import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'src/care_plan_cubit.dart';
import 'src/theme.dart';
import 'src/upload_screen.dart';

void main() => runApp(const CarePathApp());

class CarePathApp extends StatelessWidget {
  const CarePathApp({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => CarePlanCubit(),
      child: MaterialApp(
        title: 'CarePath India',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.dark,
        home: const UploadScreen(),
      ),
    );
  }
}
