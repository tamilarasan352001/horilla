// widgets/leave_drawer.dart

import 'package:flutter/material.dart';
import 'package:horilla/common/appimages.dart';
import 'package:shimmer/shimmer.dart';
// <-- where permissionLeave...Check variables are

class LeaveDrawer extends StatelessWidget {
  final Future<void> permissionFuture;

  final bool permissionLeaveOverviewCheck;
  final bool permissionMyLeaveRequestCheck;
  final bool permissionLeaveRequestCheck;
  final bool permissionLeaveTypeCheck;
  final bool permissionLeaveAllocationCheck;
  final bool permissionLeaveAssignCheck;
  
    const LeaveDrawer({
    super.key,
    required this.permissionFuture,
    required this.permissionLeaveOverviewCheck,
    required this.permissionMyLeaveRequestCheck,
    required this.permissionLeaveRequestCheck,
    required this.permissionLeaveTypeCheck,
    required this.permissionLeaveAllocationCheck,
    required this.permissionLeaveAssignCheck,
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
            return _buildLeaveMenuDrawer(context);
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
        for (int i = 0; i < 6; i++) shimmerListTile(),
      ],
    );
  }

  Widget shimmerListTile() {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: const ListTile(
        title: SizedBox(
          width: double.infinity,
          height: 20.0,
          child: ColoredBox(color: Colors.white),
        ),
      ),
    );
  }

  Widget _buildLeaveMenuDrawer(BuildContext context) {
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
        if (permissionLeaveOverviewCheck)
          ListTile(
            title: const Text('Overview'),
            onTap: () => Navigator.pushReplacementNamed(context, '/leave_overview'),
          ),
        if (permissionMyLeaveRequestCheck)
          ListTile(
            title: const Text('My Leave Request'),
            onTap: () => Navigator.pushReplacementNamed(context, '/my_leave_request'),
          ),
        if (permissionLeaveRequestCheck)
          ListTile(
            title: const Text('Leave Request'),
            onTap: () => Navigator.pushReplacementNamed(context, '/leave_request'),
          ),
        if (permissionLeaveTypeCheck)
          ListTile(
            title: const Text('Leave Type'),
            onTap: () => Navigator.pushReplacementNamed(context, '/leave_types'),
          ),
        if (permissionLeaveAllocationCheck)
          ListTile(
            title: const Text('Leave Allocation Request'),
            onTap: () =>
                Navigator.pushReplacementNamed(context, '/leave_allocation_request'),
          ),
        if (permissionLeaveAssignCheck)
          ListTile(
            title: const Text('All Assigned Leave'),
            onTap: () => Navigator.pushReplacementNamed(context, '/all_assigned_leave'),
          ),
      ],
    );
  }
}
