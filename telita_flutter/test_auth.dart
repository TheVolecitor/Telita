import 'dart:convert';
import 'package:http/http.dart' as http;

void main() async {
  final url = 'https://telita.thevolecitor.qzz.io';
  final res = await http.post(
    Uri.parse('$url/api/auth/device/code'),
    headers: {'Content-Type': 'application/json'},
  );
  print('Code Response: ${res.statusCode} ${res.body}');
  
  final data = jsonDecode(res.body);
  final deviceCode = data['device_code'];
  
  final res2 = await http.post(
    Uri.parse('$url/api/auth/device/token'),
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode({'device_code': deviceCode}),
  );
  print('Token Response: ${res2.statusCode} ${res2.body}');
}
