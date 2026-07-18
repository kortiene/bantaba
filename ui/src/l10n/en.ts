/** English — the source of truth (issue #74).
 *
 *  Every other locale is typed as `Catalog`, so this file's shape is the
 *  contract: add a key here and `fr.ts` stops compiling until it is translated.
 *
 *  Where a string already exists in the Flutter catalog
 *  (`app/lib/src/l10n/arb/app_en.arb`) its wording is REUSED verbatim rather
 *  than re-written. The two clients ship the same product; a rail that says
 *  "Left & removed" in one and "Departed" in the other is a translation bug in
 *  both languages at once.
 *
 *  Casing is sentence case, matching the Flutter catalog's normalization pass.
 *  All-caps treatments are `toUpperCase()` at render time (rule 7), never here.
 */

import type { LocaleCatalog } from './catalog';

export const en: LocaleCatalog = {
  // -- wire enums and daemon errors ---------------------------------------------
  //
  // Inlined rather than spread from another module ON PURPOSE: the CI gate
  // (scripts/check-ui-i18n.mjs) reads these files with a restricted scanner, and
  // a spread it cannot follow makes the parity, emptiness and typography rules
  // silently stop running — a gate that reports nothing looks identical to a gate
  // that finds nothing. One locale, one file, every value visible.
  wireRoleOwnerInline: 'owner',
  wireRoleMemberInline: 'member',
  wireRoleAgentInline: 'agent',

  panelRoleOwner: 'Owner',
  panelRoleAgent: 'Agent',
  panelRoleMember: 'Member',

  memberStatusMember: 'Member',
  wireStatusInvited: 'Invited',
  wireStatusLeft: 'Left',
  wireStatusRemoved: 'Removed',
  memberStatusUnknown: 'Unknown',

  wirePathDirect: 'direct',
  wirePathRelay: 'relay',

  wireModeLoopback: 'loopback',
  wireModeReal: 'real',

  wireConnConnectedInline: 'connected',
  wireConnConnectingInline: 'connecting',
  wireConnReconnectingInline: 'reconnecting',
  wireConnDisconnectedInline: 'disconnected',

  errPeerUnreachableTitle: "Couldn't reach the inviter",
  errPeerUnreachableMessage:
    'The invite is readable, but this device could not reach the room admin in time.',
  errPeerUnreachableAction:
    'Ask the inviter to keep the room open, then retry. A fresh combined invite can help if the address changed.',

  errBadTicketTitle: "This invite can't be used",
  errBadTicketMessage:
    'The ticket is invalid for this identity, malformed, or no longer matches the room invite.',
  errBadTicketAction: 'Ask for a new invite generated for your current identity ID.',

  errTicketExpiredTitle: 'This invite expired',
  errTicketExpiredMessage: 'The room rejected the ticket because its expiry time has passed.',
  errTicketExpiredAction: 'Ask the inviter to generate a fresh ticket.',

  errRoomNotOpenTitle: 'Open the room first',
  errRoomNotOpenMessage: 'This action needs a live room session on your daemon.',
  errRoomNotOpenAction: 'Open the room, wait for it to sync, then try again.',

  errNotAMemberTitle: "You're not an active member",
  errNotAMemberMessage:
    'The signed room history does not currently admit this identity as an active member.',
  errNotAMemberAction: 'Use a valid invite for this identity or ask the room owner to re-add you.',

  errRoomUnknownTitle: "This room isn't local yet",
  errRoomUnknownMessage: 'The daemon does not have enough room history to open this room.',
  errRoomUnknownAction: 'Join with an invite, or open the room with a reachable peer hint.',

  errFileUnauthorizedTitle: 'Not authorized for this file',
  errFileUnauthorizedMessage:
    'Every reachable provider refused the transfer because the signed history does not admit this identity for it.',
  errFileUnauthorizedAction: 'Ask the sender to re-share the file or re-invite you, then retry.',

  errHashMismatchTitle: 'Security check failed',
  errHashMismatchMessage:
    'The fetched bytes did not match the file hash. This is a hard stop — the copy is discarded, never shown.',
  errHashMismatchAction: 'Ask the sender to re-share the file. Do not retry the same copy.',

  errConnectionLostTitle: 'Daemon connection lost',
  errConnectionLostMessage: 'The local UI is not connected to jeliyad right now.',
  errConnectionLostAction: 'Wait for reconnect, then retry the action.',

  errInvalidParamsTitle: "This request wasn't valid",
  errInvalidParamsMessage: 'The daemon rejected one of the values in this request.',
  errInvalidParamsAction: 'Check what you entered, then try again.',

  errIdentityMissingTitle: 'No identity on this daemon yet',
  errIdentityMissingMessage: 'This action needs your identity, and one has not been created here.',
  errIdentityMissingAction: 'Create your identity first, then retry.',

  errIdentityExistsTitle: 'An identity already exists',
  errIdentityExistsMessage: 'This daemon already holds an identity — a second one cannot be created.',
  errIdentityExistsAction: 'Use the existing identity shown in Settings.',

  errFileUnavailableTitle: 'File not available right now',
  errFileUnavailableMessage: 'No provider is online for this file yet.',
  errFileUnavailableAction: 'Recheck when the sender is back online.',

  errFileTooLargeTitle: 'This file is too large to share',
  errFileTooLargeMessage: 'Shares are capped at 100 MiB per file.',
  errFileTooLargeAction: 'Pick a smaller file, or split the content.',

  errFileUnreadableTitle: "This file couldn't be read",
  errFileUnreadableMessage: 'The picked file could not be opened from disk.',
  errFileUnreadableAction: 'Check the file still exists and is readable, then retry.',

  errPipeDeniedTitle: 'Pipe access denied',
  errPipeDeniedMessage: 'This pipe does not authorize your identity.',
  errPipeDeniedAction: 'Ask the pipe owner to expose it to your identity.',

  errInternalTitle: 'The daemon hit an unexpected failure',
  errInternalMessage: 'This request failed for a reason the daemon could not classify.',
  errInternalAction: 'Retry; if it keeps failing, copy diagnostics from Settings and report it.',

  errUnknownTitle: 'Something went wrong',
  errUnknownMessage: 'The daemon reported an error this app has no specific copy for.',
  errUnknownAction: 'Open Technical details for the exact error, then retry.',

  localeTag: 'en',

  // -- common ------------------------------------------------------------------
  commonRetry: 'Retry',
  commonCancel: 'Cancel',
  commonClose: 'Close',
  commonClear: 'Clear',
  commonSave: 'Save',
  commonBack: 'Back',
  commonCopy: 'Copy',
  commonCopied: 'Copied ✓',
  commonReconnecting: 'Reconnecting…',
  commonUnknown: 'Unknown',
  commonOptional: '(optional)',

  // -- boot --------------------------------------------------------------------
  bootSyncing: 'Syncing…',
  bootNotConnected: 'Not connected.',
  bootContacting: 'Contacting daemon…',
  bootRetryingHint: 'Retrying with backoff — start {daemon} or pass {port}.',

  // -- shell / connection ------------------------------------------------------
  shellConnectionLost: (transport) => `Connection to daemon lost — reconnecting… (${transport})`,
  shellDisconnected: 'Disconnected from daemon.',
  shellSkipToMain: 'Skip to main content',
  shellSkipToComposer: 'Skip to message composer',
  shellConnConnected: 'Connected',
  shellConnConnecting: 'Connecting…',
  shellConnReconnecting: 'Reconnecting…',
  shellConnDisconnected: 'Disconnected',
  shellNavPrimary: 'Primary',
  shellNavPrimaryMobile: 'Primary (mobile)',

  // -- global destinations -----------------------------------------------------
  destRooms: 'Rooms',
  destFleet: 'Agent Fleet',
  destSettings: 'Settings',

  // -- room destinations -------------------------------------------------------
  roomDestActivity: 'Activity',
  roomDestPeople: 'People',
  roomDestAgents: 'Agents & Runs',
  roomDestFiles: 'Files',
  roomDestPipes: 'Pipes',

  // -- rooms list --------------------------------------------------------------
  roomsYourRooms: 'Your Rooms',
  roomsChoose: 'Choose a room.',
  roomsCreate: 'Create room',
  roomsJoinWithTicket: 'Join with a ticket',
  roomsSearchPlaceholder: 'Search rooms…',
  roomsSearchLabel: 'Search rooms by name or short id',
  roomsFilterLegend: 'Filter rooms by lifecycle',
  roomsFilterAll: 'All',
  roomsFilterActive: 'Active',
  roomsFilterDeparted: 'Left & removed',
  roomsSectionPinned: 'Pinned',
  roomsSectionArchived: 'Archived',
  roomsSectionCount: (n) => `(${n})`,
  roomsEmpty: 'No rooms yet',
  roomsNoMatch: (query) => `No rooms match “${query}”.`,
  roomsNoneInFilter: 'No rooms in this filter.',
  roomsUnread: 'Unread',
  roomsMemberCount: (n) => (n === 1 ? `${n} member` : `${n} members`),
  roomsUntitled: 'Untitled room',
  roomsStateOpen: 'Open',
  roomsStateClosed: 'Closed',
  roomsStateLeft: 'Left',
  roomsStateRemoved: 'Removed',
  roomsSessionOpen: 'Session open',
  roomsYouLeft: 'You left this room',
  roomsYouWereRemoved: 'You were removed from this room',
  roomsPin: (room) => `Pin ${room}`,
  roomsUnpin: (room) => `Unpin ${room}`,
  roomsArchive: (room) => `Archive ${room}`,
  roomsRestore: (room) => `Restore ${room}`,
  roomsPinShort: 'Pin',
  roomsUnpinShort: 'Unpin',
  roomsArchiveShort: 'Archive',
  roomsRestoreShort: 'Restore from archive',
  roomsRailLabel: 'Room rail',
  roomsListLabel: 'Rooms',
  roomsProfile: 'Profile & settings',

  // -- room recovery surfaces --------------------------------------------------
  roomNotOnDevice: 'That room isn’t on this device',
  roomNotOnDeviceDetail:
    'Nothing here matches {id}. It may live on another device, or you may not have joined it yet.',
  roomBackToRooms: 'Back to Rooms',
  roomLeftDetail: 'Your departure is published to the room’s signed log. You’ll need a new invite to rejoin.',
  roomRemovedDetail: 'Your removal is published to the room’s signed log. You’ll need a new invite to rejoin.',

  // -- identity ----------------------------------------------------------------
  identitySelf: 'You',
  identityP2P: 'P2P Identity',
  identityCopy: 'Copy identity ID',
  identityEndpointShort: (id) => `ep ${id}`,
  identityEndpointTitle: (id) => `endpoint ${id}`,

  // -- modals ------------------------------------------------------------------
  modalJoinCopy:
    'Paste the invite you received. A combined invite ({combined}) fills in the peer address automatically.',
  modalTicketLabel: 'Ticket',
  modalPeerAddrLabel: 'Peer address',
  modalJoinSubmit: 'Join room',
  modalJoining: 'Joining…',
  modalJoinAttempt: (attempt, max) => `Attempt ${attempt}/${max}`,
  modalCreateTitle: 'Create a room',
  modalRoomNameLabel: 'Room name',
  modalCreating: 'Creating…',
  modalCreateHomonymWarning:
    'A room with that name already exists on this device — this one will get its own ID.',
  modalLeaveTitle: 'Leave room',
  modalLeaveCopy:
    'Leaving {room} {id} publishes a signed membership departure. This is different from closing the local ' +
    'session; you’ll need a new invite to join again.',
  modalLeaveSubmit: 'Leave room',
  modalLeaving: 'Leaving…',
  modalRenameTitle: 'Name this peer',
  modalRenameCopy: 'Local alias only — names never leave this machine.',
  modalRenameIdentityLabel: 'Identity:',
  modalRenameAliasLabel: 'Alias',
  modalRenameClearAlias: 'Clear alias',

  // -- formatting vocabulary ---------------------------------------------------
  formatToday: 'Today',
  formatYesterday: 'Yesterday',
  formatBytesB: (n) => `${n} B`,
  formatBytesKb: (n) => `${n} KB`,
  formatBytesMb: (n) => `${n} MB`,
  formatBytesGb: (n) => `${n} GB`,
  formatPercent: (n) => `${n}%`,
  formatJustNow: 'just now',
};
