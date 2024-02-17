import 'dart:developer';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import 'package:sendbird_chat_sdk/sendbird_chat_sdk.dart';
import 'package:sendbird_example/send_file_message_view.dart';

class GroupChannelPage extends StatefulWidget {
  final String groupChannelURL;
  const GroupChannelPage({super.key, required this.groupChannelURL});

  @override
  State<GroupChannelPage> createState() => _GroupChannelPageState();
}

class _GroupChannelPageState extends State<GroupChannelPage> {
  final itemScrollController = ItemScrollController();
  final textEditingController = TextEditingController();
  MessageCollection? collection;

  String title = '';
  bool hasPrevious = false;
  bool hasNext = false;
  List<BaseMessage> messageList = [];
  List<String> memberIdList = [];

  @override
  void initState() {
    super.initState();
    _initializeMessageCollection();
  }

  @override
  void dispose() {
    _disposeMessageCollection();
    textEditingController.dispose();
    super.dispose();
  }

  void _initializeMessageCollection() {
    GroupChannel.getChannel(widget.groupChannelURL).then((channel) {
      collection = MessageCollection(
        channel: channel,
        params: MessageListParams(),
        handler: MyMessageCollectionHandler(this),
      )..initialize();

      setState(() {
        title = '${channel.name} (${messageList.length})';
        memberIdList = channel.members.map((member) => member.userId).toList();
        memberIdList.sort((a, b) => a.compareTo(b));
      });
    }).catchError((error) {
      if (kDebugMode) print('getChannel: ERROR: $error');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'getChannel: ERROR: $error'),
        ),
      );
      Navigator.pop(context);
    });
  }

  void _disposeMessageCollection() {
    collection?.dispose();
  }

  void _refresh({bool markAsRead = false}) {
    if (markAsRead) {
      SendbirdChat.markAsRead(channelUrls: [widget.groupChannelURL]);
    }

    setState(() {
      if (collection != null) {
        messageList = collection!.messageList;
        title = '${collection!.channel.name} (${messageList.length})';
        hasPrevious = collection!.params.reverse
            ? collection!.hasNext
            : collection!.hasPrevious;
        hasNext = collection!.params.reverse
            ? collection!.hasPrevious
            : collection!.hasNext;
        memberIdList =
            collection!.channel.members.map((member) => member.userId).toList();
        memberIdList.sort((a, b) => a.compareTo(b));
      }
    });
  }

  Widget _previousButton() {
    return Container(
      width: double.maxFinite,
      height: 32.0,
      color: Colors.purple[200],
      child: IconButton(
        icon: const Icon(Icons.expand_less, size: 16.0),
        color: Colors.white,
        onPressed: () async {
          if (collection != null) {
            if (collection!.params.reverse) {
              if (collection!.hasNext && !collection!.isLoading) {
                await collection!.loadNext();
              }
            } else {
              if (collection!.hasPrevious && !collection!.isLoading) {
                await collection!.loadPrevious();
              }
            }
          }

          setState(() {
            if (collection != null) {
              hasPrevious = collection!.hasPrevious;
              hasNext = collection!.hasNext;
            }
          });
        },
      ),
    );
  }

  Widget _nextButton() {
    return Container(
      width: double.maxFinite,
      height: 32.0,
      color: Colors.purple[200],
      child: IconButton(
        icon: const Icon(Icons.expand_more, size: 16.0),
        color: Colors.white,
        onPressed: () async {
          if (collection != null) {
            if (collection!.params.reverse) {
              if (collection!.hasPrevious && !collection!.isLoading) {
                await collection!.loadPrevious();
              }
            } else {
              if (collection!.hasNext && !collection!.isLoading) {
                await collection!.loadNext();
              }
            }
          }

          setState(() {
            if (collection != null) {
              hasPrevious = collection!.hasPrevious;
              hasNext = collection!.hasNext;
            }
          });
        },
      ),
    );
  }

  Widget _messageSender() {
    return Padding(
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
                labelText: 'Message',
              ),
              minLines: 1,
              maxLines: 20,
              keyboardType: TextInputType.multiline,
            ),
          ),
          const SizedBox(width: 8.0),
          ElevatedButton(
            onPressed: () {
              if (textEditingController.value.text.isEmpty) {
                return;
              }

              collection?.channel.sendUserMessage(
                UserMessageCreateParams(
                  message: textEditingController.value.text,
                ),
                handler: (UserMessage message, SendbirdException? e) {
                  if (e != null) throw Exception(e.toString());
                },
              );

              textEditingController.clear();
            },
            child: const Text('Send'),
          ),
        ],
      ),
    );
  }

  void _scrollToAddedMessages(CollectionEventSource eventSource) async {
    if (collection == null || collection!.messageList.length <= 1) return;

    final reverse = collection!.params.reverse;
    final previous = eventSource == CollectionEventSource.messageLoadPrevious;

    final int index;
    if ((reverse && previous) || (!reverse && !previous)) {
      index = collection!.messageList.length - 1;
    } else {
      index = 0;
    }

    while (!itemScrollController.isAttached) {
      await Future.delayed(const Duration(milliseconds: 1));
    }

    itemScrollController.scrollTo(
      index: index,
      duration: const Duration(milliseconds: 200),
      curve: Curves.fastOutSlowIn,
    );
  }

  Widget _list() {
    return ScrollablePositionedList.builder(
        itemScrollController: itemScrollController,
        itemCount: messageList.length,
        itemBuilder: (BuildContext context, int index) {
          log("messageList -- $messageList");
          BaseMessage message = messageList[index];
          final unreadMembers = (collection != null)
              ? collection!.channel.getUnreadMembers(message)
              : [];
          log("message -- ${message.toJson()}");
          return GestureDetector(
            onLongPress: () async {
              await collection?.channel.deleteMessage(message.messageId);
            },
            child: Column(
              children: [
                ListTile(
                  title: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: (message is FileMessage)
                            ? Row(
                                children: [
                                  Image.network(
                                    message.secureUrl ?? '',
                                    width: 16,
                                    height: 16,
                                    fit: BoxFit.fitHeight,
                                    errorBuilder: (context, error, stackTrace) {
                                      return const Icon(Icons.file_present,
                                          size: 16);
                                    },
                                  ),
                                  Expanded(
                                    child: Padding(
                                      padding: const EdgeInsets.only(left: 4),
                                      child: Text(
                                        message.name ?? '',
                                        style: const TextStyle(
                                            color: Colors.black),
                                      ),
                                    ),
                                  ),
                                ],
                              )
                            : Text(
                                message.message,
                                style: const TextStyle(
                                  color: Colors.black,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                      if (message.sender != null &&
                          message.sender!.isCurrentUser)
                        Container(
                          alignment: Alignment.centerRight,
                          child: Text(
                            unreadMembers.isNotEmpty
                                ? '${unreadMembers.length}'
                                : '',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.green,
                            ),
                          ),
                        ),
                    ],
                  ),
                  subtitle: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      message.sender?.profileUrl == null
                      ? const Icon(Icons.account_circle,
                          size: 16)
                      : Image.network(
                        message.sender?.profileUrl ?? '',
                        width: 16,
                        height: 16,
                        fit: BoxFit.fitHeight,
                        errorBuilder: (context, error, stackTrace) {

                          return const Icon(Icons.account_circle,
                              size: 16);
                        },
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(left: 4),
                          child: Text(
                            message.sender?.userId ?? '',
                            style: const TextStyle(
                              color: Colors.black,
                              fontSize: 12,
                            ),
                          )
                        ),
                      ),
                      Container(
                        margin: const EdgeInsets.only(left: 16),
                        alignment: Alignment.centerRight,
                        child: Text(
                          DateTime.fromMillisecondsSinceEpoch(message.createdAt)
                              .toString(),
                          style: const TextStyle(fontSize: 12.0),
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
              ],
            ),
          );
        });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Chat with $title"),
        actions: [
          IconButton(
            icon: const Icon(Icons.file_upload),
            onPressed: () async {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => GroupChannelSendFileMessageView(
                    channelUrl: widget.groupChannelURL,
                  ),
                ),
              ).then((_) => _refresh());
            },
          ),
        ],
      ),
      body: Column(
        children: [
          if (memberIdList.isNotEmpty) ...[
            Text(
              memberIdList.toString(),
            ),
            const Divider(),
          ],
          hasPrevious ? _previousButton() : Container(),
          Expanded(
            child: (collection != null && collection!.messageList.isNotEmpty)
                ? _list()
                : Container(),
          ),
          hasNext ? _nextButton() : Container(),
          _messageSender(),
        ],
      ),
    );
  }
}

class MyMessageCollectionHandler extends MessageCollectionHandler {
  final _GroupChannelPageState _state;

  MyMessageCollectionHandler(this._state);

  @override
  void onMessagesAdded(MessageContext context, GroupChannel channel,
      List<BaseMessage> messages) async {
    _state._refresh(markAsRead: true);

    if (context.collectionEventSource !=
        CollectionEventSource.messageInitialize) {
      Future.delayed(
        const Duration(milliseconds: 100),
        () => _state._scrollToAddedMessages(context.collectionEventSource),
      );
    }
  }

  @override
  void onMessagesUpdated(MessageContext context, GroupChannel channel,
      List<BaseMessage> messages) {
    _state._refresh();
  }

  @override
  void onMessagesDeleted(MessageContext context, GroupChannel channel,
      List<BaseMessage> messages) {
    _state._refresh();
  }

  @override
  void onChannelUpdated(GroupChannelContext context, GroupChannel channel) {
    _state._refresh();
  }

  @override
  void onHugeGapDetected() {
    _state._disposeMessageCollection();
    _state._initializeMessageCollection();
  }

  @override
  void onChannelDeleted(
      GroupChannelContext context, String deletedChannelUrl) {}
}
