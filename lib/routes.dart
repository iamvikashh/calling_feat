import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:awesome_notifications_example/pages/phone_call_page.dart';
import 'package:flutter/material.dart';
import 'package:awesome_notifications_example/pages/home_page.dart';

const String PAGE_HOME = '/';
const String PAGE_MEDIA_DETAILS = '/media-details';
const String PAGE_NOTIFICATION_DETAILS = '/notification-details';
const String PAGE_FIREBASE_TESTS = '/firebase-tests';
const String PAGE_PHONE_CALL = '/phone-call';

Map<String, WidgetBuilder> materialRoutes = {
  PAGE_HOME: (context) => HomePage(),
  PAGE_PHONE_CALL: (context) =>
      PhoneCallPage(receivedAction: ModalRoute.of(context)!.settings.arguments as ReceivedAction)
};
