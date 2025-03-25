import 'dart:html';
import 'dart:js';

import 'scorm_version.dart';
import 'scorm_version_extension.dart';

/// Main class for all the interaction with SCORM APIs
///
/// Begin with finding the API using the [findApi] method.
/// Check [apiFound] at any point of time.
class ScormAPI {
  ScormAPI._();

  static int _tries = 0;
  static int _maxTries = 255;

  /// Indicates whether api was successfully found. All other methods will return null/false if api has not been found
  static bool get apiFound => _apiFound;

  static bool _apiFound = false;

  static late ScormVersion _version;

  /// The found/specified SCORM version
  static ScormVersion? get version => _version;

  /// Check directly in top window - sometimes API is directly attached to top
  static bool _searchTopWindow() {
    try {
      if (context['top'] != null) {
        var top = _convert(context['top']);

        // Check for SCORM 1.2
        if (top['API'] != null) {
          context['API'] = top['API'];
          _version = ScormVersion.v1_2;
          return true;
        }

        // Check for SCORM 2004
        if (top['API_1484_11'] != null) {
          context['API_1484_11'] = top['API_1484_11'];
          _version = ScormVersion.v2004;
          return true;
        }
      }
    } catch (e) {
      // Ignore errors when checking top window (can occur due to cross-origin issues)
    }
    return false;
  }

  /// Traverses through hierarchy to find "API" or " and if found, sets the found API to current context so that it can be directly accessed
  static bool _search(JsObject window) {
    dynamic _window = _convert(window);
    while (_window[_version.objectName] == null &&
        _window['parent'] != null &&
        _window['parent'] != window) {
      _tries++;
      if (_tries > _maxTries) {
        return false;
      }

      // go up the tree
      _window = _convert(_window['parent']);
    }

    // api found? - reference found API object in current context
    if (_window[_version.objectName] != null) {
      context[_version.objectName] = _window[_version.objectName];
      return true;
    }

    return false;
  }

  /// Direct search for API objects (like in the successful code)
  static bool _findDirectAPI(JsObject window) {
    dynamic _window = _convert(window);

    for (int i = 0; i < _maxTries; i++) {
      _tries++;

      // Direct check for API (SCORM 1.2)
      if (_window['API'] != null) {
        context['API'] = _window['API'];
        _version = ScormVersion.v1_2;
        return true;
      }

      // Direct check for API_1484_11 (SCORM 2004)
      if (_window['API_1484_11'] != null) {
        context['API_1484_11'] = _window['API_1484_11'];
        _version = ScormVersion.v2004;
        return true;
      }

      if (_window['parent'] == null || _window['parent'] == window) {
        break;
      }

      // Go up the tree
      _window = _convert(_window['parent']);
    }

    return false;
  }

  /// Search for API in all available frames
  static bool _searchFrames(JsObject window) {
    try {
      dynamic _window = _convert(window);
      if (_window['frames'] != null) {
        final int framesLength = _window['frames']['length'];

        for (var i = 0; i < framesLength; i++) {
          _tries = 0;

          // Check directly in each frame
          dynamic frame = _convert(_window['frames'][i]);

          // Try SCORM 1.2
          if (frame['API'] != null) {
            context['API'] = frame['API'];
            _version = ScormVersion.v1_2;
            return true;
          }

          // Try SCORM 2004
          if (frame['API_1484_11'] != null) {
            context['API_1484_11'] = frame['API_1484_11'];
            _version = ScormVersion.v2004;
            return true;
          }
        }
      }
    } catch (e) {
      // Ignore errors when checking frames (can occur due to cross-origin issues)
    }
    return false;
  }

  /// Checks if given object is [Window], if yes, returns it's JsObject for searching the API
  static JsObject _convert(dynamic object) {
    if (object is Window) {
      return JsObject.fromBrowserObject(object);
    }
    return object;
  }

  static bool _findVersion({int maxTries = 255}) {
    _maxTries = maxTries;
    final foundNormal = _search(context);
    var foundInOpener = false;

    if (!foundNormal && context['opener'] != null) {
      _tries = 0;
      foundInOpener = _search(context['opener']);
    }

    _apiFound = foundNormal || foundInOpener;

    return _apiFound;
  }

  /// Tries to find SCORM API in the hierarchy up-to [maxTries] level. If it's not found in the current hierarchy, it tries to find it in the `opener`'s hierarchy
  ///
  /// If a [version] is specified, then will search only for that specific version, else will try to find both versions (preference is given to v2004)
  ///
  /// Returns whether the SCORM API has been found. The API status can also be accessed at any point of time with [apiFound]
  static bool findApi({ScormVersion? version, int maxTries = 255}) {
    _maxTries = maxTries;

    // 1. First try direct API discovery in current window
    if (_findDirectAPI(context)) {
      _apiFound = true;
      return true;
    }

    // 2. Check directly in top window
    if (_searchTopWindow()) {
      _apiFound = true;
      return true;
    }

    // 3. Search in all frames
    if (_searchFrames(context)) {
      _apiFound = true;
      return true;
    }

    // 4. Try in opener if available
    if (context['opener'] != null && _findDirectAPI(context['opener'])) {
      _apiFound = true;
      return true;
    }

    // 5. Special case: check if window.parent.opener exists and set as window.opener
    try {
      if (context['parent'] != null && context['parent']['opener'] != null) {
        context['opener'] = context['parent']['opener'];
        if (context['opener'] != null && _findDirectAPI(context['opener'])) {
          _apiFound = true;
          return true;
        }
      }
    } catch (e) {
      // Ignore errors when checking parent.opener (can occur due to cross-origin issues)
    }

    // 6. Fall back to traditional search approach
    if (version == null) {
      _version = ScormVersion.v2004;
      if (_findVersion(maxTries: maxTries)) {
        return true;
      } else {
        _version = ScormVersion.v1_2;
        return _findVersion(maxTries: maxTries);
      }
    } else {
      _version = version;
      return _findVersion(maxTries: _maxTries);
    }
  }

  /// Executes `Initialize`
  static bool initialize({String message = ""}) =>
      _apiFound ? _version.initialize(message) : false;

  /// Executes `Finish/Terminate`
  static bool finish({String message = ""}) =>
      _apiFound ? _version.finish(message) : false;

  /// Executes `Finish/Terminate`
  static bool terminate({String message = ""}) =>
      _apiFound ? _version.terminate(message) : false;

  /// Executes `GetValue`
  static String? getValue(String key) =>
      _apiFound ? _version.getValue(key) : null;

  /// Executes `SetValue`
  static String? setValue(String key, String value) =>
      _apiFound ? _version.setValue(key, value) : null;

  /// Executes `Commit`
  static bool commit({String message = ""}) =>
      _apiFound ? _version.commit(message) : false;

  /// Executes `GetLastError`
  static String? getLastError() => _apiFound ? _version.getLastError() : null;

  /// Executes `GetErrorString`
  static String? getErrorString(String errorCode) =>
      _apiFound ? _version.getErrorString(errorCode) : null;

  /// Executes `GetDiagnostic`
  static String? getDiagnosticMessage(String errorCode) =>
      _apiFound ? _version.getDiagnosticMessage(errorCode) : null;
}