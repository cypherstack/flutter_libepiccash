import 'dart:io';

import 'package:flutter_libepiccash_example/password_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_libepiccash_example/recover_view.dart';

class WalletNameView extends StatelessWidget {
  const WalletNameView({Key? key, required this.recover}) : super(key: key);
  final bool recover;
  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Wallet Name',
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
      home: EpicWalletNameView(
          title: 'Please enter wallet name', recover: recover),
    );
  }
}

class EpicWalletNameView extends StatefulWidget {
  const EpicWalletNameView(
      {Key? key, required this.title, required this.recover})
      : super(key: key);
  final bool recover;

  // This widget is the home page of your application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  // This class is the configuration for the state. It holds the values (in this
  // case the title) provided by the parent (in this case the App widget) and
  // used by the build method of the State. Fields in a Widget subclass are
  // always marked "final".

  final String title;

  @override
  State<EpicWalletNameView> createState() => _EpicWalletNameView();
}

class _EpicWalletNameView extends State<EpicWalletNameView> {
  var name = "";

  void _setWalletName(value) {
    setState(() {
      // This call to setState tells the Flutter framework that something has
      // changed in this State, which causes it to rerun the build method below
      // so that the display can reflect the updated values. If we changed
      // _counter without calling setState(), then the build method would not be
      // called again, and so nothing would appear to happen.
      name = name + value;
    });
  }

  final _formKey = GlobalKey<FormState>();
  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          // Here we take the value from the MyHomePage object that was created by
          // the App.build method, and use it to set our appbar title.
          title: Text(widget.title),
        ),
        body: Form(
          key: _formKey,
          child: Column(
            children: <Widget>[
              TextFormField(
                // The validator receives the text that the user has entered.
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter some text';
                  }

                  _setWalletName(value);

                  return null;
                },
              ),
              ElevatedButton(
                onPressed: () {
                  print("Name is $name");
                  bool isRecover = widget.recover;
                  // Validate returns true if the form is valid, or false otherwise.
                  if (_formKey.currentState!.validate()) {
                    print("Name is still $name");
                    print("Wallet recover is  $isRecover");
                    if (isRecover == true) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => RecoverWalletView(
                                  name: name,
                                )),
                      );
                    } else {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => PasswordView(
                                  name: name,
                                )),
                      );
                    }
                  }
                },
                child: const Text('Next'),
              ),
              // Add TextFormFields and ElevatedButton here.
            ],
          ),
        ));
    // This method is rerun every time setState is called, for instance as done
    // by the _incrementCounter method above.
    //
    // The Flutter framework has been optimized to make rerunning build methods
    // fast, so that you can just rebuild anything that needs updating rather
    // than having to individually change instances of widgets.
    return Form(
      key: _formKey,
      child: Column(
        children: <Widget>[
          TextFormField(
            // The validator receives the text that the user has entered.
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter some text';
              }
              return null;
            },
          ),
          ElevatedButton(
            onPressed: () {
              // Validate returns true if the form is valid, or false otherwise.
              if (_formKey.currentState!.validate()) {
                // If the form is valid, display a snackbar. In the real world,
                // you'd often call a server or save the information in a database.
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Processing Data')),
                );
              }
            },
            child: const Text('Submit'),
          ),
          // Add TextFormFields and ElevatedButton here.
        ],
      ),
    );
  }
}
