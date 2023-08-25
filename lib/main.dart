import 'package:flutter/material.dart';

import 'package:flutter_background_geolocation/flutter_background_geolocation.dart' as bg;

import 'dart:convert';

import 'package:flutter_switch/flutter_switch.dart';

JsonEncoder encoder = new JsonEncoder.withIndent("     ");

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        // This is the theme of your application.
        //
        // TRY THIS: Try running your application with "flutter run". You'll see
        // the application has a blue toolbar. Then, without quitting the app,
        // try changing the seedColor in the colorScheme below to Colors.green
        // and then invoke "hot reload" (save your changes or press the "hot
        // reload" button in a Flutter-supported IDE, or press "r" if you used
        // the command line to start the app).
        //
        // Notice that the counter didn't reset back to zero; the application
        // state is not lost during the reload. To reset the state, use hot
        // restart instead.
        //
        // This works for code too, not just values: Most code changes can be
        // tested with just a hot reload.
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const MyHomePage(title: 'Flutter Demo Home Page'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  // This widget is the home page of your application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  // This class is the configuration for the state. It holds the values (in this
  // case the title) provided by the parent (in this case the App widget) and
  // used by the build method of the State. Fields in a Widget subclass are
  // always marked "final".

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  late String _motionActivity = '';
  late String _content = '';
  late String _odometer = '';
  late String _geofence = '';

  late String _eventMotionChange = '';
  late String _eventLocation = "";

  Future<void> _showDialog(String title, String message) async {
    await showDialog<void>(
        context: context,
        builder: (BuildContext context) {
          return SimpleDialog( // <-- SEE HERE
            title: Text(title),
            children: <Widget>[
              SimpleDialogOption(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                child: Text(message),
              )
            ],
          );
        });
  }

  void backgroundGeolocationHeadlessTask(bg.HeadlessEvent headlessEvent) async {
    print('[BackgroundGeolocation] headless task $headlessEvent');
    Map<String, dynamic> data = <String, dynamic>{};
    data['message'] = '[providerchange] - $headlessEvent';
    //debugLogToServer(data);
  }

  void bgStop() {
    bg.BackgroundGeolocation.stop().then((bg.State state) {
      print('[stop] success: $state');
      // Reset odometer.
      bg.BackgroundGeolocation.setOdometer(0.0);
      _odometer = '0.0';
    });
  }

  void _getLocation() {
    bg.BackgroundGeolocation.getCurrentPosition(
        timeout: 30,
        // 30 second timeout to fetch location
        maximumAge: 5000,
        // Accept the last-known-location if not older than 5000 ms.
        desiredAccuracy: 10,
        // Try to fetch a location with an accuracy of `10` meters.
        samples: 3,
        // How many location samples to attempt.
        extras: {
          // [Optional] Attach your own custom meta-data to this location.  This meta-data will be persisted to SQLite and POSTed to your server
          "foo": "bar"
        }).then((bg.Location location) {
      print('[getCurrentPosition] - $location');
    }).catchError((error) {
      print('[getCurrentPosition] ERROR: $error');
    });
  }

  @override
  void initState() {
    super.initState();

    bg.BackgroundGeolocation.addGeofences([bg.Geofence(
      identifier: "Home",
      radius: 200,
      latitude: 46.15832,
      longitude: 13.7510517,
      notifyOnEntry: true,
    ), bg.Geofence(
        identifier: "Work",
        radius: 50,
        latitude: 45.9683367,
        longitude: 13.6394,
        notifyOnEntry: true
    )
    ]).then((bool success) {
      print('[addGeofences] success');
    }).catchError((dynamic error) =>
    {
      print('[addGeofences] FAILURE: $error')
    });

    bg.BackgroundGeolocation.onGeofence((bg.GeofenceEvent event) {
      print('[geofence] ${event.identifier}, ${event.action}');
      //handleResponse( event.identifier + ' / ' +  event.action);
      setState(() {
        _geofence = "[geofence] ${event.identifier}, ${event.action}";
        _showDialog('geofence', '${event.identifier}, ${event.action}');
      });
    });

    bg.BackgroundGeolocation.onGeofencesChange((bg.GeofencesChangeEvent event) {
      // Create map circles
      event.on.forEach((bg.Geofence geofence) {
        print(geofence);
      });

      // Remove map circles
      event.off.forEach((String identifier) {
        print(identifier);
      });
    });

    ////
    // 1.  Listen to events (See docs for all 12 available events).
    //

    // Fired whenever a location is recorded
    bg.BackgroundGeolocation.onLocation((bg.Location location) {
      print('[location] - $location');

      String odometerKM = (location.odometer / 1000.0).toStringAsFixed(1);

      setState(() {
        _content = encoder.convert(location.toMap());
        _odometer = odometerKM;

        _eventLocation = "[location] - $location";
      });
    }, (bg.LocationError error) {
      print('[onLocation] ERROR: ${error}');
    });

    // Fired whenever the plugin changes motion-state (stationary->moving and vice-versa)
    bg.BackgroundGeolocation.onMotionChange((bg.Location location) {
      print('[motionchange] - $location');
      setState(() {
        _eventMotionChange = "[motionchange] - $location";
      });
    });

    bg.BackgroundGeolocation.onActivityChange((bg.ActivityChangeEvent event) {
      print('[activitychange] - $event');
      setState(() {
        _motionActivity = event.activity;
      });
    });

    // Fired whenever the state of location-services changes.  Always fired at boot
    bg.BackgroundGeolocation.onProviderChange((bg.ProviderChangeEvent event) {
      print('[providerchange] - $event');
    });

    ////
    // 2.  Configure the plugin
    //
    bg.BackgroundGeolocation.ready(bg.Config(
        desiredAccuracy: bg.Config.DESIRED_ACCURACY_HIGH,
        distanceFilter: 1.0,
        stopOnTerminate: true,
        startOnBoot: true,
        autoSync: false,
        reset: true,  // <-- set true to ALWAYS apply supplied config; not just at first launch.
        isMoving: true,
        stopTimeout: 30000,
        disableStopDetection: true,
        geofenceProximityRadius: 200,
        foregroundService: true,
        debug: true,
        logLevel: bg.Config.LOG_LEVEL_VERBOSE
    )).then((bg.State state) {
      if (!state.enabled) {
        ////
        // 3.  Start the plugin.
        //
        bg.BackgroundGeolocation.start();

        // engage geofences-only mode:
        // bg.BackgroundGeolocation.startGeofences();
      }
    });
  }


  @override
  Widget build(BuildContext context) {
    // This method is rerun every time setState is called, for instance as done
    // by the _incrementCounter method above.
    //
    // The Flutter framework has been optimized to make rerunning build methods
    // fast, so that you can just rebuild anything that needs updating rather
    // than having to individually change instances of widgets.
    return Scaffold(
      appBar: AppBar(
        // TRY THIS: Try changing the color here to a specific color (to
        // Colors.amber, perhaps?) and trigger a hot reload to see the AppBar
        // change color while the other colors stay the same.
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        // Here we take the value from the MyHomePage object that was created by
        // the App.build method, and use it to set our appbar title.
        title: Text(widget.title),
      ),
      body: Center(
        // Center is a layout widget. It takes a single child and positions it
        // in the middle of the parent.
        child: SingleChildScrollView(
          child: Column(
            // Column is also a layout widget. It takes a list of children and
            // arranges them vertically. By default, it sizes itself to fit its
            // children horizontally, and tries to be as tall as its parent.
            //
            // Column has various properties to control how it sizes itself and
            // how it positions its children. Here we use mainAxisAlignment to
            // center the children vertically; the main axis here is the vertical
            // axis because Columns are vertical (the cross axis would be
            // horizontal).
            //
            // TRY THIS: Invoke "debug painting" (choose the "Toggle Debug Paint"
            // action in the IDE, or press "p" in the console), to see the
            // wireframe for each widget.
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              const SizedBox(height: 10.0),

              // Text('_eventMotionChange: $_eventMotionChange'),
              // Text('_eventLocation: $_eventLocation'),
              Text('$_motionActivity  $_odometer km'),
              Text('$_content'),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _getLocation,
        tooltip: 'GetLocation',
        child: const Icon(Icons.add),
      ), // This trailing comma makes auto-formatting nicer for build methods.
    );
  }
}