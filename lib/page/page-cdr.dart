library management_tool.page.cdr;

import 'dart:async';
import 'dart:html';

import 'package:management_tool/controller.dart' as controller;
import 'package:management_tool/eventbus.dart';
import 'package:openreception_framework/model.dart' as model;

const String _libraryName = 'management_tool.page.cdr';

final Map<model.CdrEntryState, String> actorMap = {
  model.CdrEntryState.agentChannel: 'agentkanal',
  model.CdrEntryState.inboundNotNotified: 'pbx',
  model.CdrEntryState.notifiedAnsweredByAgent: 'agent',
  model.CdrEntryState.notifiedNotAnswered: 'ubesvaret',
  model.CdrEntryState.outboundByAgent: 'agent',
  model.CdrEntryState.outboundByPbx: 'pbx',
  model.CdrEntryState.unknown: 'ukendt'
};

final Map<model.CdrEntryState, String> directionMap = {
  model.CdrEntryState.agentChannel: 'agentkanal',
  model.CdrEntryState.inboundNotNotified: 'ind',
  model.CdrEntryState.notifiedAnsweredByAgent: 'ind',
  model.CdrEntryState.notifiedNotAnswered: 'ind',
  model.CdrEntryState.outboundByAgent: 'ud',
  model.CdrEntryState.outboundByPbx: 'ud',
  model.CdrEntryState.unknown: 'ukendt'
};

class Context {
  String name;
  String orgName;
  String recName;
  model.CdrEntry entry;
  model.CdrSummary summary;
}

class Cdr {
  final controller.Cdr _cdrCtrl;
  final controller.Contact _contactCtrl;
  SelectElement costAlertRatioSelect = new SelectElement()
    ..disabled = false
    ..style.height = '28px'
    ..style.marginLeft = '0.5em'
    ..title = 'Trafik alarm ratio'
    ..children = [
      new OptionElement()
        ..text = '0.8'
        ..value = '0.8',
      new OptionElement()
        ..text = '0.9'
        ..value = '0.9',
      new OptionElement()
        ..text = '1.0'
        ..value = '1.0'
        ..selected = true,
      new OptionElement()
        ..text = '1.1'
        ..value = '1.1',
      new OptionElement()
        ..text = '1.2'
        ..value = '1.2'
    ];
  SelectElement directionSelect = new SelectElement()
    ..disabled = true
    ..style.height = '28px'
    ..style.marginLeft = '0.5em'
    ..children = [
      new OptionElement()
        ..text = 'alt'
        ..value = 'both'
        ..selected = true,
      new OptionElement()
        ..text = 'ind'
        ..value = 'inbound',
      new OptionElement()
        ..text = 'ud'
        ..value = 'outbound'
    ];
  final DivElement element = new DivElement()
    ..id = 'cdr-page'
    ..hidden = true
    ..classes.addAll(['page']);
  ButtonElement fetchButton;
  final DivElement filter = new DivElement()..style.marginLeft = '0.5em';
  InputElement fromInput;
  SelectElement kindSelect = new SelectElement()
    ..style.height = '28px'
    ..children = [
      new OptionElement()
        ..text = 'summering'
        ..value = 'summary'
        ..selected = true,
      new OptionElement()
        ..text = 'liste'
        ..value = 'list',
      new OptionElement()
        ..text = 'dagsrapport'
        ..value = 'dailyreport'
    ];

  final DivElement listing = new DivElement()
    ..style.margin = '0 0 0 1em'
    ..style.flexGrow = '1'
    ..style.overflow = 'auto';
  final controller.Organization _orgCtrl;
  final controller.Reception _rcpCtrl;
  final SelectElement receptionSelect = new SelectElement()
    ..style.height = '28px'
    ..style.marginLeft = '0.5em';
  InputElement ridInput;
  InputElement toInput;
  final DivElement totals = new DivElement()
    ..style.margin = '0.5em 0 1em 1.5em';
  InputElement uidInput;
  final controller.User _userCtrl;
  final SelectElement userSelect = new SelectElement()
    ..style.height = '28px'
    ..disabled = true;
  static const String _viewName = 'cdr';

  Cdr(
      controller.Cdr this._cdrCtrl,
      controller.Contact this._contactCtrl,
      controller.Organization this._orgCtrl,
      controller.Reception this._rcpCtrl,
      controller.User this._userCtrl) {
    final DateTime now = new DateTime.now();
    final DateTime from = new DateTime(now.year, now.month, now.day);
    final DateTime to =
        new DateTime(now.year, now.month, now.day, 23, 59, 59, 999);

    fromInput = new InputElement()
      ..placeholder = 'ISO8601 fra tidsstempel'
      ..value = from.toIso8601String().split('.').first;
    toInput = new InputElement()
      ..placeholder = 'ISO8601 til tidsstempel'
      ..value = to.toIso8601String().split('.').first;

    ridInput = new InputElement()..placeholder = 'reception id';
    uidInput = new InputElement()
      ..placeholder = 'agent id'
      ..disabled = true;
    fetchButton = new ButtonElement()
      ..text = 'hent'
      ..classes.add('create')
      ..onClick.listen((_) => _fetch());

    filter
      ..children = [
        fromInput,
        toInput,
        kindSelect,
        directionSelect,
        costAlertRatioSelect,
        receptionSelect,
        ridInput,
        userSelect,
        uidInput,
        fetchButton,
      ];

    element.children = [filter, totals, listing];

    _observers();
  }

