import '../core/cache/local_cache.dart';
import '../models/calamity_report.dart';
import '../models/cooperative.dart';
import '../models/crop_declaration.dart';
import '../models/enums.dart';
import '../models/expense.dart';
import '../models/farm.dart';
import '../models/logbook_entry.dart';
import '../models/profile.dart';

/// Seeds the local cache with realistic sample data the first time the app runs
/// in demo mode. The dataset is deliberately shaped so the analytical engines
/// produce meaningful output:
///
/// * Ampalaya is over-declared by many farmers in one harvest window → triggers
///   a **High** Market Saturation Index and a **congested harvest peak**.
/// * Juan Dela Cruz (the primary demo farmer) has declarations, expenses, a
///   logbook history, and a calamity report so every farmer screen is populated.
///
/// Demo sign-in accounts (any password works in demo mode):
///   • farmer@agrisense.ph   — Juan Dela Cruz (Farmer)
///   • coop@agrisense.ph     — Maria Santos (Cooperative)
class DemoSeed {
  const DemoSeed._();

  static const String seededFlag = 'demo_seeded_v1';
  static const String coopId = 'coop-tubungan-vegetable';
  static const String juanId = 'demo-farmer-juan';
  static const String mariaId = 'demo-coop-maria';
  static const String juanFarmId = 'farm-juan-igpaho';

