import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

import 'models.dart';
import 'character_service.dart';
import 'message_queue.dart';
import 'widgets/input_bar.dart';
import 'widgets/message_bubble.dart';
import 'widgets/enhanced_code_block.dart';
import 'widgets/custom_markdown_code_builder.dart';
import 'widgets/thread_selector.dart';


import 'services/message_modifier_service.dart';
import 'services/ai_chat_service.dart';

/* ----------------------------------------------------------
   CHAT PAGE
---------------------------------------------------------- */
class ChatPage extends StatefulWidget {
  final void Function(Message botMessage) onBookmark;
  final String selectedModel;
  const ChatPage({super.key, required this.onBookmark, required this.selectedModel});

  @override
  State<ChatPage> createState() => ChatPageState();
}

class ChatPageState extends State<ChatPage> {
  final _controller = TextEditingController();
  final _scroll = ScrollController();
  final _messages = <Message>[
    Message.bot('Hi, I\'m AhamAI. Ask me anything!'),
  ];
  bool _awaitingReply = false;
  String? _editingMessageId;

  // Web search and image upload modes
  bool _webSearchMode = false;
  String? _uploadedImagePath;
  String? _uploadedImageBase64;

  // Add memory system for general chat
  final List<String> _conversationMemory = [];
  static const int _maxMemorySize = 10;

  // Queue panel state - true means compact, false means expanded
  bool _showQueuePanel = true; // Default to compact view
  final MessageQueue _messageQueue = MessageQueue();
  
  // Threading support
  late ChatSession _chatSession;
  bool _showThreadSelector = false;
  



  final CharacterService _characterService = CharacterService();


  final _prompts = ['Explain quantum computing', 'Write a Python snippet', 'Draft an email to my boss', 'Ideas for weekend trip'];
  
  // MODIFICATION: Robust function to fix server-side encoding errors (mojibake).


  @override
  void initState() {
    super.initState();
    // Initialize chat session
    _chatSession = ChatSession(
      title: 'Main Chat',
      messages: _messages,
    );
    _characterService.addListener(_onCharacterChanged);
    _updateGreetingForCharacter();
    _controller.addListener(() {
      setState(() {}); // Refresh UI when text changes
    });
  }

  @override
  void dispose() {
    _characterService.removeListener(_onCharacterChanged);
    _controller.dispose();
    _scroll.dispose();
    super.dispose();
  }

  List<Message> getMessages() => _chatSession.currentMessages;

  void loadChatSession(List<Message> messages) {
    setState(() {
      _awaitingReply = false;
      _chatSession = ChatSession(
        title: 'Loaded Chat',
        messages: messages,
      );
    });
  }

  void _onCharacterChanged() {
    if (mounted) {
      _updateGreetingForCharacter();
    }
  }

  // Threading methods
  void _createThread(String parentMessageId, String threadName) {
    setState(() {
      _chatSession = _chatSession.createThread(parentMessageId, threadName);
    });
    
    // Show success message
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '✨ Created thread "$threadName"',
          style: const TextStyle(
            color: Color(0xFF000000),
            fontWeight: FontWeight.w500,
          ),
        ),
        backgroundColor: Colors.white,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        elevation: 4,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _switchToMainThread() {
    setState(() {
      _chatSession = _chatSession.switchThread(null);
      _showThreadSelector = false;
    });
  }

  void _switchToThread(String threadId) {
    setState(() {
      _chatSession = _chatSession.switchThread(threadId);
      _showThreadSelector = false;
    });
  }

  void _renameThread(String threadId, String newName) {
    final thread = _chatSession.threads[threadId];
    if (thread != null) {
      final updatedThread = thread.copyWith(name: newName);
      final newThreads = Map<String, MessageThread>.from(_chatSession.threads);
      newThreads[threadId] = updatedThread;
      
      setState(() {
        _chatSession = ChatSession(
          title: _chatSession.title,
          messages: _chatSession.messages,
          threads: newThreads,
          currentThreadId: _chatSession.currentThreadId,
        );
      });
    }
  }

