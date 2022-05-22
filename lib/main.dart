import 'package:flutter/material.dart';
import 'package:github/github.dart';
import 'package:github_client/github_oauth_credential.dart';
import 'package:github_client/src/github_summary.dart';
import 'src/github_login.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Github Client',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        // hover over the "VisualDensity" for more info
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: const MyHomePage(title: 'GitHub Client'),
    );
  }
}

Future<CurrentUser> viewerDetail(String accessToken) async {
  final gitHub = GitHub(auth: Authentication.withToken(accessToken));
  return gitHub.users.getCurrentUser();
}

GitHub _getGitHub(String accessToken) {
  return GitHub(auth: Authentication.withToken(accessToken));
}

class MyHomePage extends StatelessWidget {
  const MyHomePage({Key? key, required this.title}) : super(key: key);

  final String title;

  @override
  Widget build(BuildContext context) {
    return GithubLoginWidget(
        builder: (context, httpClient) {
          return FutureBuilder<CurrentUser>(
            future: viewerDetail(httpClient.credentials.accessToken),
            builder: (context, snapshot) => Scaffold(
              appBar: AppBar(
                title: Text(title),
              ),
              body: GitHubSummary(gitHub: _getGitHub(httpClient.credentials.accessToken)),
            ),
          );
        },
        githubClientId: githubClientId,
        githubClientSecret: githubClientSecret,
        githubScopes: githubScopes);
  }
}
