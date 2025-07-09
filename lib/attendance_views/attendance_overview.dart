import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:flutter_svg/svg.dart';
import 'package:horilla/attendance_views/appDrawer.dart';
import 'package:horilla/common/appColors.dart';
import 'package:horilla/common/appimages.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shimmer/shimmer.dart';
import 'package:html/parser.dart' as html_parser;

class AttendanceOverview extends StatefulWidget {
  const AttendanceOverview({super.key});

  @override
  _AttendanceOverviewState createState() => _AttendanceOverviewState();
}

class _AttendanceOverviewState extends State<AttendanceOverview>
    with SingleTickerProviderStateMixin {
  final ScrollController _scrollController = ScrollController();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  late String baseUrl = '';
  late Map<String, dynamic> arguments;
  late TabController _tabController;
  late String todayAttendance = '0';
  late String offlineEmpCount = '0';
  TextEditingController bodyController = TextEditingController();
  List<Map<String, dynamic>> requestsOfflineEmployees = [];
  List<Map<String, dynamic>> requestsOvertimeValidate = [];
  List<Map<String, dynamic>> requestsNonValidAttendance = [];
  List<Map<String, dynamic>> templateList = [];
  List<String> templateItems = [];
  String? selectedTemplate;
  String? bodyContent;
  String? nextPageUrl;
  int overtimeValidate = 0;
  int nonValidated = 0;
  int _currentPage = 0;
  final int _itemsPerPage = 5;
  final List<Widget> bottomBarPages = [];
  int maxCount = 5;
  int page = 1;
  int currentPage = 1;
  bool permissionCheck = false;
  bool isLoading = true;
  bool _isShimmerVisible = true;
  bool permissionOverview = true;
  bool permissionAttendance = false;
  bool permissionAttendanceRequest = false;
  bool permissionHourAccount = false;
  late Future<void> permissionFuture;
  @override
  void initState() {
    super.initState();
    bodyController.text = bodyContent ?? '';
    prefetchData();
    _scrollController.addListener(_scrollListener);
    _tabController = TabController(length: 2, vsync: this);
    permissionFuture = permissionChecks();
    getAllOfflineEmployees(1);
    getTodayAttendance();
    getOfflineEmployeeCount();
    getAllOvertimeValidateEmployees();
    getAllNonValidatedAttendance();
    getBaseUrl();
    _simulateLoading();
  }

  Future<void> _simulateLoading() async {
    await Future.delayed(const Duration(seconds: 10));
    setState(() {});
  }

  @override
  void dispose() {
    _scrollController.removeListener(_scrollListener);
    _scrollController.dispose();

    bodyController.dispose();

    super.dispose();
  }

  Future<void> getBaseUrl() async {
    final prefs = await SharedPreferences.getInstance();
    var typedServerUrl = prefs.getString("typed_url");
    setState(() {
      baseUrl = typedServerUrl ?? '';
    });
  }

  Future<void> permissionChecks() async {
    final prefs = await SharedPreferences.getInstance();
    var token = prefs.getString("token");
    var typedServerUrl = prefs.getString("typed_url");
    var uri =
        Uri.parse('$typedServerUrl/api/attendance/permission-check/attendance');
    var response = await http.get(uri, headers: {
      "Content-Type": "application/json",
      "Authorization": "Bearer $token",
    });
    if (response.statusCode == 200) {
      permissionCheck = true;
      permissionOverview = true;
      permissionAttendance = true;
      permissionAttendanceRequest = true;
      permissionHourAccount = true;
    } else {
      permissionAttendanceRequest = true;
      permissionHourAccount = true;
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

  Future<void> getAllOfflineEmployees(int page) async {
    final prefs = await SharedPreferences.getInstance();
    var token = prefs.getString("token");
    var typedServerUrl = prefs.getString("typed_url");
    var uri = Uri.parse(
        '$typedServerUrl/api/attendance/offline-employees/list/?page=$page');
    var response = await http.get(uri, headers: {
      "Content-Type": "application/json",
      "Authorization": "Bearer $token",
    });
    if (response.statusCode == 200) {
      var data = jsonDecode(response.body);
      setState(() {
        if (data['results'] is List) {
          List<dynamic> results = data['results'];
          List<Map<String, dynamic>> offlineEmployees = [];
          for (var result in results) {
            if (result is Map<String, dynamic>) {
              offlineEmployees.add(result);
            }
          }
          setState(() {
            requestsOfflineEmployees.addAll(offlineEmployees);
            _isShimmerVisible = false;
          });
        }
        nextPageUrl = data['next'];
      });
    }
  }

  Future<void> getTodayAttendance() async {
    final prefs = await SharedPreferences.getInstance();
    var token = prefs.getString("token");
    var typedServerUrl = prefs.getString("typed_url");
    var uri = Uri.parse('$typedServerUrl/api/attendance/today-attendance/');
    var response = await http.get(uri, headers: {
      "Content-Type": "application/json",
      "Authorization": "Bearer $token",
    });
    if (response.statusCode == 200) {
      setState(() {
        todayAttendance =
            jsonDecode(response.body)['marked_attendances_ratio'].toString();
      });
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> getOfflineEmployeeCount() async {
    final prefs = await SharedPreferences.getInstance();
    var token = prefs.getString("token");
    var typedServerUrl = prefs.getString("typed_url");
    var uri =
        Uri.parse('$typedServerUrl/api/attendance/offline-employees/count/');
    var response = await http.get(uri, headers: {
      "Content-Type": "application/json",
      "Authorization": "Bearer $token",
    });
    if (response.statusCode == 200) {
      setState(() {
        offlineEmpCount = jsonDecode(response.body)['count'].toString();
        isLoading = false;
      });
    }
  }

  List<Map<String, dynamic>> getCurrentPageOfflineEmployees() {
    final int startIndex = _currentPage * _itemsPerPage;
    final int endIndex = startIndex + _itemsPerPage;
    if (startIndex >= requestsOfflineEmployees.length) {
      return [];
    }
    return requestsOfflineEmployees.sublist(
      startIndex,
      endIndex < requestsOfflineEmployees.length
          ? endIndex
          : requestsOfflineEmployees.length,
    );
  }

  void _previousPage() {
    setState(() {
      if (_currentPage > 0) {
        _currentPage--;
      }
    });
  }

  void _nextPage() {
    setState(() {
      if ((_currentPage + 1) * _itemsPerPage <
          requestsOfflineEmployees.length) {
        _currentPage++;
      }
    });
  }

  void _scrollListener() {
    if (_scrollController.offset >=
            _scrollController.position.maxScrollExtent &&
        !_scrollController.position.outOfRange) {
      currentPage++;
      getAllOvertimeValidateEmployees();
      getAllNonValidatedAttendance();
    }
  }

  Future<void> getAllOvertimeValidateEmployees() async {
    final prefs = await SharedPreferences.getInstance();
    var token = prefs.getString("token");
    var typedServerUrl = prefs.getString("typed_url");
    var uri = Uri.parse(
        '$typedServerUrl/api/attendance/attendance/list/ot?page=$currentPage');
    var response = await http.get(uri, headers: {
      "Content-Type": "application/json",
      "Authorization": "Bearer $token",
    });
    if (response.statusCode == 200) {
      setState(() {
        requestsOvertimeValidate.addAll(
          List<Map<String, dynamic>>.from(
            jsonDecode(response.body)['results'],
          ),
        );
        overtimeValidate = jsonDecode(response.body)['count'];
      });
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> getAllNonValidatedAttendance() async {
    final prefs = await SharedPreferences.getInstance();
    var token = prefs.getString("token");
    var typedServerUrl = prefs.getString("typed_url");
    var uri = Uri.parse(
        '$typedServerUrl/api/attendance/attendance/list/non-validated?page=$currentPage');
    var response = await http.get(uri, headers: {
      "Content-Type": "application/json",
      "Authorization": "Bearer $token",
    });
    if (response.statusCode == 200) {
      setState(() {
        requestsNonValidAttendance.addAll(
          List<Map<String, dynamic>>.from(
            jsonDecode(response.body)['results'],
          ),
        );
        nonValidated = jsonDecode(response.body)['count'];
      });
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      key: _scaffoldKey,
      // appBar: AppBar(
      //   forceMaterialTransparency: true,
      //   backgroundColor: Colors.white,
      //   leading: IconButton(
      //     icon: const Icon(Icons.menu),
      //     onPressed: () {
      //       _scaffoldKey.currentState?.openDrawer();
      //     },
      //   ),
      //   title: const Text(
      //     'Attendance Overview',
      //     style: TextStyle(
      //       fontWeight: FontWeight.bold,
      //     ),
      //   ),
      // ),
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
                Appimages.appbar, // Replace with your decorative SVG
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
                      'Attendance Overview',
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
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: _isShimmerVisible
            ? _buildLoadingWidget()
            : _buildAttendanceOverview(),
      ),
      drawer: AppDrawer(permissionFuture: permissionFuture, permissionOverview: permissionOverview, permissionAttendance: permissionAttendance, permissionAttendanceRequest: permissionAttendanceRequest, permissionHourAccount: permissionHourAccount)
     /*  Drawer(
        child: FutureBuilder<void>(
          future: permissionChecks(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
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
                        child: Image.asset(
                          Appimages.splashScreenImg,
                        ),
                      ),
                    ),
                  ),
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
                            // 'Assets/horilla-logo.png',
                            ),
                      ),
                    ),
                  ),
                  permissionOverview
                      ? ListTile(
                          title: const Text('Overview'),
                          onTap: () {
                            
                            Navigator.pushReplacementNamed(
                                context, '/attendance_overview');
                          },
                        )
                      : const SizedBox.shrink(),
                  permissionAttendance
                      ? ListTile(
                          title: const Text('Attendance'),
                          onTap: () {
                            
                            Navigator.pushReplacementNamed(
                                context, '/attendance_attendance');
                          },
                        )
                      : const SizedBox.shrink(),
                  permissionAttendanceRequest
                      ? ListTile(
                          title: const Text('Attendance Request'),
                          onTap: () {
                            
                            Navigator.pushReplacementNamed(context, '/attendance_request');
                          },
                        )
                      : const SizedBox.shrink(),
                  permissionHourAccount
                      ? ListTile(
                          title: const Text('Hour Account'),
                          onTap: () {
                            
                            Navigator.pushReplacementNamed(
                                context, '/employee_hour_account');
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

  Widget _buildLoadingWidget() {
    final double screenWidth = MediaQuery.of(context).size.width;
    final double screenHeight = MediaQuery.of(context).size.height;
    final double fontSize = screenWidth * 0.04;
    final double padding = screenWidth * 0.02;

    return Padding(
      padding: EdgeInsets.all(padding),
      child: ListView(
        children: [
          Shimmer.fromColors(
            baseColor: Colors.grey[300]!,
            highlightColor: Colors.grey[100]!,
            child: SizedBox(
              height: MediaQuery.of(context).size.height * 0.15,
              child: Padding(
                padding: const EdgeInsets.all(4.0),
                child: GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 5,
                    mainAxisSpacing: 5,
                    childAspectRatio: 2,
                  ),
                  itemCount: 2,
                  itemBuilder: (context, index) {
                    String text = index == 0
                        ? '\nTODAY\'S\n ATTENDANCE\n$todayAttendance %'
                        : '\nOFFLINE\nEMPLOYEES\n$offlineEmpCount';
                    return Container(
                      padding: const EdgeInsets.all(8.0),
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        border: Border.all(color: Colors.grey[50]!),
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                      child: Center(
                        child: Text(
                          text,
                          style: TextStyle(
                            fontSize: fontSize,
                            fontWeight: FontWeight.bold,
                            color: Colors.transparent,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
          Shimmer.fromColors(
            baseColor: Colors.grey[300]!,
            highlightColor: Colors.grey[100]!,
            child: Container(
              padding: const EdgeInsets.all(8.0),
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey[50]!),
                  borderRadius: BorderRadius.circular(8.0),
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.shade400.withOpacity(0.3),
                      spreadRadius: 2,
                      blurRadius: 5,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                height: screenHeight * 0.3,
              ),
            ),
          ),
          Container(
            color: Colors.white,
            child: Column(
              children: [
                TabBar(
                  controller: _tabController,
                  indicatorColor: Colors.red,
                  labelColor: Colors.red,
                  unselectedLabelColor: Colors.grey,
                  isScrollable: true,
                  labelStyle: TextStyle(
                      fontWeight: FontWeight.bold, fontSize: fontSize * 1.2),
                  tabs: [
                    Tab(text: 'Overtime Validate ($overtimeValidate)'),
                    Tab(text: 'Non Validated ($nonValidated)'),
                  ],
                ),
                SizedBox(
                  height: screenHeight * 0.5,
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      Padding(
                        padding: EdgeInsets.all(padding),
                        child: ListView.builder(
                          itemCount: 3,
                          itemBuilder: (context, index) {
                            return Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Shimmer.fromColors(
                                baseColor: Colors.grey[300]!,
                                highlightColor: Colors.grey[100]!,
                                child: Container(
                                  padding: const EdgeInsets.all(8.0),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      border:
                                          Border.all(color: Colors.grey[50]!),
                                      borderRadius: BorderRadius.circular(8.0),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.grey.shade400
                                              .withOpacity(0.3),
                                          spreadRadius: 2,
                                          blurRadius: 5,
                                          offset: const Offset(0, 3),
                                        ),
                                      ],
                                    ),
                                    child: Card(
                                      shape: RoundedRectangleBorder(
                                        side: const BorderSide(
                                            color: Colors.white, width: 0.0),
                                        borderRadius:
                                            BorderRadius.circular(10.0),
                                      ),
                                      color: Colors.white,
                                      elevation: 0.1,
                                      child: Padding(
                                        padding: const EdgeInsets.all(8.0),
                                        child: Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            const Row(
                                              children: [
                                                SizedBox(
                                                  width: 40.0,
                                                  height: 40.0,
                                                ),
                                              ],
                                            ),
                                            SizedBox(
                                                height: MediaQuery.of(context)
                                                        .size
                                                        .height *
                                                    0.005),
                                            const SizedBox(height: 10),
                                            Container(
                                              height: 20.0,
                                            ),
                                            const SizedBox(height: 10),
                                            const SizedBox(
                                              height: 20.0,
                                              width: 80.0,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAttendanceOverview() {
    final double deviceWidth = MediaQuery.of(context).size.width;
    return Stack(
      children: [
        ListView(
          children: [
            SizedBox(
              height: 12,
            ),
            Padding(
                padding: const EdgeInsets.all(4.0),
                child: GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 5.0,
                    mainAxisSpacing: 5.0,
                    childAspectRatio: 1.5,
                  ),
                  itemCount: 2,
                  itemBuilder: (context, index) {
                    String headerText = index == 0
                        ? 'TODAY\'S\nATTENDANCE\n'
                        : 'OFFLINE\nEMPLOYEES\n';
                    String valueText =
                        index == 0 ? ' $todayAttendance' : ' $offlineEmpCount';
                    return _buildGridItem(context, headerText, valueText);
                  },
                )),
            Container(
              padding: const EdgeInsets.all(8.0),
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey[50]!),
                  borderRadius: BorderRadius.circular(8.0),
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.shade400.withOpacity(0.3),
                      spreadRadius: 2,
                      blurRadius: 5,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding:
                          EdgeInsets.symmetric(horizontal: deviceWidth * 0.04),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(
                            child: Text(
                              'Offline Employees',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: deviceWidth * 0.05,
                              ),
                            ),
                          ),
                          Padding(
                            padding: EdgeInsets.only(
                                top: MediaQuery.of(context).size.height * 0.02),
                            child: Row(
                              children: [
                                Container(
                                  constraints: const BoxConstraints(
                                    maxWidth: 30,
                                    maxHeight: 30,
                                  ),
                                  decoration: const BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.grey,
                                  ),
                                  child: Center(
                                    child: IconButton(
                                      icon: const Icon(Icons.chevron_left,
                                          color: Colors.white),
                                      onPressed: _previousPage,
                                      padding: EdgeInsets
                                          .zero, // ✅ Remove default padding
                                      iconSize: 18, // ✅ Adjust icon size to fit
                                      constraints:
                                          BoxConstraints(), // ✅ Removes extra space around IconButton
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 16.0),
                                Container(
                                  constraints: const BoxConstraints(
                                    maxWidth: 30,
                                    maxHeight: 30,
                                  ),
                                  decoration: const BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.grey,
                                  ),
                                  child: Center(
                                    child: IconButton(
                                      icon: const Icon(Icons.chevron_right,
                                          color: Colors.white),
                                      onPressed: _nextPage,
                                      padding: EdgeInsets
                                          .zero, // ✅ Remove default padding
                                      iconSize: 18, // ✅ Adjust icon size to fit
                                      constraints:
                                          BoxConstraints(), // ✅ Removes extra space around IconButton
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          )
                        ],
                      ),
                    ),
                    SizedBox(
                      height: 10,
                    ),
                    SizedBox(
                      height: MediaQuery.of(context).size.height * 0.3,
                      child: Column(
                        children: [
                          Expanded(
                            child: getCurrentPageOfflineEmployees().isEmpty
                                ?  Center(
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                      SvgPicture.asset(Appimages.emptyData),
                                        SizedBox(height: 20),
                                      const  Text(
                                          'There are no offline employees to display',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w500,
                                            fontSize: 15,
                                          ),
                                        ),
                                      ],
                                    ),
                                  )
                                : ListView.builder(
                                    itemCount:
                                        getCurrentPageOfflineEmployees().length,
                                    itemBuilder: (context, index) {
                                      final record =
                                          getCurrentPageOfflineEmployees()[
                                              index];
                                      final leaveStatus =
                                          record['leave_status'] ?? 'Unknown';
                                      return buildOfflineEmployeesTile(record,
                                          leaveStatus, baseUrl, context);
                                    },
                                  ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Column(
              children: [
                TabBar(
                  controller: _tabController,
                  labelColor: Appcolors.appBlue,
                  indicatorColor: Appcolors.appBlue,
                  indicatorWeight: 0.1,
                  indicator: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: Appcolors.appBlue,
                        width: 2.0, // super thin underline
                      ),
                    ),
                  ),
                  unselectedLabelColor: Appcolors.textColor,
                  isScrollable: true,
                  labelStyle: const TextStyle(
                      fontWeight: FontWeight.w500, fontSize: 16),
                  tabs: [
                    Tab(text: 'Overtime Validate ($overtimeValidate)'),
                    Tab(text: 'Non Validated ($nonValidated)'),
                  ],
                ),
                SizedBox(
                  height: MediaQuery.of(context).size.height * 0.5,
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      overtimeValidate == 0
                          ?  Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                SvgPicture.asset(Appimages.emptyData),
                                  SizedBox(height: 20),
                                 const Text(
                                    "There are no attendance records to display",
                                    style: TextStyle(
                                        fontSize: 15.0,
                                        color: Colors.black,
                                        fontWeight: FontWeight.w500),
                                  ),
                                ],
                              ),
                            )
                          : buildOvertimeValidate(requestsOvertimeValidate,
                              baseUrl, _scrollController),
                      nonValidated == 0
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  SvgPicture.asset(Appimages.emptyData),
                                  SizedBox(height: 20),
                                  const Text(
                                    "There are no attendance records to display",
                                    style: TextStyle(
                                        fontSize: 15.0,
                                        color: Colors.black,
                                        fontWeight: FontWeight.w500),
                                  ),
                                ],
                              ),
                            )
                          : buildNonValidatedAttendance(
                              requestsNonValidAttendance,
                              baseUrl,
                              _scrollController)
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }
}

double responsiveFontSize(
    BuildContext context, double largeFontSize, double smallFontSize) {
  double screenWidth = MediaQuery.of(context).size.width;
  if (screenWidth < 600) {
    return smallFontSize;
  } else {
    return largeFontSize;
  }
}

Widget _buildGridItem(
    BuildContext context, String headerText, String valueText) {
  return Container(
    decoration: BoxDecoration(
      color: Appcolors.cardColor,
      borderRadius: BorderRadius.circular(10.0),
    ),
    child: Padding(
      padding: const EdgeInsets.only(left: 10.0, top: 10),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            valueText,
            style: TextStyle(
              fontSize: responsiveFontSize(context, 24.0, 20.0),
              // Adjust font size for smaller screens
              fontWeight: FontWeight.w600,
              color: Colors.black,
            ),
          ),
          SizedBox(height: 7),
          Text(
            '$headerText\n',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: responsiveFontSize(context, 18.0, 14.0),
              fontWeight: FontWeight.w600,
              color: Appcolors.textColor,
            ),
          ),
        ],
      ),
    ),
  );
}

Widget buildOfflineEmployeesTile(
    record, String leaveStatus, baseUrl, BuildContext context) {
  return Padding(
    padding: const EdgeInsets.only(left: 8.0, right: 8.0),
    child: Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
          decoration: BoxDecoration(
            color: Appcolors.cardColor,
            borderRadius: const BorderRadius.all(Radius.circular(14)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Profile Avatar
              CircleAvatar(
                radius: 20.0,
                backgroundColor: Colors.white,
                child: Stack(
                  children: [
                    if (record['employee_profile'] != null &&
                        record['employee_profile'].isNotEmpty)
                      Positioned.fill(
                        child: ClipOval(
                          child: Image.network(
                            baseUrl + record['employee_profile'],
                            fit: BoxFit.cover,
                            errorBuilder: (BuildContext context,
                                Object exception, StackTrace? stackTrace) {
                              return const Icon(Icons.person);
                            },
                          ),
                        ),
                      ),
                    if (record['employee_profile'] == null ||
                        record['employee_profile'].isEmpty)
                      Positioned.fill(
                        child: Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.grey[400],
                          ),
                          child: const Icon(Icons.person),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 12),

              // Name and status
              Expanded(
                child: Text(
                  '${record['employee_first_name']} ${record['employee_last_name'] ?? ''}',
                  style: const TextStyle(
                    fontSize: 16.0,
                    color: Colors.black,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),

              // Status and email icon
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    height: 25,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.07),
                      borderRadius: BorderRadius.circular(10.0),
                    ),
                    child: Center(
                      child: Text(
                        leaveStatus.length > 7
                            ? leaveStatus.substring(0, 8)
                            : leaveStatus,
                        style: const TextStyle(
                          fontSize: 13.0,
                          color: Colors.red,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  GestureDetector(
                    onTap: () {
                      _showEmailDialog(context, record, baseUrl);
                    },
                    child: Icon(
                      Icons.email_outlined,
                      color: Colors.green[300],
                      size: 20,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
      ],
    ),
  );
}

// Widget buildOfflineEmployeesTile(
//     record, leaveStatus, baseUrl, BuildContext context) {
//   return Column(
//     children: [
//       Container(
//         decoration: BoxDecoration(
//           color: Appcolors.cardColor,
//           borderRadius: BorderRadius.all(Radius.circular(14))
//         ),
//         child: ListTile(
//           leading: CircleAvatar(
//             radius: 20.0,
//             backgroundColor: Colors.white,
//             child: Stack(
//               children: [
//                 if (record['employee_profile'] != null &&
//                     record['employee_profile'].isNotEmpty)
//                   Positioned.fill(
//                     child: ClipOval(
//                       child: Image.network(
//                         baseUrl + record['employee_profile'],
//                         fit: BoxFit.cover,
//                         errorBuilder: (BuildContext context, Object exception,
//                             StackTrace? stackTrace) {
//                           return const Icon(Icons.person);
//                         },
//                       ),
//                     ),
//                   ),
//                 if (record['employee_profile'] == null ||
//                     record['employee_profile'].isEmpty)
//                   Positioned.fill(
//                     child: Container(
//                       decoration: BoxDecoration(
//                         shape: BoxShape.circle,
//                         color: Colors.grey[400],
//                       ),
//                       child: const Icon(Icons.person),
//                     ),
//                   ),
//               ],
//             ),
//           ),
//           title: Text(
//             record['employee_first_name'] +
//                 ' ' +
//                 (record['employee_last_name'] ?? ''),
//             style: const TextStyle(
//               fontSize: 16.0,
//               color: Colors.black,
//               fontWeight: FontWeight.w500
//             ),
//           ),
//           trailing: SizedBox(
//             width: 120,
//             child: Row(
//               children: [
//                 Container(
//                   width: 80,
//                   height: 25,
//                   padding: const EdgeInsets.fromLTRB(10.0, 1.0, 10.0, 1.0),
//                   decoration: BoxDecoration(
//                     color: Colors.red.withOpacity(0.07),
//                     borderRadius: BorderRadius.circular(10.0),
//                   ),
//                   child: Center(
//                     child: Text(
//                       leaveStatus,
//                       style: const TextStyle(
//                         fontSize: 13.0,
//                         color: Colors.red,
//                       ),
//                       textAlign: TextAlign.center,
//                     ),
//                   ),
//                 ),
//                 SizedBox(width: 10,),
//                 GestureDetector(
//                   onTap: () {
//                     _showEmailDialog(context, record, baseUrl);
//                   },
//                   child: Icon(
//                     Icons.email_outlined,
//                     color: Colors.green[300],
//                     weight: 15,
//                   ),
//                 ),
//               ],
//             ),
//           ),
//         ),
//       ),
//       SizedBox(height: 10,)
//     ],
//   );
// }

void _showEmailDialog(
    BuildContext context, Map<String, dynamic> record, String baseUrl) async {
  String? selectedTemplate;
  Map<String, String> templateItems = {};
  String bodyContent = '';
  String subject = '';
  TextEditingController bodyController = TextEditingController();
  templateItems = await getTemplate();
  showDialog(
    context: context,
    builder: (BuildContext context) {
      return StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            backgroundColor: Appcolors.cardColor,
            title: Row(
              children: [
                CircleAvatar(
                  radius: 20.0,
                  backgroundColor: Colors.transparent,
                  child: ClipOval(
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: ClipOval(
                            child: Image.network(
                              baseUrl + record['employee_profile'],
                              fit: BoxFit.cover,
                              errorBuilder: (BuildContext context,
                                  Object exception, StackTrace? stackTrace) {
                                return const Icon(Icons.person,
                                    color: Colors.grey);
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 10.0),
                Expanded(
                  child: Column(
                    children: [
                      Text(
                          '${record['employee_first_name']} ${record['employee_last_name']}'),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () {
                    Navigator.of(context).pop(true);
                  },
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(height: MediaQuery.of(context).size.height * 0.03),
                    DropdownButtonFormField<String>(
                      style: const TextStyle(
                        fontWeight: FontWeight.normal,
                        color: Colors.black,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Select Template',
                        border: OutlineInputBorder(),
                      ),
                      value: selectedTemplate,
                      items: templateItems.isNotEmpty
                          ? templateItems.entries.map((entry) {
                              var value = entry.value.length > 19
                                  ? entry.value.substring(0, 19)
                                  : entry.value;
                              return DropdownMenuItem<String>(
                                value: entry.key,
                                child: Text(
                                  value,
                                  overflow: TextOverflow.visible,
                                  maxLines: 3,
                                ),
                              );
                            }).toList()
                          : [
                              const DropdownMenuItem(
                                value: null,
                                child: Text(" "),
                              )
                            ],
                      onChanged: (newValue) async {
                        setState(() {
                          selectedTemplate = newValue;
                        });

                        if (selectedTemplate != null) {
                          String fetchedBodyContent =
                              await getConvertedMailTemplate(
                            selectedTemplate!,
                            record['id'].toString(),
                          );
                          html_parser.parse(fetchedBodyContent);
                          setState(() {
                            bodyContent = fetchedBodyContent;
                            bodyController.text = bodyContent;
                          });
                        }
                      },
                    ),
                    SizedBox(height: MediaQuery.of(context).size.height * 0.03),
                    TextField(
                      decoration: const InputDecoration(
                        labelText: 'Subject',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (value) {
                        setState(() {
                          subject = value;
                        });
                      },
                    ),
                    SizedBox(height: MediaQuery.of(context).size.height * 0.03),

                    // Editable HTML field with the persistent controller
                    TextField(
                      decoration: const InputDecoration(
                        labelText: 'Edit Body Content',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: null,
                      controller: bodyController,
                      onChanged: (value) {
                        setState(() {
                          bodyContent = value;
                        });
                      },
                    ),
                    SizedBox(height: MediaQuery.of(context).size.height * 0.03),
                    Html(
                      data: bodyContent,
                    ),
                    SizedBox(height: MediaQuery.of(context).size.height * 0.03),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                child: const Text(
                  'Send',
                  style: TextStyle(color: Colors.red),
                ),
                onPressed: () async {
                  await sendEmail(
                      record['id'].toString(), subject, bodyContent);
                  Navigator.of(context).pop(); // Close the dialog
                },
              ),
            ],
          );
        },
      );
    },
  );
}

Future<String> getConvertedMailTemplate(
    String templateId, String recordId) async {
  final prefs = await SharedPreferences.getInstance();
  var token = prefs.getString("token");
  var typedServerUrl = prefs.getString("typed_url");

  var uri = Uri.parse('$typedServerUrl/api/attendance/converted-mail-template');

  var request = http.MultipartRequest('PUT', uri);

  request.headers.addAll({
    "Authorization": "Bearer $token",
  });

  request.fields['template_id'] = templateId;
  request.fields['employee_id'] = recordId;

  var streamedResponse = await request.send();

  var response = await http.Response.fromStream(streamedResponse);

  if (response.statusCode == 200) {
    var data = jsonDecode(response.body);
    return data;
  } else {
    return 'Error: ${response.statusCode}';
  }
}

Future<Map<String, String>> getTemplate() async {
  final prefs = await SharedPreferences.getInstance();
  var token = prefs.getString("token");
  var typedServerUrl = prefs.getString("typed_url");

  var uri = Uri.parse('$typedServerUrl/api/attendance/mail-templates');
  var response = await http.get(uri, headers: {
    "Content-Type": "application/json",
    "Authorization": "Bearer $token",
  });
  if (response.statusCode == 200) {
    List<Map<String, dynamic>> templateList =
        List<Map<String, dynamic>>.from(jsonDecode(response.body));

    Map<String, String> templateMap = {};

    for (var template in templateList) {
      if (template.containsKey('id') && template.containsKey('title')) {
        templateMap[template['id'].toString()] = template['title'].toString();
      } else {}
    }

    return templateMap;
  } else {
    return {};
  }
}

Future<void> sendEmail(
    String recordId, String subject, String fetchedBodyContent) async {
  final prefs = await SharedPreferences.getInstance();
  var token = prefs.getString("token");
  var typedServerUrl = prefs.getString("typed_url");

  var uri =
      Uri.parse('$typedServerUrl/api/attendance/offline-employee-mail-send');

  var request = http.MultipartRequest('POST', uri);

  request.headers['Authorization'] = 'Bearer $token';

  request.fields['employee_id'] = recordId;
  request.fields['subject'] = subject;
  request.fields['body'] = fetchedBodyContent;
  var response = await request.send();
  if (response.statusCode == 200) {
    print('Email Sent Successfully');
  } else {}
}

Widget buildOvertimeValidate(
    List<Map<String, dynamic>> requestsOvertimeValidate,
    baseUrl,
    scrollController) {
  return Padding(
    padding: const EdgeInsets.all(8.0),
    child: ListView.builder(
      controller: scrollController,
      itemCount: requestsOvertimeValidate.length,
      itemBuilder: (context, index) {
        Map<String, dynamic> record = requestsOvertimeValidate[index];
        return Column(
          children: [
            GestureDetector(
              onTap: () {
                showDialog(
                  context: context,
                  builder: (BuildContext context) {
                    return AlertDialog(
                      insetPadding: const EdgeInsets.symmetric(horizontal: 16),
                      backgroundColor: Appcolors.cardColor,
                      content: SizedBox(
                        width: MediaQuery.of(context).size.width * 0.95,
                        height: MediaQuery.of(context).size.height * 0.4,
                        child: Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: SingleChildScrollView(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Container(
                                      width: 40.0,
                                      height: 40.0,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                            color: Colors.grey, width: 1.0),
                                      ),
                                      child: Stack(
                                        children: [
                                          if (record['employee_profile_url'] !=
                                                  null &&
                                              record['employee_profile_url']
                                                  .isNotEmpty)
                                            Positioned.fill(
                                              child: ClipOval(
                                                child: Image.network(
                                                  baseUrl +
                                                      record[
                                                          'employee_profile_url'],
                                                  fit: BoxFit.cover,
                                                  errorBuilder: (BuildContext
                                                          context,
                                                      Object exception,
                                                      StackTrace? stackTrace) {
                                                    return const Icon(
                                                        Icons.person,
                                                        color: Colors.grey);
                                                  },
                                                ),
                                              ),
                                            ),
                                          if (record['employee_profile_url'] ==
                                                  null ||
                                              record['employee_profile_url']
                                                  .isEmpty)
                                            Positioned.fill(
                                              child: Container(
                                                decoration: BoxDecoration(
                                                  shape: BoxShape.circle,
                                                  color: Colors.grey[400],
                                                ),
                                                child: const Icon(Icons.person),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                    SizedBox(
                                        width:
                                            MediaQuery.of(context).size.width *
                                                0.01),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            (record['employee_first_name'] ??
                                                    '') +
                                                (record['employee_last_name'] ??
                                                    ''),
                                            style: const TextStyle(
                                                fontSize: 15.0,
                                                fontWeight: FontWeight.bold),
                                            maxLines: 2,
                                          ),
                                          Text(
                                            record['badge_id'] != null
                                                ? '(${record['badge_id']})'
                                                : '',
                                            style: const TextStyle(
                                                fontSize: 12.0,
                                                fontWeight: FontWeight.normal),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      children: [
                                        Container(
                                          decoration: BoxDecoration(
                                            color: Colors.grey[200],
                                            borderRadius:
                                                BorderRadius.circular(4.0),
                                          ),
                                        ),
                                        SizedBox(
                                            width: MediaQuery.of(context)
                                                    .size
                                                    .width *
                                                0.008),
                                        Container(
                                          decoration: BoxDecoration(
                                            color: Colors.grey[200],
                                            borderRadius:
                                                BorderRadius.circular(4.0),
                                          ),
                                        ),
                                      ],
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.close,
                                          color: Colors.grey),
                                      onPressed: () {
                                        Navigator.of(context).pop();
                                      },
                                    ),
                                  ],
                                ),
                                SizedBox(
                                    height: MediaQuery.of(context).size.height *
                                        0.03),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text(
                                      'Attendance Date',
                                      style: TextStyle(
                                        color: Colors.grey,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Text(record['attendance_date'] ?? 'None'),
                                  ],
                                ),
                                SizedBox(
                                    height: MediaQuery.of(context).size.height *
                                        0.01),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text(
                                      'Check In',
                                      style: TextStyle(
                                        color: Colors.grey,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Text(record['attendance_clock_in'] ??
                                        'None'),
                                  ],
                                ),
                                SizedBox(
                                    height: MediaQuery.of(context).size.height *
                                        0.01),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text(
                                      'Check In Date',
                                      style: TextStyle(
                                        color: Colors.grey,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Text(record['attendance_clock_in_date'] ??
                                        'None'),
                                  ],
                                ),
                                SizedBox(
                                    height: MediaQuery.of(context).size.height *
                                        0.01),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text(
                                      'Check Out ',
                                      style: TextStyle(
                                        color: Colors.grey,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Text(record['attendance_clock_out'] ??
                                        'None'),
                                  ],
                                ),
                                SizedBox(
                                    height: MediaQuery.of(context).size.height *
                                        0.01),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text(
                                      'Check Out Date',
                                      style: TextStyle(
                                        color: Colors.grey,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Text(record['attendance_clock_out_date'] ??
                                        'None'),
                                  ],
                                ),
                                SizedBox(
                                    height: MediaQuery.of(context).size.height *
                                        0.01),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text(
                                      'Shift',
                                      style: TextStyle(
                                        color: Colors.grey,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Text(record['shift_name'] ?? 'None'),
                                  ],
                                ),
                                SizedBox(
                                    height: MediaQuery.of(context).size.height *
                                        0.01),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text(
                                      'Work Type',
                                      style: TextStyle(
                                        color: Colors.grey,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Text(
                                      record['work_type'] ?? 'None',
                                      maxLines: 2,
                                    ),
                                  ],
                                ),
                                SizedBox(
                                    height: MediaQuery.of(context).size.height *
                                        0.01),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text(
                                      'At Work',
                                      style: TextStyle(
                                        color: Colors.grey,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Text(record['attendance_worked_hour'] ??
                                        'None'),
                                  ],
                                ),
                                SizedBox(
                                    height: MediaQuery.of(context).size.height *
                                        0.01),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text(
                                      'Min Hour',
                                      style: TextStyle(
                                        color: Colors.grey,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Text(record['minimum_hour'] ?? 'None'),
                                  ],
                                ),
                                SizedBox(
                                    height: MediaQuery.of(context).size.height *
                                        0.01),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
              child: Container(
                padding: const EdgeInsets.all(8.0),
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey[50]!),
                    borderRadius: BorderRadius.circular(8.0),
                    color: Appcolors.cardColor,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              width: 50.0,
                              height: 50.0,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border:
                                    Border.all(color: Colors.grey, width: 1.0),
                              ),
                              child: Stack(
                                children: [
                                  if (record['employee_profile_url'] != null &&
                                      record['employee_profile_url'].isNotEmpty)
                                    Positioned.fill(
                                      child: ClipOval(
                                        child: Image.network(
                                          baseUrl +
                                              record['employee_profile_url'],
                                          fit: BoxFit.cover,
                                          errorBuilder: (BuildContext context,
                                              Object exception,
                                              StackTrace? stackTrace) {
                                            return const Icon(Icons.person,
                                                color: Colors.grey);
                                          },
                                        ),
                                      ),
                                    ),
                                  if (record['employee_profile_url'] == null ||
                                      record['employee_profile_url'].isEmpty)
                                    Positioned.fill(
                                      child: Container(
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: Colors.grey[400],
                                        ),
                                        child: const Icon(Icons.person),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            SizedBox(
                                width:
                                    MediaQuery.of(context).size.width * 0.03),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    (record['employee_first_name'] ?? '') +
                                        (record['employee_last_name'] ?? ''),
                                    style: const TextStyle(
                                        fontSize: 15.0,
                                        fontWeight: FontWeight.bold),
                                    maxLines: 2,
                                  ),
                                  Text(
                                    record['badge_id'] != null
                                        ? '(${record['badge_id']})'
                                        : '',
                                    style: const TextStyle(
                                        fontSize: 12.0,
                                        fontWeight: FontWeight.normal),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        SizedBox(
                            height: MediaQuery.of(context).size.height * 0.01),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Date'),
                            Text(
                              '${record['attendance_date']}',
                              style: TextStyle(fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Check-In'),
                            Text(
                              '${record['attendance_clock_in_date']}',
                              style: TextStyle(fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Check-Out'),
                            Text(
                              '${record['attendance_clock_out_date']}',
                              style: TextStyle(fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                        SizedBox(
                            height: MediaQuery.of(context).size.height * 0.02),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    ),
  );
}

Widget buildNonValidatedAttendance(
    List<Map<String, dynamic>> requestsNonValidAttendance,
    baseUrl,
    scrollController) {
  return Padding(
    padding: const EdgeInsets.all(8.0),
    child: ListView.builder(
      controller: scrollController,
      itemCount: requestsNonValidAttendance.length,
      itemBuilder: (context, index) {
        Map<String, dynamic> record = requestsNonValidAttendance[index];
        return Column(
          children: [
            GestureDetector(
              onTap: () {
                showDialog(
                  context: context,
                  builder: (BuildContext context) {
                    return AlertDialog(
                      backgroundColor: Appcolors.cardColor,
                      content: SizedBox(
                        width: MediaQuery.of(context).size.width * 0.95,
                        height: MediaQuery.of(context).size.height * 0.4,
                        child: Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: SingleChildScrollView(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Container(
                                      width: 40.0,
                                      height: 40.0,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                            color: Colors.grey, width: 1.0),
                                      ),
                                      child: Stack(
                                        children: [
                                          if (record['employee_profile_url'] !=
                                                  null &&
                                              record['employee_profile_url']
                                                  .isNotEmpty)
                                            Positioned.fill(
                                              child: ClipOval(
                                                child: Image.network(
                                                  baseUrl +
                                                      record[
                                                          'employee_profile_url'],
                                                  fit: BoxFit.cover,
                                                  errorBuilder: (BuildContext
                                                          context,
                                                      Object exception,
                                                      StackTrace? stackTrace) {
                                                    return const Icon(
                                                        Icons.person,
                                                        color: Colors.grey);
                                                  },
                                                ),
                                              ),
                                            ),
                                          if (record['employee_profile_url'] ==
                                                  null ||
                                              record['employee_profile_url']
                                                  .isEmpty)
                                            Positioned.fill(
                                              child: Container(
                                                decoration: BoxDecoration(
                                                  shape: BoxShape.circle,
                                                  color: Colors.grey[400],
                                                ),
                                                child: const Icon(Icons.person),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                    SizedBox(
                                        width:
                                            MediaQuery.of(context).size.width *
                                                0.01),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            (record['employee_first_name'] ??
                                                    '') +
                                                (record['employee_last_name'] ??
                                                    ''),
                                            style: const TextStyle(
                                                fontSize: 15.0,
                                                fontWeight: FontWeight.bold),
                                            maxLines: 2,
                                          ),
                                          Text(
                                            record['badge_id'] != null
                                                ? '(${record['badge_id']})'
                                                : '',
                                            style: const TextStyle(
                                                fontSize: 12.0,
                                                fontWeight: FontWeight.normal),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      children: [
                                        Container(
                                          decoration: BoxDecoration(
                                            color: Colors.grey[200],
                                            borderRadius:
                                                BorderRadius.circular(4.0),
                                          ),
                                        ),
                                        SizedBox(
                                            width: MediaQuery.of(context)
                                                    .size
                                                    .width *
                                                0.008),
                                        Container(
                                          decoration: BoxDecoration(
                                            color: Colors.grey[200],
                                            borderRadius:
                                                BorderRadius.circular(4.0),
                                          ),
                                        ),
                                      ],
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.close,
                                          color: Colors.grey),
                                      onPressed: () {
                                        Navigator.of(context).pop();
                                      },
                                    ),
                                  ],
                                ),
                                SizedBox(
                                    height: MediaQuery.of(context).size.height *
                                        0.03),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text(
                                      'Attendance Date',
                                      style: TextStyle(
                                        color: Colors.grey,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Text(record['attendance_date'] ?? 'None'),
                                  ],
                                ),
                                SizedBox(
                                    height: MediaQuery.of(context).size.height *
                                        0.01),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text(
                                      'Check In',
                                      style: TextStyle(
                                        color: Colors.grey,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Text(record['attendance_clock_in'] ??
                                        'None'),
                                  ],
                                ),
                                SizedBox(
                                    height: MediaQuery.of(context).size.height *
                                        0.01),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text(
                                      'Check In Date',
                                      style: TextStyle(
                                        color: Colors.grey,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Text(record['attendance_clock_in_date'] ??
                                        'None'),
                                  ],
                                ),
                                SizedBox(
                                    height: MediaQuery.of(context).size.height *
                                        0.01),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text(
                                      'Check Out ',
                                      style: TextStyle(
                                        color: Colors.grey,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Text(record['attendance_clock_out'] ??
                                        'None'),
                                  ],
                                ),
                                SizedBox(
                                    height: MediaQuery.of(context).size.height *
                                        0.01),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text(
                                      'Check Out Date',
                                      style: TextStyle(
                                        color: Colors.grey,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Text(record['attendance_clock_out_date'] ??
                                        'None'),
                                  ],
                                ),
                                SizedBox(
                                    height: MediaQuery.of(context).size.height *
                                        0.01),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text(
                                      'Shift',
                                      style: TextStyle(
                                        color: Colors.grey,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Text(record['shift_name'] ?? 'None'),
                                  ],
                                ),
                                SizedBox(
                                    height: MediaQuery.of(context).size.height *
                                        0.01),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text(
                                      'Work Type',
                                      style: TextStyle(
                                        color: Colors.grey,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Text(record['work_type'] ?? 'None'),
                                  ],
                                ),
                                SizedBox(
                                    height: MediaQuery.of(context).size.height *
                                        0.01),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text(
                                      'At Work',
                                      style: TextStyle(
                                        color: Colors.grey,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Text(record['attendance_worked_hour'] ??
                                        'None'),
                                  ],
                                ),
                                SizedBox(
                                    height: MediaQuery.of(context).size.height *
                                        0.01),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text(
                                      'Min Hour',
                                      style: TextStyle(
                                        color: Colors.grey,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Text(record['minimum_hour'] ?? 'None'),
                                  ],
                                ),
                                SizedBox(
                                    height: MediaQuery.of(context).size.height *
                                        0.01),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
              child: Container(
                padding: const EdgeInsets.all(8.0),
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey[50]!),
                    borderRadius: BorderRadius.circular(8.0),
                    color: Appcolors.cardColor,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              width: 50.0,
                              height: 50.0,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border:
                                    Border.all(color: Colors.grey, width: 1.0),
                              ),
                              child: Stack(
                                children: [
                                  if (record['employee_profile_url'] != null &&
                                      record['employee_profile_url'].isNotEmpty)
                                    Positioned.fill(
                                      child: ClipOval(
                                        child: Image.network(
                                          baseUrl +
                                              record['employee_profile_url'],
                                          fit: BoxFit.cover,
                                          errorBuilder: (BuildContext context,
                                              Object exception,
                                              StackTrace? stackTrace) {
                                            return const Icon(Icons.person,
                                                color: Colors.grey);
                                          },
                                        ),
                                      ),
                                    ),
                                  if (record['employee_profile_url'] == null ||
                                      record['employee_profile_url'].isEmpty)
                                    Positioned.fill(
                                      child: Container(
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: Colors.grey[400],
                                        ),
                                        child: const Icon(Icons.person),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            SizedBox(
                                width:
                                    MediaQuery.of(context).size.width * 0.02),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    (record['employee_first_name'] ?? '') +
                                        (record['employee_last_name'] ?? ''),
                                    style: const TextStyle(
                                        fontSize: 15.0,
                                        fontWeight: FontWeight.bold),
                                    maxLines: 2,
                                  ),
                                  Text(
                                    record['badge_id'] != null
                                        ? '(${record['badge_id']})'
                                        : '',
                                    style: const TextStyle(
                                        fontSize: 12.0,
                                        fontWeight: FontWeight.normal),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        SizedBox(
                            height: MediaQuery.of(context).size.height * 0.01),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Date'),
                            Text(
                              '${record['attendance_date']}',
                              style: TextStyle(fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Check-In'),
                            Text(
                              '${record['attendance_clock_in_date']}',
                              style: TextStyle(fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Check-Out'),
                            Text(
                              '${record['attendance_clock_out_date']}',
                              style: TextStyle(fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                        SizedBox(
                            height: MediaQuery.of(context).size.height * 0.02),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    ),
  );
}
