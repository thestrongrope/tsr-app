import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/entity_cards.dart';
import '../repositories/members_repository.dart';

/// One student's card, by token. Not retried: a 404 is an answer, not a fault.
final studentCardProvider = FutureProvider.autoDispose.family<StudentCard, int>(
  (ref, token) => MembersRepository().getStudent(token),
  retry: (retryCount, error) => null,
);

/// One subscriber's card, by token.
final subscriberCardProvider = FutureProvider.autoDispose
    .family<SubscriberCard, int>(
      (ref, token) => MembersRepository().getSubscriber(token),
      retry: (retryCount, error) => null,
    );
