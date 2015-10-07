import 'dart:async';

int i=0;

main() {
  new Timer.periodic(
      new Duration(seconds: 1),
            (timer) =>
              print('timer ' + (i++).toString())
            );
}
