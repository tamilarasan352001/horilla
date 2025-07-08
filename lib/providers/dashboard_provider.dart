import 'package:flutter/material.dart';
import 'package:horilla/checkin_checkout/checkin_checkout_views/checkin_checkout_form.dart';
import 'package:horilla/employee_views/employee_form.dart';
import 'package:horilla/horilla_main/home.dart';

class DashboardProvider extends ChangeNotifier {

  final List<BottomNavigationBarItem> _navigationItems = [
    const BottomNavigationBarItem(icon: Icon(Icons.home), label: "Home"),
   const BottomNavigationBarItem(icon: Icon(Icons.update), label: "Check-In/Out"),
   const BottomNavigationBarItem(icon: Icon(Icons.person), label: "Employee"),
  ];


  List<BottomNavigationBarItem> get navigationItems => _navigationItems;

  int _selectedBottomTab = 0;

  int get selectedBottomTab => _selectedBottomTab;

  List<Widget> get widgets => [
        const HomePage(),
        const CheckInCheckOutFormPage(),
        //EmployeeFormPage(dashBoardArgs: ''),
      ];

  void setSelectedBottomTab(int index) {
    _selectedBottomTab = index;
    notifyListeners();
  }
}

