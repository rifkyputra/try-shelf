import 'dart:convert';
import 'dart:io';

import 'package:args/args.dart';
import 'package:shelf/shelf.dart' as shelf;
import 'package:shelf/shelf_io.dart' as io;
import 'package:shelf_router/shelf_router.dart';
import 'package:database/database.dart';
import 'package:database/sql.dart';
import 'package:database/sql.dart';
import 'package:database_adapter_postgre/database_adapter_postgre.dart';

// For Google Cloud Run, set _hostname to '0.0.0.0'.
const _hostname = 'localhost';

void main(List<String> args) async {
  var parser = ArgParser()..addOption('port', abbr: 'p');
  var result = parser.parse(args);

  var app = Router();

  final database = MemoryDatabaseAdapter().database();

  final config = Postgre(
    host: 'localhost',
    port: 5432,
    user: 'rifky',
    password: '12345',
    databaseName: 'rifky',
  );

  final sqlClient = config.database().sqlClient;

  final collection = database.collection('todos');

  final document = collection.newDocument();

  app.get('/hello', (shelf.Request req) {
    return shelf.Response.ok('Hello, World!');
  });
  app.post('/yas', (shelf.Request req) async {
    final todoItem = await req.readAsString();

    print(todoItem);

    return shelf.Response.ok(todoItem);
  });

  app.post('/todo/new', (shelf.Request req) async {
    final todoItem = await req.readAsString();
    // document.insert(data: data)
    final Map<String, dynamic> json = jsonDecode(todoItem);

    try {
      await collection.insert(data: json);
      final String name = json['name'] ?? '';
      final status = json['isCompleted'] == 'true' ? true : false;

      print('$status named : $name');
      // await sqlClient.query(
      //     'INSERT INTO todos ("name", "isCompleted") VALUES ("$name", "$status")');
      await sqlClient.table('todos').insert({
        'name': name,
        'isCompleted': status,
      });
    } catch (e) {
      print(e);
      return shelf.Response.internalServerError();
    }

    // await collection.insert(data: json);

    return shelf.Response.ok('success!');
  });
  app.put('/todo/<id>', (request) async {
    try {
      await sqlClient.query('UPDATE INTO todos ("isCompleted") VALUES ("") ');
    } catch (e) {
      print(e);
    }
    return shelf.Response.ok('body');
  });

  app.get('/todos', (shelf.Request req) async {
    // document.insert(data: data)
    final List allTodos = [];

    final iterator = await sqlClient.query('SELECT * FROM todos');
    final todos = (await collection.search()).snapshots ?? [];

    for (Snapshot s in todos) {
      allTodos.add(s.data);
    }

    print((await iterator.toMaps()));
    print((await iterator.toRows()));

    final encoded = jsonEncode(await iterator.toMaps());

    return shelf.Response.ok(
      encoded,
      headers: {'Content-Type': 'application/json'},
    );
  });

  // For Google Cloud Run, we respect the PORT environment variable
  var portStr = result['port'] ?? Platform.environment['PORT'] ?? '8090';
  var port = int.tryParse(portStr);

  if (port == null) {
    stdout.writeln('Could not parse port value "$portStr" into a number.');
    // 64: command line usage error
    exitCode = 64;
    return;
  }

  var handler =
      const shelf.Pipeline().addMiddleware(shelf.logRequests()).addHandler(app);

  // var handler2 = ;

  var server = await io.serve(handler, _hostname, port);
  print('Serving at http://${server.address.host}:${server.port}');
}

shelf.Response _echoRequest(shelf.Request request) =>
    shelf.Response.ok('Request for "${request.url}"');
