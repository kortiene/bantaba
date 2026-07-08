/// Sidebar copy — exact port of ui/src/components/Sidebar.tsx via
/// phase3-features.json "Sidebar (desktop left rail)". Keys are stable
/// lowerCamelCase for the later ARB migration. Decorative glyphs live here
/// too so widgets stay literal-free (they are excluded from semantics and
/// will not migrate to ARB).
library;

abstract final class SidebarStrings {
  // -- profile card ---------------------------------------------------------------
  static const String profileTitle = 'Profile & settings';

  /// Fallback profile name when no identity exists yet.
  static const String profileFallbackName = 'You';

  /// Placeholder avatar glyph when no identity exists ('··').
  static const String profileAvatarPlaceholder = '··';

  /// Handle shown when no identity exists.
  static const String profileHandleNone = '@—';

  /// Mono handle: '@' + shortId without the ellipsis (e.g. '@ab12cd34').
  static String profileHandle(String deEllipsizedShortId) =>
      '@$deEllipsizedShortId';

  static const String profileChevron = '⌄';

  // -- primary nav ------------------------------------------------------------------
  static const String navPrimaryLabel = 'Primary';
  static const String navHome = 'Home';
  static const String navRooms = 'Rooms';
  static const String navAgents = 'Agents';
  static const String navPipes = 'Pipes';
  static const String navFiles = 'Files';
  static const String navCalls = 'Calls';
  static const String navSettings = 'Settings';
  static const String navSoon = 'Soon';

  static const String glyphHome = '⌂';
  static const String glyphRooms = '▦';
  static const String glyphAgents = '✦';
  static const String glyphPipes = '⤳';
  static const String glyphFiles = '▤';
  static const String glyphCalls = '☎';
  static const String glyphSettings = '⚙';

  // -- rooms section --------------------------------------------------------------------
  static const String yourRooms = 'Your Rooms';

  /// '+' icon button aria-label/title.
  static const String createRoomIcon = 'Create room';
  static const String createRoomIconGlyph = '+';

  /// Rooms list nav aria-label.
  static const String roomsListLabel = 'Rooms';
  static const String roomHexGlyph = '⬡';
  static const String noRoomsYet = 'No rooms yet';

  static const String stateActive = 'Active';
  static const String stateIdle = 'Idle';
  static const String stateLeft = 'Left';
  static const String stateRemoved = 'Removed';

  /// '{n} member(s) · {stateLabel}'.
  static String roomMeta(int memberCount, String stateLabel) =>
      '$memberCount member${memberCount == 1 ? '' : 's'} · $stateLabel';

  /// Green-dot title when the room session is open.
  static const String sessionOpen = 'Session open';

  /// Departed-room row titles.
  static const String leftRoomTitle = 'You left this room';
  static const String removedRoomTitle = 'You were removed from this room';

  // -- entry-point rows --------------------------------------------------------------------
  static const String createRoom = 'Create Room';
  static const String createRoomGlyph = '⊕';
  static const String joinWithTicket = 'Join with a ticket';
  static const String joinRoomGlyph = '⇥';

  // -- identity footer ----------------------------------------------------------------------
  static const String p2pIdentity = 'P2P Identity';

  /// Shown in place of the identity id before onboarding.
  static const String noIdentity = '—';

  /// ' · ep {shortId}' appended to the identity id when the endpoint is known.
  static String endpointSuffix(String shortEndpointId) =>
      ' · ep $shortEndpointId';

  /// Title of the endpoint suffix (`endpoint <full id>`).
  static String endpointTitle(String endpointId) => 'endpoint $endpointId';

  static const String copyIdentityGlyph = '⧉';
  static const String copyIdentityId = 'Copy identity ID';
}
