import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:horilla/common/appColors.dart';
import 'package:horilla/common/appimages.dart';
import 'package:horilla/main.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shimmer/shimmer.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';

class EmployeeListPage extends StatefulWidget {
  const EmployeeListPage({super.key});

  @override
  _EmployeeListPageState createState() => _EmployeeListPageState();
}

class StateInfo {
  final Color color;
  final String displayString;

  StateInfo(this.color, this.displayString);
}

class _EmployeeListPageState extends State<EmployeeListPage> {
  List<Map<String, dynamic>> requests = [];
  String searchText = '';
  List<dynamic> filteredRecords = [];
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  final List<Widget> bottomBarPages = [];
  final _pageController = PageController(initialPage: 0);
  int currentPage = 1;
  int requestsCount = 0;
  int maxCount = 5;
  late Map<String, dynamic> arguments;
  late String baseUrl = '';
  bool isLoading = true;
  bool isLoadingEmployee = false;
  bool _isShimmer = true;
  bool isSearching = false;
  bool hasMore = true;
  bool hasNoMore = false;
  String nextPage = '';
  @override
  void initState() {
    super.initState();
    _simulateLoading();
    _scrollController.addListener(_scrollListener);
    prefetchData();
    getEmployeeDetails();
    getBaseUrl();
  }

