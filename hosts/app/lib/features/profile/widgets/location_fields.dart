import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/geo.dart';
import '../providers/geo_provider.dart';

/// Which of the four fields changed.
enum LocationField { country, zip, state, city }

/// The four location fields, with the help of our own copy of GeoNames (#443):
///
///  - the country is **picked from the list**, never typed in (preselected from
///    the device's locale when empty). What the member types only narrows the
///    list; leaving the field without picking puts the picked country back. Until
///    the list is loaded the field is disabled, with a retry when loading failed;
///  - the postal code is a **helper**. While one is entered, for a country that
///    has postal data, State and City are **locked** (disabled) and follow it: when
///    it matches our data they are filled from it, because people spell things
///    differently. A code we do not match (or cannot check) is not an error: there
///    is nothing to replace what was typed, so State and City become plain text
///    again and the code is kept as typed. The server applies the same rule;
///  - with no postal code, or for a country without postal data (the UAE and Oman
///    are left out on purpose), State and City are plain editable text, and a city
///    can be searched (which fills an empty state);
///  - one exception: a field the data has no value for (some codes have no state)
///    is left editable, because it is required.
///
/// The parent owns the four controllers and reads them on save, as it always
/// has; [onChanged] tells it when a field was changed by the member or filled in.
class LocationFields extends ConsumerStatefulWidget {
  final TextEditingController country;
  final TextEditingController zip;
  final TextEditingController state;
  final TextEditingController city;

  /// Called after the member edits a field or the widget fills one in.
  final void Function(LocationField field, String value) onChanged;

  /// Each screen styles its own fields.
  final InputDecoration Function(String label, IconData icon, {String? hint})
  decoration;

  final String? Function(String?)? countryValidator;
  final String? Function(String?)? zipValidator;
  final String? Function(String?)? stateValidator;
  final String? Function(String?)? cityValidator;

  /// Told whenever what blocks saving changes: a stored country that is not on
  /// the list (one from before the list existed; it cannot be typed any more).
  /// Null means nothing blocks. A screen without a Form uses this to refuse to
  /// continue; one with a Form gets the same message from the field validator.
  final ValueChanged<String?>? onProblemChanged;

  const LocationFields({
    super.key,
    required this.country,
    required this.zip,
    required this.state,
    required this.city,
    required this.onChanged,
    required this.decoration,
    this.countryValidator,
    this.zipValidator,
    this.stateValidator,
    this.cityValidator,
    this.onProblemChanged,
  });

  @override
  ConsumerState<LocationFields> createState() => _LocationFieldsState();
}

class _LocationFieldsState extends ConsumerState<LocationFields> {
  // What the country field shows: the picked country, or the member's search
  // text while they type. Only a pick writes to widget.country.
  final _countrySearch = TextEditingController();
  final _countryFocus = FocusNode();
  final _cityFocus = FocusNode();
  Timer? _postalTimer;

  // While a postal code is entered (for a country that has postal data) State and
  // City are locked from the moment it is edited, until it has been checked: if it
  // matches they follow it; if not (or it cannot be checked) they are freed again.
  bool _stateLocked = false;
  bool _cityLocked = false;
  String? _note; // shown under City
  String? _published;
  int _resolving = 0; // bumped on every edit, so a late answer is ignored
  bool _initialResolved = false;

