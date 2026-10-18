import '../models/apartment.dart';
import '../models/app_user.dart';
import '../utils/listing_validation.dart';
import 'listing_exception.dart';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import 'package:cloud_firestore/cloud_firestore.dart';

/// Reads apartment listings from the Firestore apartments collection.
class ApartmentService {
  ApartmentService({
    FirebaseFirestore? firestore,
    AppUser? Function()? currentUser,
  }) : _db = firestore ?? FirebaseFirestore.instance,
       _currentUser = currentUser ?? _firebaseUser;
  final FirebaseFirestore _db;
  final AppUser? Function() _currentUser;
  CollectionReference<Map<String, dynamic>> get _collection =>
      _db.collection('apartments');
  static AppUser? _firebaseUser() {
    final user = FirebaseAuth.instance.currentUser;
    return user == null
        ? null
        : AppUser(
            id: user.uid,
            email: user.email ?? '',
            emailVerified: user.emailVerified,
          );
  }

  String newApartmentId() => _collection.doc().id;

  /// US-24: images and listing commit together; no orphan uploads on failure.
  Future<void> createApartment(String id, Apartment listing) async {
    final user = _currentUser();
    if (user == null || !user.emailVerified) {
      throw const ListingException(
        'Verify your email before publishing an apartment.',
      );
    }
    final error = validateListing(listing);
    if (error != null) throw ListingException(error);
    final data = {
      ...listing.toMap(),
      'imageUrl': listing.imageUrls.first,
      'ownerId': user.id,
      'managerIds': <String>[],
      'availability': 'available',
    };
    try {
      await _db.runTransaction((transaction) async {
        final profile = await transaction.get(
          _db.collection('users').doc(user.id),
        );
        final roles = profile.data()?['roles'];
        if (roles is! List || !roles.contains('homeowner')) {
          throw const ListingException(
            'Only homeowners can publish apartments.',
          );
        }
        final ref = _collection.doc(id);
        final existing = await transaction.get(ref);
        if (existing.exists) {
          final old = existing.data()!;
          final same = data.entries.every(
            (entry) => entry.value is List
                ? old[entry.key] is List &&
                      listEquals(old[entry.key] as List, entry.value as List)
                : old[entry.key] == entry.value,
          );
          if (same) return;
          throw const ListingException(
            'This publication ID is already in use. Reopen the form.',
          );
        }
        transaction.set(ref, {
          ...data,
          'createdAt': FieldValue.serverTimestamp(),
        });
      });
    } on FirebaseException catch (e) {
      throw ListingException(
        e.code == 'permission-denied'
            ? 'Publication was denied. Check your homeowner role and verified email.'
            : 'Could not publish the apartment. Your form is kept; try again.',
      );
    }
  }

  Future<List<Apartment>> getApartments() async {
    final snapshot = await _collection.get();
    return snapshot.docs
        .map((doc) => Apartment.fromMap(doc.id, doc.data()))
        .toList();
  }

  /// Returns null when no apartment has this id.
  Future<Apartment?> getApartment(String id) async {
    final doc = await _collection.doc(id).get();
    if (!doc.exists) {
      return null;
    }
    return Apartment.fromMap(doc.id, doc.data()!);
  }

  /// One apartment, updated live. Emits null when it no longer exists.
  Stream<Apartment?> watchApartment(String id) {
    return _collection.doc(id).snapshots().map((doc) {
      if (!doc.exists) return null;
      return Apartment.fromMap(doc.id, doc.data()!);
    });
  }

  /// US 23: live list, so new offers are noticed while the app is open.
  Stream<List<Apartment>> watchApartments() {
    return _collection.snapshots().map(
      (snapshot) => snapshot.docs
          .map((doc) => Apartment.fromMap(doc.id, doc.data()))
          .toList(),
    );
  }

  /// Whether a different application's immediate reservation won this listing.
  Future<bool> isReservedByAnotherApplication(
    String apartmentId,
    String applicationId,
  ) async {
    final data = (await _collection.doc(apartmentId).get()).data();
    if (data == null) return false;

    final holder = data['reservationApplicationId'];
    return data['availability'] == ApartmentAvailability.reserved.name &&
        holder is String &&
        holder != applicationId;
  }
}
