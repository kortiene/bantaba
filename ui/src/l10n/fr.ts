/** French — `docs/glossary-fr.md`, decision 7 (typographie), Tier 1–3 vocabulary.
 *
 *  Typographie (non-negotiable, `docs/glossary-fr.md` decision 7). The two
 *  invisible spaces are written as ESCAPES, never as literal characters, so a
 *  reviewer can see the contract in the diff instead of trusting a glyph they
 *  cannot see:
 *
 *    \u202f  narrow no-break space — before `; ! ?` and inside « guillemets »
 *    \u00a0  no-break space — before `:`
 *    U+2019 `’` and U+2026 `…` are typed directly: they are visible, and are
 *    already the English catalog's norm.
 *
 *  Two places where the Flutter `app_fr.arb` does NOT meet decision 7 and this
 *  catalog does: the guillemets in `roomsNoMatch` (Flutter's
 *  `sidebarNoRoomsMatch` has no inner narrow spaces) and the percent sign in
 *  `formatPercent` (Flutter's `commonPercent` uses a plain space). Both are
 *  worth fixing there; neither is worth copying here.
 *
 *  Register: vouvoiement, sentence case (never Title Case), accents kept on
 *  capitals, calm and concrete — the honest tone of the English catalog, not a
 *  marketing one.
 *
 *  Vocabulary: Tier 1 is translated consistently (room → salon, member →
 *  membre, settings → réglages, Your Rooms → Vos salons). Tier 2 is verbatim in
 *  every locale — `direct`/`relay`, error codes, `daemon`, `jeliyad`, `pipe`,
 *  endpoint and identity ids — and most of it lives in `tokens.ts`, outside this
 *  file entirely. Tier 3, the brand, is never translated.
 *
 *  Where the Flutter catalog already translates a string, its French is REUSED
 *  verbatim. The two clients must not ship two French words for one English one.
 */

import type { LocaleCatalog } from './catalog';

