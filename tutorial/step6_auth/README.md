# Step 6: Authentication Flow

Demonstrates **state machine patterns** for auth flows using compound states and async operations.

> **Note**: This tutorial teaches state machine concepts, not production security. For real apps, use proper auth services (Firebase Auth, Auth0), secure token storage (`flutter_secure_storage`), HTTPS, input validation, and rate limiting.

## Run

```bash
cd tutorial/step6_auth
flutter run -d chrome
```

## Concepts Introduced

- **Compound States for UI Modes** - `loggedOut.idle`, `loggedOut.submitting`, `loggedOut.error`
- **Async Operations** - Simulated login with delayed response
- **Loading States** - Show spinner during async operations
- **Error Handling** - Display errors and retry functionality
- **Session Management** - Handle session expiry

## How to Use

1. Enter credentials (hint: `test@example.com` / `password`)
2. Click **Sign In** to trigger login (1.5s simulated delay)
3. Watch the state transition: `idle` → `submitting` → `loggedIn` or `error`
4. From home screen, click **Sign Out** or **Simulate Session Expiry**
5. Try wrong credentials to see error state and retry flow

## State Machine Structure

```
auth
├── loggedOut (compound)
│   ├── entry: [clear user and token]
│   ├── idle (initial)
│   │   └── LOGIN_SUBMIT → loggedOut.submitting
│   ├── submitting
│   │   ├── entry: [start async login]
│   │   ├── LOGIN_SUCCESS → loggedIn
│   │   └── LOGIN_FAILURE → loggedOut.error
│   └── error
│       ├── RETRY → loggedOut.idle
│       └── LOGIN_SUBMIT → loggedOut.submitting
└── loggedIn
    ├── LOGOUT → loggedOut.idle
    └── SESSION_EXPIRED → loggedOut.error
```

## Code Highlights

### Async Operations Pattern

```dart
// Entry action starts the async operation
..state('submitting', (child) => child
  ..entry([
    (ctx, event) {
      if (event is LoginSubmitEvent) {
        _simulateLogin(event.email, event.password);
      }
      return ctx;
    },
  ])
  ..on<LoginSuccessEvent>('loggedIn', actions: [...])
  ..on<LoginFailureEvent>('loggedOut.error', actions: [...])
)

// Async callback sends events back to the machine
void _simulateLogin(String email, String password) {
  Future.delayed(const Duration(milliseconds: 1500), () {
    if (/* success */) {
      _authActor!.send(LoginSuccessEvent(token: ..., user: ...));
    } else {
      _authActor!.send(LoginFailureEvent('Invalid credentials'));
    }
  });
}
```

### UI Based on Nested States

```dart
final isLoading = state.value.matches('loggedOut.submitting');
final hasError = state.value.matches('loggedOut.error');

// Show spinner when loading
child: isLoading
    ? const CircularProgressIndicator()
    : const Text('Sign In'),

// Show error banner when in error state
if (hasError && error != null)
  ErrorBanner(message: error),
```

### Error Recovery

```dart
..state('error', (child) => child
  // Go back to idle to retry
  ..on<RetryEvent>('loggedOut.idle', actions: [
    (ctx, _) => ctx.copyWith(clearError: true),
  ])
  // Or submit again directly
  ..on<LoginSubmitEvent>('loggedOut.submitting', actions: [...])
)
```

### Session Expiry Handling

```dart
..state('loggedIn', (s) => s
  ..on<LogoutEvent>('loggedOut.idle')
  ..on<SessionExpiredEvent>('loggedOut.error', actions: [
    (ctx, _) => ctx.copyWith(error: 'Session expired. Please login again.'),
  ])
)
```
