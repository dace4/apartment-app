import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:go_router/go_router.dart';
import 'package:appartment_app_group_2/views/apartments/create_apartment_view.dart';

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:image/image.dart' as image;
import 'package:appartment_app_group_2/models/apartment.dart';
import 'package:appartment_app_group_2/models/app_user.dart';
import 'package:appartment_app_group_2/models/user_role.dart';
import 'package:appartment_app_group_2/services/apartment_service.dart';
import 'package:appartment_app_group_2/services/listing_image_service.dart';
import 'package:appartment_app_group_2/services/listing_exception.dart';
import 'package:appartment_app_group_2/view_models/create_apartment_view_model.dart';
import 'package:appartment_app_group_2/view_models/auth_view_model.dart';
import 'package:appartment_app_group_2/router/app_routes.dart';
import 'package:appartment_app_group_2/utils/listing_validation.dart';
import 'package:appartment_app_group_2/views/apartments/widgets/apartment_gallery.dart';
import 'package:appartment_app_group_2/views/apartments/widgets/apartment_image.dart';

import 'us06_roles_test.dart' show RoleAuth;

String photo(int red) {
  final pixels = image.Image(width: 20, height: 20);
  image.fill(pixels, color: image.ColorRgb8(red, 70, 140));
  return normalizeListingImage(Uint8List.fromList(image.encodePng(pixels)));
}

Apartment listing({
  List<String>? photos,
  int price = 1500,
  double rooms = 3.5,
  String title = 'Sunny apartment',
}) {
  final pictures = photos ?? [photo(20), photo(100), photo(200)];
  return Apartment(
    id: '',
    title: title,
    address: 'Rue de Test 24',
    city: 'Sion',
    listingType: ListingType.rent,
    price: price,
    rooms: rooms,
    surface: 80,
    imageUrl: pictures.isEmpty ? '' : pictures.first,
    imageUrls: pictures,
    description: 'A representative apartment.',
    ownerId: 'forged',
    managerIds: {'forged'},
  );
}

class Picker extends ListingImageService {
  List<String> selected = [];
  bool fails = false;
  @override
  Future<List<String>> pickImages() async {
    if (fails) throw const ListingException('Unreadable image');
    return selected;
  }
}

class Publishing extends Fake implements ApartmentService {
  bool fails = false;
  int calls = 0;
  int ids = 0;
  final List<String> usedIds = [];
  Completer<void>? pending;
  @override
  String newApartmentId() => 'draft-${++ids}';
  @override
  Future<void> createApartment(String id, Apartment value) async {
    calls++;
    usedIds.add(id);
    if (pending != null) await pending!.future;
    if (fails) throw Exception('offline');
  }
}