  void _deleteThread(String threadId) {
    final newThreads = Map<String, MessageThread>.from(_chatSession.threads);
    newThreads.remove(threadId);
    
    // Remove messages from this thread
    final newMessages = _chatSession.messages
        .where((message) => message.threadId != threadId)
        .toList();
    
    setState(() {
      _chatSession = ChatSession(
        title: _chatSession.title,
        messages: newMessages,
        threads: newThreads,
        currentThreadId: _chatSession.currentThreadId == threadId ? null : _chatSession.currentThreadId,
      );
    });
  }

  void _toggleThreadSelector() {
    setState(() {
      _showThreadSelector = !_showThreadSelector;
    });
  }



  void _updateGreetingForCharacter() {
    final selectedCharacter = _characterService.selectedCharacter;
    setState(() {
      final currentMessages = _chatSession.currentMessages;
              if (currentMessages.isNotEmpty && currentMessages.first.sender == Sender.bot && currentMessages.length == 1) {
          final greetingMessage = selectedCharacter != null
              ? Message.bot('Hello! I\'m ${selectedCharacter.name}. ${selectedCharacter.description}. How can I help you today?')
              : Message.bot('Hi, I\'m AhamAI. Ask me anything!');
          
          final newMessages = List<Message>.from(_chatSession.messages);
          newMessages[0] = greetingMessage;
          _chatSession = ChatSession(
            title: _chatSession.title,
            messages: newMessages,
            threads: _chatSession.threads,
            currentThreadId: _chatSession.currentThreadId,
          );
      }
    });
  }

  void _startEditing(Message message) {
    setState(() {
      _editingMessageId = message.id;
      _controller.text = message.text;
      _controller.selection = TextSelection.fromPosition(TextPosition(offset: _controller.text.length));
    });
  }
  
  void _cancelEditing() {
    setState(() {
      _editingMessageId = null;
      _controller.clear();
    });
  }

