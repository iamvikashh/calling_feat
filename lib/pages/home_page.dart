import 'dart:io';
import 'dart:math';

import 'package:awesome_notifications/android_foreground_service.dart';
import 'package:awesome_notifications_example/common_widgets/led_light.dart';
import 'package:awesome_notifications_example/common_widgets/seconds_slider.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart' hide DateUtils;
import 'package:flutter/services.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:awesome_notifications/awesome_notifications.dart';

import 'package:awesome_notifications_example/main.dart';
import 'package:awesome_notifications_example/routes.dart';
import 'package:awesome_notifications_example/utils/notification_util.dart';

import 'package:awesome_notifications_example/common_widgets/check_button.dart';
import 'package:awesome_notifications_example/common_widgets/remarkble_text.dart';
import 'package:awesome_notifications_example/common_widgets/service_control_panel.dart';
import 'package:awesome_notifications_example/common_widgets/simple_button.dart';
import 'package:awesome_notifications_example/common_widgets/text_divisor.dart';
import 'package:awesome_notifications_example/common_widgets/text_note.dart';
import 'package:numberpicker/numberpicker.dart';
import 'package:vibration/vibration.dart';

class HomePage extends StatefulWidget {
  @override
  _HomePageState createState() =>
      _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String _firebaseAppToken = '';
  //String _oneSignalToken = '';

  bool delayLEDTests = false;
  double _secondsToWakeUp = 5;
  double _secondsToCallCategory = 5;

  bool globalNotificationsAllowed = false;
  bool schedulesFullControl = false;
  bool isCriticalAlertsEnabled = false;
  bool isPreciseAlarmEnabled = false;
  bool isOverrideDnDEnabled = false;

  Map<NotificationPermission, bool> scheduleChannelPermissions = {};
  Map<NotificationPermission, bool> dangerousPermissionsStatus = {};

  List<NotificationPermission> channelPermissions = [
    NotificationPermission.Alert,
    NotificationPermission.Sound,
    NotificationPermission.Badge,
    NotificationPermission.Light,
    NotificationPermission.Vibration,
    NotificationPermission.CriticalAlert,
    NotificationPermission.FullScreenIntent
  ];

  List<NotificationPermission> dangerousPermissions = [
    NotificationPermission.CriticalAlert,
    NotificationPermission.OverrideDnD,
    NotificationPermission.PreciseAlarms,
  ];



  @override
  void initState() {
    super.initState();

    for(NotificationPermission permission in channelPermissions){
      scheduleChannelPermissions[permission] = false;
    }

    for(NotificationPermission permission in dangerousPermissions){
      dangerousPermissionsStatus[permission] = false;
    }



    AwesomeNotifications().actionStream.listen((receivedAction) {

      if(receivedAction.channelKey == 'call_channel'){
        switch (receivedAction.buttonKeyPressed) {

          case 'REJECT':
            AndroidForegroundService.stopForeground();
            break;

          case 'ACCEPT':
            loadSingletonPage(targetPage: PAGE_PHONE_CALL, receivedAction: receivedAction);
            AndroidForegroundService.stopForeground();
            break;

          default:
            loadSingletonPage(targetPage: PAGE_PHONE_CALL, receivedAction: receivedAction);
            break;
        }
        return;
      }

      if (receivedAction.channelKey == 'alarm_channel') {
        AndroidForegroundService.stopForeground();
        return;
      }

      
    });

    refreshPermissionsIcons().then((_) =>
      NotificationUtils.requestBasicPermissionToSendNotifications(context).then((allowed){
        if(allowed != globalNotificationsAllowed)
          refreshPermissionsIcons();
      })
    );
  }

  void loadSingletonPage({required String targetPage, required ReceivedAction receivedAction}){
    // Avoid to open the notification details page over another details page already opened
    Navigator.pushNamedAndRemoveUntil(context, targetPage,
            (route) => (route.settings.name != targetPage) || route.isFirst,
        arguments: receivedAction);
  }

  Future<void> refreshPermissionsIcons() async {

    AwesomeNotifications().isNotificationAllowed().then((isAllowed) async {
      setState(() {
        globalNotificationsAllowed = isAllowed;
      });
    });
    refreshScheduleChannelPermissions();
    refreshDangerousChannelPermissions();
  }

