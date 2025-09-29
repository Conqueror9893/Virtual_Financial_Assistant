import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_frontend_app/models/message.dart';

class ApiService {
  final String _baseUrl = "http://10.32.2.151:3009";

  Future<Message> sendMessage(String text) async {
    try {
      // First, get the structured response from the chatbot
      final response = await http.post(
        Uri.parse('$_baseUrl/chatbot'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'user_id': '1', 'query': text}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final botResp = data['response'] ?? data;

        // Now, rephrase the response using the LLM connector
        final rephrasedResponse = await http.post(
          Uri.parse('$_baseUrl/rephrase'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(botResp),
        );

        if (rephrasedResponse.statusCode == 200) {
          final rephrasedData = jsonDecode(rephrasedResponse.body);
          return Message(
            id: DateTime.now().toString(),
            text: rephrasedData['rephrased_message'],
            isUser: false,
            data: botResp,
          );
        } else {
          // If rephrasing fails, return the original structured data as string
          return Message(
            id: DateTime.now().toString(),
            text: botResp.toString(),
            isUser: false,
          );
        }
      } else {
        return Message(
          id: DateTime.now().toString(),
          text: 'Error: ${response.statusCode}',
          isUser: false,
        );
      }
    } catch (e) {
      return Message(
        id: DateTime.now().toString(),
        text: 'Error: $e',
        isUser: false,
      );
    }
  }
}