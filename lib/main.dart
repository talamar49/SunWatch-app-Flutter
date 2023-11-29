// ignore_for_file: prefer_const_constructors, prefer_interpolation_to_compose_strings, avoid_print

import 'dart:async';
import 'package:intl/intl.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_alarm_clock/flutter_alarm_clock.dart';
import 'package:sunrise_sunset_calc/sunrise_sunset_calc.dart';
import 'package:lat_lng_to_timezone/lat_lng_to_timezone.dart' as tzmap;
import 'package:timezone_utc_offset/timezone_utc_offset.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'dart:ui' as ui;
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:flutter/widgets.dart';

GoRouter router = GoRouter(routes: [
  GoRoute(
    path: '/',
    builder: (context, state) => MyApp(),
  ),
  GoRoute(
    path: '/Maps',
    builder: (context, state) => MapsPage(),
  ),
]);

dynamic sunrise = 0;
dynamic sunset = 0;
String? location_name = "פרדס חנה";
String? country_name = "ישראל";
String? country_code = "IL";
LatLng mapsLocation = LatLng(32.475868, 34.976299);

Future<void> updateLocation(LatLng location) async {
  mapsLocation = location;
  sunrise = riseSet(location.latitude, location.longitude)['sunrise'];
  sunset = riseSet(location.latitude, location.longitude)['sunset'];
  await getPlaceData(location.latitude, location.longitude);
}

Future<void> getPlaceData(double lat, double lon) async {
  try {
    List<Placemark> placemarks =
        await placemarkFromCoordinates(lat, lon, localeIdentifier: 'he_IL');

    location_name = placemarks.first.locality;
    country_name = placemarks.first.country;
    country_code = (placemarks.first.isoCountryCode);
    print(location_name);
  } catch (e) {
    print(e);
  }
}

Future<Position> _determinePosition() async {
  bool serviceEnabled;
  LocationPermission permission;

  // Test if location services are enabled.
  serviceEnabled = await Geolocator.isLocationServiceEnabled();
  if (!serviceEnabled) {
    return Future.error('Location services are disabled.');
  }

  permission = await Geolocator.checkPermission();
  if (permission == LocationPermission.denied) {
    permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.denied) {
      return Future.error('Location permissions are denied');
    }
  }

  if (permission == LocationPermission.deniedForever) {
    return Future.error(
        'Location permissions are permanently denied, we cannot request permissions.');
  }

  return await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
}

List<String> hebrewDays = ["שני", "שלישי", "רביעי", "חמישי", "שישי", "שבת", "ראשון"];

const List<Widget> fruits = <Widget>[
  Text('זריחה'),
  Text('שקיעה'),
];

Duration offset = Duration();
Map<String, dynamic> riseSet(double lat, double lon) {
  String tz = tzmap.latLngToTimezoneString(lat, lon);
  offset = getTimezoneUTCOffset(tz)!;

  var sunriseSunset = getSunriseSunset(lat, lon, offset, DateTime.now());
  var sunrise = sunriseSunset.toString().split(',')[0].split('sunrise: ');
  var sunset = sunriseSunset.toString().split(',')[1].split('sunset: ');

  var result = {
    'timezone': tz,
    'offset': offset,
    'sunrise': DateTime.parse(sunrise[1]),
    'sunset': DateTime.parse(sunset[1])
  };

  return result;
}

void main() => runApp(MaterialApp.router(
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    ));

