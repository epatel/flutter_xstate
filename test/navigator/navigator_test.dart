import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_xstate/flutter_xstate.dart';

// Test context
class NavContext {
  final String userId;
  final String? selectedPage;

  const NavContext({this.userId = '', this.selectedPage});

  NavContext copyWith({String? userId, String? selectedPage}) {
    return NavContext(
      userId: userId ?? this.userId,
      selectedPage: selectedPage ?? this.selectedPage,
    );
  }
}

// Test events
sealed class NavEvent extends XEvent {}

class GoHomeEvent extends NavEvent {
  @override
  String get type => 'GO_HOME';
}

class GoProfileEvent extends NavEvent {
  final String userId;
  GoProfileEvent(this.userId);

  @override
  String get type => 'GO_PROFILE';
}

class LogoutEvent extends NavEvent {
  @override
  String get type => 'LOGOUT';
}

void main() {
  group('StateRouteConfig', () {
    test('should match exact state ID', () {
      final config = StateRouteConfig<NavContext, NavEvent>(
        stateId: 'home',
        path: '/',
        pageBuilder: (ctx, snapshot, params) =>
            StateMachinePage(stateId: 'home', child: const SizedBox()),
      );

      expect(config.matchesState('home'), isTrue);
      expect(config.matchesState('home.sub'), isTrue);
      expect(config.matchesState('profile'), isFalse);
    });

    test('should match wildcard state ID', () {
      final config = StateRouteConfig<NavContext, NavEvent>(
        stateId: 'loggedIn.*',
        path: '/dashboard',
        pageBuilder: (ctx, snapshot, params) =>
            StateMachinePage(stateId: 'loggedIn', child: const SizedBox()),
      );

      expect(config.matchesState('loggedIn'), isTrue);
      expect(config.matchesState('loggedIn.home'), isTrue);
      expect(config.matchesState('loggedIn.profile'), isTrue);
      expect(config.matchesState('loggedOut'), isFalse);
    });

    test('should extract path parameters', () {
      final config = StateRouteConfig<NavContext, NavEvent>(
        stateId: 'profile',
        path: '/profile/:userId',
        pageBuilder: (ctx, snapshot, params) =>
            StateMachinePage(stateId: 'profile', child: const SizedBox()),
      );

      final params = config.extractParams('/profile/123');
      expect(params, isNotNull);
      expect(params!['userId'], equals('123'));

      expect(config.extractParams('/home'), isNull);
      expect(config.extractParams('/profile'), isNull);
    });

    test('should extract multiple path parameters', () {
      final config = StateRouteConfig<NavContext, NavEvent>(
        stateId: 'post',
        path: '/user/:userId/post/:postId',
        pageBuilder: (ctx, snapshot, params) =>
            StateMachinePage(stateId: 'post', child: const SizedBox()),
      );

      final params = config.extractParams('/user/abc/post/xyz');
      expect(params, isNotNull);
      expect(params!['userId'], equals('abc'));
      expect(params['postId'], equals('xyz'));
    });

    test('should build path from context', () {
      final config = StateRouteConfig<NavContext, NavEvent>(
        stateId: 'profile',
        path: '/profile/:userId',
        pageBuilder: (ctx, snapshot, params) =>
            StateMachinePage(stateId: 'profile', child: const SizedBox()),
        contextToParams: (ctx) => {'userId': ctx.userId},
      );

      const context = NavContext(userId: '456');
      expect(config.buildPath(context), equals('/profile/456'));
    });
  });

  group('StateMachinePage', () {
    test('should create page with default values', () {
      final page = StateMachinePage(stateId: 'home', child: const Text('Home'));

      expect(page.stateId, equals('home'));
      expect(
        page.transitionDuration,
        equals(const Duration(milliseconds: 300)),
      );
      expect(page.maintainState, isTrue);
      expect(page.opaque, isTrue);
    });

    test('should create fade transition page', () {
      final page = StateMachinePage.fade(
        stateId: 'home',
        child: const Text('Home'),
        transitionDuration: const Duration(milliseconds: 500),
      );

      expect(page.stateId, equals('home'));
      expect(page.transitionBuilder, isNotNull);
      expect(
        page.transitionDuration,
        equals(const Duration(milliseconds: 500)),
      );
    });

    test('should create slide from right page', () {
      final page = StateMachinePage.slideFromRight(
        stateId: 'details',
        child: const Text('Details'),
      );

      expect(page.stateId, equals('details'));
      expect(page.transitionBuilder, isNotNull);
    });

    test('should create modal page', () {
      final page = StateMachinePage.modal(
        stateId: 'dialog',
        child: const Text('Dialog'),
      );

      expect(page.stateId, equals('dialog'));
      expect(page.fullscreenDialog, isTrue);
    });

    test('should create instant page', () {
      final page = StateMachinePage.instant(
        stateId: 'splash',
        child: const Text('Splash'),
      );

      expect(page.stateId, equals('splash'));
      expect(page.transitionDuration, equals(Duration.zero));
      expect(page.reverseTransitionDuration, equals(Duration.zero));
    });
  });

  group('StateMachineTransitions', () {
    test('fade transition returns FadeTransition widget', () {
      const animation = AlwaysStoppedAnimation<double>(0.5);

      final widget = StateMachineTransitions.fade(
        const Text('Test'),
        animation,
        animation,
      );

      expect(widget, isA<FadeTransition>());
    });

    test('slideFromRight transition returns SlideTransition widget', () {
      const animation = AlwaysStoppedAnimation<double>(0.5);

      final widget = StateMachineTransitions.slideFromRight(
        const Text('Test'),
        animation,
        animation,
      );

      expect(widget, isA<SlideTransition>());
    });

    test('slideFromBottom transition returns SlideTransition widget', () {
      const animation = AlwaysStoppedAnimation<double>(0.5);

      final widget = StateMachineTransitions.slideFromBottom(
        const Text('Test'),
        animation,
        animation,
      );

      expect(widget, isA<SlideTransition>());
    });

    test('scale transition returns ScaleTransition widget', () {
      const animation = AlwaysStoppedAnimation<double>(0.5);

      final widget = StateMachineTransitions.scale(
        const Text('Test'),
        animation,
        animation,
      );

      expect(widget, isA<ScaleTransition>());
    });

    test('none transition returns child directly', () {
      const animation = AlwaysStoppedAnimation<double>(0.5);
      const child = Text('Test');

      final widget = StateMachineTransitions.none(child, animation, animation);

      expect(widget, same(child));
    });

    test('combine applies multiple transitions', () {
      const animation = AlwaysStoppedAnimation<double>(0.5);

      final combined = StateMachineTransitions.combine([
        StateMachineTransitions.fade,
        StateMachineTransitions.scale,
      ]);

      final widget = combined(const Text('Test'), animation, animation);

      // The outer widget should be FadeTransition (first in list, applied last)
      expect(widget, isA<FadeTransition>());
    });

    test('custom slide creates PageTransitionBuilder', () {
      final builder = StateMachineTransitions.slide(
        begin: const Offset(0, 1),
        end: Offset.zero,
      );

      const animation = AlwaysStoppedAnimation<double>(0.5);

      final widget = builder(const Text('Test'), animation, animation);

      expect(widget, isA<SlideTransition>());
    });
  });

  group('StateMachineRouteInformationParser', () {
    test('should parse valid route', () async {
      final parser = StateMachineRouteInformationParser<NavContext, NavEvent>(
        routes: [
          StateRouteConfig<NavContext, NavEvent>(
            stateId: 'home',
            path: '/',
            pageBuilder: (ctx, snapshot, params) =>
                StateMachinePage(stateId: 'home', child: const SizedBox()),
          ),
          StateRouteConfig<NavContext, NavEvent>(
            stateId: 'profile',
            path: '/profile/:userId',
            pageBuilder: (ctx, snapshot, params) =>
                StateMachinePage(stateId: 'profile', child: const SizedBox()),
          ),
        ],
      );

      final result = await parser.parseRouteInformation(
        RouteInformation(uri: Uri.parse('/profile/123')),
      );

      expect(result.uri.path, equals('/profile/123'));
    });

    test('should fallback to default path for invalid route', () async {
      final parser = StateMachineRouteInformationParser<NavContext, NavEvent>(
        routes: [
          StateRouteConfig<NavContext, NavEvent>(
            stateId: 'home',
            path: '/',
            pageBuilder: (ctx, snapshot, params) =>
                StateMachinePage(stateId: 'home', child: const SizedBox()),
          ),
        ],
        defaultPath: '/home',
      );

      final result = await parser.parseRouteInformation(
        RouteInformation(uri: Uri.parse('/unknown')),
      );

      expect(result.uri.path, equals('/home'));
    });
  });

  group('SimpleRouteInformationParser', () {
    test('should accept any path', () async {
      const parser = SimpleRouteInformationParser(defaultPath: '/');

      final result = await parser.parseRouteInformation(
        RouteInformation(uri: Uri.parse('/any/path/here')),
      );

      expect(result.uri.path, equals('/any/path/here'));
    });

    test('should use default path when empty', () async {
      const parser = SimpleRouteInformationParser(defaultPath: '/home');

      final result = await parser.parseRouteInformation(
        RouteInformation(uri: Uri.parse('')),
      );

      expect(result.uri.path, equals('/home'));
    });
  });
}
