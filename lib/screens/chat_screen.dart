import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:fetch_client/fetch_client.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

const String botMark = 'Bot##';
String defaultSysMsg = '''
你是一个善于助人的人工助手。
''';
String chatUrl = 'http://localhost:11434/v1/chat/completions';
String model = 'gemma2-2b-Chinese';
int maxToken=512;


class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  ChatScreenState createState() => ChatScreenState();
}

dynamic editingSettings(bool isEditing) {
  if (isEditing) {
    return const Icon(Icons.edit, color: Colors.green);
  }
  return const Icon(Icons.save, color: Colors.green);
}

class ChatScreenState extends State<ChatScreen> {
  List<dynamic> _messages = ['$botMark$defaultSysMsg'];
  Uint8List? latestImage;
  final TextEditingController _textController = TextEditingController();
  final TextEditingController _sysMsgController = TextEditingController();
  final TextEditingController _urlController = TextEditingController();
  final TextEditingController _modelName = TextEditingController();
  final TextEditingController _maxToken = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _showSetting = false;
  bool sendLock = false;
  String backendUrl = const String.fromEnvironment('backend_url', defaultValue: 'localhost:5418');
  String ollamaUrl = const String.fromEnvironment('ollama_url', defaultValue: 'localhost:11434');
  String paligemmaUrl = const String.fromEnvironment('paligemma_url', defaultValue: 'localhost:5443');
  bool ollamaUnloaded = false;
  // settings status indicators
  dynamic settingSysMsg = editingSettings(false);
  dynamic settingUrl = editingSettings(false);
  dynamic settingModel = editingSettings(false);
  dynamic settingMaxToken = editingSettings(false);

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
        title: const Text('聊天皮'),
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
          if (_showSetting)
            Column(
              children: [
                Row(
                  children: [
                    settingSysMsg,
                    Expanded(
                      child: TextField(
                        controller: _sysMsgController,
                        decoration: const InputDecoration(
                          hintText: 'System Message (default: 你是一个善于助人的人工助手。)',
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (value) {
                          setState(() {
                            settingSysMsg = editingSettings(true);
                          });
                        },
                        onTapOutside: (value) {
                          setState(() {
                            _sysMsgController.text = '';
                            settingSysMsg = editingSettings(false);
                          });
                        },
                        onSubmitted: (value) {
                          setState(() {
                            _messages[0] = botMark+_sysMsgController.text;
                            defaultSysMsg = _sysMsgController.text;
                            settingSysMsg = editingSettings(false);
                          });
                        },
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    settingUrl,
                    Expanded(
                      child: TextField(
                        controller: _urlController,
                        decoration: const InputDecoration(
                          hintText: 'Chat Url (default: http://localhost:11434/v1/chat/completions)',
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (value) {
                          setState(() {
                            settingUrl = editingSettings(true);
                          });
                        },
                        onTapOutside: (value) {
                          setState(() {
                            _urlController.text = '';
                            settingUrl = editingSettings(false);
                          });
                        },
                        onSubmitted: (value) {
                          setState(() {
                            chatUrl = _urlController.text;
                            settingUrl = editingSettings(false);
                          });
                        },
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    settingModel,
                    Expanded(
                      child: TextField(
                        controller: _modelName,
                        decoration: const InputDecoration(
                          hintText: 'Model Name (default: gemma2-2b-Chinese)',
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (value) {
                          setState(() {
                            settingModel = editingSettings(true);
                          });
                        },
                        onTapOutside: (value) {
                          setState(() {
                            _modelName.text = '';
                            settingModel = editingSettings(false);
                          });
                        },
                        onSubmitted: (value) {
                          setState(() {
                            model = _modelName.text.trim().isEmpty ? model : _modelName.text;
                            settingModel = editingSettings(false);
                          });
                        },
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    settingMaxToken,
                    Expanded(
                      child: TextField(
                        controller: _maxToken,
                        decoration: const InputDecoration(
                          hintText: 'Max Token (default: 512)',
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (value) {
                          setState(() {
                            settingMaxToken = editingSettings(true);
                          });
                        },
                        onTapOutside: (value) {
                          setState(() {
                            _maxToken.text = '';
                            settingMaxToken = editingSettings(false);
                          });
                        },
                        onSubmitted: (value) {
                          setState(() {
                            maxToken = _maxToken.text.trim().isEmpty ? 512: int.parse(_maxToken.text.trim());
                            settingMaxToken = editingSettings(false);
                          });
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),


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
                            child: MarkdownBody(data: message, selectable: true),
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
                  icon: const Icon(Icons.settings),
                  onPressed: () {
                    setState(() {
                      _showSetting = !_showSetting;
                    });
                  },
                ),
                // For calling VLM models
                // IconButton(
                //   icon: const Icon(Icons.file_upload),
                //   onPressed: () {
                //     if (sendLock) {
                //       return;
                //     }
                //     modelSwap();
                //     _getImage();
                //     _focusNode.requestFocus();
                //   },
                // ),
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
                      _messages = [botMark + defaultSysMsg];
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
                    if (chatHistory.isEmpty) {
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
    var request = http.Request('POST', Uri.parse(chatUrl));
    request.body = json.encode({
      "model": model,
      "stream": true,
      "max_tokens": maxToken,
      "messages": chatHistory,
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
    bool keepScrolling = true;
    double position = _scrollController.position.pixels;
    double threshold = MediaQuery.of(context).size.height * 0.2;
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

      if ((_scrollController.position.pixels - position).abs() < threshold) {
        keepScrolling = true;
      }
      else {
        keepScrolling = false;
      }

      if (!keepScrolling) {
        continue;
      }

      Future.delayed(const Duration(milliseconds: 50), () {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 10),
          curve: Curves.linear,
        );
      });
      // wait for the animation to finish
      await Future.delayed(const Duration(milliseconds: 11));
      position = _scrollController.position.pixels;
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