library auth;

import 'dart:html';

import 'package:management_tool/configuration.dart';

/**Sends the user to the login site.*/
void login() {
  String loginUrl =
      '${config.clientConfig.authServerUri}/token/create?returnurl=${window.location}';
  window.location.assign(loginUrl);
}
