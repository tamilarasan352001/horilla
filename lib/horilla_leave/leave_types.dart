import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:horilla/common/appColors.dart';
import 'package:horilla/common/appimages.dart';
import 'package:horilla/horilla_leave/leaver_drawer.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shimmer/shimmer.dart';

class LeaveTypes extends StatefulWidget {
  const LeaveTypes({super.key});

  @override
  _LeaveTypes createState() => _LeaveTypes();
}

class _LeaveTypes extends State<LeaveTypes> {
  List<Map<String, dynamic>> leaveType = [];
  final _pageController = PageController(initialPage: 0);
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  int maxCount = 5;
  int leaveTypeCount = 0;
  bool isLoading = true;
  bool permissionLeaveAssignCheck = false;
  bool permissionLeaveTypeCheck = false;
  bool permissionLeaveRequestCheck = false;
  bool permissionLeaveOverviewCheck = false;
  bool permissionMyLeaveRequestCheck = false;
  bool permissionLeaveAllocationCheck = false;
  late String baseUrl = '';
  late Map<String, dynamic> arguments;
     late Future<void> permissionFuture;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  /// widget list
  final List<Widget> bottomBarPages = [
    const Home(),
    const Overview(),
    const User(),
  ];

  @override
  void initState() {
    super.initState();
    permissionFuture = checkPermissions();
    getLeaveType();
    getBaseUrl();
    prefetchData();
  }

  Future<void> checkPermissions() async {
    await permissionLeaveOverviewChecks();
    await permissionLeaveTypeChecks();
    await permissionLeaveRequestChecks();
    await permissionLeaveAssignChecks();
  }

  Future<void> permissionLeaveOverviewChecks() async {
    final prefs = await SharedPreferences.getInstance();
    var token = prefs.getString("token");
    var typedServerUrl = prefs.getString("typed_url");
    var uri = Uri.parse('$typedServerUrl/api/leave/check-perm/');
    var response = await http.get(uri, headers: {
      "Content-Type": "application/json",
      "Authorization": "Bearer $token",
    });
    if (response.statusCode == 200) {
      permissionLeaveOverviewCheck = true;
      permissionMyLeaveRequestCheck = true;
      permissionLeaveAllocationCheck = true;
    } else {
      permissionMyLeaveRequestCheck = true;
      permissionLeaveAllocationCheck = true;
    }
  }

  Future<void> permissionLeaveTypeChecks() async {
    final prefs = await SharedPreferences.getInstance();
    var token = prefs.getString("token");
    var typedServerUrl = prefs.getString("typed_url");
    var uri = Uri.parse('$typedServerUrl/api/leave/check-type/');
    var response = await http.get(uri, headers: {
      "Content-Type": "application/json",
      "Authorization": "Bearer $token",
    });
    if (response.statusCode == 200) {
      permissionLeaveTypeCheck = true;
      permissionMyLeaveRequestCheck = true;
      permissionLeaveAllocationCheck = true;
    } else {
      permissionMyLeaveRequestCheck = true;
      permissionLeaveAllocationCheck = true;
    }
  }

  Future<void> permissionLeaveRequestChecks() async {
    final prefs = await SharedPreferences.getInstance();
    var token = prefs.getString("token");
    var typedServerUrl = prefs.getString("typed_url");
    var uri = Uri.parse('$typedServerUrl/api/leave/check-request/');
    var response = await http.get(uri, headers: {
      "Content-Type": "application/json",
      "Authorization": "Bearer $token",
    });
    if (response.statusCode == 200) {
      permissionLeaveRequestCheck = true;
      permissionMyLeaveRequestCheck = true;
      permissionLeaveAllocationCheck = true;
    } else {
      permissionMyLeaveRequestCheck = true;
      permissionLeaveAllocationCheck = true;
    }
  }

  Future<void> permissionLeaveAssignChecks() async {
    final prefs = await SharedPreferences.getInstance();
    var token = prefs.getString("token");
    var typedServerUrl = prefs.getString("typed_url");
    var uri = Uri.parse('$typedServerUrl/api/leave/check-assign/');
    var response = await http.get(uri, headers: {
      "Content-Type": "application/json",
      "Authorization": "Bearer $token",
    });
    if (response.statusCode == 200) {
      permissionLeaveAssignCheck = true;
      permissionMyLeaveRequestCheck = true;
      permissionLeaveAllocationCheck = true;
    } else {
      permissionMyLeaveRequestCheck = true;
      permissionLeaveAllocationCheck = true;
    }
  }

