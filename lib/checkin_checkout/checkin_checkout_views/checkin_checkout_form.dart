import 'dart:async';
import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:horilla/checkin_checkout/checkin_checkout_views/stopwatch.dart';
import 'package:horilla/common/appColors.dart';
import 'package:horilla/common/appimages.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shimmer/shimmer.dart';
import 'package:geolocator/geolocator.dart';
import 'face_detection.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;

class CheckInCheckOutFormPage extends StatefulWidget {
  const CheckInCheckOutFormPage({super.key});

  @override
  _CheckInCheckOutFormPageState createState() =>
      _CheckInCheckOutFormPageState();
}

class _CheckInCheckOutFormPageState extends State<CheckInCheckOutFormPage> {
  List<Map<String, dynamic>> attendanceList = [];
  List<Map<String, dynamic>> attendanceLists = [];
  late String swipeDirection;
  late String baseUrl = '';
  // late Timer t;
  late String requestsEmpMyFirstName = '';
  late String requestsEmpMyLastName = '';
  late String requestsEmpMyBadgeId = '';
  late String requestsEmpMyDepartment = '';
  late String requestsEmpProfile = '';
  late String requestsEmpMyWorkInfoId = '';
  late String requestsEmpMyShiftName = '';
  bool clockCheckBool = false;
  bool clockCheckedIn = false;
  bool isLoading = true;
  bool isCheckIn = false;
  bool _isProcessingDrag = false;
  String? checkInFormattedTime = '00:00';
  String elapsedTimeString = '00:00:00';
  String? checkOutFormattedTime = '00:00';
  String? checkInFormattedTimeTopR;
  String? workingTime = '00:00:00';
  String? clockIn;
  String? clockInTimes;
  String? duration;
  String? timeDisplay;
  final StopwatchManager stopwatchManager = StopwatchManager();
  int maxCount = 5;
  Map<String, dynamic> arguments = {};
  Duration elapsedTime = Duration.zero;
  Position? userLocation;
  Timer? locationCheckTimer;
  Timer? t;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();

    listenToServiceChanges();
    prefetchData();
    _loadClockState();
    getLoginEmployeeRecord();
    getBaseUrl();
    workingTime = formatDuration(stopwatchManager.elapsed);
    elapsedTimeString =
        stopwatchManager.elapsed.toString().split('.').first.padLeft(8, '0');
    t = Timer.periodic(const Duration(milliseconds: 2000), (timer) {
      if (mounted) {
        setState(() {});
      }
    });

