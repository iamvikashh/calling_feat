import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:awesome_notifications/android_foreground_service.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

// TO AVOID CONFLICT WITH MATERIAL DATE UTILS CLASS
import 'package:awesome_notifications/awesome_notifications.dart'
    hide AwesomeDateUtils;
import 'package:awesome_notifications/awesome_notifications.dart' as Utils
    show AwesomeDateUtils;

import 'package:awesome_notifications_example/utils/common_functions.dart';

import 'package:url_launcher/url_launcher.dart';

/* *********************************************
    LARGE TEXT FOR OUR NOTIFICATIONS TESTS
************************************************ */

String lorenIpsumText =
    'Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut '
    'labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip '
    'ex ea commodo consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat '
    'nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit'
    'anim id est laborum';

Future<void> externalUrl(String url) async {
  if (await canLaunch(url)) {
    await launch(url);
  } else {
    throw 'Could not launch $url';
  }
}

int createUniqueID(int maxValue){
  Random random = new Random();
  return random.nextInt(maxValue);
}

/* *********************************************
    PERMISSIONS
************************************************ */

class NotificationUtils {

  static Future<bool> redirectToPermissionsPage() async {
    await AwesomeNotifications().showNotificationConfigPage();
    return await AwesomeNotifications().isNotificationAllowed();
  }
  
  static Future<void> redirectToBasicChannelPage() async {
    await AwesomeNotifications().showNotificationConfigPage(channelKey: 'basic_channel');
  }
  
  static Future<void> redirectToAlarmPage() async {
    await AwesomeNotifications().showAlarmPage();
  }

  static Future<void> redirectToScheduledChannelsPage() async {
    await AwesomeNotifications().showNotificationConfigPage(channelKey: 'scheduled');
  }

  static Future<void> redirectToOverrideDndsPage() async {
    await AwesomeNotifications().showGlobalDndOverridePage();
  }
  
