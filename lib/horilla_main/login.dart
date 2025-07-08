import 'dart:async';
import 'dart:convert';
import 'dart:developer';
// import 'package:connectivity/connectivity.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:flutter_svg/svg.dart';
import 'package:horilla/common/appColors.dart';
import 'package:horilla/common/appimages.dart';
import 'package:horilla/main.dart';
import 'package:http/http.dart' as http;
import 'package:internet_connection_checker/internet_connection_checker.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  late StreamSubscription subscription;
  var isDeviceConnected = false;
  bool isAlertSet = false;
  bool _passwordVisible = false;
  final TextEditingController serverController = TextEditingController();
  final TextEditingController usernameController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  double horizontalMargin = 0.0;

  @override
  void initState() {
    super.initState();
    getConnectivity();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      double screenWidth = MediaQuery.of(context).size.width;
      double horizontalMarginPercentage = 0.1;
      setState(() {
        horizontalMargin = screenWidth * horizontalMarginPercentage;
      });
      FlutterNativeSplash.remove();
    });
  }

  /// Logs in the user by sending a POST request to the server.
  Future<void> _login() async {
    String serverAddress = serverController.text.trim();
    String username = usernameController.text.trim();
    String password = passwordController.text.trim();
    String url = '$serverAddress/api/auth/login/';
    try {
      http.Response response = await http.post(
        Uri.parse(url),
        body: {'username': username, 'password': password},
      );

      if (response.statusCode == 200) {
        log(jsonEncode(response.body));
        var token = jsonDecode(response.body)['access'];
        var employeeId = jsonDecode(response.body)['employee']['id'];
        var companyId = jsonDecode(response.body)['company_id'];
        bool face_detection = jsonDecode(response.body)['face_detection'];
        bool geo_fencing = jsonDecode(response.body)['geo_fencing'];
        var face_detection_image =
            jsonDecode(response.body)['face_detection_image'].toString();
        var fullName =
            jsonDecode(response.body)['employee']['full_name'].toString();
        final prefs = await SharedPreferences.getInstance();
        prefs.setString("token", token);
        prefs.setString("typed_url", serverAddress);
        prefs.setString("face_detection_image", face_detection_image);
        prefs.setBool("face_detection", face_detection);
        prefs.setBool("geo_fencing", geo_fencing);
        prefs.setInt("employee_id", employeeId);
        prefs.setInt("company_id", companyId);
        prefs.setString("userName", fullName);
        //Navigator.pushReplacementNamed(context, '/home');
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => DashboardScreen()),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Invalid email or password'),
            backgroundColor: Appcolors.appBlue,
          ),
        );
      }
    } catch (e) {
      print(e);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Invalid server address'),
          backgroundColor: Appcolors.appBlue,
        ),
      );
    }
  }

  /// Listens for changes in connectivity status and shows an alert if no connection is found.
  void getConnectivity() {
    // subscription = Connectivity().onConnectivityChanged.listen(
    //   (ConnectivityResult result) async {
    //     isDeviceConnected = await InternetConnectionChecker().hasConnection;
    //     if (!isDeviceConnected && !isAlertSet) {
    //       showSnackBar();
    //       setState(() => isAlertSet = true);
    //     }
    //   },
    // );
  }

  @override
  Widget build(BuildContext context) {
    final String? serverAddress =
        ModalRoute.of(context)?.settings.arguments as String?;

    if (serverAddress != null && serverController.text.isEmpty) {
      serverController.text = serverAddress;
    }

    return WillPopScope(
      onWillPop: () async {
        SystemNavigator.pop();
        return false;
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        resizeToAvoidBottomInset: true,
        body: SingleChildScrollView(
            physics: ClampingScrollPhysics(),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: MediaQuery.of(context).size.width * 0.05,
                vertical: MediaQuery.of(context).size.height * 0.05,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SizedBox(height: MediaQuery.of(context).size.height * 0.09),
                  SvgPicture.asset(
                    Appimages.loginLogo,
                   
                  ),

                  SizedBox(height: MediaQuery.of(context).size.height * 0.03),

                  Container(
                    padding: const EdgeInsets.all(10.0),
                    child: Column(
                      children: <Widget>[
                        const Align(
                          alignment: Alignment.topLeft,
                          child: Text(
                            'Login',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 26,
                            ),
                          ),
                        ),
                        SizedBox(
                            height: MediaQuery.of(context).size.height * 0.02),
                        _buildTextFormField(
                          'Server Address',
                          serverController,
                          false,
                        ),
                        SizedBox(
                            height: MediaQuery.of(context).size.height * 0.02),
                        _buildTextFormField(
                          'Email',
                          usernameController,
                          false,
                        ),
                        SizedBox(
                            height: MediaQuery.of(context).size.height * 0.02),
                        _buildTextFormField(
                          'Password',
                          passwordController,
                          true,
                          _passwordVisible,
                          () {
                            setState(() {
                              _passwordVisible = !_passwordVisible;
                            });
                          },
                        ),
                        SizedBox(
                            height: MediaQuery.of(context).size.height * 0.04),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _login,
                            style: ElevatedButton.styleFrom(
                              foregroundColor: Colors.white,
                              backgroundColor: Appcolors.appBlue,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12.0),
                              ),
                            ),
                            child: const Padding(
                              padding: EdgeInsets.symmetric(vertical: 10.0),
                              child: Text(
                                'Sign In',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  SizedBox(height: MediaQuery.of(context).size.height * 0.03),
                ],
              ),
            ),
          )

      ),
    );
  }

  Widget _buildTextFormField(
    String label,
    TextEditingController controller,
    bool isPassword, [
    bool? passwordVisible,
    VoidCallback? togglePasswordVisibility,
  ]) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.w500
            ,
            fontSize: 16,
            color: Colors.grey[600],
          ),
        ),
        SizedBox(height: MediaQuery.of(context).size.height * 0.005),
        TextFormField(
          controller: controller,
          obscureText: isPassword ? !(passwordVisible ?? false) : false,
          decoration: InputDecoration(
             hintText: 'Enter $label',
               hintStyle: TextStyle(
              color: Appcolors.textColor, // ✅ Change this to your desired hint color
            ),
            border: OutlineInputBorder(
              borderSide: const BorderSide(width: 1,color: Appcolors.textColor),
              
              borderRadius: BorderRadius.circular(6.0),
            ),
             enabledBorder: OutlineInputBorder(
              borderSide: BorderSide(
                color: Appcolors.textColor, // ✅ Normal border color
                width: 1.0,
              ),
              borderRadius: BorderRadius.circular(6.0),
            ),
             focusedBorder: OutlineInputBorder(
              borderSide: BorderSide(
                color: Appcolors.textColor, // ✅ Border color when focused
                width: 1.5,
              ),
              borderRadius: BorderRadius.circular(6.0),
            ),
            contentPadding: EdgeInsets.symmetric(
              vertical: MediaQuery.of(context).size.height * 0.015,
              horizontal: controller.text.isNotEmpty ? 16.0 : 12.0,
            ),
            suffixIcon: isPassword
                ? IconButton(
                    icon: Icon(
                      passwordVisible!
                          ? Icons.visibility
                          : Icons.visibility_off,
                      color: Colors.grey,
                    ),
                    onPressed: togglePasswordVisibility,
                  )
                : null,
          ),
        ),
      ],
    );
  }

  void showSnackBar() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: Appcolors.appBlue,
        content: const Text('Please check your internet connectivity',
            style: TextStyle(color: Colors.white)),
        action: SnackBarAction(
          backgroundColor: Appcolors.appBlue,
          label: 'close',
          textColor: Colors.white,
          onPressed: () async {
            setState(() => isAlertSet = false);
            isDeviceConnected = await InternetConnectionChecker().hasConnection;
            if (!isDeviceConnected && !isAlertSet) {
              showSnackBar();
              setState(() => isAlertSet = true);
            }
          },
        ),
        duration: const Duration(hours: 1),
      ),
    );
  }
}




