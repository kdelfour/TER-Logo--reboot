import '../interpreter.dart';
import 'control.dart';
import 'io.dart';
import 'math.dart';
import 'turtle_prims.dart';
import 'words.dart';

List<Primitive> allPrimitives() => [
      ...turtlePrimitives(),
      ...controlPrimitives(),
      ...mathPrimitives(),
      ...wordPrimitives(),
      ...ioPrimitives(),
    ];