  Duration averageDuration(int seconds, int divisor) {
    if (divisor == 0 || divisor == null) {
      return new Duration(seconds: 0);
    }

    return (new Duration(seconds: seconds) ~/ divisor);
  }

  String epochToString(int epoch, {bool withDate: true}) {
    if (epoch == 0) {
      return '';
    } else {
      final String stamp = new DateTime.fromMillisecondsSinceEpoch(epoch * 1000)
          .toIso8601String()
          .split('.')
          .first;
      if (withDate) {
        return stamp.replaceAll('T', ' ');
      } else {
        return stamp.split('T').last;
      }
    }
  }

  Future _fetch() async {
    final DateTime from = DateTime.parse(fromInput.value);
    Map<String, dynamic> ridToNameMap;
    final DateTime to = DateTime.parse(toInput.value);
    Map<int, String> uidToNameMap = new Map<int, String>();

    listing.children.clear();
    totals.children.clear();

    fetchButton.disabled = true;
    fetchButton.style.backgroundColor = 'grey';
    fetchButton.text = 'Henter...';

    ridToNameMap = (await _orgCtrl.receptionMap());
    for (model.User user in (await _userCtrl.list())) {
      uidToNameMap[user.id] = user.name;
    }

    if (kindSelect.value == 'summary') {
      await _fetchSummaries(from, to, ridToNameMap);
    } else if (kindSelect.value == 'list') {
      await _fetchList(from, to, ridToNameMap, uidToNameMap);
    } else if (kindSelect.value == 'dailyreport') {
      await _fetchDaily(from, uidToNameMap);
    }

    receptionSelect.options.first.selected = true;
    userSelect.options.first.selected = true;

    fetchButton.disabled = false;
    fetchButton.style.backgroundColor = '';
    fetchButton.text = 'Hent';
  }

  Future _fetchDaily(DateTime from, Map<int, String> uidToNameMap) async {
    int answered = 0;
    int answered10 = 0;
    int answered10To20 = 0;
    int answeredAfter60 = 0;
    int inboundBillSeconds = 0;
    int inboundNotNotified = 0;
    int longCalls = 0;
    int notifiedNotAnswered = 0;
    int outboundAgent = 0;
    double outboundCost = 0.0;
    int outboundPbx = 0;
    int shortCalls = 0;
    final Map<String, dynamic> map = (await _cdrCtrl.daily(from));
    final List<TableRowElement> rows = new List<TableRowElement>();
    final TableElement table = new TableElement();
    final List<model.CdrSummary> summaries = new List<model.CdrSummary>();
    final List<model.CdrAgentSummary> agentSummaries =
        new List<model.CdrAgentSummary>();

    for (Map m in (map['summaries'] as List)) {
      final model.CdrSummary summary = new model.CdrSummary.fromJson(m);
      summaries.add(summary);
      agentSummaries.addAll(summary.agentSummaries);
    }

    Map<String, model.CdrAgentSummary> smap =
        new Map<String, model.CdrAgentSummary>();

    agentSummaries.forEach((model.CdrAgentSummary agentSummary) {
      answered += agentSummary.answered;
      answered10 += agentSummary.answered10;
      answered10To20 += agentSummary.answered10To20;
      answeredAfter60 += agentSummary.answeredAfter60;
      inboundBillSeconds += agentSummary.inboundBillSeconds;
      longCalls += agentSummary.longCalls;
      outboundAgent += agentSummary.outbound;
      shortCalls += agentSummary.shortCalls;

      if (smap.containsKey(uidToNameMap[agentSummary.uid])) {
        smap[uidToNameMap[agentSummary.uid]].add(agentSummary);
      } else {
        smap[uidToNameMap[agentSummary.uid]] = agentSummary;
      }
    });

    summaries.forEach((model.CdrSummary summary) {
      inboundNotNotified += summary.inboundNotNotified;
      notifiedNotAnswered += summary.notifiedNotAnswered;
      outboundCost += summary.outboundCost;
      outboundPbx += summary.outboundByPbx;
    });

    table.createTHead()
      ..children = [
        new TableCellElement()..text = 'agent',
        new TableCellElement()..text = 'reelle',
        new TableCellElement()..text = 'tildelt',
        new TableCellElement()..text = '< 10',
        new TableCellElement()..text = '> 60',
        new TableCellElement()..text = 'samtaletid',
        new TableCellElement()..text = 'gns. samtaletid',
        new TableCellElement()..text = 'udgående',
        new TableCellElement()..text = 'lange kald',
        new TableCellElement()..text = 'tomme kald'
      ]
      ..style.textAlign = 'center';

    final List<String> users =
        smap.keys.toList().where((u) => u != null).toList();
    users.sort();

    users.forEach((String user) {
      final model.CdrAgentSummary agentSummary = smap[user];
      rows.add(new TableRowElement()
        ..children = [
          new TableCellElement()
            ..text = user
            ..style.textAlign = 'left',
          new TableCellElement()
            ..text =
                (agentSummary.answered - agentSummary.shortCalls).toString()
            ..style.textAlign = 'center'
            ..style.fontWeight = 'bold',
          new TableCellElement()
            ..text = agentSummary.answered.toString()
            ..style.textAlign = 'center',
          new TableCellElement()
            ..text = agentSummary.answered10.toString()
            ..style.textAlign = 'center',
          new TableCellElement()
            ..text = agentSummary.answeredAfter60.toString()
            ..style.textAlign = 'center',
          new TableCellElement()
            ..text = new Duration(seconds: agentSummary.inboundBillSeconds)
                .toString()
                .split('.')
                .first
            ..style.textAlign = 'center',
          new TableCellElement()
            ..text = agentSummary.answered > 0
                ? (new Duration(seconds: agentSummary.inboundBillSeconds) ~/
                        agentSummary.answered)
                    .toString()
                    .split('.')
                    .first
                : new Duration().toString().split('.').first
            ..style.textAlign = 'center',
          new TableCellElement()
            ..text = agentSummary.outbound.toString()
            ..style.textAlign = 'center',
          new TableCellElement()
            ..text = agentSummary.longCalls.toString()
            ..style.textAlign = 'center',
          new TableCellElement()
            ..text = agentSummary.shortCalls.toString()
            ..style.textAlign = 'center'
        ]);
    });

    table.createTBody()..children = rows;

    listing.children = [table];

    setSummaryTotalsNode(
        answered + inboundNotNotified + notifiedNotAnswered,
        answered,
        answeredAfter60,
        answered10 + answered10To20,
        inboundNotNotified,
        notifiedNotAnswered,
        shortCalls,
        longCalls,
        outboundAgent,
        outboundCost,
        outboundPbx,
        inboundBillSeconds,
        map['callChargeMultiplier'],
        map['shortCallBoundaryInSeconds'],
        map['longCallBoundaryInSeconds'],
        false);
  }