export const fr: LocaleCatalog = {
  // -- wire enums and daemon errors ---------------------------------------------
  //
  // Inlined rather than spread from another module ON PURPOSE: the CI gate
  // (scripts/check-ui-i18n.mjs) reads these files with a restricted scanner, and
  // a spread it cannot follow makes the parity, emptiness and typography rules
  // silently stop running — a gate that reports nothing looks identical to a gate
  // that finds nothing. One locale, one file, every value visible.
  wireRoleOwnerInline: 'propriétaire',
  wireRoleMemberInline: 'membre',
  wireRoleAgentInline: 'agent',

  panelRoleOwner: 'Propriétaire',
  panelRoleAgent: 'Agent',
  panelRoleMember: 'Membre',

  memberStatusMember: 'Membre',
  wireStatusInvited: 'Invité',
  wireStatusLeft: 'Parti',
  wireStatusRemoved: 'Exclu',
  memberStatusUnknown: 'Inconnu',

  // Tier 2 (docs/glossary-fr.md): the daemon's own word, never translated.
  wirePathDirect: 'direct',
  wirePathRelay: 'relay',

  wireModeLoopback: 'loopback',
  wireModeReal: 'réel',

  wireConnConnectedInline: 'connecté',
  wireConnConnectingInline: 'en cours de connexion',
  wireConnReconnectingInline: 'en cours de reconnexion',
  wireConnDisconnectedInline: 'déconnecté',

  errPeerUnreachableTitle: 'Impossible de joindre l’invitant',
  errPeerUnreachableMessage:
    'L’invitation est lisible, mais cet appareil n’a pas pu joindre l’administrateur du salon à temps.',
  errPeerUnreachableAction:
    'Demandez à l’invitant de garder le salon ouvert, puis réessayez. Une nouvelle invitation combinée peut aider si l’adresse a changé.',

  errBadTicketTitle: 'Cette invitation ne peut pas être utilisée',
  errBadTicketMessage:
    'Le ticket est invalide pour cette identité, mal formé, ou ne correspond plus à l’invitation du salon.',
  errBadTicketAction: 'Demandez une nouvelle invitation générée pour votre identifiant d’identité actuel.',

  errTicketExpiredTitle: 'Cette invitation a expiré',
  errTicketExpiredMessage: 'Le salon a rejeté le ticket parce que sa date d’expiration est dépassée.',
  errTicketExpiredAction: 'Demandez à l’invitant de générer un nouveau ticket.',

  errRoomNotOpenTitle: 'Ouvrez d’abord le salon',
  errRoomNotOpenMessage: 'Cette action nécessite une session de salon active sur votre daemon.',
  errRoomNotOpenAction: 'Ouvrez le salon, attendez la fin de la synchronisation, puis réessayez.',

  errNotAMemberTitle: 'Vous n’êtes pas membre actif',
  errNotAMemberMessage:
    'L’historique signé du salon n’admet pas actuellement cette identité comme membre actif.',
  errNotAMemberAction:
    'Utilisez une invitation valide pour cette identité, ou demandez au propriétaire du salon de vous ajouter à nouveau.',

  errRoomUnknownTitle: 'Ce salon n’est pas encore sur cet appareil',
  errRoomUnknownMessage: 'Le daemon ne dispose pas de suffisamment d’historique pour ouvrir ce salon.',
  errRoomUnknownAction:
    'Rejoignez le salon avec une invitation, ou ouvrez-le avec un indice de pair joignable.',

  errFileUnauthorizedTitle: 'Accès non autorisé à ce fichier',
  errFileUnauthorizedMessage:
    'Tous les fournisseurs joignables ont refusé le transfert, car l’historique signé n’admet pas cette identité pour ce fichier.',
  errFileUnauthorizedAction:
    'Demandez à l’expéditeur de partager à nouveau le fichier ou de vous réinviter, puis réessayez.',

  errHashMismatchTitle: 'Échec du contrôle de sécurité',
  errHashMismatchMessage:
    'Les octets récupérés ne correspondent pas à l’empreinte du fichier. C’est un arrêt définitif — la copie est supprimée, jamais affichée.',
  errHashMismatchAction:
    'Demandez à l’expéditeur de partager à nouveau le fichier. Ne réessayez pas avec la même copie.',

  errConnectionLostTitle: 'Connexion au daemon perdue',
  errConnectionLostMessage: 'L’interface locale n’est pas connectée à jeliyad pour le moment.',
  errConnectionLostAction: 'Attendez la reconnexion, puis réessayez l’action.',

  errInvalidParamsTitle: 'Cette requête n’était pas valide',
  errInvalidParamsMessage: 'Le daemon a rejeté l’une des valeurs de cette requête.',
  errInvalidParamsAction: 'Vérifiez ce que vous avez saisi, puis réessayez.',

  errIdentityMissingTitle: 'Pas encore d’identité sur ce daemon',
  errIdentityMissingMessage: 'Cette action nécessite votre identité, et aucune n’a encore été créée ici.',
  errIdentityMissingAction: 'Créez d’abord votre identité, puis réessayez.',

  errIdentityExistsTitle: 'Une identité existe déjà',
  errIdentityExistsMessage: 'Ce daemon détient déjà une identité — il est impossible d’en créer une seconde.',
  errIdentityExistsAction: 'Utilisez l’identité existante affichée dans Réglages.',

  errFileUnavailableTitle: 'Fichier indisponible pour le moment',
  errFileUnavailableMessage: 'Aucun fournisseur n’est encore en ligne pour ce fichier.',
  errFileUnavailableAction: 'Revérifiez quand l’expéditeur sera de nouveau en ligne.',

  errFileTooLargeTitle: 'Ce fichier est trop volumineux pour être partagé',
  errFileTooLargeMessage: 'Les partages sont limités à 100 MiB par fichier.',
  errFileTooLargeAction: 'Choisissez un fichier plus petit, ou divisez le contenu.',

  errFileUnreadableTitle: 'Ce fichier n’a pas pu être lu',
  errFileUnreadableMessage: 'Le fichier choisi n’a pas pu être ouvert depuis le disque.',
  errFileUnreadableAction: 'Vérifiez que le fichier existe toujours et qu’il est lisible, puis réessayez.',

  errPipeDeniedTitle: 'Accès au pipe refusé',
  errPipeDeniedMessage: 'Ce pipe n’autorise pas votre identité.',
  errPipeDeniedAction: 'Demandez au propriétaire du pipe de l’exposer à votre identité.',

  errInternalTitle: 'Le daemon a rencontré une défaillance inattendue',
  errInternalMessage: 'Cette requête a échoué pour une raison que le daemon n’a pas pu classer.',
  // U+202F before the semicolon (decision 7).
  errInternalAction:
    'Réessayez ; si l’échec persiste, copiez les diagnostics depuis Réglages et signalez le problème.',

  errUnknownTitle: 'Une erreur s’est produite',
  errUnknownMessage:
    'Le daemon a signalé une erreur pour laquelle cette application n’a pas de message spécifique.',
  // U+202F inside the guillemets (decision 7) — « Détails techniques » must
  // match the disclosure's own label.
  errUnknownAction:
    'Ouvrez « Détails techniques » pour voir l’erreur exacte, puis réessayez.',

  localeTag: 'fr',

  // -- common ------------------------------------------------------------------
  commonRetry: 'Réessayer',
  commonCancel: 'Annuler',
  commonClose: 'Fermer',
  commonClear: 'Effacer',
  commonSave: 'Enregistrer',
  commonBack: 'Retour',
  commonCopy: 'Copier',
  commonCopied: 'Copié ✓',
  commonReconnecting: 'Reconnexion…',
  commonUnknown: 'Inconnu',
  commonOptional: '(facultative)',

  // -- boot --------------------------------------------------------------------
  bootSyncing: 'Synchronisation…',
  bootNotConnected: 'Non connecté.',
  bootContacting: 'Connexion au daemon…',
  bootRetryingHint: 'Nouvelles tentatives avec délai progressif — lancez {daemon} ou passez {port}.',

  // -- shell / connection ------------------------------------------------------
  shellConnectionLost: (transport) => `Connexion au daemon perdue — reconnexion… (${transport})`,
  shellDisconnected: 'Déconnecté du daemon.',
  shellSkipToMain: 'Aller au contenu principal',
  shellSkipToComposer: 'Aller au champ de message',
  shellConnConnected: 'Connecté',
  shellConnConnecting: 'Connexion…',
  shellConnReconnecting: 'Reconnexion…',
  shellConnDisconnected: 'Déconnecté',
  shellNavPrimary: 'Principal',
  shellNavPrimaryMobile: 'Principal (mobile)',

  // -- global destinations -----------------------------------------------------
  destRooms: 'Salons',
  destFleet: 'Flotte d’agents',
  destSettings: 'Réglages',

  // -- room destinations -------------------------------------------------------
  roomDestActivity: 'Activité',
  roomDestPeople: 'Personnes',
  roomDestAgents: 'Agents et exécutions',
  roomDestFiles: 'Fichiers',
  roomDestPipes: 'Pipes',

  // -- rooms list --------------------------------------------------------------
  roomsYourRooms: 'Vos salons',
  roomsChoose: 'Choisissez un salon.',
  roomsCreate: 'Créer un salon',
  roomsJoinWithTicket: 'Rejoindre avec un ticket',
  roomsSearchPlaceholder: 'Rechercher des salons…',
  roomsSearchLabel: 'Rechercher des salons par nom ou identifiant court',
  roomsFilterLegend: 'Filtrer les salons par cycle de vie',
  roomsFilterAll: 'Tous',
  roomsFilterActive: 'Actifs',
  roomsFilterDeparted: 'Quittés et retirés',
  roomsSectionPinned: 'Épinglés',
  roomsSectionArchived: 'Archivés',
  roomsSectionCount: (n) => `(${n})`,
  roomsEmpty: 'Aucun salon pour l’instant',
  // Guillemets with their inner narrow no-break spaces (decision 7). The Flutter
  // catalog's `sidebarNoRoomsMatch` is missing them; this follows the contract.
  roomsNoMatch: (query) => `Aucun salon ne correspond à «\u202f${query}\u202f».`,
  roomsNoneInFilter: 'Aucun salon dans ce filtre.',
  roomsUnread: 'Non lu',
  // French treats 0 as singular, unlike English: « 0 membre », « 1 membre »,
  // « 2 membres ». Pinned the same way the Flutter `strings_fr_test` pins it.
  roomsMemberCount: (n) => (n < 2 ? `${n} membre` : `${n} membres`),
  roomsUntitled: 'Salon sans titre',
  roomsStateOpen: 'Ouvert',
  roomsStateClosed: 'Fermé',
  roomsStateLeft: 'Quitté',
  roomsStateRemoved: 'Retiré',
  roomsSessionOpen: 'Session ouverte',
  roomsYouLeft: 'Vous avez quitté ce salon',
  roomsYouWereRemoved: 'Vous avez été retiré de ce salon',
  roomsPin: (room) => `Épingler ${room}`,
  roomsUnpin: (room) => `Désépingler ${room}`,
  roomsArchive: (room) => `Archiver ${room}`,
  roomsRestore: (room) => `Restaurer ${room}`,
  roomsPinShort: 'Épingler',
  roomsUnpinShort: 'Désépingler',
  roomsArchiveShort: 'Archiver',
  roomsRestoreShort: 'Restaurer depuis l’archive',
  roomsRailLabel: 'Barre latérale des salons',
  roomsListLabel: 'Salons',
  roomsProfile: 'Profil et réglages',

  // -- room recovery surfaces --------------------------------------------------
  roomNotOnDevice: 'Ce salon n’est pas sur cet appareil',
  roomNotOnDeviceDetail:
    'Rien ici ne correspond à {id}. Il se trouve peut-être sur un autre appareil, ou vous ne l’avez pas ' +
    'encore rejoint.',
  roomBackToRooms: 'Retour aux salons',
  roomLeftDetail:
    'Votre départ est publié dans le journal signé du salon. Il vous faudra une nouvelle invitation pour le ' +
    'rejoindre.',
  roomRemovedDetail:
    'Votre retrait est publié dans le journal signé du salon. Il vous faudra une nouvelle invitation pour le ' +
    'rejoindre.',

  // -- identity ----------------------------------------------------------------
  identitySelf: 'Vous',
  identityP2P: 'Identité P2P',
  identityCopy: 'Copier l’identifiant d’identité',
  // Tier 2: `ep` and `endpoint` are the daemon's own words for a wire id.
  identityEndpointShort: (id) => `ep ${id}`,
  identityEndpointTitle: (id) => `endpoint ${id}`,

  // -- modals ------------------------------------------------------------------
  modalJoinCopy:
    'Collez l’invitation que vous avez reçue. Une invitation combinée ({combined}) renseigne automatiquement ' +
    'l’adresse du pair.',
  modalTicketLabel: 'Ticket',
  modalPeerAddrLabel: 'Adresse du pair',
  modalJoinSubmit: 'Rejoindre le salon',
  modalJoining: 'Connexion…',
  modalJoinAttempt: (attempt, max) => `Tentative ${attempt}/${max}`,
  modalCreateTitle: 'Créer un salon',
  modalRoomNameLabel: 'Nom du salon',
  modalCreating: 'Création…',
  modalCreateHomonymWarning:
    'Un salon portant ce nom existe déjà sur cet appareil — celui-ci aura son propre identifiant.',
  modalLeaveTitle: 'Quitter le salon',
  modalLeaveCopy:
    'Quitter {room} {id} publie une annonce de départ signée. Ce n’est pas la même chose que fermer la ' +
    'session locale\u202f; il vous faudra une nouvelle invitation pour rejoindre le salon à nouveau.',
  modalLeaveSubmit: 'Quitter le salon',
  modalLeaving: 'Départ…',
  modalRenameTitle: 'Nommer ce pair',
  modalRenameCopy: 'Alias local uniquement — les noms ne quittent jamais cette machine.',
  modalRenameIdentityLabel: 'Identité\u00a0:',
  modalRenameAliasLabel: 'Alias',
  modalRenameClearAlias: 'Supprimer l’alias',

  // -- formatting vocabulary ---------------------------------------------------
  formatToday: 'Aujourd’hui',
  formatYesterday: 'Hier',
  // Octets, not bytes (decision 7). Unit WORDS follow the text locale; the
  // number inside them already came from the formatting locale.
  formatBytesB: (n) => `${n} o`,
  formatBytesKb: (n) => `${n} Ko`,
  formatBytesMb: (n) => `${n} Mo`,
  formatBytesGb: (n) => `${n} Go`,
  formatPercent: (n) => `${n}\u202f%`,
  formatJustNow: 'à l’instant',
};
