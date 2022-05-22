/// This File deals with handling the github login
/// If already not logged in GithubLoginWidget (only public class here) will only
/// show a button to prompt login (browser will launch for this) and authenticate the
/// user and use its info for work
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:oauth2/oauth2.dart' as oauth2;
import 'package:url_launcher/url_launcher.dart';

final _authorizationEndpoint =
    Uri.parse('https://github.com/login/oauth/authorize');

final _tokenEndpoint = Uri.parse('https://github.com/login/oauth/access_token');

typedef AuthenticatedBuilder = Widget Function(
    BuildContext context, oauth2.Client client);

class _GithubLoginException implements Exception {
  const _GithubLoginException(this.message);
  final String message;
  @override
  String toString() => message;
}

//client to send data to and from internet
//overridden only the send part to add info that we are sending json data
class _JsonAcceptingHttpClient extends http.BaseClient {
  final _httpClient = http.Client();
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers['Accept'] = 'application/json';
    return _httpClient.send(request);
  }
}

class GithubLoginWidget extends StatefulWidget {
  const GithubLoginWidget({
    required this.builder,
    required this.githubClientId,
    required this.githubClientSecret,
    required this.githubScopes,
    Key? key,
  }) : super(key: key);

  /// The builder method to execute after the OAuth is done by the user on GitHub
  final AuthenticatedBuilder builder;

  final String githubClientId;
  final String githubClientSecret;
  final List<String> githubScopes;

  @override
  GithubLoginState createState() => GithubLoginState();
}

class GithubLoginState extends State<GithubLoginWidget> {
  HttpServer? _redirectServer;
  oauth2.Client? _client;

  /// redirects the authorizationUrl to the OS to handle
  Future<void> _redirect(Uri authorizationUrl) async {
    if (await canLaunchUrl(authorizationUrl)) {
      await launchUrl(
          authorizationUrl); //will use the OS link handling to launch url
    } else {
      throw _GithubLoginException(
          'Could not launch ${authorizationUrl.toString()}');
    }
  }

  /// listen for the response from the authenticating server
  Future<Map<String, String>> _listen() async {
    // hover over the "first"
    var request = await _redirectServer!.first;
    // after listening, send info back to the browser launched in the OS
    var params = request.uri.queryParameters;
    request.response.statusCode = 200;
    request.response.headers.set('content-type', 'text/plain');
    request.response.writeln('Authenticated! You can close this tab.');

    // now close the request and the server itself, set server to null to avoid problems now
    await request.response.close();
    await _redirectServer!.close();
    _redirectServer = null;

    // return the params for the authenticated client
    return params;
  }

  // initiates the login procedure and returns a authenticated client
  Future<oauth2.Client> _getOAuth2Client(Uri redirectUrl) async {
    if (widget.githubClientId.isEmpty || widget.githubClientSecret.isEmpty) {
      throw const _GithubLoginException(
          'githubClientId and githubClientSecret must be not empty. '
          'See `lib/github_oauth_credentials.dart` for more detail.');
    }

    // hover over the AuthorizationCodeGrant for more info
    var grant = oauth2.AuthorizationCodeGrant(
      widget.githubClientId,
      _authorizationEndpoint,
      _tokenEndpoint,
      secret: widget.githubClientSecret,
      httpClient: _JsonAcceptingHttpClient(),
    );
    var authorizationUrl =
        grant.getAuthorizationUrl(redirectUrl, scopes: widget.githubScopes);

    await _redirect(
        authorizationUrl); // wait for the OS the redirect the authorization Url, and await till it happens

    //after successful login, authenticating server will send params of authenticated client, so listen for it
    var responseQueryParameters = await _listen();

    //  handle the authenticated client params and get the client
    var client =
        await grant.handleAuthorizationResponse(responseQueryParameters);
    return client;
  }

  @override
  Widget build(BuildContext context) {
    final client = _client;
    // if client is not null OAuth is done and client is found, proceed to the builder provided
    if (client != null) {
      return widget.builder(context, client);
    }

    // if client is null, OAuth is not done, show a button to initiate the OAuth login
    return Scaffold(
      appBar: AppBar(
        title: const Text('Github Login'),
      ),
      body: Center(
        child: ElevatedButton(
          onPressed: () async {
            // first close any existing ( hence ?) HttpServer
            await _redirectServer?.close();
            // Bind to an ephemeral port on localhost
            _redirectServer = await HttpServer.bind('localhost', 0);

            // get the authenticated Client and setState change the client to the authenticated client
            // the build method will hence execute "builder" rather than this Scaffold
            var authenticatedHttpClient = await _getOAuth2Client(
                Uri.parse('http://localhost:${_redirectServer!.port}/auth'));
            setState(() {
              _client = authenticatedHttpClient;
            });
          },
          child: const Text('Login to Github'),
        ),
      ),
    );
  }
}
