// import 'package:epic_wallet/backup_key_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_libepiccash_example/mnemonic_view.dart';
import 'package:numeric_keyboard/numeric_keyboard.dart';

class PasswordView extends StatelessWidget {
  PasswordView({Key? key, required this.name}) : super(key: key);
  final String name;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Epic cash wallet',
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
        primarySwatch: Colors.blue,
      ),
      home: EpicPasswordView(
        title: 'Please enter password',
        name: name,
      ),
    );
  }

// This widget is the root of your application.
}

class EpicPasswordView extends StatefulWidget {
  final String name;
  const EpicPasswordView({Key? key, required this.title, required this.name})
      : super(key: key);

  // This widget is the home page of your application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  // This class is the configuration for the state. It holds the values (in this
  // case the title) provided by the parent (in this case the App widget) and
  // used by the build method of the State. Fields in a Widget subclass are
  // always marked "final".

  final String title;

  @override
  State<EpicPasswordView> createState() => _EpicPasswordView();
}

class _EpicPasswordView extends State<EpicPasswordView> {
  var text = "";

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: const Text('Please enter password'),
        ),
        body: Center(
          child: NumericKeyboard(
              onKeyboardTap: (String value) {
                print("Pressed");
                print(widget.name);
                setState(() {
                  text = text + value;
                  if (text.length == 4) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => MnemonicView(
                                name: widget.name,
                                password: text,
                              )),
                    );
                  }
                });
              },
              textColor: Colors.red,
              rightButtonFn: () {
                setState(() {
                  text = text.substring(0, text.length - 1);
                });
              },
              rightIcon: Icon(
                Icons.backspace,
                color: Colors.red,
              ),
              leftButtonFn: () {
                print('left button clicked');
                print('$text');
              },
              leftIcon: Icon(
                Icons.check,
                color: Colors.red,
              ),
              mainAxisAlignment: MainAxisAlignment.spaceEvenly),
        ));
  }
}
