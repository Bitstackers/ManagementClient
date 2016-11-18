part of management_tool.view;

class EndpointChange {
  final Change type;
  final model.MessageEndpoint endpoint;

  EndpointChange.create(this.endpoint) : type = Change.created;
  EndpointChange.delete(this.endpoint) : type = Change.deleted;
  EndpointChange.update(this.endpoint) : type = Change.updated;

  String toString() => '$type $endpoint';

  int get hashCode => endpoint.toString().hashCode;
}

/**
 * Visual representation of an endpoint collection belonging to a contact.
 */
class Endpoints {
  final RegExp _emailRegex = new RegExp(
      r"^((([a-z]|\d|[!#\$%&'\*\+\-\/=\?\^_`{\|}~]|[\u00A0-\uD7FF\uF900-\uFDCF\uFDF0-\uFFEF])+(\.([a-z]|\d|[!#\$%&'\*\+\-\/=\?\^_`{\|}~]|[\u00A0-\uD7FF\uF900-\uFDCF\uFDF0-\uFFEF])+)*)|((\x22)((((\x20|\x09)*(\x0d\x0a))?(\x20|\x09)+)?(([\x01-\x08\x0b\x0c\x0e-\x1f\x7f]|\x21|[\x23-\x5b]|[\x5d-\x7e]|[\u00A0-\uD7FF\uF900-\uFDCF\uFDF0-\uFFEF])|(\\([\x01-\x09\x0b\x0c\x0d-\x7f]|[\u00A0-\uD7FF\uF900-\uFDCF\uFDF0-\uFFEF]))))*(((\x20|\x09)*(\x0d\x0a))?(\x20|\x09)+)?(\x22)))@((([a-z]|\d|[\u00A0-\uD7FF\uF900-\uFDCF\uFDF0-\uFFEF])|(([a-z]|\d|[\u00A0-\uD7FF\uF900-\uFDCF\uFDF0-\uFFEF])([a-z]|\d|-|\.|_|~|[\u00A0-\uD7FF\uF900-\uFDCF\uFDF0-\uFFEF])*([a-z]|\d|[\u00A0-\uD7FF\uF900-\uFDCF\uFDF0-\uFFEF])))\.)+(([a-z]|[\u00A0-\uD7FF\uF900-\uFDCF\uFDF0-\uFFEF])|(([a-z]|[\u00A0-\uD7FF\uF900-\uFDCF\uFDF0-\uFFEF])([a-z]|\d|-|\.|_|~|[\u00A0-\uD7FF\uF900-\uFDCF\uFDF0-\uFFEF])*([a-z]|[\u00A0-\uD7FF\uF900-\uFDCF\uFDF0-\uFFEF])))$");
  Logger _log = new Logger('$_libraryName.Endpoints');
  final RegExp _numeric = new RegExp(r'^-?[0-9]+$');

  Function onChange;

  final controller.Contact _contactController;
  final controller.Endpoint _endpointController;

  final DivElement element = new DivElement();
  final DivElement _header = new DivElement()
    ..style.display = 'flex'
    ..style.justifyContent = 'space-between'
    ..style.alignItems = 'flex-end'
    ..style.width = '97%'
    ..style.paddingLeft = '10px';
  final DivElement _buttons = new DivElement();
  bool _validationError = false;
  bool get validationError => _validationError;

  final ButtonElement _addNew = new ButtonElement()
    ..text = 'Indsæt ny tom'
    ..classes.add('create');

  final ButtonElement _foldJson = new ButtonElement()
    ..text = 'Fold sammen'
    ..classes.add('create')
    ..hidden = true;

  final HeadingElement _label = new HeadingElement.h3()
    ..text = 'Beskedadresser'
    ..style.margin = '0px'
    ..style.padding = '0px 0px 4px 0px';

  final TextAreaElement _endpointsInput = new TextAreaElement()
    ..classes.add('wide');

  final ButtonElement _unfoldJson = new ButtonElement()
    ..text = 'Fold ud'
    ..classes.add('create');

  List<model.MessageEndpoint> _originalList = [];

  Endpoints(
      controller.Contact this._contactController, this._endpointController) {
    _buttons.children = [_addNew, _foldJson, _unfoldJson];
    _header.children = [_label, _buttons];
    element.children = [_header, _endpointsInput];
    _observers();
  }