  Future _fetchList(DateTime from, DateTime to,
      Map<String, dynamic> ridToNameMap, Map<int, String> uidToNameMap) async {
    final List<model.CdrEntry> answeredEntries = new List<model.CdrEntry>();
    final List<Context> contexts = new List<Context>();
    final Map<String, dynamic> map = (await _cdrCtrl.list(
        from, to, directionSelect.value, ridInput.value, uidInput.value));
    final List<TableRowElement> rows = new List<TableRowElement>();
    final TableElement table = new TableElement();
    int totalLongCalls = 0;
    int totalMissed = 0;
    int totalOutAgent = 0;
    int totalOutPbx = 0;
    int totalPbxAnswered = 0;
    int totalShortCalls = 0;

    final double callChargeMultiplier = map['callChargeMultiplier'];
    final int longCallBoundary = map['longCallBoundaryInSeconds'];
    final int shortCallBoundary = map['shortCallBoundaryInSeconds'];

    table.createTHead()
      ..children = [
        new TableCellElement()..text = 'start',
        new TableCellElement()..text = 'besvaret',
        new TableCellElement()..text = 'ventetid',
        new TableCellElement()..text = 'retning',
        new TableCellElement()..text = 'stop',
        new TableCellElement()..text = 'længde',
        new TableCellElement()..text = 'reception',
        new TableCellElement()..text = 'opkalder',
        new TableCellElement()..text = 'destination',
        new TableCellElement()..text = 'kontakt',
        new TableCellElement()..text = 'aktør',
        new TableCellElement()..text = 'cdr uuid'
      ]
      ..style.textAlign = 'center';
    listing.children = [table];

    for (Map m in (map['entries'] as List)) {
      final model.CdrEntry entry = new model.CdrEntry.fromJson(m);
      if (ridToNameMap.containsKey(entry.rid.toString())) {
        contexts.add(new Context()
          ..name = ridToNameMap[entry.rid.toString()]['organization'] +
              ridToNameMap[entry.rid.toString()]['reception']
          ..orgName = ridToNameMap[entry.rid.toString()]['organization']
          ..recName = ridToNameMap[entry.rid.toString()]['reception']
          ..entry = entry);
      } else {
        contexts.add(new Context()
          ..name = '.....${entry.rid.toString()}'
          ..orgName = ''
          ..recName = entry.rid.toString()
          ..entry = entry);
      }
    }

    contexts.sort((a, b) => a.entry.startEpoch.compareTo(b.entry.startEpoch));

    String answerTime(model.CdrEntry entry) => entry.agentBeginEpoch > 0
        ? '${epochToString(entry.agentBeginEpoch, withDate: false)}'
        : entry.answerEpoch > 0
            ? '${epochToString(entry.answerEpoch, withDate: false)}'
            : '';

    Duration callLength(model.CdrEntry entry) {
      Duration d;

      switch (entry.state) {
        case model.CdrEntryState.agentChannel:
        case model.CdrEntryState.notifiedNotAnswered:
        case model.CdrEntryState.unknown:
          d = new Duration(seconds: entry.endEpoch - entry.startEpoch);
          break;
        case model.CdrEntryState.inboundNotNotified:
          if (entry.externalTransferEpoch > 0) {
            d = new Duration(
                seconds: entry.externalTransferEpoch - entry.answerEpoch);
          } else if (entry.answerEpoch > 0) {
            d = new Duration(seconds: entry.endEpoch - entry.answerEpoch);
          } else {
            d = new Duration(seconds: entry.endEpoch - entry.startEpoch);
          }
          break;
        case model.CdrEntryState.notifiedAnsweredByAgent:
          if (entry.externalTransferEpoch > 0) {
            d = new Duration(
                seconds: entry.externalTransferEpoch - entry.agentBeginEpoch);
          } else if (entry.agentEndEpoch > 0) {
            d = new Duration(
                seconds: entry.agentEndEpoch - entry.agentBeginEpoch);
          } else {
            d = new Duration(seconds: entry.endEpoch - entry.agentBeginEpoch);
          }
          break;
        case model.CdrEntryState.outboundByAgent:
        case model.CdrEntryState.outboundByPbx:
          if (entry.answerEpoch > 0) {
            d = new Duration(seconds: entry.endEpoch - entry.answerEpoch);
          } else {
            d = new Duration(seconds: entry.endEpoch - entry.startEpoch);
          }
      }

      return d;
    }

    String endTime(model.CdrEntry entry) => entry.agentEndEpoch > 0
        ? '${epochToString(entry.agentEndEpoch, withDate: false)}'
        : entry.externalTransferEpoch > 0
            ? '${epochToString(entry.externalTransferEpoch, withDate: false)}'
            : entry.endEpoch > 0
                ? '${epochToString(entry.endEpoch, withDate: false)}'
                : '';

    String waitDuration(model.CdrEntry entry) {
      Duration d;

      switch (entry.state) {
        case model.CdrEntryState.agentChannel:
        case model.CdrEntryState.notifiedNotAnswered:
        case model.CdrEntryState.unknown:
          return '';
        case model.CdrEntryState.inboundNotNotified:
          d = new Duration(seconds: entry.answerEpoch - entry.startEpoch);
          break;
        case model.CdrEntryState.notifiedAnsweredByAgent:
          d = new Duration(seconds: entry.agentBeginEpoch - entry.startEpoch);
          break;
        case model.CdrEntryState.outboundByAgent:
        case model.CdrEntryState.outboundByPbx:
          if (entry.answerEpoch > 0) {
            d = new Duration(seconds: entry.answerEpoch - entry.startEpoch);
          } else {
            d = new Duration(seconds: entry.endEpoch - entry.startEpoch);
          }
      }

      return d.toString().split('.').first;
    }

    for (Context c in contexts) {
      final Duration lengthOfCall = callLength(c.entry);
      final String lengthOfCallColor =
          directionMap[c.entry.state] == 'ind' && answerTime(c.entry).isNotEmpty
              ? lengthOfCall.inSeconds <= shortCallBoundary
                  ? 'red'
                  : lengthOfCall.inSeconds >= longCallBoundary ? 'blue' : ''
              : '';

      if (c.entry.state == model.CdrEntryState.notifiedAnsweredByAgent) {
        answeredEntries.add(c.entry);
        if (lengthOfCall.inSeconds <= shortCallBoundary) {
          totalShortCalls += 1;
        } else if (lengthOfCall.inSeconds >= longCallBoundary) {
          totalLongCalls += 1;
        }
      }

      if (c.entry.state == model.CdrEntryState.inboundNotNotified) {
        totalPbxAnswered += 1;
      }

      if (c.entry.state == model.CdrEntryState.notifiedNotAnswered) {
        totalMissed += 1;
      }

      if (c.entry.state == model.CdrEntryState.outboundByAgent) {
        totalOutAgent += 1;
      }

      if (c.entry.state == model.CdrEntryState.outboundByPbx) {
        totalOutPbx += 1;
      }

      rows.add(new TableRowElement()
        ..onClick.listen((MouseEvent event) {
          final Element target = event.currentTarget;
          final String bc = target.style.backgroundColor;
          if (bc == '') {
            target.style.backgroundColor = 'orange';
          } else {
            target.style.backgroundColor = '';
          }
        })
        ..children = [
          new TableCellElement()
            ..title = c.entry.state.toString().split('.').last
            ..text = epochToString(c.entry.startEpoch),
          new TableCellElement()
            ..style.textAlign = 'center'
            ..text = answerTime(c.entry)
            ..title = 'besvaret',
          new TableCellElement()
            ..style.textAlign = 'center'
            ..text = waitDuration(c.entry).toString().split('.').first
            ..title = 'ventetid',
          new TableCellElement()
            ..style.textAlign = 'center'
            ..text = directionMap[c.entry.state],
          new TableCellElement()..text = endTime(c.entry),
          new TableCellElement()
            ..style.textAlign = 'center'
            ..text = lengthOfCall.toString().split('.').first
            ..title = 'længde'
            ..style.color = lengthOfCallColor,
          new TableCellElement()..text = c.recName,
          new TableCellElement()
            ..text = c.entry.sipFromUserStripped
            ..title = 'opkalder',
          new TableCellElement()
            ..text = c.entry.destination
            ..title = 'destination',
          new TableCellElement()
            ..children = c.entry.cid > 0
                ? [
                    new SpanElement()
                      ..onClick.first.asStream().listen((MouseEvent event) {
                        event.stopPropagation();
                        _contactCtrl
                            .get(c.entry.cid)
                            .then((model.BaseContact contact) {
                          (event.target as SpanElement)
                            ..text = contact.fullName
                            ..title = 'cid: ${c.entry.cid.toString()}'
                            ..style.textDecoration = ''
                            ..style.cursor = '';
                        });
                      })
                      ..style.textDecoration = 'underline'
                      ..style.cursor = 'pointer'
                      ..text = c.entry.cid.toString()
                  ]
                : []
            ..title = 'kontaktperson',
          new TableCellElement()
            ..text = actorMap[c.entry.state] == 'agent'
                ? uidToNameMap[c.entry.uid]
                : actorMap[c.entry.state],
          new TableCellElement()
            ..text = c.entry.uuid
            ..title = c.entry.filename
            ..style.cursor =
                c.entry.answerEpoch > 0 && actorMap[c.entry.state] == 'agent'
                    ? 'pointer'
                    : ''
            ..style.textDecoration =
                c.entry.answerEpoch > 0 && actorMap[c.entry.state] == 'agent'
                    ? 'underline'
                    : ''
            ..onMouseOver.listen((MouseEvent event) {
              if (c.entry.answerEpoch > 0 &&
                  actorMap[c.entry.state] == 'agent') {
                (event.target as Element).style.color = 'blue';
              }
            })
            ..onMouseOut.listen((MouseEvent event) {
              if (c.entry.answerEpoch > 0 &&
                  actorMap[c.entry.state] == 'agent') {
                (event.target as Element).style.color = '';
              }
            })
            ..onClick.listen((_) {
              if (c.entry.answerEpoch > 0 &&
                  actorMap[c.entry.state] == 'agent') {
                window.open(
                    'https://drive.google.com/drive/search?q=${c.entry.uuid}',
                    '');
              }
            })
        ]);
    }

    table.createTBody()..children = rows;

    setListTotalsNode(
        answeredEntries,
        totalMissed,
        totalPbxAnswered,
        totalOutAgent,
        totalOutPbx,
        callChargeMultiplier,
        shortCallBoundary,
        longCallBoundary,
        totalLongCalls,
        totalShortCalls);
  }

