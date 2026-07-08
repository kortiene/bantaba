/// Onboarding copy — exact port of ui/src/components/Onboarding.tsx via
/// phase3-features.json (identity + rooms steps). Keys are stable
/// lowerCamelCase for the later ARB migration.
library;

abstract final class OnboardingStrings {
  static const String tagline =
      'Your rooms, your data. Private by default — built for humans & agents.';

  // -- identity step -----------------------------------------------------------
  static const String identityTitle = 'Create your identity';
  static const String identityCopy1 =
      'A keypair generated and stored by your local daemon. No account, no server — the private key never leaves this machine.';
  static const String identityCopy2 =
      "There's no password reset and no recovery — if you lose this device or its data folder, this identity is gone for good.";
  static const String createIdentity = 'Create identity';
  static const String creatingIdentity = 'Creating…';

  // -- rooms step: identity card -------------------------------------------------
  static const String yourIdentityId = 'Your identity id';
  static const String copy = 'Copy';
  static const String copyIdentityId = 'Copy identity ID';
  static const String identityCardCopy1 =
      'Being invited to a room? Send this id to the inviter first — tickets are bound to it.';
  static const String identityCardCopy2 =
      'Peers show up by this same hex id at first — click any name in a room to set a local nickname for them (only visible to you).';

  // -- rooms step: create card ------------------------------------------------------
  static const String createRoomTitle = 'Create a room';
  static const String createRoomCopy =
      'Start a space and invite people or agents with tickets.';
  static const String roomNameLabel = 'Room name';
  static const String roomNamePlaceholder = 'Build Iroh Rooms MVP';
  static const String createRoom = 'Create room';
  static const String creatingRoom = 'Creating…';

  // -- rooms step: join card ----------------------------------------------------------
  static const String joinTitle = 'Join with a ticket';

  /// 'ticket#address' renders mono inside this copy; the three parts
  /// concatenate to the reference sentence.
  static const String joinCopyPrefix =
      'Paste the invite you received. A combined invite (';
  static const String joinCopyMono = 'ticket#address';
  static const String joinCopySuffix =
      ') fills in the peer address automatically.';
  static const String ticketLabel = 'Ticket';
  static const String ticketPlaceholder =
      'roomtkt1… or roomtkt1…#<endpoint_id>@host:port';
  static const String peerAddrLabel = 'Peer address';
  static const String peerAddrOptional = '(optional)';
  static const String peerAddrPlaceholder = '<endpoint_id>@203.0.113.7:4242';
  static const String joinRoom = 'Join room';
  static const String joiningRoom = 'Joining…';
  static String joinAttempt(int attempt, int maxAttempts) =>
      'Attempt $attempt/$maxAttempts';
}