void main() {
  test(
    'US-24 legacy single-image records and gallery survive copy and round trip',
    () {
      final old = listing().toMap()..remove('imageUrls');
      old['imageUrl'] = 'https://example.test/legacy.jpg';
      final legacy = Apartment.fromMap('old', old);
      expect(legacy.galleryImages, ['https://example.test/legacy.jpg']);
      final modern = Apartment.fromMap('new', listing().toMap());
      expect(modern.galleryImages.length, 3);
      expect(
        modern
            .copyWith(availability: ApartmentAvailability.reserved)
            .galleryImages,
        modern.galleryImages,
      );
    },
  );
  test(
    'US-24 mandatory values, ranges and three distinct photos are validated',
    () {
      expect(validateListing(listing()), isNull);
      for (final bad in [
        listing(photos: []),
        listing(photos: [photo(1), photo(2)]),
        listing(photos: [photo(1), photo(1), photo(2)]),
        listing(price: 0),
        listing(rooms: double.nan),
        listing(title: '  '),
        listing(title: 'x' * 201),
        listing(photos: List.generate(7, (i) => photo(i * 30))),
        listing(photos: ['broken', photo(1), photo(2)]),
      ]) {
        expect(validateListing(bad), isNotNull);
      }
    },
  );
  test('US-24 image bytes are checked, compressed and decoded as JPEG', () {
    final data = photo(90);
    expect(data.startsWith('data:image/jpeg;base64,/9j/'), true);
    final bytes = base64Decode(data.substring(23));
    expect(bytes.length, lessThanOrEqualTo(96 * 1024));
    expect(image.decodeJpg(bytes), isNotNull);
    expect(
      () => normalizeListingImage(Uint8List.fromList([1, 2, 3])),
      throwsA(isA<ListingException>()),
    );
    expect(
      () => normalizeListingImage(Uint8List(10 * 1024 * 1024 + 1)),
      throwsA(isA<ListingException>()),
    );
  });
  test('US-24 persistence forces creator ownership, available status and no managers', () async {
    final db = FakeFirebaseFirestore();
    AppUser? current = const AppUser(
      id: 'owner',
      email: 'owner@test.ch',
      emailVerified: true,
    );
    final service = ApartmentService(firestore: db, currentUser: () => current);
    await db.collection('users').doc('owner').set({
      'roles': ['homeowner'],
    });
    final draft = listing();
    await service.createApartment('new', draft);
    final data = (await db.collection('apartments').doc('new').get()).data()!;
    expect(data['ownerId'], 'owner');
    expect(data['managerIds'], isEmpty);
    expect(data['availability'], 'available');
    expect(data['imageUrls'], hasLength(3));
    expect(data['createdAt'], isNotNull);
    await service.createApartment('new', draft);
    expect((await db.collection('apartments').get()).docs, hasLength(1));
    await expectLater(
      service.createApartment('new', listing(title: 'Changed')),
      throwsA(isA<ListingException>()),
    );
    await db.collection('users').doc('owner').set({
      'roles': ['renter'],
    });
    await expectLater(
      service.createApartment('denied', draft),
      throwsA(isA<ListingException>()),
    );
    current = const AppUser(id: 'owner', email: '', emailVerified: false);
    await expectLater(
      service.createApartment('unverified', draft),
      throwsA(isA<ListingException>()),
    );
    current = null;
    await expectLater(
      service.createApartment('out', draft),
      throwsA(isA<ListingException>()),
    );
    expect((await db.collection('apartments').get()).docs, hasLength(1));
  });
  test('US-24 failed publication keeps draft, reuses ID and blocks double submission', () async {
    final service = Publishing()..fails = true;
    final vm = CreateApartmentViewModel(service: service, images: Picker());
    addTearDown(vm.dispose);
    expect(await vm.publish(listing(photos: [])), false);
    expect(service.calls, 0);
    expect(await vm.publish(listing()), false);
    expect(vm.actionError, isNotNull);
    service.fails = false;
    service.pending = Completer<void>();
    final saving = vm.publish(listing());
    expect(vm.isSaving, true);
    expect(await vm.publish(listing()), false);
    service.pending!.complete();
    expect(await saving, true);
    expect(service.usedIds, ['draft-1', 'draft-1']);
    expect(vm.publishedId, 'draft-1');
    expect(vm.actionError, isNull);
  });
  test('US-24 selection cancellation, duplicates, removal and picker failures retain draft', () async {
    final picker = Picker()..selected = [photo(10), photo(80), photo(160)];
    final vm = CreateApartmentViewModel(service: Publishing(), images: picker);
    addTearDown(vm.dispose);
    await vm.pickImages();
    expect(vm.photos, hasLength(3));
    await vm.pickImages();
    expect(vm.photos, hasLength(3));
    picker.selected = [];
    await vm.pickImages();
    expect(vm.photos, hasLength(3));
    picker.fails = true;
    await vm.pickImages();
    expect(vm.photos, hasLength(3));
    expect(vm.actionError, 'Unreadable image');
    vm.removePhoto(1);
    expect(vm.photos, hasLength(2));
  });
  test(
    'US-24 creation route is homeowner-only and retains verified-email gate',
    () async {
      final auth = RoleAuth();
      final vm = AuthViewModel(service: auth);
      addTearDown(() async {
        vm.dispose();
        await auth.users.close();
      });
      for (final role in UserRole.values) {
        auth.users.add(
          AppUser(id: 'u', email: '', emailVerified: true, roles: {role}),
        );
        await Future<void>.delayed(Duration.zero);
        expect(
          vm.canAccess(AppRoutes.createApartment),
          role == UserRole.homeowner,
        );
      }
      auth.users.add(
        const AppUser(
          id: 'u',
          email: '',
          emailVerified: false,
          roles: {UserRole.homeowner},
        ),
      );
      await Future<void>.delayed(Duration.zero);
      expect(vm.redirectFor(AppRoutes.createApartment), AppRoutes.verifyEmail);
    },
  );
  test('US-24 representative fixtures include valid rent/sale galleries and a legacy listing', () {
    final rows = jsonDecode(
      File('test/fixtures/us24_apartments.json').readAsStringSync(),
    ) as List;
    expect(rows.length, 4);
    for (final row in rows.take(3)) {
      final value = Apartment.fromMap(
        row['id'] as String,
        Map<String, dynamic>.from(row as Map),
      );
      expect(validateListing(value), isNull);
    }
    final legacy = Map<String, dynamic>.from(rows.last as Map);
    expect(
      Apartment.fromMap(legacy['id'] as String, legacy).galleryImages,
      hasLength(1),
    );
  });
  for (final size in [const Size(390, 844), const Size(800, 1000)]) {
    testWidgets(
      'US-24 creation form validates and publishes at ${size.width}',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final auth = RoleAuth();
        final account = AuthViewModel(service: auth);
        auth.users.add(
          const AppUser(
            id: 'owner',
            email: '',
            emailVerified: true,
            roles: {UserRole.homeowner},
          ),
        );
        await tester.pump();
        final service = Publishing();
        final picker = Picker()..selected = [photo(1), photo(80), photo(160)];
        final vm = CreateApartmentViewModel(service: service, images: picker);
        final router = GoRouter(
          initialLocation: AppRoutes.createApartment,
          routes: [
            GoRoute(
              path: AppRoutes.createApartment,
              builder: (_, _) =>
                  CreateApartmentView(authViewModel: account, viewModel: vm),
            ),
            GoRoute(
              path: '/apartments/:id',
              builder: (_, _) => const Scaffold(body: Text('Published detail')),
            ),
          ],
        );
        addTearDown(() async {
          router.dispose();
          vm.dispose();
          account.dispose();
          await auth.users.close();
        });
        final boundary = GlobalKey();
        await tester.pumpWidget(
          RepaintBoundary(
            key: boundary,
            child: MaterialApp.router(routerConfig: router),
          ),
        );
        await tester.pumpAndSettle();
        if (Platform.environment['US24_CAPTURE'] == '1') {
          await tester.runAsync(() async {
            final render =
                boundary.currentContext!.findRenderObject()
                    as RenderRepaintBoundary;
            final image = await render.toImage();
            final bytes = await image.toByteData(
              format: ui.ImageByteFormat.png,
            );
            Directory('tmp/us24').createSync(recursive: true);
            File('tmp/us24/form-${size.width.toInt()}.png')
                .writeAsBytesSync(bytes!.buffer.asUint8List());
            image.dispose();
          });
        }
        await tester.ensureVisible(find.text('Publish apartment'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Publish apartment'));
        await tester.pumpAndSettle();
        expect(service.calls, 0);
        expect(vm.actionError, contains('Title'));
        final values = [
          'Family apartment',
          '24 Test Street',
          'Sion',
          '1850',
          '3.5',
          '82',
          'A sunny apartment.',
        ];
        for (var i = 0; i < values.length; i++) {
          await tester.enterText(find.byType(TextField).at(i), values[i]);
        }
        await vm.pickImages();
        await tester.pumpAndSettle();
        service.fails = true;
        await tester.ensureVisible(find.text('Publish apartment'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Publish apartment'));
        await tester.pumpAndSettle();
        expect(vm.actionError, contains('try again'));
        expect(vm.photos, hasLength(3));
        service.fails = false;
        await tester.ensureVisible(find.text('Publish apartment'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Publish apartment'));
        await tester.pumpAndSettle();
        expect(find.text('Published detail'), findsOneWidget);
        expect(service.usedIds, ['draft-1', 'draft-1']);
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets(
    'US-24 gallery navigates all pictures and supports legacy/failed photos',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ApartmentGallery(
              imageUrls: [photo(1), photo(80), photo(160)],
            ),
          ),
        ),
      );
      expect(find.text('1 / 3'), findsOneWidget);
      await tester.tap(find.byTooltip('Next picture'));
      await tester.pumpAndSettle();
      expect(find.text('2 / 3'), findsOneWidget);
      await tester.tap(find.byTooltip('Next picture'));
      await tester.pumpAndSettle();
      expect(find.text('3 / 3'), findsOneWidget);
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: ApartmentGallery(imageUrls: [''])),
        ),
      );
      expect(find.byTooltip('Next picture'), findsNothing);
      expect(find.byIcon(Icons.home_outlined), findsOneWidget);
      await tester.pumpWidget(
        const MaterialApp(
          home: ApartmentImage(imageUrl: 'data:image/jpeg;base64,%%%'),
        ),
      );
      expect(find.byIcon(Icons.home_outlined), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
