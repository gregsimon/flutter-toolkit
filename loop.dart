import 'dart:async';

main() {
  new Timer.periodic(new Duration(seconds: 1), (timer) => print('timer 0'));
  print('end of main');
}
