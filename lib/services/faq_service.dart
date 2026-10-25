import '../models/faq_entry.dart';
import '../router/app_routes.dart';

/// US 14: the questions and answers of the property FAQ.
/// The content is fixed and shipped with the app, so it also works offline.
/// It could later be moved to Firestore without changing the ViewModel.
class FaqService {
  List<FaqEntry> getEntries() => entries;

  static const entries = <FaqEntry>[
    // Searching
    FaqEntry(
      id: 'find-apartment',
      category: FaqCategory.searching,
      question: 'How do I find an apartment that suits me?',
      answer:
          'Open the Home tab to see every listing. Use Filters to choose the '
          'city, rent or buy, the price range, rooms, surface and amenities. '
          'If nothing matches, the list tells you so and you can reset the '
          'filters.',
      linkLabel: 'Browse apartments',
      linkLocation: AppRoutes.apartments,
    ),
    FaqEntry(
      id: 'availability',
      category: FaqCategory.searching,
      question: 'What do Available, Reserved and Unavailable mean?',
      answer:
          'Available: you can schedule a visit and apply. Reserved: the '
          'apartment is promised to someone else, so it cannot be visited or '
          'applied for. Unavailable: it is not on the market at the moment. '
          'You can still contact the advertiser in every case.',
    ),
    FaqEntry(
      id: 'new-offers',
      category: FaqCategory.searching,
      question: 'Can I be told when a new apartment matches my search?',
      answer:
          'Yes. Apply your filters, then save the search. When a new offer '
          'matches it, you receive a notification. You can save up to 5 '
          'searches and turn their alerts off at any time.',
      linkLabel: 'My saved searches',
      linkLocation: AppRoutes.savedSearches,
    ),
    FaqEntry(
      id: 'compare',
      category: FaqCategory.searching,
      question: 'How can I compare two apartments?',
      answer:
          'On an apartment, select Add to comparison, then do the same on a '
          'second one of the same type (rent with rent, sale with sale). The '
          'comparison shows both prices side by side and the price per m².',
      linkLabel: 'Open comparison',
      linkLocation: AppRoutes.compare,
    ),
    // Visits
    FaqEntry(
      id: 'visit',
      category: FaqCategory.visits,
      question: 'How do I schedule a visit?',
      answer:
          'Open an available apartment and select Schedule a visit. Visits '
          'take place Monday to Friday, 09:00–11:00 or 14:00–16:00, from '
          'tomorrow up to 30 days ahead. The owner is notified of your visit.',
      linkLabel: 'My visits',
      linkLocation: AppRoutes.visits,
    ),
    FaqEntry(
      id: 'question-owner',
      category: FaqCategory.visits,
      question: 'I have a question about a specific apartment. Who answers?',
      answer:
          'Open the apartment and select Contact advertiser. Your message is '
          "sent to the apartment's owner or manager, who sees it in their "
          'inbox.',
      linkLabel: 'Browse apartments',
      linkLocation: AppRoutes.apartments,
    ),
    // Applying
    FaqEntry(
      id: 'apply',
      category: FaqCategory.applying,
      question: 'How do I apply for an apartment?',
      answer:
          'Open an available apartment and select Apply. Fill in your name, '
          'phone, move-in date and number of occupants. You can attach up to '
          '5 documents. You can have one open application per apartment.',
      linkLabel: 'My applications',
      linkLocation: AppRoutes.applications,
    ),
    FaqEntry(
      id: 'documents',
      category: FaqCategory.applying,
      question: 'Which documents should I prepare?',
      answer:
          'Owners usually ask for an ID, a debt collection extract and your '
          'last pay slips. Upload them once in My documents (.jpg or .pdf, at '
          'most 700 KiB each) and attach them to any application.',
      linkLabel: 'My documents',
      linkLocation: AppRoutes.documents,
    ),
    FaqEntry(
      id: 'edit-application',
      category: FaqCategory.applying,
      question: 'Can I change or withdraw my application?',
      answer:
          'Yes, during 5 days after submitting, as long as the owner has not '
          'decided. Open the application in the Applications tab and select '
          'Edit or Withdraw.',
      linkLabel: 'My applications',
      linkLocation: AppRoutes.applications,
    ),
    FaqEntry(
      id: 'application-status',
      category: FaqCategory.applying,
      question: 'How will I know if my application is accepted?',
      answer:
          'The status in the Applications tab is updated, and you receive an '
          'Application status notification when the owner reviews it.',
      linkLabel: 'Notifications',
      linkLocation: AppRoutes.notifications,
    ),
    // Rent & costs
    FaqEntry(
      id: 'price',
      category: FaqCategory.costs,
      question: 'What does the price of a listing include?',
      answer:
          'For a rental, the price is the rent per month in CHF. Ask the '
          'advertiser whether charges such as heating and water are included '
          'or paid on top.',
    ),
    FaqEntry(
      id: 'deposit',
      category: FaqCategory.costs,
      question: 'How much is the rental deposit?',
      answer:
          'In Switzerland the security deposit for an apartment is at most '
          "three months' rent. It is paid into a blocked bank account in the "
          "tenant's name. Check the amount in your lease.",
    ),
    FaqEntry(
      id: 'mortgage',
      category: FaqCategory.costs,
      question: 'How much would I pay each month to buy an apartment?',
      answer:
          'Use the mortgage calculator with the price, your down payment, the '
          'interest rate and the duration. Apartments for sale have a '
          'Mortgage calculator button that fills in their price.',
      linkLabel: 'Mortgage calculator',
      linkLocation: AppRoutes.mortgage,
    ),
    // Owners & managers
    FaqEntry(
      id: 'publish',
      category: FaqCategory.owners,
      question: 'How do I publish my apartment?',
      answer:
          'Homeowners can add an apartment with its details and at least '
          'three pictures. It then appears in the list for everyone.',
      linkLabel: 'Add an apartment',
      linkLocation: AppRoutes.createApartment,
    ),
    FaqEntry(
      id: 'inbox',
      category: FaqCategory.owners,
      question: 'Where do I see applications and messages for my apartment?',
      answer:
          'Owners and assigned property managers find them in Profile → '
          'Inbox, where they can review applications and read messages.',
      linkLabel: 'Inbox',
      linkLocation: AppRoutes.inbox,
    ),
    FaqEntry(
      id: 'maintenance',
      category: FaqCategory.owners,
      question: 'How do I book a repair or maintenance service?',
      answer:
          'Property managers can book plumbing, electrical, heating or '
          'appliance services for the apartments they are assigned to, on '
          'weekdays between 08:00 and 17:00, and reschedule or cancel them '
          'before they start.',
      linkLabel: 'Repair & maintenance',
      linkLocation: AppRoutes.maintenance,
    ),
    // Account
    FaqEntry(
      id: 'roles',
      category: FaqCategory.account,
      question: 'Why can I not see some features?',
      answer:
          'Features depend on your roles: renters and buyers apply and visit, '
          'homeowners publish apartments, owners and managers handle '
          'applications, and property managers book maintenance. You choose '
          'your roles in your profile.',
      linkLabel: 'Profile',
      linkLocation: AppRoutes.profile,
    ),
    FaqEntry(
      id: 'notifications',
      category: FaqCategory.account,
      question: 'How do I choose which notifications I receive?',
      answer:
          'Open Profile → Notifications and switch each kind of notification '
          'on or off. Unread notifications put a red dot on the Profile tab.',
      linkLabel: 'Notifications',
      linkLocation: AppRoutes.notifications,
    ),
  ];
}