  void refreshScheduleChannelPermissions(){
    AwesomeNotifications().checkPermissionList(
        channelKey: 'scheduled',
        permissions: channelPermissions
    ).then((List<NotificationPermission> permissionsAllowed) =>
        setState(() {
          schedulesFullControl = true;
          for(NotificationPermission permission in channelPermissions){
            scheduleChannelPermissions[permission] = permissionsAllowed.contains(permission);
            schedulesFullControl = schedulesFullControl && scheduleChannelPermissions[permission]!;
          }
        })
    );
  }

  void refreshDangerousChannelPermissions(){
    AwesomeNotifications().checkPermissionList(
        permissions: dangerousPermissions
    ).then((List<NotificationPermission> permissionsAllowed) =>
        setState(() {
          for(NotificationPermission permission in dangerousPermissions){
            dangerousPermissionsStatus[permission] = permissionsAllowed.contains(permission);
          }
          isCriticalAlertsEnabled = dangerousPermissionsStatus[NotificationPermission.CriticalAlert]!;
          isPreciseAlarmEnabled = dangerousPermissionsStatus[NotificationPermission.PreciseAlarms]!;
          isOverrideDnDEnabled = dangerousPermissionsStatus[NotificationPermission.OverrideDnD]!;
        })
    );
  }


 

  

  @override
  void dispose() {
    AwesomeNotifications().createdSink.close();
    AwesomeNotifications().displayedSink.close();
    AwesomeNotifications().actionSink.close();
    super.dispose();
  }

