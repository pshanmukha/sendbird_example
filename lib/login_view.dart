import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'dart:async';
import 'package:sendbird_chat_sdk/sendbird_chat_sdk.dart';
import 'package:sendbird_example/group_channel_custom_ui_page.dart';

class LoginView extends StatefulWidget {
  const LoginView({super.key});

  @override
  State<LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends State<LoginView> {
  final String appId = '';
  final String clientUserId = '';
  final String customerAgentUserId = '';
  final String clientAccessToken = '';
  final String customerAgentAccessToken = '';
  final String channelURL = '';

  bool isLoading = false;

  Future<User> connect(
      {required String userId, required String accessToken}) async {
    try {
      await SendbirdChat.init(appId: appId);
      final user = await SendbirdChat.connect(userId, accessToken: accessToken);
      return user;
    } catch (e) {
      if (kDebugMode) print('connect: ERROR: $e');
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("Login"),
      ),
      body: Center(
        child: isLoading
            ? const CircularProgressIndicator()
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TextButton(
                    style: ButtonStyle(
                        backgroundColor: MaterialStateProperty.all<Color>(
                            const Color(0xff742DDD)),
                        foregroundColor:
                            MaterialStateProperty.all<Color>(Colors.white)),
                    onPressed: () async {
                      //Login with Sendbird
                      setState(() {
                        isLoading = true;
                      });
                      await connect(
                              userId: clientUserId,
                              accessToken: clientAccessToken)
                          .then((user) {
                        ///navigate to channel Page
                        setState(() {
                          isLoading = false;
                        });
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => GroupChannelCustomUIPage(
                              groupChannelURL: channelURL,
                            ),
                          ),
                        );
                      }).catchError((error) {
                        setState(() {
                          isLoading = false;
                        });
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                                'login_view: _signInButton: ERROR: $error'),
                          ),
                        );
                      });
                    },
                    child: const Text(
                      "Sign In as Client",
                      style: TextStyle(fontSize: 20.0),
                    ),
                  ),
                  TextButton(
                    style: ButtonStyle(
                        backgroundColor: MaterialStateProperty.all<Color>(
                            const Color(0xff742DDD)),
                        foregroundColor:
                            MaterialStateProperty.all<Color>(Colors.white)),
                    onPressed: () {
                      //Login with Sendbird
                      connect(
                              userId: customerAgentUserId,
                              accessToken: customerAgentAccessToken)
                          .then((user) {
                        ///navigate to channel Page
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => GroupChannelCustomUIPage(
                              groupChannelURL: channelURL,
                            ),
                          ),
                        );
                      }).catchError((error) {
                        if (kDebugMode) print('login_view: _signInButton: ERROR: $error');
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                                'login_view: _signInButton: ERROR: $error'),
                          ),
                        );
                      });
                    },
                    child: const Text(
                      "Sign In as Customer Agent",
                      style: TextStyle(fontSize: 20.0),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