    //startLocationWatcher();
  }

  late StreamSubscription<ServiceStatus> _serviceStatusStream;

  void listenToServiceChanges() {
    _serviceStatusStream = Geolocator.getServiceStatusStream().listen(
      (ServiceStatus status) async {
        if (!mounted) return;

        if (status == ServiceStatus.enabled) {
          // 🛡️ Step 1: Check permission
          LocationPermission permission = await Geolocator.checkPermission();

          // Step 2: Request if denied
          if (permission == LocationPermission.denied) {
            permission = await Geolocator.requestPermission();
          }

          // ❌ Step 3: Don't continue if permanently denied
          if (permission == LocationPermission.deniedForever ||
              permission == LocationPermission.denied) {
            if (mounted) {
              setState(() {
                userLocation = null;
              });
            }
            return;
          }

          // ✅ Step 4: Get current location safely
          try {
            final position = await Geolocator.getCurrentPosition(
              desiredAccuracy: LocationAccuracy.high,
            );

            if (mounted) {
              setState(() {
                userLocation = position;
              });
            }
          } catch (e) {
            // Handle errors (like timeout, etc.)
            if (mounted) {
              setState(() {
                userLocation = null;
              });
            }
          }
        } else {
          // 📍 Location was turned OFF
          if (mounted) {
            setState(() {
              userLocation = null;
            });
          }
        }
      },
    );
  }

  // void startLocationWatcher() {
  //   locationCheckTimer =
  //       Timer.periodic(const Duration(seconds: 3), (timer) async {

  //     bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
  //     if (!serviceEnabled) return;

  //     LocationPermission permission = await Geolocator.checkPermission();
  //     if (permission == LocationPermission.denied) {
  //       permission = await Geolocator.requestPermission();
  //     }

  //     if (permission == LocationPermission.deniedForever ||
  //         permission == LocationPermission.denied) return;

  //     final currentPosition = await Geolocator.getCurrentPosition(
  //       desiredAccuracy: LocationAccuracy.high,
  //     );

  //     if (mounted&& currentPosition != null) {
  //       setState(() {
  //         userLocation = currentPosition;
  //       });
  //       locationCheckTimer?.cancel(); // stop checking after getting location
  //     }
  //   });
  // }

  @override
  void didChangeDependencies() async {
    super.didChangeDependencies();
    await getCheckIn();
    if (clockIn != 'false') {
      isCheckIn = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        setState(() {
          clockCheckedIn = true;
          clockCheckBool = true;
          DateTime now = DateTime.now();
          timeDisplay = clockIn;
          checkInFormattedTimeTopR = DateFormat('h:mm').format(now);
          Duration clockInTime = Duration.zero;
          String? clockTimeString = duration;
          if (clockTimeString != null) {
            List<String> timeComponents = clockTimeString.split(':');
            int hours = int.parse(timeComponents[0]);
            int minutes = int.parse(timeComponents[1]);
            int seconds = int.parse(timeComponents[2].split('.')[0]);
            clockInTime =
                Duration(hours: hours, minutes: minutes, seconds: seconds);
          }
          stopwatchManager.startStopwatch(initialTime: clockInTime);
          _saveClockState(clockCheckedIn, 1, checkInFormattedTime.toString());
          swipeDirection = 'Swipe to Check-out';
        });
      });
    } else {
      isCheckIn = false;
      clockCheckedIn = false;
      clockCheckBool = false;
      timeDisplay = clockInTimes;
      Duration clockInTime = Duration.zero;
      String? clockTimeString = duration;
      elapsedTimeString = duration ?? '';
      if (clockTimeString != null) {
        List<String> timeComponents = clockTimeString.split(':');
        int hours = int.parse(timeComponents[0]);
        int minutes = int.parse(timeComponents[1]);
        int seconds = int.parse(timeComponents[2].split('.')[0]);
        clockInTime =
            Duration(hours: hours, minutes: minutes, seconds: seconds);
        elapsedTime = clockInTime;
      }
      swipeDirection = 'Swipe to Check-In';
    }
  }

  Future<void> getCheckIn() async {
    final prefs = await SharedPreferences.getInstance();
    var token = prefs.getString("token");
    var typedServerUrl = prefs.getString("typed_url");
    var uri = Uri.parse('$typedServerUrl/api/attendance/checking-in');
    var response = await http.get(uri, headers: {
      "Content-Type": "application/json",
      "Authorization": "Bearer $token",
    });
    if (response.statusCode == 200) {
      var responseBody = jsonDecode(response.body);
      if (responseBody['status'] == true) {
        setState(() {
          clockIn = true.toString();
          clockIn = responseBody['clock_in'];
          duration = responseBody['duration'];
        });
      } else {
        setState(() {
          clockIn = false.toString();
          clockInTimes = responseBody['clock_in_time'];
          duration = responseBody['duration'];
        });
      }
    }
  }

  void prefetchData() async {
    userLocation = await fetchCurrentLocation();
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

  _loadClockState() async {
    final prefs = await SharedPreferences.getInstance();
    final clockIn = prefs.getBool('clockCheckedIn') ?? false;
    final checkInTime = prefs.getString('checkin') ?? '00:00';
    final checkOutTime = prefs.getString('checkout') ?? '00:00';
    if (!mounted) return;
    setState(() {
      clockCheckedIn = clockIn;
      checkInFormattedTime = checkInTime;
      checkOutFormattedTime = checkOutTime;
      // clockCheckedIn = prefs.getBool('clockCheckedIn') ?? false;
      // checkInFormattedTime = prefs.getString('checkin') ?? '00:00';
      // checkOutFormattedTime = prefs.getString('checkout') ?? '00:00';
    });
  }

  _saveClockState(bool isCheckedIn, int option, [String? check]) async {
    final prefs = await SharedPreferences.getInstance();
    prefs.setBool('clockCheckedIn', isCheckedIn);
    if (check != null && option == 2) {
      prefs.setString('checkout', check);
    } else {
      prefs.setString('checkin', check!);
    }
  }

  @override
  void dispose() {
    locationCheckTimer?.cancel();
    _serviceStatusStream.cancel();
    t?.cancel();
    _isProcessing = false;
    super.dispose();
  }

  Future<void> getBaseUrl() async {
    final prefs = await SharedPreferences.getInstance();
    var typedServerUrl = prefs.getString("typed_url");
    if (!mounted) return;
    setState(() {
      baseUrl = typedServerUrl ?? '';
    });
  }

  Future<void> getLoginEmployeeRecord() async {
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
      var responseBody = jsonDecode(response.body);
      if (!mounted) return;
      setState(() {
        requestsEmpMyFirstName = responseBody['employee_first_name'] ?? '';
        requestsEmpMyLastName = responseBody['employee_last_name'] ?? '';
        requestsEmpMyBadgeId = responseBody['badge_id'] ?? '';
        requestsEmpMyDepartment = responseBody['job_position_name'] ?? '';
        requestsEmpProfile = responseBody['employee_profile'] ?? '';
        requestsEmpMyWorkInfoId = responseBody['employee_work_info_id'] ?? '';
      });
      await getLoginEmployeeWorkInfoRecord(requestsEmpMyWorkInfoId);
    }
    if (mounted) {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> getLoginEmployeeWorkInfoRecord(
      String requestsEmpMyWorkInfoId) async {
    final prefs = await SharedPreferences.getInstance();
    var token = prefs.getString("token");
    var typedServerUrl = prefs.getString("typed_url");
    var uri = Uri.parse(
        '$typedServerUrl/api/employee/employee-work-information/$requestsEmpMyWorkInfoId');
    var response = await http.get(uri, headers: {
      "Content-Type": "application/json",
      "Authorization": "Bearer $token",
    });
    if (response.statusCode == 200) {
      var responseBody = jsonDecode(response.body);
      setState(() {
        var shiftName = responseBody['shift_name'];
        requestsEmpMyShiftName = shiftName ?? "None";
        // isLoading = false;
      });
    }
  }

  Future<Position?> fetchCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return null;

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return null;
      }

      if (permission == LocationPermission.deniedForever) return null;

      return await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);
    } catch (e) {
      print('Error fetching location: $e');
      return null;
    }
  }

  Future<void> clearToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }

  String getErrorMessage(String responseBody) {
    try {
      final Map<String, dynamic> decoded = json.decode(responseBody);
      return decoded['message'] ?? 'Unknown error occurred';
    } catch (e) {
      return 'Error parsing server response';
    }
  }

  Future<void> postCheckout() async {
    final prefs = await SharedPreferences.getInstance();
    var token = prefs.getString("token");
    var typedServerUrl = prefs.getString("typed_url");
    var uri = Uri.parse('$typedServerUrl/api/attendance/clock-out/');
    var response = await http.post(uri, headers: {
      "Content-Type": "application/json",
      "Authorization": "Bearer $token",
    });
    if (response.statusCode == 200) {
      setState(() {});
    }
  }

  Future<void> postCheckIn() async {
    final prefs = await SharedPreferences.getInstance();
    var token = prefs.getString("token");
    var typedServerUrl = prefs.getString("typed_url");
    var uri = Uri.parse('$typedServerUrl/api/attendance/clock-in/');
    var response = await http.post(uri, headers: {
      "Content-Type": "application/json",
      "Authorization": "Bearer $token",
    });
    if (response.statusCode == 200) {
      setState(() {});
    }
  }

  void showCheckInFailedDialog(BuildContext context, String errorMessage) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Check-in Failed'),
          content: Text(errorMessage),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pop(context);
                // Navigator.of(context).pop(); // Close the dialog
              },
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Your full screen (AppBar + body) below the image
        Scaffold(
          backgroundColor: Colors.transparent,
          extendBodyBehindAppBar: true,
          appBar: AppBar(
            automaticallyImplyLeading: false,
            backgroundColor: Appcolors.appBlue,
            elevation: 0,
          ),
          body:
              isLoading ? _buildLoadingWidget() : _buildCheckInCheckoutWidget(),
        ),

        Positioned(
          top: 0,
          left: 0,
          child: Image.asset(
            Appimages.appbar,
            width: 226, // ✅ correct usage
            height: 135, // optional
            fit: BoxFit.contain, // optional
          ),
        ),
      ],
    );

    // return Scaffold(
    //   backgroundColor: Colors.white,
    //   appBar: AppBar(
    //     automaticallyImplyLeading: false,
    //     backgroundColor: Appcolors.appBlue,

    //   ),
    //   body: isLoading ? _buildLoadingWidget() : _buildCheckInCheckoutWidget(),
    // );
  }

  void storeCheckoutTime() {
    elapsedTime = stopwatchManager.elapsed;
    elapsedTimeString = elapsedTime.toString().split('.').first.padLeft(8, '0');
  }

  Widget _buildLoadingWidget() {
    checkInFormattedTime = timeDisplay ?? "00.00";
    return ListView(
      children: [
        if (clockCheckBool || clockCheckedIn)
          Container(
            decoration: const BoxDecoration(
                color: Appcolors.appBlue,
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(15),
                  bottomRight: Radius.circular(15),
                )),
            // color: Appcolors.appBlue,
            height: MediaQuery.of(context).size.height * 0.20,
            child: Padding(
              padding:
                  const EdgeInsets.only(left: 16.0, right: 16.0, bottom: 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Clock In',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 20)),
                      Text('00:00:00', style: TextStyle(color: Colors.white)),
                    ],
                  ),
                  SizedBox(height: MediaQuery.of(context).size.height * 0.05),
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Row(
                        spacing: 3,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Image.asset(
                            Appimages.alaram,
                            width: 32,
                          ),
                          StreamBuilder<int>(
                            stream: Stream.periodic(
                                const Duration(milliseconds: 1), (_) {
                              return stopwatchManager.elapsed.inMilliseconds;
                            }),
                            builder: (context, snapshot) {
                              return Text(
                                '${Duration(milliseconds: snapshot.data ?? 0)}'
                                    .substring(0, 7),
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 25),
                              );
                            },
                          ),
                        ],
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text('Clocked In: Today at ',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15)),
                          Text(
                            checkInFormattedTime ??
                                DateFormat('h:mm').format(DateTime.now()) +
                                    (DateTime.now().hour < 12 ? ' AM' : ' PM'),
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 15),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          )
        else
          Container(
            decoration: const BoxDecoration(
                color: Appcolors.appBlue,
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(15),
                  bottomRight: Radius.circular(15),
                )),
            //color: Appcolors.appBlue,
            height: MediaQuery.of(context).size.height * 0.20,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Clock Out',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 20)),
                      Text(elapsedTimeString,
                          style: const TextStyle(color: Colors.white)),
                    ],
                  ),
                  SizedBox(height: MediaQuery.of(context).size.height * 0.05),
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Row(
                        spacing: 3,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Image.asset(
                            Appimages.alaram,
                            width: 32,
                          ),
                          Text(
                            elapsedTimeString,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 25),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        SizedBox(height: MediaQuery.of(context).size.height * 0.02),
        // Shimmer loading placeholder remains unchanged
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20.0),
          child: Shimmer.fromColors(
            baseColor: Colors.grey[300]!,
            highlightColor: Colors.grey[100]!,
            child: ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: 1,
              itemBuilder: (context, index) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: Colors.grey[50]!),
                      borderRadius: BorderRadius.circular(8.0),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.shade400.withOpacity(0.3),
                          spreadRadius: 2,
                          blurRadius: 5,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                  width: 90.0,
                                  height: 90.0,
                                  decoration: BoxDecoration(
                                      color: Colors.grey[300],
                                      shape: BoxShape.circle)),
                              const SizedBox(width: 10.0),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                        height: 20.0, color: Colors.grey[300]),
                                    const SizedBox(height: 5.0),
                                    Container(
                                        height: 120.0,
                                        width: 90.0,
                                        color: Colors.grey[300]),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 5.0),
                          Container(
                              height: 16.0,
                              width: double.infinity,
                              color: Colors.grey[300]),
                          const SizedBox(height: 5.0),
                          Container(
                              height: 16.0,
                              width: double.infinity,
                              color: Colors.grey[300]),
                          const SizedBox(height: 5.0),
                          Container(
                              height: 16.0,
                              width: double.infinity,
                              color: Colors.grey[300]),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        // GestureDetector(
        //   onHorizontalDragUpdate: (details) {
        //     if (details.primaryDelta! < 0) {
        //       setState(() {
        //         clockCheckedIn = true;
        //         swipeDirection = 'Swipe to Check-In';
        //       });
        //     } else if (details.primaryDelta! > 0) {
        //       setState(() {
        //         clockCheckedIn = true;
        //         swipeDirection = 'Swipe to Check-out';
        //       });
        //     }
        //   },
        //   child: Padding(
        //     padding: const EdgeInsets.only(
        //         left: 16.0, right: 16.0, top: 0.0, bottom: 8.0),
        //     child: Shimmer.fromColors(
        //       baseColor: Colors.grey[300]!,
        //       highlightColor: Colors.grey[100]!,
        //       child: Container(
        //         width: MediaQuery.of(context).size.width * 0.95,
        //         height: MediaQuery.of(context).size.height * 0.07,
        //         decoration: BoxDecoration(
        //             borderRadius: BorderRadius.circular(15.0),
        //             color: Colors.grey),
        //       ),
        //     ),
        //   ),
        // ),
      ],
    );
  }

  Widget _buildCheckInCheckoutWidget() {
    checkInFormattedTime = timeDisplay ?? "00.00";
    return ListView(
      children: [
        if (clockCheckBool || clockCheckedIn)
          Container(
            decoration: const BoxDecoration(
                color: Appcolors.appBlue,
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(15),
                  bottomRight: Radius.circular(15),
                )),
            height: MediaQuery.of(context).size.height * 0.20,
            child: Padding(
              padding:
                  const EdgeInsets.only(left: 16.0, right: 16.0, bottom: 16.0),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Clock In',
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 20)),
                        Text('00:00:00', style: TextStyle(color: Colors.white)),
                      ],
                    ),
                    SizedBox(height: MediaQuery.of(context).size.height * 0.05),
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Row(
                          spacing: 3,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Image.asset(
                              Appimages.alaram,
                              width: 32,
                            ),
                            // IconButton(
                            //   onPressed: () {},
                            //   icon: const Icon(Icons.access_alarm),
                            //   color: Colors.white,
                            //   iconSize: 40,
                            // ),
                            StreamBuilder<int>(
                              stream: Stream.periodic(
                                  const Duration(milliseconds: 1), (_) {
                                return stopwatchManager.elapsed.inMilliseconds;
                              }),
                              builder: (context, snapshot) {
                                if (snapshot.hasData) {
                                  int milliseconds = snapshot.data!;
                                  Duration duration =
                                      Duration(milliseconds: milliseconds);
                                  String formattedTime =
                                      '${duration.inHours.toString().padLeft(2, '0')}:${(duration.inMinutes % 60).toString().padLeft(2, '0')}:${(duration.inSeconds % 60).toString().padLeft(2, '0')}';
                                  return Text(
                                    formattedTime,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 25),
                                  );
                                }
                                return const Text('00:00:00',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 25));
                              },
                            ),
                          ],
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text('Clocked In: Today at ',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15)),
                            Text(
                              checkInFormattedTime ??
                                  DateFormat('h:mm').format(DateTime.now()) +
                                      (DateTime.now().hour < 12
                                          ? ' AM'
                                          : ' PM'),
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          )
        else
          Container(
            decoration: const BoxDecoration(
                color: Appcolors.appBlue,
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(15),
                  bottomRight: Radius.circular(15),
                )),
            //color: Appcolors.appBlue,
            height: MediaQuery.of(context).size.height * 0.20,
            child: Padding(
              padding:
                  const EdgeInsets.only(left: 16.0, right: 16.0, bottom: 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Clock Out',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 20)),
                      Text(elapsedTimeString,
                          style: const TextStyle(color: Colors.white)),
                    ],
                  ),
                  SizedBox(height: MediaQuery.of(context).size.height * 0.05),
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Row(
                        spacing: 3,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Image.asset(
                            Appimages.alaram,
                            width: 32,
                          ),
                          // IconButton(
                          //   onPressed: () {},
                          //   icon: const Icon(Icons.access_alarm),
                          //   color: Colors.white,
                          //   iconSize: 40,
                          // ),
                          Text(
                            elapsedTimeString,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 25),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        SizedBox(height: MediaQuery.of(context).size.height * 0.02),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8.0),
              color: Appcolors.cardColor,
              border: Border.all(color: Colors.grey.shade300, width: 0.0),
              // boxShadow: [
              //   BoxShadow(
              //       color: Colors.grey.shade50.withOpacity(0.3),
              //       spreadRadius: 7,
              //       blurRadius: 1,
              //       offset: const Offset(0, 1)),
              // ],
            ),
            width: MediaQuery.of(context).size.width * 0.50,
            height: MediaQuery.of(context).size.height * 0.3,
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        width: 40.0,
                        height: 40.0,
                        decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border:
                                Border.all(color: Colors.grey, width: 1.0)),
                        child: Stack(
                          children: [
                            if (requestsEmpProfile.isNotEmpty)
                              Positioned.fill(
                                child: ClipOval(
                                  child: Image.network(
                                    baseUrl + requestsEmpProfile,
                                    fit: BoxFit.cover,
                                    errorBuilder:
                                        (context, exception, stackTrace) =>
                                            const Icon(Icons.person,
                                                color: Colors.grey),
                                  ),
                                ),
                              ),
                            if (requestsEmpProfile.isEmpty)
                              Positioned.fill(
                                child: Container(
                                  decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: Colors.grey[400]),
                                  child: const Icon(Icons.person),
                                ),
                              ),
                          ],
                        ),
                      ),
                      SizedBox(
                          width: MediaQuery.of(context).size.width * 0.01),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '$requestsEmpMyFirstName $requestsEmpMyLastName',
                              style: const TextStyle(
                                  fontSize: 16.0,
                                  fontWeight: FontWeight.bold),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(requestsEmpMyBadgeId,
                                style: const TextStyle(
                                    fontSize: 12.0,
                                    fontWeight: FontWeight.normal)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  SizedBox(
                      height: MediaQuery.of(context).size.height * 0.005),
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Department'),
                        Text(requestsEmpMyDepartment),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Check-In'),
                        Text('$checkInFormattedTime'),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Shift'),
                        Text(requestsEmpMyShiftName),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onPanUpdate: (details) async {
                      if (!_isProcessingDrag) {
                        final prefs = await SharedPreferences.getInstance();
                        var face_detection = prefs.getBool("face_detection");
                        var geo_fencing = prefs.getBool("geo_fencing");
                        if (face_detection == true) {
                          if (details.delta.dx.abs() >
                                  details.delta.dy.abs() &&
                              details.delta.dx.abs() > 10) {
                            _isProcessingDrag = true;
                            if (userLocation == null) {
                              if (_isProcessing) {
                                _isProcessingDrag = false;
                                return;
                              }
                              _isProcessing = true;
                              ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content: Text(
                                          'Location unavailable. Cannot proceed.')));
                              _isProcessingDrag = false;
                              return;
                            }
                            _isProcessing = false;
                            if (details.delta.dx < 0 && clockCheckedIn) {
                              // Check-out
                              final result = await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => FaceScanner(
                                    userLocation: userLocation,
                                    userDetails: arguments,
                                    attendanceState: 'CHECKED_IN',
                                  ),
                                ),
                              );
                              if (result != null &&
                                  result['checkedOut'] == true) {
                                setState(() {
                                  isCheckIn = false;
                                  clockCheckedIn = false;
                                  stopwatchManager.stopStopwatch();
                                  storeCheckoutTime();
                                  Duration initialElapsedTime =
                                      stopwatchManager.elapsed;
                                  workingTime =
                                      formatDuration(initialElapsedTime);
                                  clockCheckBool = false;
                                  DateTime now = DateTime.now();
                                  checkOutFormattedTime =
                                      DateFormat('h:mm a').format(now);
                                  swipeDirection = 'Swipe to Check-In';
                                  _saveClockState(clockCheckedIn, 2,
                                      checkOutFormattedTime.toString());
                                });
                              }
                            } else if (details.delta.dx > 0 &&
                                !clockCheckedIn) {
                              // Check-in
                              final result = await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => FaceScanner(
                                    userLocation: userLocation,
                                    userDetails: arguments,
                                    attendanceState: 'NOT_CHECKED_IN',
                                  ),
                                ),
                              );
                              if (result != null &&
                                  result['checkedIn'] == true) {
                                setState(() {
                                  isCheckIn = true;
                                  clockCheckedIn = true;
                                  clockCheckBool = true;
                                  DateTime now = DateTime.now();
                                  checkInFormattedTime =
                                      DateFormat('h:mm a').format(now);
                                  checkInFormattedTimeTopR =
                                      DateFormat('h:mm').format(now);
                                  _saveClockState(clockCheckedIn, 1,
                                      checkInFormattedTime.toString());
            
                                  if (duration?.isNotEmpty ?? false) {
                                    String durationString =
                                        duration.toString();
            
                                    try {
                                      List<String> parts =
                                          durationString.split(':');
                                      if (parts.length == 3) {
                                        int hours = int.parse(parts[0]);
                                        int minutes = int.parse(parts[1]);
                                        int seconds = int.parse(parts[2]);
                                        Duration initialElapsedTime =
                                            Duration(
                                                hours: hours,
                                                minutes: minutes,
                                                seconds: seconds);
                                        stopwatchManager.startStopwatch(
                                            initialTime: initialElapsedTime);
                                      }
                                    } catch (e) {}
                                  } else {}
            
                                  swipeDirection = 'Swipe to Check-out';
                                });
                              }
                            }
                          }
                        } else if (geo_fencing == true) {
                          if (details.delta.dx.abs() >
                                  details.delta.dy.abs() &&
                              details.delta.dx.abs() > 10) {
                            _isProcessingDrag = true;
                            if (userLocation == null) {
                              ScaffoldMessenger.of(context)
                                ..clearSnackBars()
                                ..showSnackBar(const SnackBar(
                                    content: Text(
                                        'Location unavailable. Cannot proceed.')));
                              _isProcessingDrag = false;
                              return;
                            }
            
                            if (details.delta.dx < 0 && clockCheckedIn) {
                              final prefs =
                                  await SharedPreferences.getInstance();
                              var token = prefs.getString("token");
                              var typedServerUrl =
                                  prefs.getString("typed_url");
                              var geo_fencing = prefs.getBool("geo_fencing");
                              var uri = Uri.parse(
                                  '$typedServerUrl/api/attendance/clock-out/');
                              var response_geofence = await http.post(
                                uri,
                                headers: {
                                  "Content-Type": "application/json",
                                  "Authorization": "Bearer $token",
                                },
                                body: jsonEncode({
                                  "latitude": userLocation!.latitude,
                                  "longitude": userLocation!.longitude,
                                }),
                              );
            
                              if (response_geofence.statusCode == 200) {
                              } else {
                                String errorMessage =
                                    getErrorMessage(response_geofence.body);
                                showCheckInFailedDialog(
                                    context, errorMessage);
                              }
                              // Check-out
                              setState(() {
                                isCheckIn = false;
                                clockCheckedIn = false;
                                stopwatchManager.stopStopwatch();
                                storeCheckoutTime();
                                clockCheckBool = false;
                                DateTime now = DateTime.now();
                                checkOutFormattedTime =
                                    DateFormat('h:mm a').format(now);
                                swipeDirection = 'Swipe to Check-In';
                                _saveClockState(clockCheckedIn, 2,
                                    checkOutFormattedTime.toString());
                              });
                            } else if (details.delta.dx > 0 &&
                                !clockCheckedIn) {
                              final prefs =
                                  await SharedPreferences.getInstance();
                              var token = prefs.getString("token");
                              var typedServerUrl =
                                  prefs.getString("typed_url");
                              var geo_fencing = prefs.getBool("geo_fencing");
                              var uri = Uri.parse(
                                  '$typedServerUrl/api/attendance/clock-in/');
                              var response_geofence = await http.post(
                                uri,
                                headers: {
                                  "Content-Type": "application/json",
                                  "Authorization": "Bearer $token",
                                },
                                body: jsonEncode({
                                  "latitude": userLocation!.latitude,
                                  "longitude": userLocation!.longitude,
                                }),
                              );
            
                              if (response_geofence.statusCode == 200) {
                              } else {
                                String errorMessage =
                                    getErrorMessage(response_geofence.body);
                                showCheckInFailedDialog(
                                    context, errorMessage);
                              }
                              // Check-in
                              setState(() {
                                isCheckIn = true;
                                clockCheckedIn = true;
                                clockCheckBool = true;
                                DateTime now = DateTime.now();
                                checkInFormattedTime =
                                    DateFormat('h:mm a').format(now);
                                checkInFormattedTimeTopR =
                                    DateFormat('h:mm').format(now);
                                _saveClockState(clockCheckedIn, 1,
                                    checkInFormattedTime.toString());
            
                                if (duration?.isNotEmpty ?? false) {
                                  String durationString = duration.toString();
            
                                  try {
                                    List<String> parts =
                                        durationString.split(':');
                                    if (parts.length == 3) {
                                      int hours = int.parse(parts[0]);
                                      int minutes = int.parse(parts[1]);
                                      int seconds = int.parse(parts[2]);
                                      Duration initialElapsedTime = Duration(
                                          hours: hours,
                                          minutes: minutes,
                                          seconds: seconds);
                                      stopwatchManager.startStopwatch(
                                          initialTime: initialElapsedTime);
                                    }
                                  } catch (e) {}
                                } else {}
            
                                swipeDirection = 'Swipe to Check-out';
                              });
                            }
                          }
                        } else {
                          if (details.delta.dx.abs() >
                                  details.delta.dy.abs() &&
                              details.delta.dx.abs() > 10) {
                            _isProcessingDrag = true;
                            if (details.delta.dx < 0) {
                              setState(() {
                                postCheckout();
                                isCheckIn = false;
                                clockCheckedIn = false;
                                stopwatchManager.stopStopwatch();
                                storeCheckoutTime();
                                Duration initialElapsedTime =
                                    stopwatchManager.elapsed;
                                workingTime =
                                    formatDuration(initialElapsedTime);
                                clockCheckBool = false;
                                DateTime now = DateTime.now();
                                checkOutFormattedTime =
                                    DateFormat('h:mm a').format(now);
                                swipeDirection = 'Swipe to Check-In';
                                _saveClockState(clockCheckedIn, 2,
                                    checkOutFormattedTime.toString());
                              });
                            } else if (details.delta.dx > 0) {
                              setState(() {
                                postCheckIn();
                                isCheckIn = true;
                                clockCheckedIn = true;
                                clockCheckBool = true;
                                DateTime now = DateTime.now();
                                checkInFormattedTime =
                                    DateFormat('h:mm a').format(now);
                                checkInFormattedTimeTopR =
                                    DateFormat('h:mm').format(now);
                                _saveClockState(clockCheckedIn, 1,
                                    checkInFormattedTime.toString());
            
                                if (duration?.isNotEmpty ?? false) {
                                  String durationString = duration.toString();
            
                                  try {
                                    List<String> parts =
                                        durationString.split(':');
                                    if (parts.length == 3) {
                                      int hours = int.parse(parts[0]);
                                      int minutes = int.parse(parts[1]);
                                      int seconds = int.parse(parts[2]);
                                      Duration initialElapsedTime = Duration(
                                          hours: hours,
                                          minutes: minutes,
                                          seconds: seconds);
                                      stopwatchManager.startStopwatch(
                                          initialTime: initialElapsedTime);
                                    }
                                  } catch (e) {}
                                } else {}
            
                                swipeDirection = 'Swipe to Check-out';
                              });
                            }
                          }
                        }
                      }
                    },
                    onPanEnd: (details) {
                      _isProcessingDrag = false;
                    },
                    child: Container(
                      width: MediaQuery.of(context).size.width * 0.95,
                      height: MediaQuery.of(context).size.height *
                          0.05, // ✅ Fixed height
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8.0),
                        color: clockCheckedIn ? Colors.red : Colors.green,
                      ),
                      alignment: Alignment.center,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          if (swipeDirection == 'Swipe to Check-In' ||
                              !clockCheckedIn)
                            Padding(
                              padding: const EdgeInsets.all(4.0),
                              child: Container(
                                width: MediaQuery.of(context).size.width *
                                    0.09, // smaller
                                height: 30,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(6.0),
                                  color: Colors.white,
                                ),
                                child: Icon(Icons.arrow_forward,
                                    color: Colors.green,
                                    size: MediaQuery.of(context).size.width *
                                        0.066), // smaller
                              ),
                            ),
                          Expanded(
                            child: Center(
                              child: Text(
                                swipeDirection,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize:
                                      MediaQuery.of(context).size.width *
                                          0.035, // smaller
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                          if (swipeDirection == 'Swipe to Check-out' ||
                              clockCheckedIn)
                            Padding(
                              padding: const EdgeInsets.all(4.0),
                              child: Container(
                                width:
                                    MediaQuery.of(context).size.width * 0.09,
                                height: 30,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(6.0),
                                  color: Colors.white,
                                ),
                                child: Icon(Icons.arrow_back,
                                    color: Colors.red,
                                    size: MediaQuery.of(context).size.width *
                                        0.066),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        SizedBox(height: MediaQuery.of(context).size.height * 0.02),
      ],
    );
  }

  String formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    return "${twoDigits(duration.inHours)}:$twoDigitMinutes:$twoDigitSeconds";
  }
}

class Home extends StatelessWidget {
  const Home({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance
        .addPostFrameCallback((_) => Navigator.pushNamed(context, '/home'));
    return Container(
        color: Colors.white, child: const Center(child: Text('Page 1')));
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
    WidgetsBinding.instance
        .addPostFrameCallback((_) => Navigator.pushNamed(context, '/user'));
    return Container(
        color: Colors.white, child: const Center(child: Text('Page 1')));
  }
}