  static Future<void> ensureSeeded(LocalCache cache) async {
    if (cache.has(seededFlag)) return;

    final now = DateTime.now();
    DateTime daysFromNow(int d) => DateTime(now.year, now.month, now.day + d);
    DateTime daysAgo(int d) => DateTime(now.year, now.month, now.day - d);

    // ── Cooperative ────────────────────────────────────────────────────────
    final cooperative = Cooperative(
      id: coopId,
      name: 'Tubungan Vegetable Growers Association',
      barangay: 'Poblacion',
      contactPerson: 'Maria Santos',
      contactNumber: '0917 555 0142',
      memberCount: 48,
      buyBackCapacityTons: 120,
      createdAt: daysAgo(400),
    );

    // ── Profiles ───────────────────────────────────────────────────────────
    final profiles = <Profile>[
      Profile(
        id: juanId,
        fullName: 'Juan Dela Cruz',
        role: UserRole.farmer,
        email: 'farmer@agrisense.ph',
        contactNumber: '0918 222 1010',
        barangay: 'Igpaho',
        cooperativeId: coopId,
        createdAt: daysAgo(120),
      ),
      Profile(
        id: mariaId,
        fullName: 'Maria Santos',
        role: UserRole.cooperative,
        email: 'coop@agrisense.ph',
        contactNumber: '0917 555 0142',
        barangay: 'Poblacion',
        cooperativeId: coopId,
        createdAt: daysAgo(400),
      ),
    ];

    // ── Farm (Juan) ────────────────────────────────────────────────────────
    final farms = <Farm>[
      Farm(
        id: juanFarmId,
        ownerId: juanId,
        name: 'Dela Cruz Family Farm',
        barangay: 'Igpaho',
        totalAreaHa: 1.5,
        latitude: 10.7896,
        longitude: 122.3186,
        soilType: 'Clay loam',
        previousCrops: const ['ampalaya', 'eggplant'],
        previousActivities: 'Rice paddy (wet season), vegetables (dry season).',
        createdAt: daysAgo(120),
      ),
    ];

    // ── Crop declarations ──────────────────────────────────────────────────
    // Many synthetic farmers all declaring Ampalaya harvesting the same week to
    // force a high-saturation, congested-harvest scenario.
    final declarations = <CropDeclaration>[];

    // Juan's own declarations.
    declarations.add(CropDeclaration(
      id: 'decl-juan-ampalaya',
      farmerId: juanId,
      farmId: juanFarmId,
      cropId: 'ampalaya',
      variety: 'Galaxy',
      areaHa: 1.0,
      plantingDate: daysAgo(40),
      expectedHarvestDate: daysFromNow(20),
      expectedYieldKg: 12000,
      barangay: 'Igpaho',
      status: DeclarationStatus.approved,
      projectedPricePerKg: 45,
      notes: 'First declaration of the dry season.',
      createdAt: daysAgo(45),
    ));
    declarations.add(CropDeclaration(
      id: 'decl-juan-eggplant',
      farmerId: juanId,
      farmId: juanFarmId,
      cropId: 'eggplant',
      variety: 'Casino',
      areaHa: 0.5,
      plantingDate: daysAgo(10),
      expectedHarvestDate: daysFromNow(70),
      expectedYieldKg: 9000,
      barangay: 'Igpaho',
      status: DeclarationStatus.pending,
      projectedPricePerKg: 40,
      createdAt: daysAgo(10),
    ));

    // Synthetic congestion: 6 other farmers, all Ampalaya, same harvest week.
    final congestionWeek = daysFromNow(20);
    for (var i = 1; i <= 6; i++) {
      declarations.add(CropDeclaration(
        id: 'decl-syn-amp-$i',
        farmerId: 'syn-farmer-$i',
        farmId: 'syn-farm-$i',
        cropId: 'ampalaya',
        variety: 'Galaxy',
        areaHa: 0.8 + (i * 0.1),
        plantingDate: daysAgo(38 - i),
        expectedHarvestDate: congestionWeek.add(Duration(days: i % 3)),
        expectedYieldKg: 9000 + (i * 800),
        barangay: i.isEven ? 'Bading' : 'Igpaho',
        status: DeclarationStatus.approved,
        projectedPricePerKg: 44,
        createdAt: daysAgo(50 - i),
      ));
    }

    // A few balanced declarations of other crops for contrast.
    declarations.addAll([
      CropDeclaration(
        id: 'decl-syn-okra-1',
        farmerId: 'syn-farmer-7',
        farmId: 'syn-farm-7',
        cropId: 'okra',
        variety: 'Smooth Green',
        areaHa: 0.6,
        plantingDate: daysAgo(20),
        expectedHarvestDate: daysFromNow(35),
        expectedYieldKg: 5400,
        barangay: 'Bondoc',
        status: DeclarationStatus.approved,
        createdAt: daysAgo(22),
      ),
      CropDeclaration(
        id: 'decl-syn-string-1',
        farmerId: 'syn-farmer-8',
        farmId: 'syn-farm-8',
        cropId: 'string_beans',
        variety: 'Sandigan',
        areaHa: 0.7,
        plantingDate: daysAgo(15),
        expectedHarvestDate: daysFromNow(45),
        expectedYieldKg: 5600,
        barangay: 'Molina',
        status: DeclarationStatus.approved,
        createdAt: daysAgo(18),
      ),
    ]);

    // ── Expenses (Juan's Ampalaya project) ────────────────────────────────
    final expenses = <Expense>[
      Expense(
        id: 'exp-1',
        declarationId: 'decl-juan-ampalaya',
        farmerId: juanId,
        category: ExpenseCategory.seed,
        description: 'Galaxy F1 ampalaya seeds (250g)',
        amount: 3200,
        incurredOn: daysAgo(44),
      ),
      Expense(
        id: 'exp-2',
        declarationId: 'decl-juan-ampalaya',
        farmerId: juanId,
        category: ExpenseCategory.fertilizer,
        description: 'Complete 14-14-14 (4 bags)',
        amount: 6400,
        incurredOn: daysAgo(40),
      ),
      Expense(
        id: 'exp-3',
        declarationId: 'decl-juan-ampalaya',
        farmerId: juanId,
        category: ExpenseCategory.labor,
        description: 'Land prep & trellising (8 man-days)',
        amount: 4000,
        incurredOn: daysAgo(38),
      ),
      Expense(
        id: 'exp-4',
        declarationId: 'decl-juan-ampalaya',
        farmerId: juanId,
        category: ExpenseCategory.irrigation,
        description: 'Pump fuel & water fees',
        amount: 1800,
        incurredOn: daysAgo(20),
      ),
      Expense(
        id: 'exp-5',
        declarationId: 'decl-juan-ampalaya',
        farmerId: juanId,
        category: ExpenseCategory.pesticide,
        description: 'Foliar & pest management',
        amount: 2100,
        incurredOn: daysAgo(12),
      ),
    ];

    // ── Logbook (Juan) ────────────────────────────────────────────────────
    final logs = <LogbookEntry>[
      LogbookEntry(
        id: 'log-1',
        farmerId: juanId,
        declarationId: 'decl-juan-ampalaya',
        activity: ActivityType.landPrep,
        title: 'Plowing and bed preparation',
        performedOn: daysAgo(44),
        details: 'Two passes, raised beds at 1m spacing.',
      ),
      LogbookEntry(
        id: 'log-2',
        farmerId: juanId,
        declarationId: 'decl-juan-ampalaya',
        activity: ActivityType.planting,
        title: 'Direct seeding of ampalaya',
        performedOn: daysAgo(40),
        inputUsed: 'Galaxy F1',
        quantity: 250,
        unit: 'g',
      ),
      LogbookEntry(
        id: 'log-3',
        farmerId: juanId,
        declarationId: 'decl-juan-ampalaya',
        activity: ActivityType.fertilizing,
        title: 'Basal fertilizer application',
        performedOn: daysAgo(38),
        inputUsed: 'Complete 14-14-14',
        quantity: 200,
        unit: 'kg',
        cost: 6400,
      ),
      LogbookEntry(
        id: 'log-4',
        farmerId: juanId,
        declarationId: 'decl-juan-ampalaya',
        activity: ActivityType.pestControl,
        title: 'Foliar spray vs. fruit fly',
        performedOn: daysAgo(12),
        inputUsed: 'Cypermethrin',
        quantity: 1,
        unit: 'L',
        cost: 2100,
      ),
    ];

    // ── Calamity report (Juan) ────────────────────────────────────────────
    final calamities = <CalamityReport>[
      CalamityReport(
        id: 'cal-1',
        farmerId: juanId,
        barangay: 'Igpaho',
        type: CalamityType.typhoon,
        occurredOn: daysAgo(8),
        affectedAreaHa: 0.4,
        lossPercent: 35,
        status: VerificationStatus.underReview,
        declarationId: 'decl-juan-ampalaya',
        cropId: 'ampalaya',
        estimatedLossValue: 18000,
        description:
            'Strong winds from TS "Crising" lodged trellises on the lower plot.',
      ),
    ];

    // ── Market channels (cooperative buy-back) ────────────────────────────
    final channels = <MarketChannel>[
      MarketChannel(
        id: 'chan-1',
        cooperativeId: coopId,
        name: 'Association Surplus Buy-back',
        type: 'buy_back',
        capacityTons: 60,
        cropIds: const ['ampalaya', 'eggplant', 'okra'],
        pricePerKg: 38,
        contact: '0917 555 0142',
        notes: 'Guaranteed floor price for member surplus.',
      ),
      MarketChannel(
        id: 'chan-2',
        cooperativeId: coopId,
        name: 'Iloilo City Terminal Market',
        type: 'neighboring_market',
        capacityTons: 200,
        cropIds: const ['ampalaya', 'tomato', 'squash'],
        pricePerKg: 42,
        contact: 'La Paz Public Market consolidators',
      ),
      MarketChannel(
        id: 'chan-3',
        cooperativeId: coopId,
        name: 'AgriProcess Pickling Plant',
        type: 'processor',
        capacityTons: 80,
        cropIds: const ['ampalaya', 'squash'],
        pricePerKg: 30,
        contact: 'procurement@agriprocess.ph',
        notes: 'Absorbs Grade-B produce for pickling.',
      ),
    ];

    // ── Persist ────────────────────────────────────────────────────────────
    await cache.writeList('profiles', profiles.map((e) => e.toMap()).toList());
    await cache.writeList('cooperatives', [cooperative.toMap()]);
    await cache.writeList('farms', farms.map((e) => e.toMap()).toList());
    await cache.writeList(
        'crop_declarations', declarations.map((e) => e.toMap()).toList());
    await cache.writeList('expenses', expenses.map((e) => e.toMap()).toList());
    await cache.writeList(
        'production_reports', const <Map<String, dynamic>>[]);
    await cache.writeList(
        'logbook_entries', logs.map((e) => e.toMap()).toList());
    await cache.writeList(
        'calamity_reports', calamities.map((e) => e.toMap()).toList());
    await cache.writeList(
        'market_channels', channels.map((e) => e.toMap()).toList());

    await cache.writeObject(seededFlag, {'at': now.toIso8601String()});
  }
}
