import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:fetch_client/fetch_client.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

const String botMark = 'Bot##';
const String defaultSysMsg = '''
你的名字叫杰玛-南瓜(Gemma NameCraft)，你是一个帮助新生儿父母取名字的超级AI智能体。你负责和新生儿父母沟通，帮助他们找到最适合的名字。尽量使用中文回答，除非必要，不要使用英文。
''';
const String defaultGreeting = '''
你好！我是你的中文取名助手，我叫杰玛-南瓜(Gemma NameCraft)。请问有什么可以帮您的？
''';
const Map<String, dynamic> injectedPayload = {
  '_last_name': '王',
  '_first_name': '哪跑',
  '_year': 2024,
  '_month': 1,
  '_day': 1,
  '_hour': 12,
  '_minute': 13,
  '_province': '青海',
  '_city': '西宁',
  'is_boy': true,
};


class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  ChatScreenState createState() => ChatScreenState();
}

class ChatScreenState extends State<ChatScreen> {
  List<dynamic> _messages = ['$botMark$defaultGreeting'];
  Uint8List? latestImage;
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool sendLock = false;
  String backendUrl = const String.fromEnvironment('backend_url', defaultValue: 'localhost:5418');
  String ollamaUrl = const String.fromEnvironment('ollama_url', defaultValue: 'localhost:11434');
  String paligemmaUrl = const String.fromEnvironment('paligemma_url', defaultValue: 'localhost:5443');
  bool ollamaUnloaded = false;
  List<Map<String, String>> chatHistory = [];

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
                    if (sendLock) {
                      return;
                    }
                    modelSwap();
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
                  icon: const Icon(Icons.clear_all_rounded),
                  onPressed: () {
                    if (sendLock) {
                      return;
                    }
                    setState(() {
                      _messages = [botMark + defaultGreeting];
                      chatHistory = [];
                    });
                    latestImage = null;
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: () {
                    if (sendLock) {
                      return;
                    }
                    var chatLastIndex = chatHistory.length - 1;
                    var messageLastIndex = _messages.length - 1;
                    var usrMsg = chatHistory[chatLastIndex - 1]['content'];
                    setState(() {
                      _messages.removeAt(messageLastIndex);
                    });
                    chatHistory.removeAt(chatLastIndex);
                    chatHistory.removeAt(chatLastIndex - 1);
                    chatHistory.removeAt(chatLastIndex - 2);
                    sendLock = true;
                    getTextReply(usrMsg);
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
    String? msg;
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
    if (img != null) {
      String caption = await imageToTextReply(img);
      caption = await translateCaption(caption);
      msg = '$caption<imageCaption>用户上传了一张照片,同时问道：${_messages.last}\n用户可能想结合图片和文字像你提问。你的回复是：';
    }
    getTextReply(msg);
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
    if (ollamaUnloaded) {
      return;
    }
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
    ollamaUnloaded = true;
  }

  Future<String> imageToTextReply(Uint8List? img) async {
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
      'sample': true
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
    return _messages.last.replaceAll(botMark, '');
  }

  Future<void> getTextReply(String? msg) async {
    var userMsg = msg ?? _messages.last;
    _messages.add(botMark);
    var lastMessageIndex = _messages.length - 1;
    chatHistory.add({'role': 'system', 'content': defaultSysMsg});
    chatHistory.add({'role': 'user', 'content': userMsg});


    var headers = {
      'Content-Type': 'application/json'
    };
    var request = http.Request('POST', Uri.parse('http://$backendUrl/chat/main'));
    request.body = json.encode({
      "model": "gemma2-2b-Chinese",
      "stream": true,
      "max_tokens": 512,
      "messages": chatHistory,
      "injected_payload": injectedPayload,
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
    chatHistory.add({'role': 'assistant', 'content': _messages.last.replaceAll(botMark, '')});
    ollamaUnloaded = false;
    sendLock = false;
  }

  Future<void> paligemmaPreload() async {
    await http.get(Uri.parse('http://$paligemmaUrl/preload'));
  }

  Future<void> modelSwap() async {
    await ollamaUnload();
    paligemmaPreload();
  }

  Future<String> translateCaption(String caption) async {
    String transcription = '';
    _messages.last += '  \n中文翻译：';
    var headers = {
      'Content-Type': 'application/json'
    };
    var request = http.Request('POST', Uri.parse('http://$backendUrl/transcribe'));
    request.body = json.encode({
      "prompt": caption,
      "stream": true
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
      var content = jsonMap['response'] as String;
      transcription += content;

      setState(() {
        _messages.last += content;
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
    return transcription;
  }
}