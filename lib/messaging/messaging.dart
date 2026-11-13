import 'chat_api.dart';
import 'chat_repository.dart';
import 'sms_repository.dart';

/// Instancias únicas de los dos canales. Cada uno con su propio repositorio.
class Messaging {
  Messaging._();

  static final ChatRepository chat =
      ChatRepository(store: const NativePrefsStore(), api: ChatConfig.api());
  static final SmsRepository sms = SmsRepository(const NativeSmsSource(), store: const NativePrefsStore());
}
