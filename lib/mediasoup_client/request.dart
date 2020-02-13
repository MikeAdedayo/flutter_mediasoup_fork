import 'dart:async';

class Request {
  Map message;
  Completer completer = Completer();

  Request(this.message);
}