  static Future<bool> requestBasicPermissionToSendNotifications(BuildContext context) async {
    bool isAllowed = await AwesomeNotifications().isNotificationAllowed();
    if(!isAllowed){
      await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: Color(0xfffbfbfb),
            title: Text(
                'Get Notified!',
                maxLines: 2,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 22.0, fontWeight: FontWeight.w600)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset(
                  'assets/images/animated-bell.gif',
                  height: MediaQuery.of(context).size.height * 0.3,
                  fit: BoxFit.fitWidth,
                ),
                Text(
                  'Allow Awesome Notifications to send you beautiful notifications!',
                  maxLines: 4,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
            actions: [
              TextButton(
                  onPressed: (){ Navigator.pop(context); },
                  child: Text(
                    'Later',
                    style: TextStyle(color: Colors.grey, fontSize: 18),
                  )
              ),
              TextButton(
                onPressed: () async {
                  isAllowed = await AwesomeNotifications().requestPermissionToSendNotifications();
                  Navigator.pop(context);
                },
                child: Text(
                  'Allow',
                  style: TextStyle(color: Colors.deepPurple, fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          )
      );
    }
    return isAllowed;
  }

  static Future<void> requestFullScheduleChannelPermissions(BuildContext context, List<NotificationPermission> requestedPermissions) async {
    String channelKey = 'scheduled';

    await requestUserPermissions(context, channelKey: channelKey, permissionList: requestedPermissions);
  }

  static Future<List<NotificationPermission>> requestUserPermissions(
      BuildContext context,{
      // if you only intends to request the permissions until app level, set the channelKey value to null
      required String? channelKey,
      required List<NotificationPermission> permissionList}
    ) async {

    // Check if the basic permission was conceived by the user
    if(!await requestBasicPermissionToSendNotifications(context))
      return [];

    // Check which of the permissions you need are allowed at this time
    List<NotificationPermission> permissionsAllowed = await AwesomeNotifications().checkPermissionList(
        channelKey: channelKey,
        permissions: permissionList
    );

    // If all permissions are allowed, there is nothing to do
    if(permissionsAllowed.length == permissionList.length)
      return permissionsAllowed;

    // Refresh the permission list with only the disallowed permissions
    List<NotificationPermission> permissionsNeeded =
      permissionList.toSet().difference(permissionsAllowed.toSet()).toList();

    // Check if some of the permissions needed request user's intervention to be enabled
    List<NotificationPermission> lockedPermissions = await AwesomeNotifications().shouldShowRationaleToRequest(
        channelKey: channelKey,
        permissions: permissionsNeeded
    );

    // If there is no permitions depending of user's intervention, so request it directly
    if(lockedPermissions.isEmpty){

      // Request the permission through native resources.
      await AwesomeNotifications().requestPermissionToSendNotifications(
          channelKey: channelKey,
          permissions: permissionsNeeded
      );

      // After the user come back, check if the permissions has successfully enabled
      permissionsAllowed = await AwesomeNotifications().checkPermissionList(
          channelKey: channelKey,
          permissions: permissionsNeeded
      );
    }
    else {
      // If you need to show a rationale to educate the user to conceed the permission, show it
      await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: Color(0xfffbfbfb),
            title: Text('Awesome Notificaitons needs your permission',
              textAlign: TextAlign.center,
              maxLines: 2,
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset(
                  'assets/images/animated-clock.gif',
                  height: MediaQuery.of(context).size.height * 0.3,
                  fit: BoxFit.fitWidth,
                ),
                Text(
                  'To proceede, you need to enable the permissions above'+
                      (channelKey?.isEmpty ?? true ? '' : ' on channel $channelKey')+':',
                  maxLines: 2,
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 5),
                Text(
                  lockedPermissions.join(', ').replaceAll('NotificationPermission.', ''),
                  maxLines: 2,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
              ],
            ),
            actions: [
              TextButton(
                  onPressed: (){ Navigator.pop(context); },
                  child: Text(
                    'Deny',
                    style: TextStyle(color: Colors.red, fontSize: 18),
                  )
              ),
              TextButton(
                onPressed: () async {

                  // Request the permission through native resources. Only one page redirection is done at this point.
                  await AwesomeNotifications().requestPermissionToSendNotifications(
                      channelKey: channelKey,
                      permissions: lockedPermissions
                  );

                  // After the user come back, check if the permissions has successfully enabled
                  permissionsAllowed = await AwesomeNotifications().checkPermissionList(
                      channelKey: channelKey,
                      permissions: lockedPermissions
                  );

                  Navigator.pop(context);
                },
                child: Text(
                  'Allow',
                  style: TextStyle(color: Colors.deepPurple, fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          )
      );
    }

    // Return the updated list of allowed permissions
    return permissionsAllowed;
  }

  static Future<bool> requestCriticalAlertsPermission(BuildContext context) async {

    List<NotificationPermission> requestedPermissions = [
      NotificationPermission.CriticalAlert
    ];

    List<NotificationPermission> permissionsAllowed =
    await requestUserPermissions(
        context,
        channelKey: null,
        permissionList: requestedPermissions);

    return permissionsAllowed.isNotEmpty;
  }

  static Future<bool> requestFullIntentPermission(BuildContext context) async {

    List<NotificationPermission> requestedPermissions = [
      NotificationPermission.CriticalAlert
    ];

    List<NotificationPermission> permissionsAllowed =
    await requestUserPermissions(
        context,
        channelKey: null,
        permissionList: requestedPermissions);

    return permissionsAllowed.isNotEmpty;
  }




  static Future<void> showCallNotification(int id) async {
    String platformVersion = await getPlatformVersion();
    AndroidForegroundService.startForeground(
    //await AwesomeNotifications().createNotification(
        content: NotificationContent(
            id: id,
            channelKey: 'call_channel',
            title: 'Incoming Call',
            body: 'from Little Mary',
            category: NotificationCategory.Call,
            largeIcon: 'asset://assets/images/girl-phonecall.jpg',
            wakeUpScreen: true,
            fullScreenIntent: true,
            autoDismissible: false,
            backgroundColor: (platformVersion == 'Android-31') ?
              Color(0x00796a) : Colors.white,
            payload: {
              'username': 'Vikash'
            }
        ),
        actionButtons: [
          NotificationActionButton(
              key: 'ACCEPT',
              label: 'Accept Call',
              color: Colors.green,
              autoDismissible: true
          ),
          NotificationActionButton(
              key: 'REJECT',
              label: 'Reject',
              isDangerousOption: true,
              autoDismissible: true
          ),
        ]
    );
  }
  
  static Future<void> stopForegroundServiceNotification() async {
    await AndroidForegroundService.stopForeground();
  }
  

  

  

 

 
  
  static Future<void> cancelAllNotifications() async {
    await AwesomeNotifications().cancelAll();
  }
  
  String toTwoDigitString(int value) {
    return value.toString().padLeft(2, '0');
  }

}