  void prefetchData() async {
    final prefs = await SharedPreferences.getInstance();
    var token = prefs.getString("token");
    var typedServerUrl = prefs.getString("typed_url");
    var employeeId = prefs.getInt("employee_id");
    var uri = Uri.parse('$typedServerUrl/api/employee/employees/$employeeId');
    var response = await http.get(uri, headers: {
      "Content-Type": "application/json",
      "Authorization": "Bearer $token",
    });

    if (response.statusCode == 200) {
      final responseData = jsonDecode(response.body);
      arguments = {
        'employee_id': responseData['id'],
        'employee_name': responseData['employee_first_name'] +
            ' ' +
            responseData['employee_last_name'],
        'badge_id': responseData['badge_id'],
        'email': responseData['email'],
        'phone': responseData['phone'],
        'date_of_birth': responseData['dob'],
        'gender': responseData['gender'],
        'address': responseData['address'],
        'country': responseData['country'],
        'state': responseData['state'],
        'city': responseData['city'],
        'qualification': responseData['qualification'],
        'experience': responseData['experience'],
        'marital_status': responseData['marital_status'],
        'children': responseData['children'],
        'emergency_contact': responseData['emergency_contact'],
        'emergency_contact_name': responseData['emergency_contact_name'],
        'employee_work_info_id': responseData['employee_work_info_id'],
        'employee_bank_details_id': responseData['employee_bank_details_id'],
        'employee_profile': responseData['employee_profile']
      };
    }
  }

  Future<void> getBaseUrl() async {
    final prefs = await SharedPreferences.getInstance();
    var typedServerUrl = prefs.getString("typed_url");
    setState(() {
      baseUrl = typedServerUrl ?? '';
    });
  }

