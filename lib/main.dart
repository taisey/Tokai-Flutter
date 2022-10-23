import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:tokaionairapp/privacy_policy.dart';
import './firebase_options.dart' as firebase_options;
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'dart:async';
import 'package:flutter_config/flutter_config.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

Future<void> main() async {
  // For Android emulator
  WidgetsFlutterBinding.ensureInitialized();
  // await FlutterConfig.loadEnvVariables();
  // Initialize Firebase
  await Firebase.initializeApp(
      options: firebase_options.DefaultFirebaseOptions.currentPlatform);
  if (const bool.fromEnvironment('dart.vm.product')) {
    await FirebaseFirestore.instance.enablePersistence();
  }
  // Load env variables
  await dotenv.load(fileName: '.env');
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
            title: 'Tokai OnAir Fan Site',
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

  final Completer<GoogleMapController> _controller = Completer();
  CameraPosition _cameraPosition =
      const CameraPosition(target: LatLng(34.956325, 137.1588248), zoom: 16);
  bool isScrollable = true;

  List<DocumentSnapshot> placeDocuments = [];
  var movieDataObjects = [];

  @override
  void initState() {
    super.initState();
    // getCurrentLocation();
    setAllPlace();
  }

  Future<QuerySnapshot<Map<String, dynamic>>> getFromFirestoreCache(
      collectionName, limit,
      [condition, isEqualTo]) async {
    if (condition == null) {
      return FirebaseFirestore.instance
          .collection(collectionName)
          .limit(limit)
          .get(const GetOptions(source: Source.cache));
    } else {
      return FirebaseFirestore.instance
          .collection(collectionName)
          .where(condition, isEqualTo: isEqualTo)
          .limit(limit)
          .get(const GetOptions(source: Source.cache));
    }
  }

  Future<QuerySnapshot<Map<String, dynamic>>> getFromFirestoreServer(
      collectionName, limit,
      [condition, isEqualTo]) async {
    if (condition == null) {
      return FirebaseFirestore.instance
          .collection(collectionName)
          .limit(limit)
          .get(const GetOptions(source: Source.server));
    } else {
      return FirebaseFirestore.instance
          .collection(collectionName)
          .where(condition, isEqualTo: isEqualTo)
          .limit(limit)
          .get(const GetOptions(source: Source.server));
    }
  }

  Future<void> setAllPlace() async {
    var data = await getFromFirestoreCache('place', 100);
    if (data.docs.isEmpty) {
      data = await getFromFirestoreServer('place', 100);
    }
    setState(() {
      placeDocuments = data.docs;
    });
  }

  Future<bool> getThumbnailKeyList(String placeId) async {
    var data = await getFromFirestoreCache('movie', 5, 'place_id', placeId);
    if (data.docs.isEmpty) {
      data = await getFromFirestoreServer('movie', 5, 'place_id', placeId);
    }
    var movieDocs = data.docs.map((e) => e.id).toList().join(',');
    var url = Uri.parse(
        'https://www.googleapis.com/youtube/v3/videos?id=$movieDocs&key=${dotenv.get('YOUTUBE_API_KEY')}&part=snippet');
    var res = await http.get(url);
    if (res.statusCode == 200) {
      var itemList = jsonDecode(res.body)['items'];
      var currentMovieDataObjects = [];
      for (var i = 0; i < itemList.length; i++) {
        var date = itemList[i]['snippet']['publishedAt'].split('T')[0];
        var publishedAt = date.split('-').join('/');
        currentMovieDataObjects.add({
          'id': itemList[i]['snippet']['videoId'],
          'title': itemList[i]['snippet']['title'],
          'thumbnail': itemList[i]['snippet']['thumbnails']['medium']['url'],
          'publishedAt': publishedAt,
        });
      }
      setState(() {
        movieDataObjects = currentMovieDataObjects;
      });
    } else {
      throw Exception('Failed to load movie data');
    }

    return true;
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
      _cameraPosition = CameraPosition(
          target: LatLng(position.latitude, position.longitude), zoom: 16);
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
        }).then(((value) {
      // showModalBottomSheetが閉じたことを検知(value == null)
      // マップをスクロール可能にする
      setState(() {
        isScrollable = !isScrollable;
      });
    }));
  }

  @override
  Widget build(BuildContext context) {
    List<Marker> markers = placeDocuments.map((placeDocument) {
      return mapMarker(placeDocument);
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title,
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white, fontSize: 20.sp)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      drawer: Drawer(
        child: ListView(children: [
          ListTile(
            title: const Text('Privacy policy'),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const PrivacyPolicy(),
                ),
              );
            },
          ),
        ]),
      ),
      body: Center(
        child: GoogleMap(
          scrollGesturesEnabled: isScrollable,
          mapType: MapType.normal,
          initialCameraPosition: _cameraPosition,
          onMapCreated: (GoogleMapController controller) {
            _controller.complete(controller);
          },
          markers: markers.toSet(),
          myLocationEnabled: true,
          myLocationButtonEnabled: true,
        ),
      ),
      // floatingActionButtonLocation: FloatingActionButtonLocation.startFloat,
      // floatingActionButton: FloatingActionButton(
      //   onPressed: () async {
      //     await getCurrentLocation();
      //     _controller.future.then((controller) {
      //       controller
      //           .animateCamera(CameraUpdate.newCameraPosition(_cameraPosition));
      //     });
      //   },
      //   tooltip: '現在地を取得',
      //   child: const Icon(Icons.my_location, color: Colors.white),
      // ),
    );
  }

  void onTapMarker(placeDocument) async {
    setState(() {
      isScrollable = !isScrollable;
    });
    await getThumbnailKeyList(placeDocument.id);
    if (!mounted) return;
    _showStandardModalBottomSheet(
        context, false, modalContainer(placeDocument));
  }

  Marker mapMarker(placeDocument) {
    return Marker(
      markerId: MarkerId(placeDocument.id),
      position: LatLng(placeDocument['lat'], placeDocument['long']),
      onTap: () => onTapMarker(placeDocument),
    );
  }

  // Modal

  Widget modalContainer(placeDocument) {
    return FutureBuilder(
        future: getThumbnailKeyList(placeDocument.id),
        builder: (context, snapshot) {
          if (snapshot.hasData) {
            return Container(
                margin: const EdgeInsets.all(10),
                height: 500.h,
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      Text(placeDocument['name'],
                          style: TextStyle(fontSize: 18.sp)),
                      _ThumbnailCarousel(
                        movieDataObjects: movieDataObjects,
                      ),
                      // Text(movieDataObjects[currentThumbnailIndex]['title']),
                      modalButtonRow(placeDocument),
                    ]));
          } else {
            return const Center(child: CircularProgressIndicator());
          }
        });
  }

  void moveToGoogleMap(placeDocument) async {
    final Uri url = Uri.parse(
        'comgooglemaps://?api=1&destination=${placeDocument['lat']},${placeDocument['long']}');
    final secondUrl = Uri.parse(
        'https://www.google.com/maps/dir/?api=1&destination=${placeDocument['lat']},${placeDocument['long']}');
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    } else if (await canLaunchUrl(secondUrl)) {
      await launchUrl(secondUrl);
    } else {}
  }

  void moveToMovieList() {
    Navigator.push(
      context,
      MaterialPageRoute(
          builder: (context) => MovieListPage(
                movieDataObjects: movieDataObjects,
              )),
    );
  }

  Widget modalButton(bgColor, text, onPressed) {
    return SizedBox(
      width: 120.w,
      height: 40.h,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: bgColor,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        onPressed: onPressed,
        child: Text(text, style: TextStyle(fontSize: 12.sp)),
      ),
    );
  }

  Widget modalButtonRow(placeDocument) {
    return Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
      modalButton(const Color.fromARGB(255, 245, 157, 42), 'ここへ行く',
          () => moveToGoogleMap(placeDocument)),
      modalButton(
          const Color.fromARGB(255, 102, 202, 241), '動画一覧', moveToMovieList),
    ]);
  }
}

