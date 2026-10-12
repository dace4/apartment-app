# Architecture & Development Guide

This app follows a simple **MVVM** architecture, the same one as the course lab
([Flutter lab: Widget to layered architecture](https://gianou.github.io/flutter-lab-widget-to-layered-architecture/mvvm_view.html)).

Read this page before writing code. Every feature is built the same way, so once
you understand one, you understand all of them.

---

## 1. The layers

```
Firebase ──▶ Service ──(Models)──▶ ViewModel ──▶ View
                                       ▲          │
                                       └─ actions ┘
```

| Layer | Role | Knows about | Never does |
|---|---|---|---|
| **Model** | The shape of a piece of data (`Apartment`: id, title, price…) and its conversion from/to Firebase (`fromMap` / `toMap`). | nothing (pure Dart, except Firestore's `Timestamp` to convert dates in `fromMap` / `toMap`) | fetch data, hold app state |
| **Service** | Reads and writes Firebase (Firestore, Auth). One method = one operation. Returns Models. | Firebase, Models | hold state, call `notifyListeners()`, import `material.dart` |
| **ViewModel** | The state and logic of **one screen**: data to show, `isLoading`, `errorMessage`, filters, validation, actions (`fetchX()`, `submit()`…). | Services, Models | import `cloud_firestore` / `firebase_auth`, build widgets, navigate |
| **View** | Displays the ViewModel and forwards user actions (taps, input) to it. | its ViewModel, widgets | call a Service, take decisions (filter, validate, compute…) |

**Where does my code go?**

- It talks to Firebase → **Service**
- It decides something or holds state (filtering, validation, loading…) → **ViewModel**
- It is a widget, a style, or navigation → **View**
- It describes what a piece of data contains → **Model**
- It is a small pure function used by several screens (form validator,
  price formatter…) → **utils/**

---

## 2. Folder structure

```
lib/
├── main.dart                 # Firebase init, starts the app
├── app.dart                  # MaterialApp, creates AuthViewModel and the router
├── router/
│   ├── app_router.dart       # GoRouter routes + auth redirect
│   └── app_routes.dart       # Every path of the app (AppRoutes.apartments…)
├── models/                   # Data classes
│   ├── apartment.dart
│   └── rental_application.dart
├── services/                 # Firebase access, one file per kind of data
│   ├── auth_service.dart
│   ├── apartment_service.dart
│   └── application_service.dart
├── view_models/              # One file per screen
│   ├── apartments_view_model.dart
│   └── applications_view_model.dart
├── utils/                    # Pure helpers shared by several screens
│   ├── formatters.dart
│   └── validators.dart
└── views/
    ├── apartments/           # One folder per feature
    │   ├── apartments_view.dart
    │   ├── filters_view.dart
    │   └── widgets/          # Widgets used only by this feature
    │       └── apartment_card.dart
    ├── applications/
    └── shared/widgets/       # Widgets used by several features
```

### Naming

| What | File | Class |
|---|---|---|
| Model | `models/apartment.dart` | `Apartment` |
| Service | `services/apartment_service.dart` | `ApartmentService` |
| ViewModel | `view_models/apartments_view_model.dart` | `ApartmentsViewModel` |
| View (a page/route) | `views/apartments/apartments_view.dart` | `ApartmentsView` |
| Widget (part of a page) | `views/apartments/widgets/apartment_card.dart` | `ApartmentCard` |

One **Service per kind of data** (used by several screens).
One **ViewModel per screen** (or per group of screens sharing state, see §4).

---

## 3. Templates

Copy these when you create something new. They are shortened versions of the
real applications files (`rental_application.dart`, `application_service.dart`,
`applications_view_model.dart`, `applications_view.dart`): open those to see a
complete example.

### Model

```dart
class Application {
  const Application({
    required this.id,
    required this.apartmentId,
    required this.message,
  });

  final String id;
  final String apartmentId;
  final String message;

  factory Application.fromMap(String id, Map<String, dynamic> map) {
    return Application(
      id: id,
      apartmentId: map['apartmentId'] as String,
      message: map['message'] as String,
    );
  }

  Map<String, dynamic> toMap() {
    return {'apartmentId': apartmentId, 'message': message};
  }
}
```

### Service

```dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/application.dart';

class ApplicationService {
  final _collection = FirebaseFirestore.instance.collection('applications');

  String get _userId => FirebaseAuth.instance.currentUser!.uid;

  Future<List<Application>> getMyApplications() async {
    final snapshot = await _collection.where('userId', isEqualTo: _userId).get();
    return snapshot.docs
        .map((doc) => Application.fromMap(doc.id, doc.data()))
        .toList();
  }

  Future<void> submit(Application application) {
    return _collection.add({...application.toMap(), 'userId': _userId});
  }
}
```

### ViewModel

```dart
import 'package:flutter/foundation.dart';

import '../models/application.dart';
import '../services/application_service.dart';

class ApplicationsViewModel extends ChangeNotifier {
  final ApplicationService service = ApplicationService();

  List<Application> applications = [];
  bool isLoading = false;
  String? errorMessage;

  Future<void> fetchApplications() async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      applications = await service.getMyApplications();
    } catch (e) {
      errorMessage = 'Could not load your applications.';
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }
}
```

### View

```dart
import 'package:flutter/material.dart';

import '../../view_models/applications_view_model.dart';

class ApplicationsView extends StatefulWidget {
  const ApplicationsView({super.key});

  @override
  State<ApplicationsView> createState() => _ApplicationsViewState();
}

class _ApplicationsViewState extends State<ApplicationsView> {
  final viewModel = ApplicationsViewModel();

  @override
  void initState() {
    super.initState();
    viewModel.fetchApplications();
  }

  @override
  void dispose() {
    viewModel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My applications')),
      body: ListenableBuilder(
        listenable: viewModel,
        builder: (context, _) {
          // 1. Loading
          if (viewModel.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          // 2. Error
          if (viewModel.errorMessage != null) {
            return Center(child: Text(viewModel.errorMessage!));
          }
          // 3. Empty
          if (viewModel.applications.isEmpty) {
            return const Center(child: Text('No applications yet.'));
          }
          // 4. Data
          return ListView.builder(
            itemCount: viewModel.applications.length,
            itemBuilder: (context, index) {
              final application = viewModel.applications[index];
              return ListTile(title: Text(application.message));
            },
          );
        },
      ),
    );
  }
}
```

Every View that loads data handles the same 4 states in the same order:
**loading → error → empty → data**.

### Live data (Firestore `snapshots()`)

Use it when the data can change while the screen stays open, for example
when another screen edits it. Tabs stay alive, so a list read once with
`get()` would not show a new or edited item. (Applications use this.)

```dart
// Service: snapshots() instead of get()
Stream<List<RentalApplication>> watchMyApplications() {
  return _collection
      .where('userId', isEqualTo: _userId)
      .snapshots()
      .map((snapshot) => snapshot.docs
          .map((doc) => RentalApplication.fromMap(doc.id, doc.data()))
          .toList());
}

// ViewModel: listen instead of await, and cancel in dispose()
StreamSubscription<List<RentalApplication>>? _subscription;

void listenToApplications() {
  isLoading = true;
  errorMessage = null;
  notifyListeners();

  _subscription?.cancel();
  _subscription = service.watchMyApplications().listen(
    (newApplications) {
      applications = newApplications;
      isLoading = false;
      notifyListeners();
    },
    onError: (e) {
      errorMessage = 'Could not load your applications.';
      isLoading = false;
      notifyListeners();
    },
  );
}

@override
void dispose() {
  _subscription?.cancel();
  super.dispose();
}
```

The View calls `viewModel.listenToApplications()` in `initState`, exactly
like a `fetchX()`.

### Actions followed by navigation

When an action (submit, save…) must open another page on success, the
ViewModel method returns `true` when it worked, and the **View** navigates:

```dart
// ViewModel
Future<bool> save(ApplicationDetails details) async {
  isSaving = true;
  saveError = null;
  notifyListeners();
  try {
    await service.update(application!.id, details);
    return true;
  } catch (e) {
    saveError = 'Could not save the changes. Please try again.';
    return false;
  } finally {
    isSaving = false;
    notifyListeners();
  }
}

// View
Future<void> _save(ApplicationDetails details) async {
  final saved = await viewModel.save(details);
  if (saved && mounted) context.go(AppRoutes.applicationDetail(id));
}
```

Keep the loading error (`errorMessage`, replaces the page) separate from the
action error (`saveError`, shown under the button) so a failed save does not
hide the form.

---

## 4. Sharing a ViewModel between Views

Some state is needed by several screens. For example, the apartment list and the
Filters page must see the same filter, and the whole app needs the signed-in user.

In that case the ViewModel is **created once** (in `app.dart` or `router/app_router.dart`)
and **passed to each View through its constructor**:

```dart
// router/app_router.dart
final apartmentsViewModel = ApartmentsViewModel();

GoRoute(
  path: '/apartments',
  builder: (context, state) => ApartmentsView(viewModel: apartmentsViewModel),
),
GoRoute(
  path: '/apartments/filters',
  builder: (context, state) => FiltersView(viewModel: apartmentsViewModel),
),
```

The Filters page then updates the shared ViewModel and simply goes back. Nothing
is returned through `pop`:

```dart
// filters_view.dart
onPressed: () {
  widget.viewModel.applyFilter(newFilter);
  context.pop();
},
```

The list rebuilds by itself because it listens to the same ViewModel.

**Rule:** if only one screen needs the state, the View creates its own ViewModel
(§3). If several screens need it, it is created once and passed to them.

---

## 5. Adding a feature: checklist

1. **Model**: add the data class in `lib/models/` with `fromMap` / `toMap`.
2. **Service**: add the Firebase methods in `lib/services/xxx_service.dart`
   (create the file if this kind of data is new).
3. **ViewModel**: create `lib/view_models/xxx_view_model.dart` (state + actions).
4. **View**: create `lib/views/xxx/xxx_view.dart`, plus its widgets in
   `lib/views/xxx/widgets/`.
5. **Route**: add the path in `lib/router/app_routes.dart` and the route in
   `lib/router/app_router.dart`.
6. **Check**: `flutter analyze` passes, then try it in the app.

---

## 6. Rules to keep the code simple

- **Views only display, ViewModels decide.** A View may use `if` to choose
  *what to show* (`if (viewModel.isLoading)` → spinner). Anything that *decides*
  something belongs in the ViewModel:

  | In the ViewModel | In the View |
  |---|---|
  | Filter the apartments | Show `viewModel.apartments` |
  | Check that max price ≥ min price | Show the error message the ViewModel gives |
  | Know if an application can still be edited (5 days) | Disable the button when `viewModel.canEdit` is false |
  | Compute a monthly mortgage payment | Show `viewModel.monthlyPayment` |
- **No Firebase outside `services/`.** `cloud_firestore` and `firebase_auth` are
  only imported there. Only exception: a Model may use Firestore's `Timestamp`
  to convert dates in `fromMap` / `toMap`.
- **No `material.dart` in ViewModels or Services.** Use
  `package:flutter/foundation.dart` for `ChangeNotifier`.
- **No values returned through navigation** (`pop(result)`). Share a ViewModel
  instead (§4).
- **The View shows error messages as-is.** The ViewModel puts them in
  `errorMessage`. When the message depends on the Firebase error (wrong
  password, email already used…), the Service throws an exception that
  already contains a readable message (see `AuthException` in
  `auth_service.dart`), and the ViewModel copies it.
- **Generic form validators** (email, password…) go in `utils/validators.dart`.
  A validator specific to one screen (max price ≥ min price) goes in that
  screen's ViewModel.
- **Keep it simple.** Write the straightforward version first. Add timeouts,
  retries, caching or abstractions only when there is a real need.
- One public class per file, the file named after the class.

---

## 7. Git

See the [Git Workflow section of the README](README.md#-git-workflow--branching-strategy).
Branch off `develop`, one branch per user story, Pull Request back to `develop`.