  Future<void> getLeaveType() async {
    final prefs = await SharedPreferences.getInstance();
    var token = prefs.getString("token");
    var typedServerUrl = prefs.getString("typed_url");
    var uri = Uri.parse('$typedServerUrl/api/leave/leave-type/');
    var response = await http.get(uri, headers: {
      "Content-Type": "application/json",
      "Authorization": "Bearer $token",
    });

    if (response.statusCode == 200) {
      setState(() {
        leaveType = List<Map<String, dynamic>>.from(
          jsonDecode(response.body)['results'],
        );
        leaveTypeCount = jsonDecode(response.body)['count'];
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      key: _scaffoldKey,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(115),
        child: Stack(
          children: [
            // Blue background layer
            Container(
              height: 115,
              decoration: const BoxDecoration(
                color: Appcolors.appBlue,
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(20),
                  bottomRight: Radius.circular(20),
                ),
              ),
            ),

            Positioned(
              child: Image.asset(
                width: 200,
                Appimages.appbar,
                fit: BoxFit.cover,
              ),
            ),
            // Actual content
            Positioned.fill(
              child: Row(
                children: [
                  // Back button
                  Padding(
                    padding: const EdgeInsets.only(left: 20.0, top: 40),
                    child: GestureDetector(
                      onTap: () {
                        _scaffoldKey.currentState?.openDrawer();
                      },
                      child: SvgPicture.asset(
                        Appimages.menuIcon,
                        color: Colors.white,
                        // height: 24,
                        // width: 24,
                      ),
                    ),
                  ),

                  const Padding(
                    padding: EdgeInsets.only(left: 50.0, top: 40),
                    child: Text(
                      'Leave Types',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      // AppBar(
      //   backgroundColor: Colors.white,
      //   leading: IconButton(
      //     icon: const Icon(Icons.menu),
      //     onPressed: () {
      //       _scaffoldKey.currentState?.openDrawer();
      //     },
      //   ),
      //   automaticallyImplyLeading: false,
      //   title: const Text('Leave Types',
      //       style: TextStyle(
      //         color: Colors.black,
      //         fontWeight: FontWeight.bold,
      //       )),
      //   actions: const [],
      // ),
      floatingActionButton: const Padding(
        padding: EdgeInsets.all(25.0),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 5),
        child: Center(
          child: isLoading
              ? Shimmer.fromColors(
                  baseColor: Colors.grey[300]!,
                  highlightColor: Colors.grey[100]!,
                  child: ListView.builder(
                    itemCount: 20,
                    itemBuilder: (context, index) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: Container(
                        width: 40.0,
                        height: 80.0,
                        color: Colors.white,
                      ),
                    ),
                  ),
                )
              : leaveTypeCount == 0
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SvgPicture.asset(Appimages.emptyData),
                          SizedBox(height: 20),
                          const Text(
                            "There are no Leave type records to display",
                            style: TextStyle(
                                fontSize: 15.0,
                                color: Colors.black,
                                fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      itemCount: leaveType.length,
                      itemBuilder: (context, index) {
                        final record = leaveType[index];
                        if (record['name'] != null) {
                          return buildListItem(context, baseUrl, record);
                        } else {
                          return Container();
                        }
                      },
                    ),
        ),
      ),
      drawer: LeaveDrawer(permissionFuture: permissionFuture, permissionLeaveOverviewCheck: permissionLeaveOverviewCheck, permissionMyLeaveRequestCheck: permissionMyLeaveRequestCheck, permissionLeaveRequestCheck: permissionLeaveRequestCheck, permissionLeaveTypeCheck: permissionLeaveTypeCheck, permissionLeaveAllocationCheck: permissionLeaveAllocationCheck, permissionLeaveAssignCheck: permissionLeaveAssignCheck)
      /* Drawer(
        child: FutureBuilder<void>(
          future: checkPermissions(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              // Show shimmer effect while waiting
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
                        child: Image.asset(Appimages.splashScreenImg
                            //'Assets/horilla-logo.png',
                            ),
                      ),
                    ),
                  ),
                  shimmerListTile(),
                  shimmerListTile(),
                  shimmerListTile(),
                  shimmerListTile(),
                  shimmerListTile(),
                  shimmerListTile(),
                ],
              );
            } else if (snapshot.hasError) {
              return const Center(child: Text('Error loading permissions.'));
            } else {
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
                        child: Image.asset(Appimages.splashScreenImg
                            //'Assets/horilla-logo.png',
                            ),
                      ),
                    ),
                  ),
                  permissionLeaveOverviewCheck
                      ? ListTile(
                          title: const Text('Overview'),
                          onTap: () {
                            Navigator.pushNamed(context, '/leave_overview');
                          },
                        )
                      : const SizedBox.shrink(),
                  permissionMyLeaveRequestCheck
                      ? ListTile(
                          title: const Text('My Leave Request'),
                          onTap: () {
                            Navigator.pushNamed(context, '/my_leave_request');
                          },
                        )
                      : const SizedBox.shrink(),
                  permissionLeaveRequestCheck
                      ? ListTile(
                          title: const Text('Leave Request'),
                          onTap: () {
                            Navigator.pushNamed(context, '/leave_request');
                          },
                        )
                      : const SizedBox.shrink(),
                  permissionLeaveTypeCheck
                      ? ListTile(
                          title: const Text('Leave Type'),
                          onTap: () {
                            Navigator.pushNamed(context, '/leave_types');
                          },
                        )
                      : const SizedBox.shrink(),
                  permissionLeaveAllocationCheck
                      ? ListTile(
                          title: const Text('Leave Allocation Request'),
                          onTap: () {
                            Navigator.pushNamed(
                                context, '/leave_allocation_request');
                          },
                        )
                      : const SizedBox.shrink(),
                  permissionLeaveAssignCheck
                      ? ListTile(
                          title: const Text('All Assigned Leave'),
                          onTap: () {
                            Navigator.pushNamed(context, '/all_assigned_leave');
                          },
                        )
                      : const SizedBox.shrink(),
                ],
              );
            }
          },
        ),
      ), */
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

Widget buildListItem(
    BuildContext context, baseUrl, Map<String, dynamic> record) {
  return Padding(
    padding: const EdgeInsets.all(8.0),
    child: GestureDetector(
      onTap: () {
        Navigator.pushNamed(context, '/selected_leave_type', arguments: {
          'selectedTypeId': record['id'],
          'selectedTypeName': record['name'],
        });
      },
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey[50]!),
          borderRadius: BorderRadius.circular(8.0),
          color: Appcolors.cardColor,
        ),
        child: ListTile(
            tileColor: Colors.white,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            leading: Container(
              width: 40.0,
              height: 40.0,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Appcolors.profileBg, width: 1.0),
              ),
              child: Stack(
                children: [
                  if (record['icon'] != null && record['icon'].isNotEmpty)
                    Positioned.fill(
                      child: ClipOval(
                        child: Image.network(
                          baseUrl + record['icon'],
                          fit: BoxFit.cover,
                          errorBuilder: (BuildContext context, Object exception,
                              StackTrace? stackTrace) {
                            return Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Image.asset(Appimages.calendarIcon),
                            );
                            // const Icon(Icons.calendar_month_outlined,
                            //     color: Colors.grey);
                          },
                        ),
                      ),
                    ),
                  if (record['icon'] == null || record['icon'].isEmpty)
                    Positioned.fill(
                      child: Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Appcolors.profileBg,
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Image.asset(Appimages.calendarIcon),
                          )),
                    ),
                ],
              ),
            ),
            title: Text(
              record['name'],
              style: const TextStyle(
                fontSize: 18.0,
              ),
            ),
            trailing: Padding(
              padding: const EdgeInsets.all(8.0),
              child: SvgPicture.asset(Appimages.rightArrow),
            )
            //const Icon(Icons.keyboard_arrow_right),
            ),
      ),
    ),
  );
}

class Home extends StatelessWidget {
  const Home({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Navigator.pushNamed(context, '/home');
    });
    return Container(
      color: Colors.white,
      child: const Center(child: Text('Page 1')),
    );
  }
}

class Overview extends StatelessWidget {
  const Overview({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
        color: Colors.white, child: const Center(child: Text('Page 2')));
  }
}

class User extends StatelessWidget {
  const User({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Navigator.pushNamed(context, '/user');
    });
    return Container(
      color: Colors.white,
      child: const Center(child: Text('Page 1')),
    );
  }
}