  Future _fetchSummaries(
      DateTime from, DateTime to, Map<String, dynamic> ridToNameMap) async {
    final List<Context> contexts = new List<Context>();
    final Map<String, dynamic> map =
        (await _cdrCtrl.summaries(from, to, ridInput.value));
    final List<TableRowElement> rows = new List<TableRowElement>();
    final TableElement table = new TableElement();

    table.createTHead()
      ..children = [
        new TableCellElement()..text = 'organisation',
        new TableCellElement()..text = 'reception',
        new TableCellElement()..text = 'ind total',
        new TableCellElement()..text = 'trafik',
        new TableCellElement()..text = 'besvarede',
        new TableCellElement()..text = 'udgående',
        new TableCellElement()..text = 'voicesvar',
        new TableCellElement()..text = 'mistede',
        new TableCellElement()..text = 'gns. samtaletid',
        new TableCellElement()..text = 'tomme kald',
        new TableCellElement()..text = 'lange kald'
      ]
      ..style.textAlign = 'center';
    listing.children = [table];

    /// Reset total counters and tbody element.
    table.querySelector('tbody')?.remove();
    int totalAnswered = 0;
    int totalAnsweredAfter60 = 0;
    int totalAnsweredBefore20 = 0;
    int totalInbound = 0;
    int totalInboundBillSec = 0;
    int totalInboundNotNotified = 0;
    int totalLongCalls = 0;
    int totalNotifiedNotAnswered = 0;
    int totalOutboundAgent = 0;
    int totalOutboundPbx = 0;
    double totalOutboundCost = 0.0;
    int totalShortCalls = 0;

    for (Map m in (map['summaries'] as List)) {
      final model.CdrSummary summary = new model.CdrSummary.fromJson(m);
      if (ridToNameMap.containsKey(summary.rid.toString())) {
        contexts.add(new Context()
          ..name = ridToNameMap[summary.rid.toString()]['organization'] +
              ridToNameMap[summary.rid.toString()]['reception']
          ..orgName = ridToNameMap[summary.rid.toString()]['organization']
          ..recName = ridToNameMap[summary.rid.toString()]['reception']
          ..summary = summary);
      } else {
        contexts.add(new Context()
          ..name = '.....${summary.rid.toString()}'
          ..orgName = ''
          ..recName = summary.rid.toString()
          ..summary = summary);
      }
    }

    contexts
        .sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    for (Context c in contexts) {
      final int answered = c.summary.agentSummaries
          .fold(0, (acc, model.CdrAgentSummary a) => acc + a.answered);
      final int answered10 = c.summary.agentSummaries
          .fold(0, (acc, model.CdrAgentSummary a) => acc + a.answered10);
      final int answered10To20 = c.summary.agentSummaries
          .fold(0, (acc, model.CdrAgentSummary a) => acc + a.answered10To20);
      final int answered20To60 = c.summary.agentSummaries
          .fold(0, (acc, model.CdrAgentSummary a) => acc + a.answered20To60);
      final int answeredAfter60 = c.summary.agentSummaries
          .fold(0, (acc, model.CdrAgentSummary a) => acc + a.answeredAfter60);
      final int inboundBillSeconds = c.summary.agentSummaries.fold(
          0, (acc, model.CdrAgentSummary a) => acc + a.inboundBillSeconds);
      final int longCalls = c.summary.agentSummaries
          .fold(0, (acc, model.CdrAgentSummary a) => acc + a.longCalls);
      final int outboundAgent = c.summary.agentSummaries
          .fold(0, (acc, model.CdrAgentSummary a) => acc + a.outbound);
      final int shortCalls = c.summary.agentSummaries
          .fold(0, (acc, model.CdrAgentSummary a) => acc + a.shortCalls);

      totalAnswered += answered;
      totalAnsweredAfter60 += answeredAfter60;
      totalAnsweredBefore20 += answered10 + answered10To20;
      totalInbound += (answered +
          c.summary.notifiedNotAnswered +
          c.summary.inboundNotNotified);
      totalInboundBillSec += inboundBillSeconds;
      totalInboundNotNotified += c.summary.inboundNotNotified;
      totalLongCalls += longCalls;
      totalNotifiedNotAnswered += c.summary.notifiedNotAnswered;
      totalOutboundAgent += outboundAgent;
      totalOutboundCost += c.summary.outboundCost;
      totalOutboundPbx += c.summary.outboundByPbx;
      totalShortCalls += shortCalls;

      bool costAlert = false;
      final int inboundCount = answered +
          c.summary.inboundNotNotified +
          c.summary.notifiedNotAnswered;
      if (inboundCount > 0) {
        final double maxRatio = double.parse(costAlertRatioSelect.value);
        final double ratio = (c.summary.outboundCost / 100) / inboundCount;
        if (ratio > maxRatio) {
          costAlert = true;
        }
      }

      rows.add(new TableRowElement()
        ..onClick.listen((MouseEvent event) {
          final Element target = event.currentTarget;
          final String bc = target.style.backgroundColor;
          if (bc == '') {
            target.style.backgroundColor = 'orange';
          } else {
            target.style.backgroundColor = '';
          }
        })
        ..children = [
          new TableCellElement()..text = c.orgName,
          new TableCellElement()
            ..text = c.recName
            ..title = c.summary.rid.toString(),
          new TableCellElement()
            ..style.textAlign = 'center'
            ..text = inboundCount.toString()
            ..title = 'Ind total',
          new TableCellElement()
            ..style.textAlign = 'right'
            ..style.color = costAlert ? 'red' : ''
            ..style.fontWeight = costAlert ? 'bold' : ''
            ..text = (c.summary.outboundCost / 100).toString()
            ..title = 'Trafik',
          new TableCellElement()
            ..style.textAlign = 'right'
            ..children = [
              new SpanElement()
                ..text = '$answered'
                ..title = 'Besvarede',
              new SpanElement()
                ..style.color = 'grey'
                ..style.paddingLeft = '0.5em'
                ..text =
                    '($answered10 / $answered10To20 / $answered20To60 / $answeredAfter60)'
                ..title = '>10, 10-20, 20-60, >60'
            ],
          new TableCellElement()
            ..style.textAlign = 'center'
            ..text = (c.summary.outboundByPbx + outboundAgent).toString()
            ..title = 'Udgående',
          new TableCellElement()
            ..style.textAlign = 'center'
            ..text = c.summary.inboundNotNotified > 0
                ? c.summary.inboundNotNotified.toString()
                : ''
            ..title = 'Voicesvar',
          new TableCellElement()
            ..style.textAlign = 'center'
            ..text = c.summary.notifiedNotAnswered > 0
                ? c.summary.notifiedNotAnswered.toString()
                : ''
            ..title = 'Mistede',
          new TableCellElement()
            ..style.textAlign = 'right'
            ..text = averageDuration(inboundBillSeconds, answered)
                .toString()
                .split('.')
                .first
            ..title = 'Gns. samtaletid',
          new TableCellElement()
            ..style.textAlign = 'center'
            ..text = '$shortCalls'
            ..title = 'Tomme kald',
          new TableCellElement()
            ..style.textAlign = 'center'
            ..text = '$longCalls'
            ..title = 'Lange kald'
        ]);
    }

    table.createTBody()..children = rows;

    setSummaryTotalsNode(
        totalInbound,
        totalAnswered,
        totalAnsweredAfter60,
        totalAnsweredBefore20,
        totalInboundNotNotified,
        totalNotifiedNotAnswered,
        totalShortCalls,
        totalLongCalls,
        totalOutboundAgent,
        totalOutboundCost,
        totalOutboundPbx,
        totalInboundBillSec,
        map['callChargeMultiplier'],
        map['shortCallBoundaryInSeconds'],
        map['longCallBoundaryInSeconds'],
        true);
  }