// import 'dart:async';
// import 'dart:convert';
// // import 'package:connectivity/connectivity.dart';
// import 'package:flutter/material.dart';
// import 'package:flutter/services.dart';
// import 'package:http/http.dart' as http;
// import 'package:internet_connection_checker/internet_connection_checker.dart';
// import 'package:shared_preferences/shared_preferences.dart';
//
// class LoginPage extends StatefulWidget {
//   const LoginPage({super.key});
//
//   @override
//   _LoginPageState createState() => _LoginPageState();
// }
//
// class _LoginPageState extends State<LoginPage> {
//   late StreamSubscription subscription;
//   var isDeviceConnected = false;
//   bool isAlertSet = false;
//   bool _passwordVisible = false;
//   TextEditingController serverController =
//   TextEditingController();
//   TextEditingController usernameController =
//   TextEditingController();
//   TextEditingController passwordController =
//   TextEditingController();
//   double horizontalMargin = 0.0;
//
//   @override
//   void initState() {
//     super.initState();
//     // getConnectivity();
//
//     WidgetsBinding.instance.addPostFrameCallback((_) {
//       double screenWidth = MediaQuery.of(context).size.width;
//       double horizontalMarginPercentage = 0.1;
//       setState(() {
//         horizontalMargin = screenWidth * horizontalMarginPercentage;
//       });
//     });
//   }
//
//   Future<void> _login() async {
//     String serverAddress = serverController.text.trim();
//     String username = usernameController.text.trim();
//     String password = passwordController.text.trim();
//     String url = '$serverAddress/api/auth/login/';
//     try {
//       http.Response response = await http.post(
//         Uri.parse(url),
//         body: {'username': username, 'password': password},
//       );
//
//       if (response.statusCode == 200) {
//         var token = jsonDecode(response.body)['access'];
//         var employeeId = jsonDecode(response.body)['employee']['id'];
//         final prefs = await SharedPreferences.getInstance();
//         prefs.setString("token", token);
//         prefs.setString("typed_url", serverAddress);
//         prefs.setInt("employee_id", employeeId);
//         Navigator.pushReplacementNamed(context, '/home');
//       } else {
//         ScaffoldMessenger.of(context).showSnackBar(
//           const SnackBar(
//             content: Text('Invalid email or password'),
//             backgroundColor: Colors.red,
//           ),
//         );
//       }
//     } catch (e) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(
//           content: Text('Invalid server address'),
//           backgroundColor: Colors.red,
//         ),
//       );
//     }
//   }
//
//   // void getConnectivity() {
//   //   subscription = Connectivity().onConnectivityChanged.listen(
//   //         (ConnectivityResult result) async {
//   //       isDeviceConnected = await InternetConnectionChecker().hasConnection;
//   //       if (!isDeviceConnected && !isAlertSet) {
//   //         showSnackBar();
//   //         setState(() => isAlertSet = true);
//   //       }
//   //     },
//   //   );
//   // }
//
//   @override
//   Widget build(BuildContext context) {
//     return WillPopScope(
//       onWillPop: () async {
//         SystemNavigator.pop();
//         return false;
//       },
//       child: Scaffold(
//         backgroundColor: Colors.white,
//         body: Stack(
//           children: [
//             Positioned(
//               top: 0,
//               left: 0,
//               right: 0,
//               height: MediaQuery.of(context).size.height * 0.42,
//               child: Container(
//                 decoration: BoxDecoration(
//                   borderRadius: BorderRadius.circular(8.0),
//                   color: Colors.red,
//                 ),
//                 alignment: Alignment.bottomCenter,
//                 child: Center(
//                   child: ClipOval(
//                     child: Container(
//                       color: Colors.white,
//                       padding: const EdgeInsets.fromLTRB(10, 5, 10, 15),
//                       child: Image.asset(
//                         'Assets/horilla-logo.png',
//                         height: MediaQuery.of(context).size.height * 0.11,
//                         width: MediaQuery.of(context).size.height * 0.11,
//                         fit: BoxFit.contain,
//                       ),
//                     ),
//                   ),
//                 ),
//               ),
//             ),
//             Positioned(
//               top: MediaQuery.of(context).size.height * 0.3,
//               left: 0,
//               right: 0,
//               child: Center(
//                 child: Container(
//                   padding: const EdgeInsets.all(10.0),
//                   margin: EdgeInsets.symmetric(
//                     horizontal: MediaQuery.of(context).size.width * 0.05,
//                   ),
//                   height: MediaQuery.of(context).size.height * 0.5,
//                   decoration: BoxDecoration(
//                     border: Border.all(color: Colors.grey[300]!),
//                     borderRadius: BorderRadius.circular(20.0),
//                     color: Colors.white,
//                     boxShadow: [
//                       BoxShadow(
//                         color: Colors.black.withOpacity(0.1),
//                         spreadRadius: 2,
//                         blurRadius: 5,
//                         offset: const Offset(0, 3),
//                       ),
//                     ],
//                   ),
//                   child: SingleChildScrollView(
//                     child: Column(
//                       children: <Widget>[
//                         SizedBox(
//                             height: MediaQuery.of(context).size.height * 0.01),
//                         const Text(
//                           'Sign In',
//                           style: TextStyle(
//                             fontWeight: FontWeight.bold,
//                             fontSize: 20,
//                           ),
//                         ),
//                         SizedBox(
//                             height: MediaQuery.of(context).size.height * 0.02),
//                         Column(
//                           crossAxisAlignment: CrossAxisAlignment.start,
//                           children: [
//                             Text(
//                               'Server Address',
//                               style: TextStyle(
//                                 fontWeight: FontWeight.bold,
//                                 color: Colors.grey[600],
//                               ),
//                             ),
//                             SizedBox(
//                                 height:
//                                 MediaQuery.of(context).size.height * 0.005),
//                             TextFormField(
//                               controller: serverController,
//                               decoration: InputDecoration(
//                                 border: OutlineInputBorder(
//                                   borderSide: const BorderSide(
//                                     width: 1,
//                                   ),
//                                   borderRadius: BorderRadius.circular(8.0),
//                                 ),
//                                 contentPadding: EdgeInsets.symmetric(
//                                   vertical: MediaQuery.of(context).size.height *
//                                       0.005,
//                                   horizontal: serverController.text.isNotEmpty
//                                       ? 16.0
//                                       : 12.0,
//                                 ),
//                                 labelStyle: TextStyle(
//                                   color: Colors.grey[600],
//                                 ),
//                               ),
//                             ),
//                           ],
//                         ),
//                         SizedBox(
//                             height: MediaQuery.of(context).size.height * 0.01),
//                         Column(
//                           crossAxisAlignment: CrossAxisAlignment.start,
//                           children: [
//                             Text(
//                               'Email',
//                               style: TextStyle(
//                                 fontWeight: FontWeight.bold,
//                                 color: Colors.grey[600],
//                               ),
//                             ),
//                             SizedBox(
//                                 height:
//                                 MediaQuery.of(context).size.height * 0.005),
//                             TextFormField(
//                               controller: usernameController,
//                               decoration: InputDecoration(
//                                 border: OutlineInputBorder(
//                                   borderSide: const BorderSide(
//                                     width: 1,
//                                   ),
//                                   borderRadius: BorderRadius.circular(8.0),
//                                 ),
//                                 contentPadding: EdgeInsets.symmetric(
//                                   vertical: MediaQuery.of(context).size.height *
//                                       0.005,
//                                   horizontal: usernameController.text.isNotEmpty
//                                       ? 16.0
//                                       : 12.0,
//                                 ),
//                                 labelStyle: TextStyle(
//                                   color: Colors.grey[600],
//                                 ),
//                               ),
//                             ),
//                           ],
//                         ),
//                         SizedBox(
//                             height: MediaQuery.of(context).size.height * 0.01),
//                         Column(
//                           crossAxisAlignment: CrossAxisAlignment.start,
//                           children: [
//                             Text(
//                               'Password',
//                               style: TextStyle(
//                                 fontWeight: FontWeight.bold,
//                                 color: Colors.grey[600],
//                               ),
//                             ),
//                             SizedBox(
//                                 height:
//                                 MediaQuery.of(context).size.height * 0.005),
//                             TextFormField(
//                               controller: passwordController,
//                               obscureText: !_passwordVisible,
//                               decoration: InputDecoration(
//                                 border: OutlineInputBorder(
//                                   borderSide: const BorderSide(
//                                     width: 1,
//                                   ),
//                                   borderRadius: BorderRadius.circular(8.0),
//                                 ),
//                                 contentPadding: EdgeInsets.symmetric(
//                                   vertical: MediaQuery.of(context).size.height *
//                                       0.005,
//                                   horizontal: passwordController.text.isNotEmpty
//                                       ? 16.0
//                                       : 12.0,
//                                 ),
//                                 labelStyle: TextStyle(
//                                   color: Colors.grey[600],
//                                 ),
//                                 suffixIcon: IconButton(
//                                   icon: Icon(
//                                     _passwordVisible
//                                         ? Icons.visibility
//                                         : Icons.visibility_off,
//                                     color: Colors.grey,
//                                   ),
//                                   onPressed: () {
//                                     setState(() {
//                                       _passwordVisible = !_passwordVisible;
//                                     });
//                                   },
//                                 ),
//                               ),
//                             ),
//                           ],
//                         ),
//                         SizedBox(
//                             height: MediaQuery.of(context).size.height * 0.02),
//                         SizedBox(
//                           width: double.infinity,
//                           child: ElevatedButton(
//                             onPressed: _login,
//                             style: ElevatedButton.styleFrom(
//                               foregroundColor: Colors.white,
//                               backgroundColor: Colors.red,
//                               shape: RoundedRectangleBorder(
//                                 borderRadius: BorderRadius.circular(8.0),
//                               ),
//                             ),
//                             child: const Padding(
//                               padding: EdgeInsets.symmetric(vertical: 10.0),
//                               child: Text(
//                                 'Sign In',
//                                 style: TextStyle(
//                                   fontWeight: FontWeight.bold,
//                                   fontSize: 20,
//                                 ),
//                               ),
//                             ),
//                           ),
//                         ),
//                       ],
//                     ),
//                   ),
//                 ),
//               ),
//             )
//           ],
//         ),
//       ),
//     );
//   }
//
//   void showSnackBar() {
//     ScaffoldMessenger.of(context).showSnackBar(
//       SnackBar(
//         backgroundColor: Colors.red,
//         content: const Text('Please check your internet connectivity',
//             style: TextStyle(color: Colors.white)),
//         action: SnackBarAction(
//           backgroundColor: Colors.red,
//           label: 'close',
//           textColor: Colors.white,
//           onPressed: () async {
//             setState(() => isAlertSet = false);
//             isDeviceConnected = await InternetConnectionChecker().hasConnection;
//             if (!isDeviceConnected && !isAlertSet) {
//               showSnackBar();
//               setState(() => isAlertSet = true);
//             }
//           },
//         ),
//         duration: const Duration(hours: 1),
//       ),
//     );
//   }
// }