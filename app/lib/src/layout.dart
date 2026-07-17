/// The form-factor seam: width, never platform, orientation, or shortestSide —
/// a tablet (or a wide desktop window) keeps the workbench shell; a narrow
/// window gets the one-pane compact shell.
///
/// Three shells, one information architecture (docs/room-workbench.md,
/// decision 3; web parity: ui/src/lib/shell.ts and the matching queries in
/// ui/src/styles.css):
///
///   compact  < 900      one pane at a time
///   medium   900-1279   room rail + workspace; the inspector is a drawer
///   wide     >= 1280    room rail + workspace + inspector column
///
/// Every fork that decides *which shell* goes through [shellOf], so the whole
/// UI flips together. That is narrower than "every width fork in the app",
/// which this file used to claim and never enforced: a pane whose own box gets
/// narrow may reflow its own contents without consulting the shell — see
/// room_header.dart, which forks at its own width because a Wrap inside a Row
/// can never actually wrap. The rule is that pane-local reflow may not decide
/// which panes exist.
library;

import 'package:flutter/widgets.dart';

/// Logical px below which the shell renders the one-pane compact layout.
///
/// The medium shell begins exactly AT this width — which is why the responsive
/// contract names 899 and 900 as separate cases.
const double kShellBreakpoint = 900;

/// Logical px at and above which the inspector stops being a drawer and takes
/// a column of its own.
///
/// Not 901: at 901 a three-column layout leaves the workspace narrower than
/// the phone layout it just graduated from. A third column is paid for only
/// once one fits.
const double kWideBreakpoint = 1280;

/// The three shells.
enum Shell { compact, medium, wide }

Shell shellForWidth(double width) {
  if (width < kShellBreakpoint) return Shell.compact;
  return width >= kWideBreakpoint ? Shell.wide : Shell.medium;
}

/// The shell for the current window. MediaQuery-based (the WINDOW width, not
/// the local pane width) so an over-painting surface like the fleet overlay
/// forks the same way as the shell hosting it, and so a live window resize
/// re-routes on the next build.
Shell shellOf(BuildContext context) =>
    shellForWidth(MediaQuery.sizeOf(context).width);

/// True when the window is narrower than [kShellBreakpoint].
bool isMobileWidth(BuildContext context) => shellOf(context) == Shell.compact;