class MyApp extends StatefulWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  Timer diffTimer = Timer(Duration(), () {});
  String diffClock = '';
  Duration clockOffset = Duration();
  Duration hourOffset = Duration();
  Duration minOffset = Duration();

  void _clockDiff(
      {Duration hourOffset = Duration.zero, Duration minOffset = Duration.zero}) {
    Duration sunDiff = Duration();

    hourOffset = _selectedFruits[1] ? hourOffset : -hourOffset;
    minOffset = _selectedFruits[1] ? minOffset : -minOffset;

    diffTimer = Timer.periodic(Duration(milliseconds: 10), (Timer t) {
      dynamic riseSetState = isRise ? sunrise : sunset;
      DateTime riseSetDt = DateTime.parse(riseSetState.toString().replaceAll('Z', ''));
      riseSetDt = DateTime(riseSetDt.year, riseSetDt.month, riseSetDt.day, selectedAlarmH,
          selectedAlarmM, 0);

      // print(riseSetState);

      DateTime Dstate = riseSetDt.add(Duration(days: 1));
      DateTime currentTime = DateTime.now();

      setState(() {
        if (Dstate.isAfter(currentTime)) {
          sunDiff = Dstate.difference(currentTime);
          diffClock =
              '${formatNumber(sunDiff.inHours % 24)}:${formatNumber(sunDiff.inMinutes % 60)}';
        } else {
          sunDiff = currentTime.difference(Dstate.add(Duration(days: 1)));
          diffClock =
              '${formatNumber(sunDiff.inHours)}:${formatNumber(sunDiff.inMinutes % 60)}';
        }
      });
    });
  }

  String formatNumber(int number) {
    return number.toString().padLeft(2, '0');
  }

  Future<void> _showTimePicker(BuildContext context) async {
    final TimeOfDay? selectedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );

    if (selectedTime != null) {
      DateTime now = DateTime.now();
      // Convert the selected time to 24-hour format
      DateTime formattedTime =
          DateTime(now.year, now.month, now.day, selectedTime.hour, selectedTime.minute);
      print('Selected time: $formattedTime');
      setState(() {
        diffTimer.cancel();
        _clockDiff();
        selectedAlarmH = formattedTime.hour;
        selectedAlarmM = formattedTime.minute;

      });
    }
  }

  void returnHour(int num) {
    selectedHour = _selectedFruits[1] ? selectedHour : -selectedHour;
    dynamic riseState;
    setState(() {
      riseState = isRise ? sunrise : sunset;
      number = riseState.add(Duration(hours: selectedHour, minutes: selectedMin));
      selectedAlarmH = DateTime.parse(number.toString()).hour;
      selectedAlarmM = DateTime.parse(number.toString()).minute;
    });
  }

  void returnMinute(int num) {
    selectedMin = _selectedFruits[1] ? selectedMin : -selectedMin;
    dynamic riseState;
    setState(() {
      riseState = isRise ? sunrise : sunset;

      number = riseState.add(Duration(minutes: selectedMin, hours: selectedHour));
      selectedAlarmH = DateTime.parse(number.toString()).hour;
      selectedAlarmM = DateTime.parse(number.toString()).minute;
    });
  }

  Future<void> initializeData() async {
    try {
      Position cords = await _determinePosition();
      setState(() {
        updateLocation(LatLng(cords.latitude, cords.longitude));
      });
    } catch (e) {
      print(e);
    }
  }

  String time = '';
  // FixedExtentScrollController scrollController = FixedExtentScrollController(initialItem: 0);
  void getTime() {
    Timer.periodic(Duration(seconds: 1), (Timer t) {
      DateTime now = DateTime.now();
      setState(() {
        time =
            '${formatNumber(now.hour)}:${formatNumber(now.minute)}:${formatNumber(now.second)}';
      });
    });
  }

  int selectedMin = 0;
  int selectedHour = 0;
  int selectedAlarmH = 0;
  int selectedAlarmM = 0;
  bool isRise = true;
  dynamic number = '';

  @override
  void initState() {
    super.initState();
    getTime();

    updateLocation(mapsLocation);
    _clockDiff();
    print(
        DateTime(2023, 11, 27, 14, 40, 0).difference(DateTime(2023, 11, 26, 14, 40, 0)));
    number = sunrise;
    selectedAlarmH = DateTime.parse(number.toString()).hour;
    selectedAlarmM = DateTime.parse(number.toString()).minute;
    setState(() {
      initializeData();
    });
  }

  final List<bool> _selectedFruits = <bool>[true, false];
  final List<bool> _selectedRiseSet = <bool>[true, false];

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: ui.TextDirection.rtl,
      child: SafeArea(
        child: Scaffold(
          body: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  // Color(0xFFD39D87)
                  Color(0xFFBB7154),
                  Color(0xFFD2A96A),
                  Color(0xFFA6B7AA),
                ],
              ),
            ),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: Color(0xFFA6B7AA),
                        width: 2,
                      ),
                    ),
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Row(
                            children: [
                              Flexible(
                                flex: 2,
                                child: Padding(
                                  padding: const EdgeInsets.only(left: 8),
                                  child: FloatingActionButton(
                                    onPressed: () async {
                                      try {
                                        Position coords = await _determinePosition();
                                        setState(() {
                                          updateLocation(
                                              LatLng(coords.latitude, coords.longitude));
                                        });
                                      } catch (e) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            duration: Duration(seconds: 1),
                                            content: Center(
                                                child: Text(
                                              'אין אפשרות למצוא את המיקום',
                                              style: TextStyle(color: Colors.black),
                                            )),
                                            behavior: SnackBarBehavior.floating,
                                          ),
                                        );
                                      }
                                    },
                                    child: Icon(Icons.my_location_outlined),
                                    backgroundColor: Colors.blue,
                                  ),
                                ),
                              ),
                              Flexible(
                                flex: 10,
                                child: Container(
                                  width: double.infinity,
                                  decoration: BoxDecoration(
                                      color: Color(0xFFA6B7AA),
                                      borderRadius: BorderRadius.circular(10)),
                                  child: Stack(
                                    children: [
                                      TextButton(
                                        onPressed: () async {
                                          await context.push('/Maps');
                                          setState(() {});
                                        },
                                        child: Container(
                                          child: Row(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            crossAxisAlignment: CrossAxisAlignment.end,
                                            children: [
                                              Text(
                                                ('${location_name! != "" ? location_name! : country_name!}'),
                                                style: TextStyle(
                                                    fontSize: 26,
                                                    color: Color(0xFF0363B0)),
                                              ),
                                              SizedBox(
                                                width: 5,
                                              ),
                                              Text(
                                                country_name!,
                                                style:
                                                    TextStyle(color: Color(0xFF0363B0)),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Padding(
                          padding:
                              const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8),
                          child: Container(
                            width: double.infinity,
                            decoration: BoxDecoration(
                                color: Color(0xFFA6B7AA),
                                borderRadius: BorderRadius.circular(10)),
                            child: Center(
                              child: Text(
                                time,
                                style: TextStyle(
                                    fontSize: 40,
                                    color: Color(0xFFBB7154),
                                    fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                        ),
                        Row(
                          children: [
                            Flexible(
                              flex: 5,
                              child: Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: Color(0xFFA6B7AA),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.sunny,
                                        color: Color(0xFFDD9F0D),
                                        size: 30,
                                      ),
                                      SizedBox(
                                        width: 10,
                                      ),
                                      Text(
                                        DateFormat('HH:mm')
                                            .format(DateTime.parse(sunrise.toString())),
                                        style: TextStyle(
                                            fontSize: 30,
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            SizedBox(
                              width: 10,
                            ),
                            Flexible(
                              flex: 5,
                              child: Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: Color(0xFFA6B7AA),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.sunny_snowing,
                                        color: Color(0xFFBB7154),
                                        size: 30,
                                      ),
                                      SizedBox(
                                        width: 10,
                                      ),
                                      Text(
                                        DateFormat('HH:mm')
                                            .format(DateTime.parse(sunset.toString())),
                                        style: TextStyle(
                                            fontSize: 30,
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: Color(0xFFA6B7AA),
                        width: 2,
                      ),
                    ),
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 10, 10, 20),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // ToggleButtons with a single selection.
                            const SizedBox(height: 0),
                            ToggleButtons(
                              onPressed: (int ind) {
                                setState(() {
                                  for (int i = 0; i < _selectedRiseSet.length; i++) {
                                    _selectedRiseSet[i] = i == ind;
                                    isRise = _selectedRiseSet[i] ? false : true;
                                    returnHour(selectedHour);
                                    returnMinute(selectedMin);
                                  }
                                });
                              },
                              borderRadius: const BorderRadius.all(Radius.circular(8)),
                              selectedBorderColor: Colors.grey,
                              selectedColor: Colors.white,
                              fillColor: _selectedRiseSet[1]
                                  ? Color(0xFFBB7154)
                                  : Color(0xFFDD9F0D),
                              color: Color(0xFF5C6E6C),
                              constraints: const BoxConstraints(
                                minHeight: 40.0,
                                minWidth: 80.0,
                              ),
                              isSelected: _selectedRiseSet,
                              children: fruits,
                            ),
                            const SizedBox(height: 0),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Column(
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.all(8.0),
                                      child: Text(
                                        '',
                                        style: TextStyle(fontSize: 16),
                                      ),
                                    ),
                                    SizedBox(
                                      width: 100,
                                      height: 100,
                                      child: CupertinoPicker(
                                        // scrollController: scrollController,
                                        itemExtent: 33,
                                        onSelectedItemChanged: (ind) {
                                          setState(() {
                                            // The button that is tapped is set to true, and the others to false.

                                            for (int i = 0;
                                                i < _selectedFruits.length;
                                                i++) {
                                              _selectedFruits[i] = i == ind;
                                              returnHour(selectedHour);
                                              returnMinute(selectedMin);

                                              diffTimer.cancel();
                                              _clockDiff(
                                                  minOffset: minOffset,
                                                  hourOffset: hourOffset);
                                            }
                                          });
                                        },
                                        children: <Widget>[Text("לפני"), Text("אחרי")],
                                      ),
                                    ),
                                  ],
                                ),
                                Column(
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.all(8.0),
                                      child: Text(
                                        'דקות',
                                        style: TextStyle(fontSize: 16),
                                      ),
                                    ),
                                    SizedBox(
                                      width: 100,
                                      height: 100,
                                      child: CupertinoPicker(
                                        // scrollController: scrollController,
                                        // looping: true,
                                        itemExtent: 33,
                                        onSelectedItemChanged: (value) {
                                          selectedMin = value;
                                          minOffset = Duration(minutes: selectedMin);

                                          diffTimer.cancel();
                                          _clockDiff(
                                              minOffset: minOffset,
                                              hourOffset: hourOffset);
                                          returnMinute(value);
                                        },
                                        children: List.generate(
                                          61,
                                          (index) => Text("$index"),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                Column(
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.all(8.0),
                                      child: Text(
                                        'שעות',
                                        style: TextStyle(fontSize: 16),
                                      ),
                                    ),
                                    SizedBox(
                                      width: 100,
                                      height: 100,
                                      child: CupertinoPicker(
                                        // scrollController: scrollController,
                                        // looping: true,
                                        itemExtent: 33,
                                        onSelectedItemChanged: (value) {
                                          selectedHour = value;
                                          hourOffset = Duration(hours: selectedHour);

                                          diffTimer.cancel();
                                          _clockDiff(
                                              minOffset: minOffset,
                                              hourOffset: hourOffset);
                                          returnHour(value);
                                        },
                                        children: List.generate(
                                          13,
                                          (index) => Text("$index"),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            SizedBox(
                              height: 30,
                            ),

                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                FloatingActionButton(
                                  onPressed: () {
                                    FlutterAlarmClock.createAlarm(
                                        hour: selectedAlarmH, minutes: selectedAlarmM);
                                  },
                                  child: Icon(Icons.add, color: Colors.black),
                                  backgroundColor: Color(0xFFD2A96A),
                                ),
                                SizedBox(
                                  width: 20,
                                ),
                                InkWell(
                                  onTap: () {
                                    _showTimePicker(context);
                                  },
                                  child: Container(
                                    alignment: Alignment.center,
                                    height: 50,
                                    width: 130,
                                    decoration: BoxDecoration(
                                        color: _selectedRiseSet[1]
                                            ? Color(0xFFBB7154)
                                            : Color(0xFFDD9F0D),
                                        borderRadius: BorderRadius.circular(10),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withOpacity(0.3),
                                            blurRadius: 3,
                                            spreadRadius: 4,
                                            offset: Offset(0, 3),
                                          ),
                                        ]),
                                    child: Text(
                                      '${formatNumber(selectedAlarmH)}:${formatNumber(selectedAlarmM)}',
                                      style: TextStyle(
                                        fontSize: 37,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ),
                                SizedBox(
                                  width: 20,
                                ),
                                FloatingActionButton(
                                  onPressed: FlutterAlarmClock.showAlarms,
                                  backgroundColor: Color(0xFFD2A96A),
                                  child: Icon(
                                    Icons.watch_later_rounded,
                                    color: Colors.black,
                                  ),
                                  // backgroundColor: Colors.red.shade300,
                                ),
                              ],
                            ),
                            SizedBox(
                              height: 10,
                            ),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                SizedBox(width: 15),
                                Text(
                                  'עוד: ',
                                  style: TextStyle(
                                    fontSize: 28,
                                    color: Colors.blueGrey[400]
                                  ),
                                ),
                                Container(
                                  decoration: BoxDecoration(
                                    border: Border.all(
                                      color: Colors.blueGrey[400]!,
                                      width: 2,
                                    ),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 8),
                                    child: Text(
                                      diffClock,
                                      style: TextStyle(
                                          fontSize: 32,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.blueGrey[500]
                                      ),
                                    ),
                                  ),
                                ),
                                Text(
                                  ' שעות',
                                  style: TextStyle(
                                      fontSize: 28,
                                      color: Colors.blueGrey[400]
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class MapsPage extends StatefulWidget {
  @override
  _MapsPageState createState() => _MapsPageState();
}

class _MapsPageState extends State<MapsPage> {
  late GoogleMapController mapController;

  final LatLng _center = LatLng(mapsLocation.latitude, mapsLocation.longitude);
  LatLng? selectedLocation;

  void _onMapCreated(GoogleMapController controller) {
    mapController = controller;
  }

  void _selectLocation(LatLng location) {
    setState(() {
      selectedLocation = location;
    });
    setState(() async {
      await updateLocation(location);
      context.pop();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: ui.TextDirection.rtl,
      child: SafeArea(
        child: Scaffold(
          appBar: AppBar(
            backgroundColor: Color(0xFFA6B7AA),
            centerTitle: true,
            title: const Text('בחר אזור'),
            elevation: 2,
          ),
          body: GoogleMap(
            myLocationEnabled: true,
            mapToolbarEnabled: true,
            onMapCreated: _onMapCreated,
            initialCameraPosition: CameraPosition(
              target: _center,
              zoom: 9.0,
            ),
            onTap: _selectLocation,
            markers: selectedLocation != null
                ? {
              Marker(
                markerId: MarkerId('selectedLocation'),
                position: selectedLocation!,
              ),
            }
                : {},
          ),
        ),
      ),
    );
  }
}