class _ThumbnailCarousel extends StatefulWidget {
  final List<dynamic> movieDataObjects;
  const _ThumbnailCarousel({required this.movieDataObjects});

  @override
  State<StatefulWidget> createState() => _ThumbnailCarouselState();
}

class _ThumbnailCarouselState extends State<_ThumbnailCarousel> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    return CarouselSlider.builder(
        itemCount: widget.movieDataObjects.length,
        itemBuilder: (context, index, realIndex) =>
            // child: Image.network(
            //     'https://i.ytimg.com/vi/${movieDataObjects[index]['id']}/maxresdefault.jpg'),

            index == _currentIndex
                ? SizedBox(
                    height: 400.h,
                    child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          GestureDetector(
                              onTap: () {
                                showDialog(
                                    context: context,
                                    builder: (context) {
                                      return alertYouTubeDialog(index);
                                    });
                              },
                              child: Image.network(
                                  widget.movieDataObjects[index]['thumbnail'])),
                          Padding(
                              padding: const EdgeInsets.only(top: 10),
                              child: Text(
                                  widget.movieDataObjects[index]['title'],
                                  style: TextStyle(fontSize: 12.sp))),
                        ]))
                : Image.network(widget.movieDataObjects[index]['thumbnail']),
        options: CarouselOptions(
            height: 300.h,
            initialPage: 0,
            viewportFraction: 0.8,
            enlargeCenterPage: true,
            enableInfiniteScroll: false,
            onPageChanged: (index, reason) {
              setState(() {
                _currentIndex = index;
              });
            }));
  }

  Widget alertYouTubeDialog(index) {
    return AlertDialog(
      title: const Text(textAlign: TextAlign.center, 'YouTubeを開きます'),
      actions: <Widget>[alertYouTubeDialogContainer(index)],
    );
  }

  Widget alertYouTubeDialogContainer(index) {
    return Container(
        margin: const EdgeInsets.all(10),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
          GestureDetector(
            child: const Text('いいえ'),
            onTap: () {
              Navigator.pop(context);
            },
          ),
          GestureDetector(
            child: const Text('はい'),
            onTap: () async {
              final Uri url = Uri.parse(
                  'https://www.youtube.com/watch?v=${widget.movieDataObjects[index]['id']}');
              if (await canLaunchUrl(url)) {
                launchUrl(
                  url,
                );
              }
            },
          )
        ]));
  }
}

