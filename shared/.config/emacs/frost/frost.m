// frost.m --- the native half of frost.el  -*- mode: objc -*-
//
// SPDX-License-Identifier: GPL-3.0-or-later
//
// One function, (frost--apply MODE MATERIAL RED GREEN BLUE ALPHA), applied to
// the window of every top-level NS frame:
//
// - an NSVisualEffectView blurring what is behind the window, in the theme
//   frame below the content view, the size of the whole window (title bar
//   included), following it by its autoresizing mask;
// - over it a flat tint, RED GREEN BLUE at ALPHA (0 to 1);
// - on the EmacsView's layer, a blend mode that lets the glass through its
//   background: screen for MODE `dark', multiply for `light'.
//
// MODE nil takes all of it off.  The window itself is left as Emacs keeps it,
// opaque, so nothing Emacs does to it undoes this.  Calling it again with the
// same arguments changes nothing.  MATERIAL is an NSVisualEffectMaterial value.
//
// Built by frost.el:
//   clang -shared -fobjc-arc -framework Cocoa -framework QuartzCore -I. frost.m -o frost-module.dylib

#import <Cocoa/Cocoa.h>
#import <QuartzCore/QuartzCore.h>
#include "emacs-module.h"

int plugin_is_GPL_compatible;

static NSString *const kEffect = @"frost-effect";
static NSString *const kTint = @"frost-tint";

// A top-level frame's window: an EmacsWindow's delegate is its EmacsView.  A
// child frame (posframe, corfu) stays opaque; it loses its parentWindow while
// hidden, so its floating subrole tells it apart then.  Tooltips and
// non-native fullscreen windows are borderless.
static BOOL is_frame_window(NSWindow *window) {
  return [NSStringFromClass([window.delegate class]) isEqualToString:@"EmacsView"]
      && window.parentWindow == nil
      && ![window.accessibilitySubrole isEqualToString:NSAccessibilityFloatingWindowSubrole]
      && window.styleMask != NSWindowStyleMaskBorderless;
}

// The EmacsView: a subview of the content view, or the content view itself in
// older layouts.
static NSView *emacs_view(NSView *view) {
  if ([NSStringFromClass(view.class) isEqualToString:@"EmacsView"]) return view;
  for (NSView *child in view.subviews) {
    NSView *found = emacs_view(child);
    if (found) return found;
  }
  return nil;
}

static NSView *subview(NSView *parent, NSString *identifier) {
  for (NSView *view in parent.subviews)
    if ([view.identifier isEqualToString:identifier]) return view;
  return nil;
}

// Return the view IDENTIFIER in the theme frame, made with MAKE when missing,
// below the content view.
static NSView *placed(NSView *content, NSString *identifier, NSView *(^make)(NSRect)) {
  NSView *frame = content.superview;
  NSView *view = subview(frame, identifier);
  if (!view) {
    view = make(frame.bounds);
    view.identifier = identifier;
    view.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    [frame addSubview:view positioned:NSWindowBelow relativeTo:content];
  }
  return view;
}

static void frost(NSWindow *window, NSString *mode, NSInteger material, NSColor *tint) {
  NSView *content = window.contentView;
  NSView *emacs = emacs_view(content);
  if (!content.superview || !emacs) return;
  if (!mode) {
    [subview(content.superview, kTint) removeFromSuperview];
    [subview(content.superview, kEffect) removeFromSuperview];
    emacs.layer.compositingFilter = nil;
    return;
  }
  BOOL dark = [mode isEqualToString:@"dark"];
  // The effect first, so that the tint, placed below the content view after
  // it, lands above it.
  NSVisualEffectView *effect = (NSVisualEffectView *)placed(content, kEffect, ^(NSRect bounds) {
    NSVisualEffectView *view = [[NSVisualEffectView alloc] initWithFrame:bounds];
    view.blendingMode = NSVisualEffectBlendingModeBehindWindow;
    view.state = NSVisualEffectStateActive;
    return (NSView *)view;
  });
  effect.material = material;
  effect.appearance = [NSAppearance appearanceNamed:dark ? NSAppearanceNameDarkAqua : NSAppearanceNameAqua];
  NSView *view = placed(content, kTint, ^(NSRect bounds) {
    NSView *view = [[NSView alloc] initWithFrame:bounds];
    view.wantsLayer = YES;
    return view;
  });
  view.layer.backgroundColor = tint.CGColor;
  // Core Animation's blend modes, by the names CIFilter gives them.
  emacs.layer.compositingFilter = dark ? @"screenBlendMode" : @"multiplyBlendMode";
}

static emacs_value apply(emacs_env *env, ptrdiff_t nargs, emacs_value *args, void *data) {
  NSString *mode = nil;
  if (env->eq(env, args[0], env->intern(env, "dark"))) mode = @"dark";
  else if (env->eq(env, args[0], env->intern(env, "light"))) mode = @"light";
  NSInteger material = env->extract_integer(env, args[1]);
  NSColor *tint = [NSColor colorWithSRGBRed:env->extract_float(env, args[2])
                                      green:env->extract_float(env, args[3])
                                       blue:env->extract_float(env, args[4])
                                      alpha:env->extract_float(env, args[5])];
  if (env->non_local_exit_check(env) != emacs_funcall_exit_return) return NULL;
  @try {
    for (NSWindow *window in NSApp.windows)
      if (is_frame_window(window)) frost(window, mode, material, tint);
  } @catch (NSException *exception) {
    return env->intern(env, "nil");
  }
  return env->intern(env, "t");
}

int emacs_module_init(struct emacs_runtime *runtime) {
  if (runtime->size < (ptrdiff_t)sizeof *runtime) return 1;
  emacs_env *env = runtime->get_environment(runtime);
  if (env->size < (ptrdiff_t)sizeof(struct emacs_env_25)) return 2;
  emacs_value args[] = {
    env->intern(env, "frost--apply"),
    env->make_function(env, 6, 6, apply,
                       "Frost every top-level frame: MODE MATERIAL RED GREEN BLUE ALPHA.\n\n"
                       "(fn MODE MATERIAL RED GREEN BLUE ALPHA)", NULL)};
  env->funcall(env, env->intern(env, "defalias"), 2, args);
  return 0;
}