  // Platform messages are asynchronous, so we initialize in an async method.
  Future<void> initializeFirebaseService() async {
    FirebaseMessaging messaging = FirebaseMessaging.instance;

    String firebaseAppToken = await messaging.getToken(
          // https://stackoverflow.com/questions/54996206/firebase-cloud-messaging-where-to-find-public-vapid-key
          vapidKey: '',
        ) ??
        '';

    if (AwesomeStringUtils.isNullOrEmpty(firebaseAppToken,
        considerWhiteSpaceAsEmpty: true)) return;

    if (!mounted) {
      _firebaseAppToken = firebaseAppToken;
    } else {
      setState(() {
        _firebaseAppToken = firebaseAppToken;
      });
    }

    print('Firebase token: $firebaseAppToken');

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print('Got a message whilst in the foreground!');
      print('Message data: ${message.data}');

      if (
          // This step (if condition) is only necessary if you pretend to use the
          // test page inside console.firebase.google.com
          !AwesomeStringUtils.isNullOrEmpty(message.notification?.title,
                  considerWhiteSpaceAsEmpty: true) ||
              !AwesomeStringUtils.isNullOrEmpty(message.notification?.body,
                  considerWhiteSpaceAsEmpty: true)) {
        print('Message also contained a notification: ${message.notification}');

        String? imageUrl;
        imageUrl ??= message.notification!.android?.imageUrl;
        imageUrl ??= message.notification!.apple?.imageUrl;

        // https://pub.dev/packages/awesome_notifications#notification-types-values-and-defaults
        Map<String, dynamic> notificationAdapter = {
          NOTIFICATION_CONTENT: {
            NOTIFICATION_ID: Random().nextInt(2147483647),
            NOTIFICATION_CHANNEL_KEY: 'basic_channel',
            NOTIFICATION_TITLE: message.notification!.title,
            NOTIFICATION_BODY: message.notification!.body,
            NOTIFICATION_LAYOUT:
                AwesomeStringUtils.isNullOrEmpty(imageUrl) ? 'Default' : 'BigPicture',
            NOTIFICATION_BIG_PICTURE: imageUrl
          }
        };

        AwesomeNotifications()
            .createNotificationFromJsonData(notificationAdapter);
      } else {
        AwesomeNotifications().createNotificationFromJsonData(message.data);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    MediaQueryData mediaQuery = MediaQuery.of(context);
    ThemeData themeData = Theme.of(context);

    return Scaffold(
        appBar: AppBar(
          centerTitle: false,
          brightness: Brightness.light,
          title: Text("Calling feature."), //Text('Local Notification Example App', style: TextStyle(fontSize: 20)),
          elevation: 10,
        ),
        body: ListView(
          padding: EdgeInsets.symmetric(horizontal: 15, vertical: 8),
          children: <Widget>[
            TextDivisor(title: 'Global Permission to send Notifications'),
            PermissionIndicator(name: null, allowed: globalNotificationsAllowed),
            TextNote(
                'To send local and push notifications, it is necessary to obtain the user\'s consent. Keep in mind that he user consent can be revoked at any time.\n\n'
                '* Android: notifications are enabled by default and are considered not dangerous.\n'
                '* iOS: notifications are not enabled by default and you must explicitly request it to the user.'),
            SimpleButton('Request permission',
                enabled: !globalNotificationsAllowed,
                onPressed: (){
                  NotificationUtils.requestBasicPermissionToSendNotifications(context).then(
                    (isAllowed) =>
                        setState(() {
                          globalNotificationsAllowed = isAllowed;
                          refreshPermissionsIcons();
                        })
                  );
                }
            ),
            SimpleButton('Open notifications permission page',
                onPressed: () => NotificationUtils.redirectToPermissionsPage().then(
                        (isAllowed) =>
                        setState(() {
                          globalNotificationsAllowed = isAllowed;
                          refreshPermissionsIcons();
                        })
                )
            ),
            SimpleButton('Open basic channel permission page',
                enabled: !Platform.isIOS,
                onPressed: () => NotificationUtils.redirectToBasicChannelPage()
            ),


            TextDivisor(title: 'Channel\'s Permissions'),
            Wrap(
              alignment: WrapAlignment.center,
                children: <Widget>[
                  PermissionIndicator(name: 'Alerts', allowed: scheduleChannelPermissions[NotificationPermission.Alert]!),
                  PermissionIndicator(name: 'Sounds', allowed: scheduleChannelPermissions[NotificationPermission.Sound]!),
                  PermissionIndicator(name: 'Badges', allowed: scheduleChannelPermissions[NotificationPermission.Badge]!),
                  PermissionIndicator(name: 'Vibrations', allowed: scheduleChannelPermissions[NotificationPermission.Vibration]!),
                  PermissionIndicator(name: 'Lights', allowed: scheduleChannelPermissions[NotificationPermission.Light]!),
                  PermissionIndicator(name: 'Full Intents', allowed: scheduleChannelPermissions[NotificationPermission.FullScreenIntent]!),
                  PermissionIndicator(name: 'Critical Alerts', allowed: scheduleChannelPermissions[NotificationPermission.CriticalAlert]!),
                ]),
            TextNote(
                'To send local and push notifications, it is necessary to obtain the user\'s consent. Keep in mind that he user consent can be revoked at any time.\n\n'
                    '* OBS: if the feature is not available on device, it will be considered enabled by default.\n'),
            SimpleButton('Open Schedule channel\'s permission page',
                enabled: !Platform.isIOS,
                onPressed: () => NotificationUtils.redirectToScheduledChannelsPage().then(
                    (_)=> refreshPermissionsIcons()
                )
            ),
          


          
        



            //TextDivisor(title: 'Notification\'s Special Category'),
            // TextNote('The notification category is a group of predefined categories that best describe the nature of the notification and may be used by some systems for ranking, delay or filter the notifications. Its highly recommended to correctly categorize your notifications..\n\n'
            //     'Slide the bar above to add some delay on notification.'),
            SecondsSlider(steps: 12, minValue: 0, onChanged: (newValue){ setState(() => _secondsToCallCategory = newValue ); }),
            SimpleButton('Show call notification',
                onPressed: () {
                  Vibration.vibrate(duration: 100);
                  Future.delayed(Duration(seconds: _secondsToCallCategory.toInt()), () {
                    NotificationUtils.showCallNotification(1);
                  });
                }),
            // SimpleButton('Show alarm notification',
            //     onPressed: () {
            //       Vibration.vibrate(duration: 100);
            //       Future.delayed(Duration(seconds: _secondsToCallCategory.toInt()), () {
            //         NotificationUtils.showAlarmNotification(1);
            //       });
            //     }),
            SimpleButton(' Call',
                backgroundColor: Colors.red,
                labelColor: Colors.white,
                onPressed: () => NotificationUtils.stopForegroundServiceNotification()),

      
            SimpleButton('Cancel all notifications and schedules',
                backgroundColor: Colors.red,
                labelColor: Colors.white,
                onPressed: NotificationUtils.cancelAllNotifications),
          ],
        ));
  }
}

class PermissionIndicator extends StatelessWidget {
  const PermissionIndicator({
    Key? key,
    required this.name,
    required this.allowed
  }) : super(key: key);

  final String? name;
  final bool allowed;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(5),
      width: 125,
      child: Column(
        children: [
          (name != null) ? Text(name!+':', textAlign: TextAlign.center) : SizedBox(),
          Text(allowed ? 'Allowed' : 'Not allowed',
              style: TextStyle(
                  color: allowed
                      ? Colors.green
                      : Colors.red)),
          LedLight(allowed)
        ],
      ),
    );
  }
}