class MovieListPage extends StatelessWidget {
  final List<dynamic> movieDataObjects;
  const MovieListPage({Key? key, required this.movieDataObjects})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('動画一覧', style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: movieDataObjects
              .map((elem) => Container(
                    alignment: Alignment.center,
                    margin: const EdgeInsets.symmetric(
                        vertical: 10, horizontal: 20),
                    child: GestureDetector(
                      child: Card(
                          child: Padding(
                              padding: const EdgeInsets.all(10),
                              child: Column(children: [
                                Image.network(elem['thumbnail']),
                                SizedBox(
                                    width: 320,
                                    child: Padding(
                                        padding: const EdgeInsets.only(top: 10),
                                        child: Column(children: [
                                          Text(elem['title']),
                                          Align(
                                              alignment: Alignment.centerRight,
                                              child: Text(elem['publishedAt'])),
                                        ]))),
                              ]))),
                      onTap: () async {
                        final Uri url = Uri.parse(
                            'https://www.youtube.com/watch?v=${elem['id']}');
                        if (await canLaunchUrl(url)) {
                          launchUrl(
                            url,
                          );
                        }
                      },
                    ),
                  ))
              // 'https://i.ytimg.com/vi/${elem['id']}/maxresdefault.jpg')))
              .toList(),
        ),
      ),
    );
  }
}
