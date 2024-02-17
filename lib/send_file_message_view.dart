import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:sendbird_chat_sdk/sendbird_chat_sdk.dart';

class GroupChannelSendFileMessageView extends StatefulWidget {
  final String channelUrl;
  const GroupChannelSendFileMessageView({super.key, required this.channelUrl});

  @override
  State<GroupChannelSendFileMessageView> createState() =>
      _GroupChannelSendFileMessageViewState();
}

class _GroupChannelSendFileMessageViewState
    extends State<GroupChannelSendFileMessageView> {
  final textEditingController = TextEditingController();

  String title = 'Send FileMessage';
  double? uploadProgressValue;

  String? filePath;
  final ImagePicker picker = ImagePicker();

  @override
  void dispose() {
    textEditingController.dispose();
    super.dispose();
  }

  Future<XFile?> openCamera({required ImageSource source}) async {
    final image = await picker.pickImage(source: source);
    if(image != null) {
      return image;
    } else {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: Text(title),
          actions: [
            if (filePath != null)
              IconButton(
                icon: const Icon(Icons.done),
                onPressed: () async {
                  FileMessageCreateParams? params;
                  if (filePath != null) {
                    params = FileMessageCreateParams.withFile(
                      File(filePath!),
                      fileName: textEditingController.text,
                    );
                  }

                  if (params != null) {
                    final channel = await GroupChannel.getChannel(widget.channelUrl);
                    channel.sendFileMessage(
                      params,
                      handler: (FileMessage message, SendbirdException? e) {
                        Navigator.pop(context);
                      },
                      progressHandler: (sentBytes, totalBytes) {
                        setState(() {
                          uploadProgressValue = (sentBytes / totalBytes);
                        });
                      },
                    );
                  }
                },
              ),
          ],
        ),
        body: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: textEditingController,
                  decoration: const InputDecoration(
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.purple),
                    ),
                    labelText: 'File Name',
                  ),
                  minLines: 1,
                  maxLines: 20,
                  keyboardType: TextInputType.multiline,
                ),
              ),
              const SizedBox(width: 8,),
              uploadProgressValue != null
              ? CircularProgressIndicator(value: uploadProgressValue,)
                  : Column(
                    children: [
                      ElevatedButton(onPressed: () async {
                        final result = await openCamera(source: ImageSource.camera);
                        if(result != null ){
                          filePath = result.path;
                          setState(() {
                            textEditingController.text = result.name;
                          });
                        }
                                    }, child: const Text("Pick from camera"),),
                      ElevatedButton(onPressed: () async {
                        final result = await openCamera(source: ImageSource.gallery);
                        if(result != null ){
                          filePath = result.path;
                          setState(() {
                            textEditingController.text = result.name;
                          });
                        }
                      }, child: const Text("Pick from Gallery"),),
                    ],
                  ),
            ],
          ),
        ));
  }
}
