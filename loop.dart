import 'dart:async';

int i=0;

main() {
  /*
  while (true) {
    print('1');
    print('2');
    print('3');
  }*/

  new Timer.periodic(
      new Duration(seconds: 1),
            (timer) =>
              print('timer ' + (i++).toString())
            );
}
