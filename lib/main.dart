import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import './firebase_options.dart' as firebase_options;
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:url_launcher/url_launcher.dart';

Future<void> main() async {
  await Firebase.initializeApp(
      options: firebase_options.DefaultFirebaseOptions.currentPlatform);
  if (const bool.fromEnvironment('dart.vm.product')) {
    await FirebaseFirestore.instance.enablePersistence();
  }
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return ScreenUtilInit(
        designSize: const Size(390, 844),
        builder: (context, child) {
          return MaterialApp(
            title: 'Flutter Demo',
            theme: ThemeData(
              // This is the theme of your application.
              //
              // Try running your application with "flutter run". You'll see the
              // application has a blue toolbar. Then, without quitting the app, try
              // changing the primarySwatch below to Colors.green and then invoke
              // "hot reload" (press "r" in the console where you ran "flutter run",
              // or simply save your changes to "hot reload" in a Flutter IDE).
              // Notice that the counter didn't reset back to zero; the application
              // is not restarted.
              primarySwatch: Colors.orange,
              fontFamily: 'MPLUSRounded1c',
            ),
            home: const MyHomePage(title: 'Tokai OnAir Fan Site'),
          );
        });
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
  final Map<String, double> _currentLocation = {
    'latitude': 34.956325,
    'longitude': 137.1588248
  };
  final MapController _mapController = MapController();

  int currentThumbnailIndex = 0;
  List<String> thumbnailKeyList = ['KvpsHIRVd94', 'feDU_I2iL1I'];
  List<DocumentSnapshot> placeDocuments = [];
  List<DocumentSnapshot> thumbnailDocuments = [];

  @override
  void initState() {
    super.initState();
    // getCurrentLocation();
    setAllPlace();
  }

  getFromFirestoreCache(collectionName, [condition, isEqualTo]) async {
    if (condition == null) {
      return FirebaseFirestore.instance
          .collection(collectionName)
          .get(GetOptions(source: Source.cache));
    } else {
      return FirebaseFirestore.instance
          .collection(collectionName)
          .where(condition, isEqualTo: isEqualTo)
          .get(GetOptions(source: Source.cache));
    }
  }

  getFromFirestoreServer(collectionName, [condition, isEqualTo]) async {
    if (condition == null) {
      return FirebaseFirestore.instance
          .collection(collectionName)
          .get(GetOptions(source: Source.server));
    } else {
      return FirebaseFirestore.instance
          .collection(collectionName)
          .where(condition, isEqualTo: isEqualTo)
          .get(GetOptions(source: Source.server));
    }
  }

  Future<void> setAllPlace() async {
    var data = await getFromFirestoreCache('Place');
    if (data.docs.isEmpty) {
      data = await getFromFirestoreServer('Place');
    }
    setState(() {
      placeDocuments = data.docs;
    });
  }

  Future<void> getThumbnailKeyList(int placeId) async {
    var data = await getFromFirestoreCache('Movie', 'place_id', placeId);
    print('${data.docs}');
    if (data.docs.isEmpty) {
      data = await getFromFirestoreServer('Movie', 'place_id', placeId);
    }
    setState(() {
      thumbnailDocuments = data.docs;
    });
    return;
  }

  Future<void> getCurrentLocation() async {
    // 権限を取得
    LocationPermission permission = await Geolocator.requestPermission();
    // 権限がない場合は戻る
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return;
    }
    // 位置情報を取得
    Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high);

    setState(() {
      // 北緯がプラス。南緯がマイナス
      _currentLocation['latitude'] = position.latitude;
      // 東経がプラス、西経がマイナス
      _currentLocation['longitude'] = position.longitude;
      // 現在地をマップの中央に設定する
      _mapController.move(LatLng(position.latitude, position.longitude), 16.0);
    });
  }

  void _showStandardModalBottomSheet(
    BuildContext context,
    bool isScrollControlled,
    Widget child,
  ) {
    showModalBottomSheet(
        //モーダルの背景の色、透過
        backgroundColor: Colors.transparent,
        //ドラッグ可能にする（高さもハーフサイズからフルサイズになる様子）
        isScrollControlled: isScrollControlled,
        context: context,
        builder: (BuildContext context) {
          return Container(
              decoration: const BoxDecoration(
                //モーダル自体の色
                color: Colors.white,
                //角丸にする
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
              ),
              child: child);
        });
  }

  @override
  Widget build(BuildContext context) {
    LatLng _center =
        LatLng(_currentLocation['latitude']!, _currentLocation['longitude']!);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title,
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white, fontSize: 20.sp)),
      ),
      body: Center(
        child: FlutterMap(
          options: MapOptions(
            center: _center,
            zoom: 16.0,
            maxZoom: 17.0,
            minZoom: 3.0,
          ),
          mapController: _mapController,
          children: [
            TileLayer(
              urlTemplate: "https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png",
              subdomains: ['a', 'b', 'c'],
              retinaMode: true,
            ),
            MarkerLayer(
              markers: [
                Marker(
                  point: LatLng(_currentLocation['latitude']!,
                      _currentLocation['longitude']!),
                  builder: (context) => const Icon(Icons.my_location),
                ),
                for (var placeDocument in placeDocuments)
                  Marker(
                    point: LatLng(placeDocument['lat'], placeDocument['long']),
                    builder: (context) => GestureDetector(
                      onTap: () async {
                        await getThumbnailKeyList(placeDocument['id']);
                        if (!mounted) return;
                        _showStandardModalBottomSheet(
                            context,
                            false,
                            Container(
                                margin: const EdgeInsets.all(10),
                                height: 450.h,
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.center,
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceEvenly,
                                    children: [
                                      Text(placeDocument['name'],
                                          style: TextStyle(fontSize: 18.sp)),
                                      thumbnailCarousel(),
                                      Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceAround,
                                          children: [
                                            SizedBox(
                                              width: 120.w,
                                              height: 40.h,
                                              child: ElevatedButton(
                                                  style:
                                                      ElevatedButton.styleFrom(
                                                    backgroundColor:
                                                        Color.fromARGB(
                                                            255, 245, 157, 42),
                                                    foregroundColor:
                                                        Colors.white,
                                                    shape:
                                                        RoundedRectangleBorder(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              10),
                                                    ),
                                                  ),
                                                  child: Text('ここへ行く',
                                                      style: TextStyle(
                                                          fontSize: 12.sp)),
                                                  onPressed: () async {
                                                    final Uri url = Uri.parse(
                                                        'comgooglemaps://?api=1&destination=${placeDocument['lat']},${placeDocument['long']}');
                                                    final secondUrl = Uri.parse(
                                                        'https://www.google.com/maps/dir/?api=1&destination=${placeDocument['lat']},${placeDocument['long']}');
                                                    if (await canLaunchUrl(
                                                        url)) {
                                                      await launchUrl(url);
                                                    } else if (await canLaunchUrl(
                                                        secondUrl)) {
                                                      await launchUrl(
                                                          secondUrl);
                                                    } else {}
                                                  }),
                                            ),
                                            SizedBox(
                                              width: 120.w,
                                              height: 40.h,
                                              child: ElevatedButton(
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor:
                                                      Color.fromARGB(
                                                          255, 102, 202, 241),
                                                  foregroundColor: Colors.white,
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            10),
                                                  ),
                                                ),
                                                child: Text('動画一覧',
                                                    style: TextStyle(
                                                        fontSize: 12.sp)),
                                                onPressed: () {
                                                  Navigator.push(
                                                    context,
                                                    MaterialPageRoute(
                                                        builder: (context) =>
                                                            MovieListPage(
                                                              thumbnailDocuments:
                                                                  thumbnailDocuments,
                                                            )),
                                                  );
                                                },
                                              ),
                                            ),
                                          ]),
                                    ])));
                      },
                      child: const Icon(
                        Icons.location_pin,
                        color: Color.fromARGB(255, 27, 89, 224),
                        size: 40,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: getCurrentLocation,
        tooltip: '現在地を取得',
        child: const Icon(Icons.my_location),
      ),
    );
  }

  Widget thumbnailCarousel() {
    return CarouselSlider.builder(
        // itemCount: thumbnailKeyList.length,
        itemCount: thumbnailDocuments.length,
        itemBuilder: (context, index, realIndex) => GestureDetector(
              onTap: () {
                showDialog(
                    context: context,
                    builder: (context) {
                      return AlertDialog(
                        title: const Text(
                            textAlign: TextAlign.center, 'YouTubeを開きます'),
                        actions: <Widget>[
                          Container(
                              margin: const EdgeInsets.all(10),
                              child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceAround,
                                  children: [
                                    GestureDetector(
                                      child: Text('いいえ'),
                                      onTap: () {
                                        Navigator.pop(context);
                                      },
                                    ),
                                    GestureDetector(
                                      child: Text('はい'),
                                      onTap: () async {
                                        final Uri url = Uri.parse(
                                            'https://www.youtube.com/watch?v=${thumbnailDocuments[index].id}');
                                        if (await canLaunchUrl(url)) {
                                          launchUrl(
                                            url,
                                          );
                                        }
                                        ;
                                      },
                                    )
                                  ]))
                        ],
                      );
                    });
              },
              child: Image.network(
                  'https://img.youtube.com/vi/${thumbnailDocuments[index].id}/maxresdefault.jpg'),
            ),
        options: CarouselOptions(
            initialPage: 0,
            viewportFraction: 0.8,
            enlargeCenterPage: true,
            enableInfiniteScroll: false,
            onPageChanged: (index, reason) => setState(() {
                  currentThumbnailIndex = index;
                })));
  }
}

class MovieListPage extends StatelessWidget {
  final List<DocumentSnapshot> thumbnailDocuments;
  const MovieListPage({Key? key, required this.thumbnailDocuments})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('動画一覧'),
      ),
      body: SingleChildScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: thumbnailDocuments
              .map((elem) => Container(
                  margin:
                      const EdgeInsets.symmetric(vertical: 10, horizontal: 20),
                  child: Image.network(
                      'https://img.youtube.com/vi/${elem.id}/maxresdefault.jpg')))
              .toList(),
        ),
      ),
    );
  }
}
