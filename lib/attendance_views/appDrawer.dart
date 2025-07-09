// widgets/app_drawer.dart
import 'package:flutter/material.dart';
import 'package:horilla/common/appimages.dart';
import 'package:shimmer/shimmer.dart';

class AppDrawer extends StatelessWidget {
  final Future<void> permissionFuture;
  final bool permissionOverview;
  final bool permissionAttendance;
  final bool permissionAttendanceRequest;
  final bool permissionHourAccount;

  const AppDrawer({
    required this.permissionFuture,
    required this.permissionOverview,
    required this.permissionAttendance,
    required this.permissionAttendanceRequest,
    required this.permissionHourAccount,
    super.key,
  });


  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: FutureBuilder<void>(
        future: permissionFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return _buildShimmerDrawer();
          } else if (snapshot.hasError) {
            return const Center(child: Text('Error loading permissions.'));
          } else {
            return _buildMenuDrawer(context);
          }
        },
      ),
    );
  }

  Widget _buildShimmerDrawer() {
    return ListView(
      padding: const EdgeInsets.all(0),
      children: [
        DrawerHeader(
          decoration: const BoxDecoration(),
          child: FittedBox(
            fit: BoxFit.contain,
            child: SizedBox(
              width: 80,
              height: 80,
              child: Image.asset(Appimages.splashScreenImg),
            ),
          ),
        ),
        shimmerListTile(),
        shimmerListTile(),
        shimmerListTile(),
        shimmerListTile(),
      ],
    );
    
  }
  Widget shimmerListTile() {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: ListTile(
        title: Container(
          width: double.infinity,
          height: 20.0,
          color: Colors.white,
        ),
      ),
    );
  }
  Widget _buildMenuDrawer(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(0),
      children: [
        DrawerHeader(
          decoration: const BoxDecoration(),
          child: FittedBox(
            fit: BoxFit.contain,
            child: SizedBox(
              width: 80,
              height: 80,
              child: Image.asset(Appimages.splashScreenImg),
            ),
          ),
        ),
        if (permissionOverview)
          ListTile(
            title: const Text('Overview'),
            onTap: () =>
                Navigator.pushReplacementNamed(context, '/attendance_overview'),
          ),
        if (permissionAttendance)
          ListTile(
            title: const Text('Attendance'),
            onTap: () => Navigator.pushReplacementNamed(
                context, '/attendance_attendance'),
          ),
        if (permissionAttendanceRequest)
          ListTile(
            title: const Text('Attendance Request'),
            onTap: () =>
                Navigator.pushReplacementNamed(context, '/attendance_request'),
          ),
        if (permissionHourAccount)
          ListTile(
            title: const Text('Hour Account'),
            onTap: () => Navigator.pushReplacementNamed(
                context, '/employee_hour_account'),
          ),
      ],
    );
  }
}
  Widget shimmerListTile() {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: ListTile(
        title: Container(
          width: double.infinity,
          height: 20.0,
          color: Colors.white,
        ),
      ),
    );
  }