  void kindSelectUpdate(String kind) {
    if (kind == 'summary') {
      costAlertRatioSelect.disabled = false;
      directionSelect.options.first.selected = true;
      directionSelect.disabled = true;
      receptionSelect.disabled = false;
      ridInput.disabled = false;
      toInput.disabled = false;
      userSelect.options.first.selected = true;
      userSelect.disabled = true;
      uidInput.disabled = true;
      uidInput.value = '';
    } else if (kind == 'list') {
      costAlertRatioSelect.disabled = true;
      directionSelect.options.first.selected = true;
      directionSelect.disabled = false;
      receptionSelect.disabled = false;
      ridInput.disabled = false;
      toInput.disabled = false;
      userSelect.options.first.selected = true;
      userSelect.disabled = false;
      uidInput.disabled = false;
    } else if (kind == 'dailyreport') {
      costAlertRatioSelect.disabled = true;
      directionSelect.options.first.selected = true;
      directionSelect.disabled = true;
      receptionSelect.disabled = true;
      ridInput.disabled = true;
      toInput.disabled = true;
      userSelect.options.first.selected = true;
      userSelect.disabled = true;
      uidInput.disabled = true;
      uidInput.value = '';
    }
  }

  void _observers() {
    bus.on(WindowChanged).listen((WindowChanged event) async {
      if (event.window == _viewName) {
        element.hidden = false;
        element.style.display = 'flex';
        element.style.flexDirection = 'column';

        rcpList(Iterable<model.Reception> receptions) {
          final List<model.Reception> list = receptions.toList();
          list.sort((model.Reception a, b) =>
              a.fullName.toLowerCase().compareTo(b.fullName.toLowerCase()));
          final List<OptionElement> options = new List<OptionElement>();
          receptionSelect.children.add(new OptionElement()
            ..text = 'filtrer efter receptioner...'
            ..disabled = true
            ..selected = true);
          for (model.Reception reception in list) {
            options.add(new OptionElement()
              ..text = reception.fullName
              ..value = reception.ID.toString());
          }
          receptionSelect.children.addAll(options);
        }

        userList(Iterable<model.User> users) {
          final List<model.User> list = users
              .where(
                  (model.User user) => user.address.isNotEmpty && user.id > 0)
              .toList();
          list.sort((model.User a, b) =>
              a.name.toLowerCase().compareTo(b.name.toLowerCase()));
          final List<OptionElement> options = new List<OptionElement>();
          userSelect.children.add(new OptionElement()
            ..text = 'filtrer efter agent...'
            ..disabled = true
            ..selected = true);
          userSelect.children.add(new OptionElement()
            ..text = 'pbx'
            ..value = '0');
          for (model.User user in list) {
            options.add(new OptionElement()
              ..text = user.name
              ..value = user.id.toString());
          }
          userSelect.children.addAll(options);
        }

        Future.wait([_rcpCtrl.list(), _userCtrl.list()]).then((results) {
          rcpList(results.first);
          userList(results.last);

          if (event.data.isNotEmpty) {
            kindSelect.options.forEach((OptionElement o) {
              if (o.value == event.data['cdrKind']) {
                o.selected = true;
                kindSelectUpdate(o.value);
              }
            });

            if (event.data.containsKey('from') &&
                event.data.containsKey('to')) {
              final DateTime from = event.data['from'];
              final DateTime to = event.data['to'];
              fromInput.value = from.toIso8601String().split('.').first;
              toInput.value = to.toIso8601String().split('.').first;
            }

            if (event.data.containsKey('uid')) {
              uidInput.value = event.data['uid'];
              ridInput.value = '';
              directionSelect.options.first.selected = true;
              fetchButton.click();
            }
          }
        });
      } else {
        element.hidden = true;
        element.style.display = '';
        element.style.flexDirection = '';
      }
    });

    kindSelect.onChange.listen((Event event) {
      final SelectElement se = (event.target as SelectElement);
      kindSelectUpdate(se.value);
    });

    receptionSelect.onChange.listen((Event event) {
      final SelectElement se = (event.target as SelectElement);
      if (se.value.isNotEmpty) {
        if (ridInput.value.trim().isNotEmpty) {
          ridInput.value = ridInput.value + ',';
        }
        ridInput.value = ridInput.value + se.value;
      }
    });

    userSelect.onChange.listen((Event event) {
      final SelectElement se = (event.target as SelectElement);
      if (se.value.isNotEmpty) {
        if (uidInput.value.trim().isNotEmpty) {
          uidInput.value = uidInput.value + ',';
        }
        uidInput.value = uidInput.value + se.value;
      }
    });

    void checkFromAndTo() {
      try {
        final DateTime from = DateTime.parse(fromInput.value);
        final DateTime to = DateTime.parse(toInput.value);

        if (from.isBefore(to)) {
          kindSelect.disabled = false;
          fetchButton.disabled = false;
          fetchButton.style.backgroundColor = '';
          fetchButton.text = 'Hent';
        } else {
          throw 'from is after to';
        }
      } catch (_) {
        kindSelect.disabled = true;
        fetchButton.disabled = true;
        fetchButton.style.backgroundColor = 'grey';
        fetchButton.text = '....';
      }
    }

    fromInput.onInput.listen((_) {
      checkFromAndTo();
    });

    toInput.onInput.listen((_) {
      checkFromAndTo();
    });
  }