  void _scrollListener() {
    if (_scrollController.offset >=
            _scrollController.position.maxScrollExtent &&
        !_scrollController.position.outOfRange) {
      currentPage++;
      getEmployeeDetails();
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _scrollController.removeListener(_scrollListener);
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> getBaseUrl() async {
    final prefs = await SharedPreferences.getInstance();
    var typedServerUrl = prefs.getString("typed_url");
    setState(() {
      baseUrl = typedServerUrl ?? '';
    });
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

  Future<void> _simulateLoading() async {
    await Future.delayed(const Duration(seconds: 2));
    setState(() {
      _isShimmer = false;
    });
  }

  Future<void> getEmployeeDetails({bool isFromSearch = false}) async {
    setState(() {
      if (isFromSearch) {
        isLoadingEmployee = true;
      }
    });
    try {
      final prefs = await SharedPreferences.getInstance();
      var token = prefs.getString("token");
      var typedServerUrl = prefs.getString("typed_url");
      var uri = Uri.parse(
          '$typedServerUrl/api/employee/list/employees?page=$currentPage&search=$searchText');
      var response = await http.get(uri, headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      });
      if (response.statusCode == 200) {
        setState(() {
          requests.addAll(
            List<Map<String, dynamic>>.from(
              jsonDecode(response.body)['results'],
            ),
          );
          requestsCount = jsonDecode(response.body)['count'];

          String serializeMap(Map<String, dynamic> map) {
            return jsonEncode(map);
          }

          Map<String, dynamic> deserializeMap(String jsonString) {
            return jsonDecode(jsonString);
          }

          List<String> mapStrings = requests.map(serializeMap).toList();
          Set<String> uniqueMapStrings = mapStrings.toSet();
          requests = uniqueMapStrings.map(deserializeMap).toList();
          filteredRecords = filterRecords(searchText);
          setState(() {
            isLoading = false;
            isLoadingEmployee = false;
          });
          nextPage = jsonDecode(response.body)['next'] ?? '';
        });
      } else {
        hasNoMore = true;
        isLoadingEmployee = false;
      }
    } catch (e) {
      isLoadingEmployee = false;
    }
  }

  List<dynamic> filterRecords(String searchText) {
    List<dynamic> allRecords = requests;
    List<dynamic> filteredRecords = allRecords.where((record) {
      final firstName = record['employee_first_name'] ?? '';
      final lastName = record['employee_last_name'] ?? '';
      final fullName = (firstName + ' ' + lastName).toLowerCase();
      final jobPosition = record['job_position_name'] ?? '';
      return fullName.contains(searchText.toLowerCase()) ||
          jobPosition.toLowerCase().contains(searchText.toLowerCase());
    }).toList();

    return filteredRecords;
  }

  Color _getColorForPosition(String position) {
    int hashCode = position.hashCode;
    return Color((hashCode & 0xFFFFFF).toInt()).withOpacity(1.0);
  }

  Widget buildListItem(Map<String, dynamic> record, baseUrl) {
    String position = record['job_position_name'] ?? 'Unknown';
    Color positionColor = _getColorForPosition(position);
    return Column(
      children: [
        Card(
          color: Appcolors.cardColor,
          elevation: 0,
          child: ListTile(
            onTap: () {
              final args = ModalRoute.of(context)?.settings.arguments;
              // Navigator.pushNamed(context, '/employees_form',
              //  arguments: {
              //   'employee_id': record['id'],
              //   'employee_name': record['employee_first_name'] +
              //       ' ' +
              //       record['employee_last_name'],
              //   'permission_check': args,
              // }
              // );

              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => DashboardScreen(
                    initialIndex: 2,
                    arguments: {
                      'employee_id': record['id'],
                      'employee_name': (record['employee_first_name'] ?? '') +
                          ' ' +
                          (record['employee_last_name'] ?? ''),

                      // 'employee_name': record['employee_first_name'] +
                      //     ' ' +
                      //     record['employee_last_name'],
                      'permission_check': args,
                    },
                  ),
                ),
              );
            },
            leading: CircleAvatar(
              radius: 20.0,
              backgroundColor: Colors.transparent,
              child: Stack(
                children: [
                  if (record['employee_profile'] != null &&
                      record['employee_profile'].isNotEmpty)
                    Positioned.fill(
                      child: ClipOval(
                        child: Image.network(
                          baseUrl + record['employee_profile'],
                          fit: BoxFit.cover,
                          errorBuilder: (BuildContext context, Object exception,
                              StackTrace? stackTrace) {
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
            title: Text(
              maxLines: 1, // ✅ Restrict to 1 line
              //overflow: TextOverflow.ellipsis,
              record['employee_first_name'] +
                  ' ' +
                  (record['employee_last_name'] ?? ''),
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 15.0,
              ),
            ),
            subtitle: Text(
              overflow: TextOverflow.visible,
              softWrap: false,
              (record['email'] ?? '').substring(
                  0,
                  (record['email'] ?? '').length > 20
                      ? 20
                      : (record['email'] ?? '').length),
              //record['email'],
              style: const TextStyle(
                fontWeight: FontWeight.normal,
                fontSize: 10.0,
                color: Colors.grey,
              ),
            ),
            trailing: SizedBox(
              width: 150,
              child: Row(
                children: [
                  Flexible(
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Container(
                        width: 100,
                        height: 25,
                        padding:
                            const EdgeInsets.fromLTRB(10.0, 1.0, 10.0, 1.0),
                        decoration: BoxDecoration(
                          color: positionColor.withOpacity(0.03),
                          borderRadius: BorderRadius.circular(10.0),
                        ),
                        child: Center(
                          child: Text(
                            position,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 13.0,
                              color: positionColor,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.all(4.0),
                    child: Icon(Icons.keyboard_arrow_right),
                  ),
                ],
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          // Adjust padding as needed
          // child: Divider(height: 1.0, color: Colors.grey[300]),
        ),
      ],
    );
  }

  Future<void> loadMoreData() async {
    currentPage++;
    await getEmployeeDetails();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
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
                        Navigator.pop(context);
                      },
                      child: SvgPicture.asset(
                        Appimages.leftArrow,
                        color: Colors.white,
                        height: 24,
                        width: 24,
                      ),
                    ),
                  ),
                  if (isSearching) ...[
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(
                            left: 20.0, right: 20, top: 20),
                        child: TextFormField(
                          controller: _searchController,
                          focusNode: _searchFocusNode,
                          decoration: const InputDecoration(
                            //labelText: 'Search *',
                            hintText: 'Search',
                            hintStyle: TextStyle(color: Colors.white),
                            labelStyle: TextStyle(color: Colors.white),
                            enabledBorder: UnderlineInputBorder(
                              borderSide: BorderSide(color: Colors.white),
                            ),
                            focusedBorder: UnderlineInputBorder(
                              borderSide:
                                  BorderSide(color: Colors.white, width: 2),
                            ),
                          ),
                          style: const TextStyle(color: Colors.white),
                          onChanged: (employeeSearchValue) {
                            currentPage = 1;
                            requests.clear();
                            searchText = employeeSearchValue;
                            getEmployeeDetails(isFromSearch: true);
                          },
                        ),
                      ),
                    ),
                  ] else ...[
                    const Padding(
                      padding: EdgeInsets.only(left: 70.0, top: 40),
                      child: Text(
                        'Employees',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ),

                    // Spacer + search icon
                    const Spacer(),
                  ],

                  Padding(
                    padding: const EdgeInsets.only(right: 20.0, top: 40),
                    child: InkWell(
                      onTap: () {
                        setState(() {
                          isSearching = !isSearching;
                          if (isSearching) {
                            // Delay needed to wait until TextField is built
                            Future.delayed(Duration(milliseconds: 100), () {
                              FocusScope.of(context)
                                  .requestFocus(_searchFocusNode);
                            });
                             //currentPage = 1;
                            // requests.clear();
                             searchText = '';
                             _searchController.clear();
                            getEmployeeDetails();
                          }
                        });
                      },
                      child: SvgPicture.asset(
                        Appimages.searchIcon,
                        height: 24,
                        width: 24,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),

      // appBar: AppBar(
      //   automaticallyImplyLeading: false,
      //   leading: GestureDetector(
      //     onTap: () {
      //       Navigator.pop(context);
      //     },
      //     child: Padding(
      //       padding: const EdgeInsets.only(
      //           right: 12.0, top: 40, bottom: 12, left: 20),
      //       child: SvgPicture.asset(
      //         Appimages.leftArrow,
      //         color: Colors.white,
      //       ),
      //     ),
      //   ),
      //   toolbarHeight: 115,
      //   backgroundColor: Appcolors.appBlue,
      //   title: const Padding(
      //     padding: EdgeInsets.only(left: 40.0, top: 30),
      //     child: Text('Employees', style: TextStyle(color: Colors.white)),
      //   ),
      //   shape: const RoundedRectangleBorder(
      //     borderRadius: BorderRadius.only(
      //       bottomLeft: Radius.circular(20),
      //       bottomRight: Radius.circular(20),
      //     ),
      //   ),
      //   actions: [
      //     Padding(
      //       padding: const EdgeInsets.only(right: 20.0, top: 25),
      //       child: SvgPicture.asset(Appimages.searchIcon),
      //     )
      //   ],
      // ),
      body: Stack(
        children: [
          Center(
            child: isLoading
                ? Column(
                    children: [
                      const SizedBox(height: 5),
                      Padding(
                        padding: MediaQuery.of(context).size.width > 600
                            ? const EdgeInsets.all(20.0)
                            : const EdgeInsets.all(15.0),
                        child: Row(
                          children: [
                            Expanded(
                              child: Card(
                                margin: const EdgeInsets.all(8),
                                elevation: 0,
                                child: Shimmer.fromColors(
                                  baseColor: Colors.grey[300]!,
                                  highlightColor: Colors.grey[100]!,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: Colors.grey[100],
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: TextField(
                                      enabled: false,
                                      decoration: InputDecoration(
                                        hintText: 'Loading...',
                                        hintStyle: TextStyle(
                                            color: Colors.grey.shade400,
                                            fontSize: 14),
                                        border: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(8.0),
                                          borderSide: BorderSide.none,
                                        ),
                                        prefixIcon: Transform.scale(
                                          scale: 0.8,
                                          child: Icon(Icons.search,
                                              color: Colors.grey.shade400),
                                        ),
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                                vertical: 12.0,
                                                horizontal: 4.0),
                                        filled: true,
                                        fillColor: Colors.grey[100],
                                      ),
                                      style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.grey.shade400),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: ListView.builder(
                            itemCount: 6,
                            itemBuilder: (context, index) {
                              return Shimmer.fromColors(
                                baseColor: Colors.grey[300]!,
                                highlightColor: Colors.grey[100]!,
                                child: Card(
                                  margin:
                                      const EdgeInsets.symmetric(vertical: 8),
                                  child: ListTile(
                                    title: Container(
                                      height: 20,
                                      color: Colors.grey[300],
                                    ),
                                    subtitle: Container(
                                      height: 16,
                                      color: Colors.grey[200],
                                      margin: const EdgeInsets.only(top: 8.0),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ],
                  )
                : Column(
                    children: [
                      const SizedBox(height: 5),
                      // Padding(
                      //   padding: MediaQuery.of(context).size.width > 600
                      //       ? const EdgeInsets.all(20.0)
                      //       : const EdgeInsets.all(15.0),
                      //   child: Row(
                      //     children: [
                      //       Expanded(
                      //         child: Card(
                      //           margin: const EdgeInsets.all(8),
                      //           elevation: 0,
                      //           child: Container(
                      //             decoration: BoxDecoration(
                      //               border:
                      //                   Border.all(color: Colors.grey.shade50),
                      //               borderRadius: BorderRadius.circular(10),
                      //             ),
                      //             child: TextField(
                      //               onChanged: (employeeSearchValue) {
                      //                 //setState(() {
                      //                 currentPage = 1;
                      //                 requests.clear();
                      //                 searchText = employeeSearchValue;
                      //                 getEmployeeDetails(isFromSearch: true);
                      //                 //});
                      //               },
                      //               decoration: InputDecoration(
                      //                 hintText: 'Search',
                      //                 border: OutlineInputBorder(
                      //                   borderRadius:
                      //                       BorderRadius.circular(8.0),
                      //                   borderSide: BorderSide.none,
                      //                 ),
                      //                 prefixIcon: Transform.scale(
                      //                   scale: 0.8,
                      //                   child: Icon(Icons.search,
                      //                       color: Colors.blueGrey.shade300),
                      //                 ),
                      //                 contentPadding:
                      //                     const EdgeInsets.symmetric(
                      //                         vertical: 12.0, horizontal: 4.0),
                      //                 hintStyle: TextStyle(
                      //                     color: Colors.blueGrey.shade300,
                      //                     fontSize: 14),
                      //                 filled: true,
                      //                 fillColor: Colors.grey[100],
                      //               ),
                      //               style: const TextStyle(fontSize: 14),
                      //             ),
                      //           ),
                      //         ),
                      //       ),
                      //     ],
                      //   ),
                      // ),
                      if (isLoadingEmployee) ...[
                        const Expanded(
                          child: Center(
                            child:
                                CircularProgressIndicator(), // Or any loader you like
                          ),
                        )
                      ] else if (requestsCount == 0)
                        const Expanded(
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.search,
                                  color: Colors.black,
                                  size: 92,
                                ),
                                SizedBox(height: 20),
                                Text(
                                  "There are no employee records to display",
                                  style: TextStyle(
                                    fontSize: 16.0,
                                    color: Colors.black,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      else
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: ListView.builder(
                              controller: _scrollController,
                              itemCount: searchText.isEmpty
                                  ? requests.length + (hasMore ? 1 : 0)
                                  : filteredRecords.length,
                              itemBuilder: (context, index) {
                                if (index == requests.length &&
                                    searchText.isEmpty &&
                                    hasMore) {
                                  return Column(
                                    children: [
                                      if (nextPage != '')
                                        Center(
                                          child: ListTile(
                                            title: LoadingAnimationWidget
                                                .bouncingBall(
                                              size: 25,
                                              color: Colors.grey,
                                            ),
                                            onTap: () {
                                              //setState(() {
                                              loadMoreData();
                                              // });
                                            },
                                          ),
                                        ),
                                    ],
                                  );
                                }

                                final record = searchText.isEmpty
                                    ? requests[index]
                                    : filteredRecords[index];
                                return buildListItem(record, baseUrl);
                              },
                            ),
                          ),
                        ),
                    ],
                  ),
          )
        ],
      ),
    );
  }
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
