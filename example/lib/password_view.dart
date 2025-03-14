import 'package:flutter/material.dart';
import 'package:flutter_libepiccash_example/mnemonic_view.dart';
import 'package:numeric_keyboard/numeric_keyboard.dart';

class PasswordView extends StatelessWidget {
  PasswordView({Key? key, required this.name}) : super(key: key);
  final String name;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Enter Password'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: EpicPasswordView(
        title: 'Please enter password',
        name: name,
      ),
    );
  }
}

class EpicPasswordView extends StatefulWidget {
  final String name;
  const EpicPasswordView({Key? key, required this.title, required this.name})
      : super(key: key);

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
          leading: IconButton(
            icon: Icon(Icons.arrow_back),
            onPressed: () => Navigator.pop(context),
          ),
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