  void _observers() {
    _addNew.onClick.listen((_) {
      final model.MessageEndpoint template = new model.MessageEndpoint.empty()
        ..address = 'service@responsum.dk'
        ..confidential = false
        ..description = 'Kort beskrivelse'
        ..enabled = true
        ..type = model.MessageEndpointType.EMAIL;

      if (_unfoldJson.hidden) {
        _endpointsInput.value =
            _jsonpp.convert(endpoints.toList()..add(template));
      } else {
        endpoints = endpoints.toList()..add(template);
      }

      _resizeInput();

      if (onChange != null) {
        onChange();
      }
    });

    _endpointsInput.onInput.listen((_) {
      _validationError = false;
      _endpointsInput.classes.toggle('error', false);
      try {
        final Iterable<model.MessageEndpoint> eps = endpoints;

        if (eps.any((model.MessageEndpoint ep) =>
            ep.type != 'sms' && ep.type != 'email')) {
          throw new FormatException('bad type');
        }

        if (eps.any((model.MessageEndpoint ep) =>
            ep.role != 'to' && ep.role != 'cc' && ep.role != 'bcc')) {
          throw new FormatException('bad role');
        }

        if (!eps.where((model.MessageEndpoint ep) => ep.type == 'email').every(
            (model.MessageEndpoint ep) =>
                _emailRegex.hasMatch(ep.address.toLowerCase()) &&
                ep.address == ep.address.toLowerCase() &&
                !ep.address.contains(new RegExp(r'[æ,ø,å]')))) {
          throw new FormatException('bad emailaddress');
        }

        if (!eps.where((model.MessageEndpoint ep) => ep.type == 'sms').every(
            (model.MessageEndpoint ep) =>
                ep.address.length == 8 &&
                _numeric.hasMatch(ep.address) &&
                ep.role == 'to')) {
          throw new FormatException('bad sms');
        }
      } on FormatException {
        _validationError = true;
        _endpointsInput.classes.toggle('error', true);
      }

      if (onChange != null) {
        onChange();
      }
    });

    _unfoldJson.onClick.listen((_) {
      _unfoldJson.hidden = true;
      _foldJson.hidden = false;
      _endpointsInput.value = _jsonpp.convert(endpoints.toList());
      _resizeInput();
    });

    _foldJson.onClick.listen((_) {
      _foldJson.hidden = true;
      _unfoldJson.hidden = false;
      _endpointsInput.style.height = '';
      _endpointsInput.value = JSON.encode(endpoints.toList());
    });
  }

  void set endpoints(Iterable<model.MessageEndpoint> eps) {
    _originalList = eps.toList(growable: false);
    if (_unfoldJson.hidden) {
      _endpointsInput.value = _jsonpp.convert(_originalList);
    } else {
      _endpointsInput.value = JSON.encode(_originalList);
    }
  }

  Iterable<EndpointChange> get endpointChanges {
    Set<EndpointChange> epcs = new Set();

    Map<int, model.MessageEndpoint> mepIdMap = {};
    _originalList.forEach((model.MessageEndpoint ep) {
      mepIdMap[ep.id] = ep;

      if (!endpoints.any((model.MessageEndpoint chEp) => chEp.id == ep.id)) {
        epcs.add(new EndpointChange.delete(ep));
      }
    });

    endpoints.forEach((ep) {
      if (ep.id == model.MessageEndpoint.noId) {
        epcs.add(new EndpointChange.create(ep));
      } else if (mepIdMap.containsKey(ep.id) && mepIdMap[ep.id] != ep) {
        epcs.add(new EndpointChange.update(ep));
      } else if (!mepIdMap.containsKey(ep.id)) {
        epcs.add(new EndpointChange.delete(ep));
      }
    });

    return epcs;
  }

  Iterable<model.MessageEndpoint> get endpoints =>
      JSON.decode(_endpointsInput.value).map(model.MessageEndpoint.decode)
      as Iterable<model.MessageEndpoint>;

  void _resizeInput() {
    while (_endpointsInput.client.height < _endpointsInput.scrollHeight) {
      _endpointsInput.style.height = '${_endpointsInput.client.height + 10}px';
    }
  }
}
