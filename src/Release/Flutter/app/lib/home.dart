import 'dart:convert';
import 'dart:io';
import 'dart:ui';
import 'dart:core';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:uuid/uuid.dart';
import 'package:app/main.dart';
import 'package:app/utils/polariscode_util.dart' as util;
import 'package:app/utils/polaris_code_language.dart';
import 'package:app/utils/global.dart';

class Home extends StatefulWidget {
  Home({super.key }){
    

  }

  
  @override
  State<StatefulWidget> createState() => HomeState();

  HomeState? _state;
  void setState(HomeState? value) {
    _state = value;
    
  }


  
  
  
  

  Future<void> onInactive(BuildContext context) async {   }
  Future<void> onRefresh(BuildContext context) async {   }



 
  
  
}  

class HomeState extends State<Home> with SingleTickerProviderStateMixin {
  @override
  void initState(){
    super.initState();
    
  }
  
  @override
  void dispose(){
    
    super.dispose();
  }

  void refresh() {
    if (mounted) {
      setState(() {});
      if(_dialogSetState != null){
        _dialogSetState!((){});
      }
    }
  }
  
  Function(void Function())? _dialogSetState = null;
  void closeDrawer(){
    _dialogSetState = null;
  }
    
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey();
  double _statusHeight = 0;
  
  @override
  Widget build(BuildContext context) {
    _statusHeight = MediaQuery.of(context).padding.top;
    widget.setState(this);
    

    return ScreenUtilInit(
      designSize: Size(
        util.isTablet(context) ? 1024 : 375,
        util.isTablet(context) ? 768: 822,
      ),
      splitScreenMode: true,
      minTextAdapt: true,
      builder: (c, constraints) {
 
      return Scaffold(
          //Body
          body: Container(
            width: double.infinity,
            height: double.infinity,
          ),
        );


      },
    );

  }







  
  
  
  
  
}



