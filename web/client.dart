import 'dart:async';
import 'dart:html';

import 'package:logging/logging.dart';
import 'package:management_tool/configuration.dart';
import 'package:management_tool/controller.dart' as controller;
import 'package:management_tool/page/page-cdr.dart' as page;
import 'package:management_tool/page/page-dialplan.dart' as page;
import 'package:management_tool/page/page-ivr.dart' as page;
import 'package:management_tool/page/page-message.dart' as page;
import 'package:management_tool/page/page-organization.dart' as page;
import 'package:management_tool/page/page-reception.dart' as page;
import 'package:management_tool/page/page-user.dart' as page;
import 'package:management_tool/view.dart' as view;
import 'package:openreception_framework/model.dart' as model;
import 'package:openreception_framework/service-html.dart' as transport;
import 'package:openreception_framework/service.dart' as service;

import 'lib/auth.dart';
import 'menu.dart';
import 'views/contact-view.dart' as conView;

controller.Popup notify = controller.popup;

Future main() async {
  final Uri appUri = Uri.parse(window.location.href);
  final String token = getToken(appUri);
  model.User user;
  Iterable<model.UserGroup> userGroups;

  Logger.root.level = Level.ALL;
  Logger.root.onRecord.listen(print);
  Logger _log = Logger.root;

  final transport.Client client = new transport.Client();
  config.clientConfig =
      await (new service.RESTConfiguration(config.configUri, client))
          .clientConfig();

  if (token == null) {
    login();
  } else {
    try {
      user = await getUser(config.clientConfig.authServerUri, token);
    } catch (error) {
      _log.info('No user found for token $token - redirecting to login');
      login();
    }
  }

  userGroups =
      await getUserGroup(user, config.clientConfig.userServerUri, token);

  if (userGroups.any((model.UserGroup g) =>
      g.name == 'Administrator' || g.name == 'Service agent')) {
    config.token = token;

    /// Initialize the stores.
    final service.RESTUserStore userStore = new service.RESTUserStore(
        config.clientConfig.userServerUri, config.token, client);
    final service.RESTDistributionListStore dlistStore =
        new service.RESTDistributionListStore(
            config.clientConfig.contactServerUri, config.token, client);
    final service.RESTEndpointStore epStore = new service.RESTEndpointStore(
        config.clientConfig.contactServerUri, config.token, client);
    final service.RESTReceptionStore receptionStore =
        new service.RESTReceptionStore(
            config.clientConfig.receptionServerUri, config.token, client);
    final service.RESTOrganizationStore organizationStore =
        new service.RESTOrganizationStore(
            config.clientConfig.receptionServerUri, config.token, client);
    final service.RESTContactStore contactStore = new service.RESTContactStore(
        config.clientConfig.contactServerUri, config.token, client);
    final service.RESTCalendarStore calendarStore =
        new service.RESTCalendarStore(
            config.clientConfig.calendarServerUri, config.token, client);
    final service.RESTDialplanStore dialplanStore =
        new service.RESTDialplanStore(
            config.clientConfig.dialplanServerUri, config.token, client);
    final service.RESTIvrStore ivrStore = new service.RESTIvrStore(
        config.clientConfig.dialplanServerUri, config.token, client);

    final service.RESTMessageStore messageStore = new service.RESTMessageStore(
        config.clientConfig.messageServerUri, config.token, client);

    /// Controllers
    final controller.Cdr cdrController =
        new controller.Cdr(config.clientConfig.cdrServerUri, config.token);
    final controller.DistributionList dlistController =
        new controller.DistributionList(dlistStore);
    final controller.Endpoint epController = new controller.Endpoint(epStore);
    final controller.Reception receptionController =
        new controller.Reception(receptionStore);
    final controller.Organization organizationController =
        new controller.Organization(organizationStore);
    final controller.Contact contactController =
        new controller.Contact(contactStore);
    final controller.Calendar calendarController =
        new controller.Calendar(calendarStore);
    final controller.Dialplan dialplanController =
        new controller.Dialplan(dialplanStore, receptionStore);
    final controller.Message messageController =
        new controller.Message(messageStore);
    final controller.User userController = new controller.User(userStore);

    final controller.Ivr ivrController =
        new controller.Ivr(ivrStore, dialplanStore);

    final page.Cdr cdrPage = new page.Cdr(cdrController, contactController,
        organizationController, receptionController, userController);

    final page.OrganizationView orgPage =
        new page.OrganizationView(organizationController, receptionController);

    querySelector('#cdr-page').replaceWith(cdrPage.element);

    querySelector("#organization-page").replaceWith(orgPage.element);

    view.Reception receptionView = new view.Reception(receptionController,
        organizationController, dialplanController, calendarController);

    querySelector("#reception-page").replaceWith(new page.ReceptionView(
            contactController, receptionController, receptionView)
        .element);

    new conView.ContactView(
        querySelector('#contact-page'),
        contactController,
        organizationController,
        receptionController,
        calendarController,
        dlistController,
        epController,
        receptionView);

    final messagePage = new page.Message(contactController, messageController,
        receptionController, userController);
    final dialplanPage = new page.Dialplan(dialplanController);

    querySelector('#message-page').replaceWith(messagePage.element);
    querySelector('#dialplan-page').replaceWith(dialplanPage.element);

    querySelector('#ivr-page').replaceWith(new page.Ivr(ivrController).element);
    querySelector("#user-page")
        .replaceWith(new page.UserPage(userController).element);

    new Menu(querySelector('nav#navigation'));

    /// Verify that we support HTMl5 notifications
    if (Notification.supported) {
      Notification
          .requestPermission()
          .then((String perm) => _log.info('HTML5 permission ${perm}'));
    } else {
      _log.shout('HTML5 notifications not supported.');
    }
  } else {
    _log.info('Access not allowed for user "$user.name" with token $token');
    document.body.text = 'Forbidden';
  }
}

/**
 * Return the value of the URL path parameter 'settoken'
 */
String getToken(Uri appUri) => appUri.queryParameters['settoken'];

/**
 * Return the current user.
 */
Future<model.User> getUser(Uri authServerUri, String token) {
  service.Authentication authService =
      new service.Authentication(authServerUri, token, new transport.Client());

  return authService.userOf(token);
}

/**
 * Return the current user.
 */
Future<Iterable<model.UserGroup>> getUserGroup(
    model.User user, Uri userServerUri, String token) {
  service.RESTUserStore userService =
      new service.RESTUserStore(userServerUri, token, new transport.Client());

  return userService.userGroups(user.id);
}