  @override
  void initState() {
    super.initState();
    _countrySearch.text = widget.country.text;
    _countrySearch.addListener(_searchChanged);
    widget.country.addListener(_countryChanged);
    _countryFocus.addListener(_countryFocusChanged);
    // After the parent has put the stored values into the controllers.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _initialResolve();
      _publish();
    });
  }

  @override
  void dispose() {
    widget.country.removeListener(_countryChanged);
    _postalTimer?.cancel();
    _countrySearch.dispose();
    _countryFocus.dispose();
    _cityFocus.dispose();
    super.dispose();
  }

  /// The country was picked, preselected or set by the parent: show it.
  void _countryChanged() {
    _showCountry();
    setState(() {});
    _publish();
  }

  void _showCountry() {
    if (_countrySearch.text != widget.country.text) {
      _countrySearch.text = widget.country.text;
    }
  }

  /// The search text changed: the "no country matches" line may change.
  void _searchChanged() => setState(() {});

  /// Entering the field selects its text, so typing starts a new search.
  /// Leaving it without a pick puts the picked country back.
  void _countryFocusChanged() {
    if (!_countryFocus.hasFocus) {
      _showCountry();
      return;
    }
    _countrySearch.selection = TextSelection(
      baseOffset: 0,
      extentOffset: _countrySearch.text.length,
    );
  }

  /// The countries the search text narrows the list to. An empty search, or the
  /// picked country's own name, shows the whole list.
  Iterable<GeoCountry> _countryOptions(String text) {
    final typed = text.trim().toLowerCase();
    if (typed.isEmpty || typed == widget.country.text.trim().toLowerCase()) {
      return _countries;
    }
    return _countries.where((c) => c.name.toLowerCase().contains(typed));
  }

  /// A stored country that is not on the list, once the list is known.
  String? get _countryProblem {
    final typed = widget.country.text.trim();
    if (typed.isEmpty || _countries.isEmpty || _selected != null) return null;
    return 'Choose your country from the list';
  }

  String? get _problem => _countryProblem;

  void _publish() {
    final problem = _problem;
    if (problem == _published) return;
    _published = problem;
    widget.onProblemChanged?.call(problem);
  }

  /// Is the postal code in charge? Then State and City follow it.
  bool get _codeInCharge {
    final country = _selected;
    return country != null &&
        country.hasPostalCodes &&
        widget.zip.text.trim().isNotEmpty;
  }

  List<GeoCountry> get _countries =>
      ref.read(geoCountriesProvider).value ?? const [];

  GeoCountry? get _selected {
    final typed = widget.country.text.trim().toLowerCase();
    if (typed.isEmpty) return null;
    for (final c in _countries) {
      if (c.name.toLowerCase() == typed) return c;
    }
    return null;
  }

  /// Fill the country from the device's locale, once, when it is empty.
  void _preselectCountry(List<GeoCountry> countries) {
    if (widget.country.text.trim().isNotEmpty) return;
    final code = WidgetsBinding.instance.platformDispatcher.locale.countryCode;
    if (code == null) return;
    for (final c in countries) {
      if (c.code == code.toUpperCase()) {
        widget.country.text = c.name;
        widget.onChanged(LocationField.country, c.name);
        return;
      }
    }
  }

  /// No code in charge: State and City are plain editable text.
  void _free() {
    setState(() {
      _stateLocked = false;
      _cityLocked = false;
      _note = null;
    });
    _publish();
  }

  void _put(
    TextEditingController controller,
    LocationField field,
    String? value,
    bool overwrite,
  ) {
    if (!overwrite && controller.text.trim().isNotEmpty) return;
    final text = value ?? '';
    if (controller.text == text) return;
    controller.text = text;
    widget.onChanged(field, text);
  }

  /// Lock both fields until the code has been checked.
  void _checking() {
    setState(() {
      _stateLocked = true;
      _cityLocked = true;
      _note = 'Checking the postal code...';
    });
  }

  /// Look the code up. [overwrite] true: the member just changed the code or the
  /// country, so State and City take the data's values. False: the screen just
  /// opened with a stored code, so the stored values stay (an empty one is filled).
  Future<void> _resolvePostal({required bool overwrite}) async {
    final mine = ++_resolving;
    if (!_codeInCharge) {
      _free();
      return;
    }
    final country = _selected!;
    _checking();
    try {
      final found = await ref
          .read(geoRepositoryProvider)
          .postal(country.code, widget.zip.text.trim());
      if (!mounted || mine != _resolving) return;
      if (found == null) {
        // Nothing to use: what was typed stands, and State and City are theirs again.
        _free();
        setState(
          () => _note =
              'We do not have that postal code for ${country.name}. '
              'Enter your state and city yourself.',
        );
        return;
      }
      if (found.state?.isNotEmpty ?? false) {
        _put(widget.state, LocationField.state, found.state, overwrite);
      }
      if (found.city?.isNotEmpty ?? false) {
        _put(widget.city, LocationField.city, found.city, overwrite);
      }
      setState(() {
        // A field the data has no value for stays editable: it is required.
        _stateLocked = found.state?.isNotEmpty ?? false;
        _cityLocked = found.city?.isNotEmpty ?? false;
        _note =
            'Filled in from your postal code. Change the postal code to edit.';
      });
    } catch (_) {
      if (!mounted || mine != _resolving) return;
      _free();
      setState(
        () => _note =
            'Could not check the postal code. Enter your state and city yourself.',
      );
    }
  }

  void _initialResolve() {
    if (_initialResolved || _countries.isEmpty) return;
    _initialResolved = true;
    if (_codeInCharge) _resolvePostal(overwrite: false);
  }

  /// The postal code or the country was edited by the member: it takes effect at
  /// once. While there is a code State and City stay locked until it is checked.
  void _postalOrCountryEdited() {
    _resolving++;
    _postalTimer?.cancel();
    if (!_codeInCharge) {
      _free();
      return;
    }
    _checking();
    _postalTimer = Timer(
      const Duration(milliseconds: 500),
      () => _resolvePostal(overwrite: true),
    );
  }

  Future<Iterable<GeoCity>> _cityOptions(String text) async {
    final country = _selected;
    final query = text.trim();
    if (country == null || query.length < 2 || _cityLocked) return const [];
    // Wait out a burst of typing: if the text moved on, this search is stale.
    await Future<void>.delayed(const Duration(milliseconds: 300));
    if (!mounted || widget.city.text.trim() != query) return const [];
    try {
      return await ref.read(geoRepositoryProvider).cities(country.code, query);
    } catch (_) {
      return const [];
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<List<GeoCountry>>>(geoCountriesProvider, (_, next) {
      final countries = next.value;
      if (countries == null) return;
      _preselectCountry(countries);
      _initialResolve();
      _publish();
    });
    final countryList = ref.watch(geoCountriesProvider);
    final listReady = countryList.hasValue;
    // Riverpod retries a failed load by itself, so a failure may also be loading.
    final listFailed = !listReady && countryList.hasError;
    final search = _countrySearch.text.trim();
    final noMatch =
        listReady && _countryFocus.hasFocus && _countryOptions(search).isEmpty;
    final selected = _selected;
    // Without a postal system for the country the field would never help; an
    // unrecognised (typed) country keeps it, as before.
    final showZip = selected == null || selected.hasPostalCodes;

    return AutofillGroup(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          RawAutocomplete<GeoCountry>(
            textEditingController: _countrySearch,
            focusNode: _countryFocus,
            displayStringForOption: (c) => c.name,
            optionsBuilder: (value) => _countryOptions(value.text),
            onSelected: (c) {
              widget.country.text = c.name;
              widget.onChanged(LocationField.country, c.name);
              _postalOrCountryEdited();
            },
            fieldViewBuilder: (context, controller, focusNode, _) {
              return TextFormField(
                controller: controller,
                focusNode: focusNode,
                enabled: listReady,
                textInputAction: TextInputAction.next,
                decoration: widget
                    .decoration(
                      'Country',
                      Icons.public,
                      hint: 'Type to search the list',
                    )
                    .copyWith(
                      suffixIcon: const Icon(Icons.arrow_drop_down),
                      helperText: noMatch
                          ? 'No country matches "$search"'
                          : null,
                    ),
                // The value is the picked country, not the search text.
                validator: (_) =>
                    _countryProblem ??
                    widget.countryValidator?.call(widget.country.text),
              );
            },
            optionsViewBuilder: (context, onSelected, options) =>
                _OptionsList<GeoCountry>(
                  options: options,
                  label: (c) => c.name,
                  onSelected: onSelected,
                ),
          ),
          if (!listReady) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Text(
                    listFailed
                        ? 'Could not load the list of countries.'
                        : 'Loading the list of countries...',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
                if (listFailed)
                  TextButton(
                    onPressed: () => ref.invalidate(geoCountriesProvider),
                    child: const Text('Try again'),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 16),
          if (showZip) ...[
            TextFormField(
              controller: widget.zip,
              autofillHints: const [AutofillHints.postalCode],
              textInputAction: TextInputAction.next,
              decoration: widget.decoration(
                'Postal code',
                Icons.markunread_mailbox_outlined,
                hint: selected?.hasPostalCodes == true
                    ? 'Fills in your state and city'
                    : null,
              ),
              validator: widget.zipValidator,
              onChanged: (v) {
                widget.onChanged(LocationField.zip, v.trim());
                _postalOrCountryEdited();
              },
            ),
            const SizedBox(height: 16),
          ],
          TextFormField(
            controller: widget.state,
            enabled: !_stateLocked,
            autofillHints: const [AutofillHints.addressState],
            textInputAction: TextInputAction.next,
            decoration: widget.decoration('State/Province', Icons.map_outlined),
            validator: widget.stateValidator,
            onChanged: (v) => widget.onChanged(LocationField.state, v.trim()),
          ),
          const SizedBox(height: 16),
          RawAutocomplete<GeoCity>(
            textEditingController: widget.city,
            focusNode: _cityFocus,
            displayStringForOption: (c) => c.name,
            optionsBuilder: (value) => _cityOptions(value.text),
            onSelected: (c) {
              widget.onChanged(LocationField.city, c.name);
              // A picked city fills a state that is still empty.
              _put(widget.state, LocationField.state, c.state, false);
            },
            fieldViewBuilder: (context, controller, focusNode, _) {
              return TextFormField(
                controller: controller,
                focusNode: focusNode,
                enabled: !_cityLocked,
                autofillHints: const [AutofillHints.addressCity],
                textInputAction: TextInputAction.done,
                decoration: widget.decoration(
                  'City',
                  Icons.location_city_outlined,
                ),
                validator: widget.cityValidator,
                onChanged: (v) =>
                    widget.onChanged(LocationField.city, v.trim()),
              );
            },
            optionsViewBuilder: (context, onSelected, options) =>
                _OptionsList<GeoCity>(
                  options: options,
                  label: (c) =>
                      c.state == null ? c.name : '${c.name}, ${c.state}',
                  onSelected: onSelected,
                ),
          ),
          if (_note != null) ...[
            const SizedBox(height: 8),
            Text(_note!, style: Theme.of(context).textTheme.bodySmall),
          ],
          const SizedBox(height: 8),
          const _GeoNamesCredit(),
        ],
      ),
    );
  }
}

/// GeoNames is CC BY 4.0: the credit and a link, where its data shows.
class _GeoNamesCredit extends StatelessWidget {
  const _GeoNamesCredit();

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () async {
        try {
          await launchUrl(
            Uri.parse('https://www.geonames.org'),
            mode: LaunchMode.externalApplication,
          );
        } catch (_) {
          // No browser to open: the credit is still on screen.
        }
      },
      child: Text(
        'Place suggestions from GeoNames (CC BY 4.0)',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: Theme.of(context).hintColor,
          decoration: TextDecoration.underline,
        ),
      ),
    );
  }
}

/// The suggestions under a field.
class _OptionsList<T extends Object> extends StatelessWidget {
  final Iterable<T> options;
  final String Function(T) label;
  final AutocompleteOnSelected<T> onSelected;

  const _OptionsList({
    required this.options,
    required this.label,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topLeft,
      child: Material(
        elevation: 4,
        borderRadius: BorderRadius.circular(8),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 240, maxWidth: 480),
          child: ListView(
            padding: EdgeInsets.zero,
            shrinkWrap: true,
            children: [
              for (final option in options)
                ListTile(
                  dense: true,
                  title: Text(label(option)),
                  onTap: () => onSelected(option),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
