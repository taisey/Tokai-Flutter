import 'package:flutter/material.dart';
import 'package:url_launcher/link.dart';

class PrivacyPolicy extends StatelessWidget {
  const PrivacyPolicy({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title:
            const Text('Privacy policy', style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          linkContainer(
              'https://www.youtube.com/static?template=terms&hl=ja&gl=JP',
              'YouTube規約 (外部リンク)'),
          linkContainer(
              'https://developers.google.com/youtube/terms/api-services-terms-of-service',
              'YouTube API 利用規約 (外部リンク)'),
          const Text('Copyright ©2022 東海オンエア聖地サイト All Rights Reserved.')
        ]),
      ),
    );
  }

  Widget linkContainer(uri, text) {
    return Link(
      uri: Uri.parse(uri),
      builder: (BuildContext ctx, FollowLink? openLink) {
        return TextButton(
          onPressed: openLink,
          style: ButtonStyle(
            padding: MaterialStateProperty.all(EdgeInsets.zero),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: Text(
            text,
            style: const TextStyle(fontSize: 12, color: Colors.blue),
          ),
        );
      },
    );
  }
}
