import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:fetch_client/fetch_client.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

const String botMark = 'Bot##';


class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  ChatScreenState createState() => ChatScreenState();
}

class ChatScreenState extends State<ChatScreen> {
  List<dynamic> _messages = ['$botMark你好！我是你的中文取名助手。请问有什么可以帮您的？'];
  Uint8List? latestImage;
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool sendLock = false;
  String ollamaUrl = const String.fromEnvironment('ollama_url', defaultValue: 'localhost:11434');
  String paligemmaUrl = const String.fromEnvironment('paligemma_url', defaultValue: 'localhost:5443');

  late final _focusNode = FocusNode(
    onKey: (FocusNode node, RawKeyEvent evt) {
      if (!evt.isShiftPressed && evt.logicalKey.keyLabel == 'Enter') {
        if (evt is RawKeyDownEvent) {
          _sendMessage();
        }
        return KeyEventResult.handled;
      }
      else {
        return KeyEventResult.ignored;
      }
    },
  );

  @override
  void initState() {
    super.initState();
    ollamaUnload();
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('👶 Gemma NameCraft'), //：帮你构思宝宝的名字 :D
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.orange, Colors.purple],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            )
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: Container(
              color: Colors.grey[200],
              child: ListView.builder(
                controller: _scrollController,
                itemCount: _messages.length,
                itemBuilder: (BuildContext context, int index) {
                  var message = _messages[index];
                  // final isUserMessage = index % 2 == 0;
                  // final alignment = isUserMessage ? AlignmentDirectional.centerStart : AlignmentDirectional.centerEnd;
                  // final backgroundColor = isUserMessage ? null : Colors.lightGreen[100];
                  late final AlignmentDirectional alignment;
                  late final Color? backgroundColor;
                  late final bool isUserMessage;
                  if (message is String) {
                    if (message.startsWith(botMark)) {
                      isUserMessage = false;
                      message = message.replaceAll(botMark, '');
                    }
                    else {
                      isUserMessage = true;
                    }
                  }
                  else {
                    isUserMessage = true;
                  }
                  if (isUserMessage) {
                    alignment = AlignmentDirectional.centerEnd;
                    backgroundColor = Colors.lightGreen[100];
                  }
                  else {
                    alignment = AlignmentDirectional.centerStart;
                    backgroundColor = null;
                  }
                  var width = MediaQuery.of(context).size.width * 0.6;
                  var imageHeight = MediaQuery.of(context).size.height * 0.5;
                  if (message is String) {
                    return Container(
                      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
                      alignment: alignment,
                      child: SizedBox(
                        width: width,
                        child: Card(
                          color: backgroundColor,
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: MarkdownBody(data: message),
                          ),
                        ),
                      ),
                    );
                  } else if (message is Uint8List) {
                    return Container(
                      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
                      alignment: alignment,
                      child: SizedBox(
                        width: width,
                        height: imageHeight,
                        child: Card(
                          color: backgroundColor,
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Image.memory(
                                message,
                                fit: BoxFit.contain
                            ),
                          ),
                        ),
                      ),
                    );
                  }
                  return Container(
                    padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
                    alignment: alignment,
                    child: SizedBox(
                      width: MediaQuery.of(context).size.width * 0.8,
                      child: Card(
                        color: backgroundColor,
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Text(message),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(
                top: BorderSide(
                  color: Colors.grey[300]!,
                  width: 1.0,
                ),
              ),
            ),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.file_upload),
                  onPressed: () {
                    _getImage();
                    _focusNode.requestFocus();
                  },
                ),
                SizedBox(
                  width: 58,
                  height: 42,
                  child: latestImage != null
                      ? Image.memory(latestImage!)
                      : const ColorFiltered(
                        colorFilter: ColorFilter.mode(Colors.grey, BlendMode.srcIn),
                        child: Icon(Icons.image_not_supported),
                      ),
                ),
                Expanded(
                  child: LimitedBox(
                    maxHeight: MediaQuery.of(context).size.width * 0.15,
                    child: TextField(
                      controller: _textController,
                      decoration: const InputDecoration(
                        hintText: 'Type a message',
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.all(10.0),
                      ),
                      focusNode: _focusNode,
                      keyboardType: TextInputType.multiline,
                      textInputAction: TextInputAction.newline,
                      minLines: 1,
                      maxLines: 32,
                      onSubmitted: (value) {
                        _sendMessage();
                        _focusNode.requestFocus();
                      },
                    ),
                  )
                ),
                IconButton(
                  icon: const Icon(Icons.arrow_downward),
                  onPressed: () {
                    Future.delayed(const Duration(milliseconds: 100), () {
                      _scrollController.animateTo(
                        _scrollController.position.maxScrollExtent,
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeOut,
                      );
                    });
                  },
                ),
                ElevatedButton(
                  onPressed: () {
                    _sendMessage();
                    _focusNode.requestFocus();
                  },
                  child: const Text('Send'),
                ),
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: () {
                    setState(() {
                      _messages = [botMark + 'How can I help?'];
                    });
                    latestImage = null;
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _sendMessage() async {
    Uint8List? img;
    if (_textController.text.isEmpty) {
      return;
    }
    if (sendLock) {
      return;
    }
    if (_textController.text.isNotEmpty) {
      setState(() {
        sendLock = true;
        if (latestImage != null) {
          _messages.add(latestImage);
          img = latestImage;
        }
        _messages.add(_textController.text);
      });
      _textController.clear();
      latestImage = null;
      Future.delayed(const Duration(milliseconds: 100), () {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      });
    }
    // fakeReply();
    if (img != null) {
      await imageToTextReply(img);
    }
    getTextReply();
  }

  Future<void> _getImage() async {
    final pickedFile = await FilePicker.platform.pickFiles(
        type: FileType.custom, allowedExtensions: ['jpg', 'jpeg', 'png'], withData: true
    );


    if (pickedFile != null) {
      setState(() {
        latestImage = pickedFile.files.first.bytes;
      });
    }
  }

  Future<void> fakeReply() async {
    const fake = 'I am a test bot. I am not capable of replying to your message.';
    final words = fake.split(' ');
    _messages.add(botMark);
    var lastMessageIndex = _messages.length - 1;
    for (int i = 0; i < words.length; i++) {
      await Future.delayed(const Duration(milliseconds: 50), () {
        setState(() {
          var word = i != words.length - 1 ? '${words[i]} ' : words[i];
          _messages[lastMessageIndex] += word;
        });
      });
    }
    sendLock = false;
  }

  Future<void> ollamaUnload() async {
    var headers = {
      'Content-Type': 'application/json'
    };
    var body = json.encode({
      "model": "gemma2-2b-Chinese",
      "keep_alive": 0,
    });
    await http.post(
      Uri.parse('http://$ollamaUrl/api/generate'),
      headers: headers,
      body: body,
    );
  }

  Future<void> imageToTextReply(Uint8List? img) async {
    await ollamaUnload();

    _messages.add(botMark);
    var lastMessageIndex = _messages.length - 1;

    String imageBase64 = base64Encode(img!);
    var prompt = 'caption en in great detail';
    var headers = {
      'Content-Type': 'application/json',
    };
    var request = http.Request('POST', Uri.parse('http://$paligemmaUrl/generate'));
    request.body = json.encode({
      'prompt': prompt,
      'image': imageBase64,
    });
    request.headers.addAll(headers);

    Stream<String> stringStream;
    if (kIsWeb) {
      var client = FetchClient(mode: RequestMode.cors);
      final response = await client.send(request);
      stringStream = response.stream.transform(utf8.decoder).transform(const LineSplitter());
    }
    else {
      http.StreamedResponse response = await request.send();
      stringStream = response.stream.transform(utf8.decoder).transform(const LineSplitter());
    }

    await for (String jsonString in stringStream) {
      jsonString = jsonString.replaceAll('data: ', '').trim();
      if (jsonString.isEmpty) {
        continue;
      }
      final jsonMap = jsonDecode(jsonString);
      var content = jsonMap['payload'] as String;

      setState(() {
        _messages[lastMessageIndex] += content;
      });

      Future.delayed(const Duration(milliseconds: 50), () {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 10),
          curve: Curves.linear,
        );
      });
      await Future.delayed(const Duration(milliseconds: 11));
    }
    sendLock = false;
  }

  Future<void> getTextReply() async {
    var userMsg = _messages.last;
    _messages.add(botMark);
    var lastMessageIndex = _messages.length - 1;

    var headers = {
      'Content-Type': 'application/json'
    };
    var request = http.Request('POST', Uri.parse('http://$ollamaUrl/v1/chat/completions'));
    request.body = json.encode({
      "model": "gemma2-2b-Chinese",
      "stream": true,
      "max_tokens": 512,
      "messages": [
        {
          "role": "system",
          "content": "你用中文和用户聊天."
        },
        {
          "role": "user",
          "content": userMsg
        }
      ]
    });
    request.headers.addAll(headers);

    Stream<String> stringStream;
    if (kIsWeb) {
      var client = FetchClient(mode: RequestMode.cors);
      final response = await client.send(request);
      stringStream = response.stream.transform(utf8.decoder).transform(const LineSplitter());
    }
    else {
      http.StreamedResponse response = await request.send();
      stringStream = response.stream.transform(utf8.decoder).transform(const LineSplitter());
    }
    await for (String jsonString in stringStream) {
      jsonString = jsonString.replaceAll('data: ', '').trim();
      if (jsonString.trimRight().endsWith('[DONE]')) {
        break;
      }
      if (jsonString.isEmpty) {
        continue;
      }
      final jsonMap = jsonDecode(jsonString);
      final choices = jsonMap['choices'] as List<dynamic>;
      var content = choices[0]['delta']['content'] as String;

      setState(() {
        _messages[lastMessageIndex] += content;
      });

      Future.delayed(const Duration(milliseconds: 50), () {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 10),
          curve: Curves.linear,
        );
      });
      // wait for the animation to finish
      await Future.delayed(const Duration(milliseconds: 11));
    }
    sendLock = false;
  }
}