  /**
   * Populate the list totals node.
   */
  void setListTotalsNode(
      List<model.CdrEntry> answeredEntries,
      int totalMissed,
      int totalPbxAnswered,
      int totalOutAgent,
      int totalOutPbx,
      double callChargeMultiplier,
      int shortCallBoundaryInSeconds,
      int longCallBoundaryInSeconds,
      int longCalls,
      int shortCalls) {
    final int above60 = answeredEntries
        .where((model.CdrEntry entry) =>
            entry.agentBeginEpoch - entry.startEpoch > 60)
        .length;
    final int less10 = answeredEntries
        .where((model.CdrEntry entry) =>
            entry.agentBeginEpoch - entry.startEpoch <= 10)
        .length;
    final int less20 = answeredEntries
        .where((model.CdrEntry entry) =>
            entry.agentBeginEpoch - entry.startEpoch <= 20)
        .length;
    final Duration totalSpeakTime = new Duration(
        seconds: answeredEntries.fold(
            0, (acc, model.CdrEntry entry) => acc + entry.billSec));
    final DivElement sumsIn = new DivElement()
      ..text =
          'Total ind: ${answeredEntries.length + totalPbxAnswered + totalMissed}'
          ' / Agent: ${answeredEntries.length}'
          ' / PBX: $totalPbxAnswered'
          ' / Mistede: $totalMissed';
    final DivElement sumsOut = new DivElement()
      ..text = 'Total ud: ${totalOutAgent + totalOutPbx}'
          ' / Agent: $totalOutAgent'
          ' / PBX: $totalOutPbx';

    totals..children = [sumsIn, sumsOut];

    if (answeredEntries.isNotEmpty) {
      final DivElement stats = new DivElement()
        ..text =
            '<= 10: $less10 (${((less10 / answeredEntries.length) * 100.0).toStringAsFixed(2)}%)'
            ' / <= 20: $less20 (${((less20 / answeredEntries.length) * 100).toStringAsFixed(2)}%)'
            ' / >60: $above60 (${((above60 / answeredEntries.length) * 100).toStringAsFixed(2)}%)';
      final DivElement averages = new DivElement()
        ..text =
            'Total agent samtaletid: ${totalSpeakTime.toString().split('.').first}'
            ' / Gns. agent samtaletid: ${(totalSpeakTime ~/ answeredEntries.length).toString().split('.').first}';
      final DivElement boundaries = new DivElement()
        ..text = 'Tomme kald: $shortCalls'
            ' / Lange kald: $longCalls';
      // ' / shortCallBoundary: $shortCallBoundaryInSeconds'
      // ' / longCallBoundary: $longCallBoundaryInSeconds'
      // ' / takstjustering: $callChargeMultiplier';
      totals..children.addAll([stats, averages, boundaries]);
    }
  }

