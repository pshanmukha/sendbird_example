import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:sendbird_chat_sdk/sendbird_chat_sdk.dart';

class GroupChannelCustomUIPage extends StatefulWidget {
  final String groupChannelURL;
  const GroupChannelCustomUIPage({super.key, required this.groupChannelURL});

  @override
  State<GroupChannelCustomUIPage> createState() =>
      _GroupChannelCustomUIPageState();
}

class _GroupChannelCustomUIPageState extends State<GroupChannelCustomUIPage> {
  final TextEditingController textEditingController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  double currentScroll = 0.0;
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
    _scrollController.addListener(_scrollListener);
  }

  _scrollListener() {
    setState(() {});
  }

  @override
  void dispose() {
    _disposeMessageCollection();
    textEditingController.dispose();
    _scrollController.removeListener(_scrollListener);
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            ClipOval(
              child: CachedNetworkImage(
                imageUrl: '${collection?.channel.coverUrl}',
                fit: BoxFit.cover,
                width: 40.0,
                height: 40.0,
                placeholder: (context, url) =>
                    const CircularProgressIndicator(),
                errorWidget: (context, url, error) =>
                    const Icon(Icons.person),
              ),
            ),
            const SizedBox(
              width: 6,
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    "${collection?.channel.name}",
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (memberIdList.isNotEmpty) ...[
                    Text(
                      memberIdList.toString(),
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
        centerTitle: false,
      ),
      body: Column(
        children: [
          Expanded(
            child: (collection != null && collection!.messageList.isNotEmpty)
                ? listBuilder()
                : Container(),
          ),
          inputTextField(),
        ],
      ),
      floatingActionButton: Visibility(
        visible: _scrollController.hasClients && _scrollController.offset > 0.0,
        child: IconButton(
          onPressed: () {
            _scrollDown();
          },
          icon: const Icon(
            Icons.arrow_circle_down_rounded,
            size: 35,
            color: Colors.purple,
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
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
          content: Text('getChannel: ERROR: $error'),
        ),
      );
      Navigator.pop(context);
    });
  }

  void _refresh({bool markAsRead = false}) {
    if (markAsRead) {
      SendbirdChat.markAsRead(channelUrls: [widget.groupChannelURL]);
    }

    setState(() {
      if (collection != null) {
        messageList = collection!.messageList;
        messageList.sort(((a, b) => b.createdAt.compareTo(a.createdAt)));
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

  void _disposeMessageCollection() {
    collection?.dispose();
  }

  Widget buildMessageBubble(ChatMessage chatMessage) {
    return Container(
      key: ValueKey<int>(chatMessage.messageId),
      child: Row(
        mainAxisAlignment: chatMessage.isFromCurrentUser
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        children: <Widget>[
          if (!chatMessage.isFromCurrentUser)
            Container(
              margin: const EdgeInsets.only(left: 10),
              child: ClipOval(
                child: CachedNetworkImage(
                  imageUrl: chatMessage.avatarUrl,
                  fit: BoxFit.cover,
                  width: 40.0,
                  height: 40.0,
                  placeholder: (context, url) =>
                  const CircularProgressIndicator(),
                  errorWidget: (context, url, error) =>
                  const Icon(Icons.person),
                ),
              ),
            ),
          const SizedBox(
            width: 4,
          ),
          Flexible(
            child: Container(
              margin: const EdgeInsets.all(10.0),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.purple, Colors.purple[100]!],
                ),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(20.0),
                  topRight: const Radius.circular(20.0),
                  bottomLeft: chatMessage.isFromCurrentUser
                      ? const Radius.circular(20.0)
                      : const Radius.circular(0),
                  bottomRight: chatMessage.isFromCurrentUser
                      ? const Radius.circular(0)
                      : const Radius.circular(20.0),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(10.0),
                child: Text(
                  chatMessage.message,
                  style: const TextStyle(fontSize: 16),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget listBuilder() {
    return ListView.separated(
      controller: _scrollController,
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      itemCount: messageList.length,
      reverse: true,
      itemBuilder: (context, index) {
        BaseMessage message = messageList[index];
        ChatMessage user = ChatMessage(
            messageId: message.messageId,
            message: message.message,
            isFromCurrentUser: isCurrentUser(message.sender?.userId),
          date: DateTime.fromMillisecondsSinceEpoch(message.createdAt),
          avatarUrl: message.sender?.profileUrl ?? '',
          userName: message.sender?.nickname ?? '',
        );
        return Column(
          children: [
            if (index == messageList.length - 1)...[
              Text(formatDate(DateTime.fromMillisecondsSinceEpoch(messageList[index].createdAt),),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
            buildMessageBubble(user),
          ],
        );
      },
      separatorBuilder: (context, index) {
        if (index < messageList.length - 1 &&
            DateTime.fromMillisecondsSinceEpoch(messageList[index].createdAt).day !=
                DateTime.fromMillisecondsSinceEpoch(messageList[index + 1].createdAt).day) {
          return Center(
            child: Text(formatDate(DateTime.fromMillisecondsSinceEpoch(messageList[index].createdAt),),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          );
        } else {
          return const SizedBox.shrink();
        }
      },
    );
  }

  Widget inputTextField() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 16),
      child: TextField(
        controller: textEditingController,
        minLines: 1,
        maxLines: 5,
        textInputAction: TextInputAction.send,
        onSubmitted: (message) => sendMessage(),
        decoration: InputDecoration(
          filled: true,
          fillColor: Colors.white,
          hintText: "Type a message here...",
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(35.0),
            borderSide: const BorderSide(color: Colors.purple, width: 2.0),
          ),
          suffixIcon: sendButton(),
        ),
      ),
    );
  }

  Widget sendButton() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 5),
      decoration: BoxDecoration(
        color: Colors.purple,
        borderRadius: BorderRadius.circular(35.0),
      ),
      child: IconButton(
        icon: const Icon(
          Icons.send,
          color: Colors.white,
        ),
        onPressed: () => sendMessage(),
      ),
    );
  }

  bool isCurrentUser(String? userId) {
    final currentUserid = SendbirdChat.currentUser?.userId;
    if (userId == null || userId == '') {
      return false;
    }
    return userId == currentUserid;
  }

  void sendMessage() {
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
  }

  void _scrollDown() {
    _scrollController.animateTo(
      _scrollController.position.minScrollExtent,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  String formatDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    final aDate = DateTime(date.year, date.month, date.day);

    if (aDate == today) {
      return 'Today';
    } else if (aDate == yesterday) {
      return 'Yesterday';
    } else {
      if(date.year == now.year) {
        return DateFormat('EEE, d MMM').format(date); // e.g., Wed, 9 Feb
      }
      else {
        return DateFormat('EEE, d MMM yyyy').format(date); // e.g., Wed, 9 Feb 2023
      }
    }
  }
}

class MyMessageCollectionHandler extends MessageCollectionHandler {
  final _GroupChannelCustomUIPageState _state;

  MyMessageCollectionHandler(this._state);

  @override
  void onMessagesAdded(MessageContext context, GroupChannel channel,
      List<BaseMessage> messages) async {
    _state._refresh(markAsRead: true);

    if (context.collectionEventSource !=
        CollectionEventSource.messageInitialize) {
      // Future.delayed(
      //   const Duration(milliseconds: 100),
      //       () => _state._scrollToAddedMessages(context.collectionEventSource),
      // );
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

class ChatMessage {
  final int messageId;
  final String message;
  final bool isFromCurrentUser;
  final DateTime date;
  final String avatarUrl;
  final String userName;

  ChatMessage({
    required this.messageId,
    required this.message,
    required this.isFromCurrentUser,
    required this.date,
    required this.avatarUrl,
    required this.userName,
  });
}
