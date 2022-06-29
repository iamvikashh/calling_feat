import 'dart:math';

import 'package:awesome_notifications_example/utils/notification_util.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:awesome_notifications_example/routes.dart';
import 'package:awesome_notifications/awesome_notifications.dart';


import 'firebase_options.dart';



//this method is to show feature which we need to show when app in not in foreground.
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // If you're going to use other Firebase services in the background, such as Firestore,
  // make sure you call `initializeApp` before using other Firebase services.

  NotificationUtils.showCallNotification(10);
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);


//initialize the plugin and also check and do the same as in the manifest file in android folder.
  AwesomeNotifications().initialize(
      'resource://drawable/res_app_icon',
      [
        NotificationChannel(
            channelGroupKey: 'category_tests',
            channelKey: 'call_channel',
            channelName: 'Calls Channel',
            channelDescription: 'Channel with call ringtone',
            defaultColor: Color(0xFF9D50DD),
            importance: NotificationImportance.Max,
            ledColor: Colors.white,
            channelShowBadge: true,
            locked: true,
            defaultRingtoneType: DefaultRingtoneType.Ringtone),
      ],
      debug: true);

  runApp(App());
}





class App extends StatefulWidget {
  App();

  static final GlobalKey<NavigatorState> navKey = GlobalKey<NavigatorState>();

  static String name = 'Awesome Notifications - Example App';
  static Color mainColor = Color(0xFF9D50DD);

  @override
  _AppState createState() => _AppState();
}

class _AppState extends State<App> {
  @override
  void initState() {

    printToken();

    super.initState();
  }

  printToken() async {
    print(await FirebaseMessaging.instance.getToken());
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: App.navKey,
      title: App.name,
      color: App.mainColor,
      initialRoute: PAGE_HOME,
      //onGenerateRoute: generateRoute,
      routes: materialRoutes,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
        child: child ?? const SizedBox.shrink(),
      ),
      theme: ThemeData(
        brightness: Brightness.light,

        primaryColor: App.mainColor,
        accentColor: Colors.blueGrey,
        canvasColor: Colors.white,
        focusColor: Colors.blueAccent,
        disabledColor: Colors.grey,

        backgroundColor: Colors.blueGrey.shade400,

        appBarTheme: AppBarTheme(
            brightness: Brightness.dark,
            color: Colors.white,
            elevation: 0,
            iconTheme: IconThemeData(
              color: App.mainColor,
            ),
            textTheme: TextTheme(
              headline6: TextStyle(color: App.mainColor, fontSize: 18),
            )),

        fontFamily: 'Robot',

        // Define the default TextTheme. Use this to specify the default
        // text styling for headlines, titles, bodies of text, and more.
        textTheme: TextTheme(
          headline1: TextStyle(
              fontSize: 64.0, height: 1.5, fontWeight: FontWeight.w500),
          headline2: TextStyle(
              fontSize: 52.0, height: 1.5, fontWeight: FontWeight.w500),
          headline3: TextStyle(
              fontSize: 48.0, height: 1.5, fontWeight: FontWeight.w500),
          headline4: TextStyle(
              fontSize: 32.0, height: 1.5, fontWeight: FontWeight.w500),
          headline5: TextStyle(
              fontSize: 28.0, height: 1.5, fontWeight: FontWeight.w500),
          headline6: TextStyle(
              fontSize: 22.0, height: 1.5, fontWeight: FontWeight.w500),
          subtitle1:
              TextStyle(fontSize: 18.0, height: 1.5, color: Colors.black54),
          subtitle2:
              TextStyle(fontSize: 12.0, height: 1.5, color: Colors.black54),
          button: TextStyle(fontSize: 16.0, height: 1.5, color: Colors.black54),
          bodyText1: TextStyle(fontSize: 16.0, height: 1.5),
          bodyText2: TextStyle(fontSize: 16.0, height: 1.5),
        ),

        buttonTheme: ButtonThemeData(
          buttonColor: Colors.grey.shade200,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(5))),
          padding: EdgeInsets.symmetric(vertical: 10.0, horizontal: 15.0),
          textTheme: ButtonTextTheme.accent,
        ),
      ),
    );
  }
}