  void _showUserMessageOptions(BuildContext context, Message message) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFFF4F3F0),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return Wrap(
          children: <Widget>[
            ListTile(
              leading: const Icon(Icons.copy_all_rounded, color: Color(0xFF8E8E93)),
              title: const Text('Copy', style: TextStyle(color: Colors.white)),
              onTap: () {
                Clipboard.setData(ClipboardData(text: message.text));
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(duration: Duration(seconds: 2), content: Text('Copied to clipboard')));
              },
            ),
            ListTile(
              leading: const Icon(Icons.edit_rounded, color: Color(0xFF8E8E93)),
              title: const Text('Edit & Resend', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                _startEditing(message);
              },
            ),
          ],
        );
      },
    );
  }

  void _updateConversationMemory(String userMessage, String aiResponse) {
    final memoryEntry = 'User: $userMessage\nAI: $aiResponse';
    _conversationMemory.add(memoryEntry);
    
    // Keep only the last 10 memory entries
    if (_conversationMemory.length > _maxMemorySize) {
      _conversationMemory.removeAt(0);
    }
  }

  String _getMemoryContext() {
    if (_conversationMemory.isEmpty) return '';
    return 'Previous conversation context:\n${_conversationMemory.join('\n\n')}\n\nCurrent conversation:';
  }

  Future<void> _generateResponse(String prompt) async {
    if (widget.selectedModel.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No model selected'), backgroundColor: Color(0xFFEAE9E5)),
      );
      return;
    }

    setState(() => _awaitingReply = true);

    try {
      final responseStream = await AIChatService.generateResponse(
        prompt: prompt,
        selectedModel: widget.selectedModel,
        memoryContext: _getMemoryContext(),
        uploadedImageBase64: _uploadedImageBase64,
      );

      // Create bot message placeholder
      final botMessage = Message.bot('', threadId: _chatSession.currentThreadId);
      setState(() {
        _chatSession = _chatSession.addMessage(botMessage);
      });
      final botMessageIndex = _chatSession.currentMessages.length - 1;

      String accumulatedText = '';
      await for (final content in responseStream) {
        if (!mounted || !_awaitingReply) break;

        accumulatedText += AIChatService.fixServerEncoding(content);
        setState(() {
          final newMessages = List<Message>.from(_chatSession.messages);
          final actualIndex = newMessages.indexWhere((m) => m.id == botMessage.id);
          if (actualIndex >= 0) {
            newMessages[actualIndex] = newMessages[actualIndex].copyWith(
              text: accumulatedText,
              isStreaming: true,
              displayText: accumulatedText,
              codes: [], // Clear codes during streaming to prevent duplication
            );
            _chatSession = ChatSession(
              title: _chatSession.title,
              messages: newMessages,
              threads: _chatSession.threads,
              currentThreadId: _chatSession.currentThreadId,
            );
          }
        });
        _scrollToBottom();
      }

      // Final update when streaming is complete
      if (mounted && _awaitingReply) {
        setState(() {
          final newMessages = List<Message>.from(_chatSession.messages);
          final actualIndex = newMessages.indexWhere((m) => m.id == botMessage.id);
          if (actualIndex >= 0) {
            newMessages[actualIndex] = newMessages[actualIndex].copyWith(isStreaming: false);
            _chatSession = ChatSession(
              title: _chatSession.title,
              messages: newMessages,
              threads: _chatSession.threads,
              currentThreadId: _chatSession.currentThreadId,
            );
          }
          _awaitingReply = false;
        });

        _updateConversationMemory(prompt, accumulatedText);

        if (_uploadedImageBase64 != null) {
          Future.delayed(const Duration(milliseconds: 500), () {
            if (mounted) _clearUploadedImage();
          });
        }
        _processNextQueuedMessage();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _awaitingReply = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: const Color(0xFFEAE9E5)),
        );
        
        if (_uploadedImageBase64 != null) {
          Future.delayed(const Duration(milliseconds: 500), () {
            if (mounted) _clearUploadedImage();
          });
        }
        _processNextQueuedMessage();
      }
    }
  }



  void _regenerateResponse(int botMessageIndex) {
    final currentMessages = _chatSession.currentMessages;
    int userMessageIndex = botMessageIndex - 1;
    if (userMessageIndex >= 0 && currentMessages[userMessageIndex].sender == Sender.user) {
      String lastUserPrompt = currentMessages[userMessageIndex].text;
      setState(() {
        final newMessages = List<Message>.from(_chatSession.messages);
        final messageToRemove = currentMessages[botMessageIndex];
        newMessages.removeWhere((m) => m.id == messageToRemove.id);
        _chatSession = ChatSession(
          title: _chatSession.title,
          messages: newMessages,
          threads: _chatSession.threads,
          currentThreadId: _chatSession.currentThreadId,
        );
      });
      _generateResponse(lastUserPrompt);
    }
  }

  void _modifyResponse(int botMessageIndex, String modifyType) {
    final currentMessages = _chatSession.currentMessages;
    if (botMessageIndex < 0 || botMessageIndex >= currentMessages.length) return;
    
    final botMessage = currentMessages[botMessageIndex];
    if (botMessage.sender != Sender.bot || botMessage.isStreaming) return;

    // Get the original user message
    int userMessageIndex = botMessageIndex - 1;
    if (userMessageIndex < 0 || currentMessages[userMessageIndex].sender != Sender.user) return;
    
    final modifiedPrompt = MessageModifierService.createModificationPrompt(
      currentMessages[userMessageIndex].text,
      botMessage.text,
      modifyType,
    );

    // Remove the old bot response and generate a new one
    setState(() {
      final newMessages = List<Message>.from(_chatSession.messages);
      newMessages.removeWhere((m) => m.id == botMessage.id);
      _chatSession = ChatSession(
        title: _chatSession.title,
        messages: newMessages,
        threads: _chatSession.threads,
        currentThreadId: _chatSession.currentThreadId,
      );
    });
    _generateResponse(modifiedPrompt);
  }
  
  void _stopGeneration() {
    if(mounted) {
      setState(() {
        final currentMessages = _chatSession.currentMessages;
        if (_awaitingReply && currentMessages.isNotEmpty && currentMessages.last.isStreaming) {
           final newMessages = List<Message>.from(_chatSession.messages);
           final lastStreamingMessage = currentMessages.last;
           final lastIndex = newMessages.indexWhere((m) => m.id == lastStreamingMessage.id);
           if (lastIndex >= 0) {
             newMessages[lastIndex] = lastStreamingMessage.copyWith(isStreaming: false);
             _chatSession = ChatSession(
               title: _chatSession.title,
               messages: newMessages,
               threads: _chatSession.threads,
               currentThreadId: _chatSession.currentThreadId,
             );
           }
        }
        _awaitingReply = false;
      });
      // Process next message in queue if available
      _processNextQueuedMessage();
    }
  }

  void _processNextQueuedMessage() {
    if (!_awaitingReply && _messageQueue.hasMessages) {
      final nextMessage = _messageQueue.getNextMessage();
      if (nextMessage != null) {
        // Add small delay to make the flow feel natural
        Future.delayed(const Duration(milliseconds: 800), () {
          if (mounted && !_awaitingReply) {
            _sendMessageDirectly(nextMessage);
          }
        });
      }
    }
  }

  void _sendMessageDirectly(String messageText) {
    setState(() {
      _chatSession = _chatSession.addMessage(Message.user(messageText, threadId: _chatSession.currentThreadId));
    });
    _generateResponse(messageText);
    _scrollToBottom();
  }

  void startNewChat() {
    setState(() {
      _awaitingReply = false;
      _editingMessageId = null;
      _conversationMemory.clear(); // Clear memory for fresh start
      final selectedCharacter = _characterService.selectedCharacter;
      final greetingMessage = selectedCharacter != null 
          ? Message.bot('Fresh chat started with ${selectedCharacter.name}. How can I help?')
          : Message.bot('Hi, I\'m AhamAI. Ask me anything!');
      _chatSession = ChatSession(
        title: 'Main Chat',
        messages: [greetingMessage],
      );
    });
  }



  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(_scroll.position.maxScrollExtent, duration: const Duration(milliseconds: 220), curve: Curves.easeOutCubic);
      }
    });
  }

  Future<void> _send({String? text}) async {
    final messageText = text ?? _controller.text.trim();
    if (messageText.isEmpty) return;

    // If AI is currently responding, add to queue instead
    if (_awaitingReply) {
      _messageQueue.addMessage(messageText);
      _controller.clear();
      setState(() {
        _showQueuePanel = true;
      });
      HapticFeedback.lightImpact();
      return;
    }

    final isEditing = _editingMessageId != null;
    if (isEditing) {
      final messageIndex = _chatSession.messages.indexWhere((m) => m.id == _editingMessageId);
      if (messageIndex != -1) {
        setState(() {
          final newMessages = _chatSession.messages.take(messageIndex).toList();
          _chatSession = ChatSession(
            title: _chatSession.title,
            messages: newMessages,
            threads: _chatSession.threads,
            currentThreadId: _chatSession.currentThreadId,
          );
        });
      }
    }
    
    _controller.clear();
    setState(() {
      _chatSession = _chatSession.addMessage(Message.user(messageText, threadId: _chatSession.currentThreadId));
      _editingMessageId = null;
    });

    _scrollToBottom();
    HapticFeedback.lightImpact();
    await _generateResponse(messageText);
  }

  void _toggleWebSearch() {
    setState(() {
      _webSearchMode = !_webSearchMode;
    });
  }

  Future<void> _handleImageUpload() async {
    try {
      await _showImageSourceDialog();
    } catch (e) {
      // Handle error
      print('Error uploading image: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error uploading image: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _showImageSourceDialog() async {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: Color(0xFFF4F3F0),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: const Color(0xFFC4C4C4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            
            // Title
            Text(
              'Select Image Source',
              style: GoogleFonts.inter(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF000000),
              ),
            ),
            
            const SizedBox(height: 20),
            
            // Camera option
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF000000).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.camera_alt_rounded, color: Color(0xFF000000)),
              ),
              title: Text(
                'Take Photo',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF000000),
                ),
              ),
              subtitle: Text(
                'Capture with camera',
                style: GoogleFonts.inter(
                  color: const Color(0xFFA3A3A3),
                ),
              ),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera);
              },
            ),
            
            // Gallery option
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF000000).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.photo_library_rounded, color: Color(0xFF000000)),
              ),
              title: Text(
                'Choose from Gallery',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF000000),
                ),
              ),
              subtitle: Text(
                'Select from photos',
                style: GoogleFonts.inter(
                  color: const Color(0xFFA3A3A3),
                ),
              ),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery);
              },
            ),
            
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: source,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );
      
      if (pickedFile != null) {
        final bytes = await pickedFile.readAsBytes();
        final base64Image = base64Encode(bytes);
        
        setState(() {
          _uploadedImagePath = pickedFile.path;
          _uploadedImageBase64 = 'data:image/jpeg;base64,$base64Image';
        });
        
        // Add image message to chat
        final imageMessage = Message.user("📷 Image uploaded: ${pickedFile.name}", threadId: _chatSession.currentThreadId);
        setState(() {
          _chatSession = _chatSession.addMessage(imageMessage);
        });
        
        _scrollToBottom();
      }
    } catch (e) {
      print('Error picking image: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error selecting image: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _clearUploadedImage() {
    setState(() {
      _uploadedImagePath = null;
      _uploadedImageBase64 = null;
    });
  }



  @override
  Widget build(BuildContext context) {
    final currentMessages = _chatSession.currentMessages;
    final emptyChat = currentMessages.length <= 1;
    return Stack(
      children: [
        Column(
          children: [
            // Thread selector (collapsible)
            if (_showThreadSelector || _chatSession.threads.isNotEmpty)
              Container(
                constraints: BoxConstraints(
                  maxHeight: _showThreadSelector ? 300 : 60,
                ),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                  height: _showThreadSelector ? null : 60,
                  child: _showThreadSelector
                      ? ThreadSelector(
                          threads: _chatSession.availableThreads,
                          currentThreadId: _chatSession.currentThreadId,
                          onMainThreadTap: _switchToMainThread,
                          onThreadTap: _switchToThread,
                          onThreadRename: _renameThread,
                          onThreadDelete: _deleteThread,
                        )
                      : Container(
                          height: 60,
                          decoration: const BoxDecoration(
                            color: Color(0xFFF4F3F0),
                            border: Border(
                              bottom: BorderSide(
                                color: Color(0xFFE0DED9),
                                width: 1,
                              ),
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            child: Row(
                              children: [
                                Icon(
                                  _chatSession.isMainThread ? Icons.home_outlined : Icons.alt_route_outlined,
                                  color: const Color(0xFF000000),
                                  size: 18,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _chatSession.isMainThread 
                                        ? 'Main Chat' 
                                        : _chatSession.currentThread?.name ?? 'Thread',
                                    style: const TextStyle(
                                      color: Color(0xFF000000),
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                if (_chatSession.threads.isNotEmpty)
                                  GestureDetector(
                                    onTap: _toggleThreadSelector,
                                    child: Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFEAE9E5),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Icon(
                                        _showThreadSelector 
                                            ? Icons.expand_less_rounded 
                                            : Icons.expand_more_rounded,
                                        color: const Color(0xFF000000),
                                        size: 20,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                ),
              ),
            
            // Chat content
            Expanded(
              child: Container(
                color: const Color(0xFFF4F3F0),
                child: Column(
                  children: [
                    Expanded(
                      child: ListView.builder(
                        controller: _scroll,
                        physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                        itemCount: currentMessages.length,
                        itemBuilder: (_, index) {
                          final message = currentMessages[index];
                          return MessageBubble(
                            key: ValueKey(message.id),
                            message: message,
                            onRegenerate: () => _regenerateResponse(index),
                            onUserMessageTap: () => _showUserMessageOptions(context, message),
                            onCreateThread: _createThread,
                      onModifyResponse: (modifyType) => _modifyResponse(index, modifyType),

                      
                      messageContentBuilder: (message) {
                        if (message.sender == Sender.bot) {
                          // For bot messages, render with markdown and enhanced code blocks
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (message.displayText.isNotEmpty)
                                MarkdownBody(
                                  data: message.displayText,
                                  builders: {
                                    'code': CustomMarkdownCodeBuilder(),
                                  },
                                  styleSheet: MarkdownStyleSheet(
                                    p: const TextStyle(
                                      fontSize: 15, 
                                      height: 1.5, 
                                      color: Color(0xFF000000),
                                      fontWeight: FontWeight.w400,
                                    ),
                                    code: TextStyle(
                                      backgroundColor: const Color(0xFFEAE9E5),
                                      color: const Color(0xFF000000),
                                      fontFamily: 'SF Mono',
                                      fontSize: 14,
                                    ),
                                    codeblockDecoration: BoxDecoration(
                                      color: const Color(0xFFEAE9E5),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    h1: const TextStyle(color: Color(0xFF000000), fontWeight: FontWeight.bold),
                                    h2: const TextStyle(color: Color(0xFF000000), fontWeight: FontWeight.bold),
                                    h3: const TextStyle(color: Color(0xFF000000), fontWeight: FontWeight.bold),
                                    listBullet: const TextStyle(color: Color(0xFFA3A3A3)),
                                    blockquote: const TextStyle(color: Color(0xFFA3A3A3)),
                                    strong: const TextStyle(color: Color(0xFF000000), fontWeight: FontWeight.bold),
                                    em: const TextStyle(color: Color(0xFF000000), fontStyle: FontStyle.italic),
                                  ),
                                ),
                            ],
                          );
                        } else {
                          // For user messages, simple text
                          return Text(
                            message.text,
                            style: const TextStyle(
                              fontSize: 15,
                              height: 1.4,
                              color: Color(0xFF000000),
                              fontWeight: FontWeight.w500,
                            ),
                          );
                        }
                      },
                    );
                  },
                ),
              ),
          if (emptyChat && _editingMessageId == null)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: _prompts.map((p) => Container(
                        margin: const EdgeInsets.only(right: 12),
                        child: GestureDetector(
                          onTap: () {
                            HapticFeedback.lightImpact();
                            _controller.text = p;
                            _send();
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEAE9E5),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              p,
                              style: const TextStyle(
                                fontSize: 14,
                                color: Color(0xFF000000),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                      )).toList(),
                    ),
                  ),
                ],
              ),
            ),

                        SafeArea(
            top: false,
            left: false,
            right: false,
            child: InputBar(
              controller: _controller,
              onSend: () => _send(),
              onStop: _stopGeneration,
              awaitingReply: _awaitingReply,
              isEditing: _editingMessageId != null,
              onCancelEdit: _cancelEditing,

              onImageUpload: _handleImageUpload,
              uploadedImagePath: _uploadedImagePath,
              onClearImage: _clearUploadedImage,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        // Queue Panel - positioned just above input area
        Positioned(
          bottom: 100, // Just above the input area
          right: 0,
          left: 0,
          child: QueuePanel(
            isVisible: !_showQueuePanel && _messageQueue.hasMessages,
            onDismiss: () {
              setState(() {
                _showQueuePanel = true; // Back to compact view
              });
            },
          ),
        ),
        // Queue Button (shows when there are queued messages - compact view)
        if (_messageQueue.hasMessages && _showQueuePanel)
          Positioned(
            bottom: 110, // Just above the input area
            right: 20,
            child: ValueListenableBuilder<List<String>>(
              valueListenable: _messageQueue.queueNotifier,
              builder: (context, messages, child) {
                if (messages.isEmpty) return const SizedBox.shrink();
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _showQueuePanel = false; // Show expanded panel
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF000000),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 20,
                          height: 20,
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFFFFF),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Center(
                            child: Text(
                              '${messages.length}',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF000000),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Queue',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFFFFFFFF),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

      ],
    );
  }


  

}