  /**
   * Populate the summary totals node.
   */
  void setSummaryTotalsNode(
      int totalInbound,
      int totalAnswered,
      int totalAnsweredAfter60,
      int totalAnsweredBefore20,
      int totalInboundNotNotified,
      int totalNotifiedNotAnswered,
      int totalShortCalls,
      int totalLongCalls,
      int totalOutboundAgent,
      double totalOutboundCost,
      int totalOutboundPbx,
      int totalInboundBillSec,
      double callChargeMultiplier,
      int shortCallBoundaryInSeconds,
      int longCallBoundaryInSeconds,
      bool printMeta) {
    final DivElement inboundData = new DivElement()
      ..text = 'Total ind: $totalInbound'
          ' / Svarede: $totalAnswered'
          ' / <=20: ${(totalAnsweredBefore20 / totalAnswered * 100).toStringAsFixed(2)}%'
          ' / >60: ${(totalAnsweredAfter60 / totalAnswered * 100).toStringAsFixed(2)}%'
          ' / Gns. samtaletid: ${averageDuration(totalInboundBillSec, totalAnswered).toString().split('.').first}'
          ' / Voicesvar: $totalInboundNotNotified'
          ' / Mistede: $totalNotifiedNotAnswered';
    String meta = 'Tomme kald: $totalShortCalls'
        ' / Lange kald: $totalLongCalls';
    if (printMeta) {
      // meta += ' / shortCallBoundary: $shortCallBoundaryInSeconds'
      //     ' / longCallBoundary: $longCallBoundaryInSeconds'
      //     ' / takstjustering: $callChargeMultiplier';
      meta += ' / takstjustering: $callChargeMultiplier';
    }
    final DivElement metadata = new DivElement()..text = meta;
    final DivElement outboundData = new DivElement()
      ..text = 'Udgående agent: $totalOutboundAgent'
          ' / Udgående PBX: $totalOutboundPbx'
          ' / Teleomkostning: ${totalOutboundCost / 100}';
    totals..children = [inboundData, outboundData, metadata];
  }
}
