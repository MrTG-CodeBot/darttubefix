import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';

final http.Client _client = IOClient(
  HttpClient()..badCertificateCallback = (X509Certificate cert, String host, int port) => true,
);

Future<String> executeRequest(
  String url, {
  String? method,
  Map<String, String>? headers,
  dynamic data,
}) async {
  final uri = Uri.parse(url);
  final reqHeaders = <String, String>{
    "User-Agent": "Mozilla/5.0",
    "accept-language": "en-US,en",
  };
  if (headers != null) {
    reqHeaders.addAll(headers);
  }

  http.Response response;
  final bodyStr = data is Map ? json.encode(data) : data?.toString();

  if (method == 'POST') {
    response = await _client.post(uri, headers: reqHeaders, body: bodyStr);
  } else if (method == 'HEAD') {
    response = await _client.head(uri, headers: reqHeaders);
  } else {
    response = await _client.get(uri, headers: reqHeaders);
  }

  return response.body;
}

Future<String> getRequest(String url, {Map<String, String>? extraHeaders}) async {
  return executeRequest(url, method: 'GET', headers: extraHeaders);
}

Future<String> postRequest(
  String url, {
  Map<String, String>? extraHeaders,
  Map<String, dynamic>? data,
}) async {
  final Map<String, String> headers = {"Content-Type": "application/json"};
  if (extraHeaders != null) {
    headers.addAll(extraHeaders);
  }
  return executeRequest(url, method: 'POST', headers: headers, data: data);
}
