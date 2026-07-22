import '../core/cache/local_cache.dart';
import '../models/calamity_report.dart';
import '../models/cooperative.dart';
import '../models/crop_declaration.dart';
import '../models/enums.dart';
import '../models/expense.dart';
import '../models/farm.dart';
import '../models/barangay_assignment.dart';
import '../models/demand_signal.dart';
import '../models/logbook_entry.dart';
import '../models/planned_activity.dart';
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

  static const String seededFlag = 'demo_seeded_v3';
  static const String coopId = 'coop-tubungan-vegetable';
  static const String juanId = 'demo-farmer-juan';
  static const String mariaId = 'demo-coop-maria';
  static const String juanFarmId = 'farm-juan-igpaho';
  static const String technicianId = 'demo-tech-rosario';

  static Future<void> ensureSeeded(LocalCache cache) async {
    if (cache.has(seededFlag)) return;

    final now = DateTime.now();
    DateTime daysFromNow(int d) => DateTime(now.year, now.month, now.day + d);
    DateTime daysAgo(int d) => DateTime(now.year, now.month, now.day - d);

    // ── Cooperative ────────────────────────────────────────────────────────
    final cooperative = Cooperative(
      id: coopId,
      name: 'Tubungan Vegetable Growers Association',
      barangay: 'Zone I (Poblacion)',
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
        firstName: 'Juan',
        middleName: 'Ramos',
        lastName: 'Dela Cruz',
        username: 'juan.delacruz',
        role: UserRole.farmer,
        email: 'farmer@agrisense.ph',
        contactNumber: '0918 222 1010',
        barangay: 'Igpaho',
        cooperativeId: coopId,
        rsbsaNumber: '06-30-79-001-000123',
        verification: AccountVerification.verified,
        verifiedAt: daysAgo(118),
        createdAt: daysAgo(120),
      ),
      Profile(
        id: technicianId,
        firstName: 'Rosario',
        lastName: 'Beltran',
        username: 'rosario.beltran',
        role: UserRole.technician,
        email: 'technician@agrisense.ph',
        contactNumber: '0929 471 8830',
        barangay: 'Igpaho',
        verification: AccountVerification.verified,
        verifiedAt: daysAgo(199),
        createdAt: daysAgo(200),
      ),
      Profile(
        id: mariaId,
        firstName: 'Maria',
        lastName: 'Santos',
        username: 'maria.santos',
        role: UserRole.cooperative,
        email: 'coop@agrisense.ph',
        contactNumber: '0917 555 0142',
        barangay: 'Zone I (Poblacion)',
        cooperativeId: coopId,
        verification: AccountVerification.verified,
        verifiedAt: daysAgo(399),
        createdAt: daysAgo(400),
      ),
    ];

    // ── Farm (Juan) ────────────────────────────────────────────────────────
    final farms = <Farm>[
      Farm(
        id: juanFarmId,
        ownerId: juanId,
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
      status: DeclarationStatus.active,
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
      status: DeclarationStatus.active,
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
        barangay: i.isEven ? 'Badiang' : 'Igpaho',
        status: DeclarationStatus.active,
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
        status: DeclarationStatus.active,
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
        status: DeclarationStatus.active,
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
        description: 'Basal fertilizer application',
        amount: 6400,
        incurredOn: daysAgo(38),
        // Captured while logging the activity, not as a separate entry.
        logbookEntryId: 'log-3',
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
        description: 'Foliar spray vs. fruit fly',
        amount: 2100,
        incurredOn: daysAgo(12),
        logbookEntryId: 'log-4',
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
        expenseId: 'exp-2',
        plannedActivityId: 'plan-2',
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
        expenseId: 'exp-5',
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

    // ── Crop calendar ──────────────────────────────────────────────────────
    // A slice of a real protocol against Juan's ampalaya planting: some work
    // already done, one item overdue, the rest ahead — so the calendar, the
    // "needs doing now" card, and the cost-capture flow all have something to
    // show on first launch.
    final planned = <PlannedActivity>[
      PlannedActivity(
        id: 'plan-1',
        declarationId: 'decl-juan-ampalaya',
        farmerId: juanId,
        activity: ActivityType.landPrep,
        title: 'Plow and first harrow',
        scheduledOn: daysAgo(54),
        daysAfterPlanting: -14,
        status: PlannedActivityStatus.done,
        completedOn: daysAgo(54),
        createdAt: daysAgo(60),
      ),
      PlannedActivity(
        id: 'plan-2',
        declarationId: 'decl-juan-ampalaya',
        farmerId: juanId,
        activity: ActivityType.fertilizing,
        title: 'Apply basal fertilizer',
        scheduledOn: daysAgo(40),
        daysAfterPlanting: 0,
        suggestedInput: 'Complete 14-14-14 + compost',
        suggestedQtyPerHa: 4,
        unit: 'bags',
        status: PlannedActivityStatus.done,
        logbookEntryId: 'log-3',
        completedOn: daysAgo(40),
        createdAt: daysAgo(60),
      ),
      PlannedActivity(
        id: 'plan-3',
        declarationId: 'decl-juan-ampalaya',
        farmerId: juanId,
        activity: ActivityType.pestControl,
        title: 'Scheduled protective spray',
        scheduledOn: daysAgo(3),
        daysAfterPlanting: 37,
        suggestedInput: 'Cypermethrin / fungicide rotation',
        suggestedQtyPerHa: 0.5,
        unit: 'L',
        createdAt: daysAgo(60),
      ),
      PlannedActivity(
        id: 'plan-4',
        declarationId: 'decl-juan-ampalaya',
        farmerId: juanId,
        activity: ActivityType.irrigation,
        title: 'Irrigate',
        scheduledOn: daysFromNow(1),
        daysAfterPlanting: 41,
        createdAt: daysAgo(60),
      ),
      PlannedActivity(
        id: 'plan-5',
        declarationId: 'decl-juan-ampalaya',
        farmerId: juanId,
        activity: ActivityType.fertilizing,
        title: 'Flowering-stage fertilizer',
        scheduledOn: daysFromNow(4),
        daysAfterPlanting: 44,
        suggestedInput: 'Urea 46-0-0',
        suggestedQtyPerHa: 1,
        unit: 'bags',
        createdAt: daysAgo(60),
      ),
      PlannedActivity(
        id: 'plan-6',
        declarationId: 'decl-juan-ampalaya',
        farmerId: juanId,
        activity: ActivityType.harvesting,
        title: 'Harvest — pick 1',
        scheduledOn: daysFromNow(12),
        daysAfterPlanting: 70,
        createdAt: daysAgo(60),
      ),
    ];

    // ── Cooperative demand ─────────────────────────────────────────────────
    // Declared demand takes precedence over the municipal baseline, so the
    // saturation panels show cooperative-sourced figures out of the box.
    final demandSignals = <DemandSignal>[
      DemandSignal(
        id: 'demand-1',
        cooperativeId: coopId,
        cropId: 'ampalaya',
        periodStart: daysAgo(15),
        periodEnd: daysFromNow(45),
        demandTons: 34,
        buyerType: BuyerType.bagsakan,
        pricePerKg: 40,
        buyerName: 'Tubungan Bagsakan',
        notes: 'Weekly consolidation every Tuesday and Friday.',
        createdAt: daysAgo(15),
      ),
      DemandSignal(
        id: 'demand-2',
        cooperativeId: coopId,
        cropId: 'eggplant',
        periodStart: daysAgo(10),
        periodEnd: daysFromNow(50),
        demandTons: 52,
        buyerType: BuyerType.institutional,
        pricePerKg: 44,
        buyerName: 'DepEd school feeding programme',
        createdAt: daysAgo(10),
      ),
      DemandSignal(
        id: 'demand-3',
        cooperativeId: coopId,
        cropId: 'pechay',
        periodStart: daysAgo(5),
        periodEnd: daysFromNow(25),
        demandTons: 18,
        buyerType: BuyerType.retail,
        pricePerKg: 35,
        buyerName: 'Iloilo City retailers',
        createdAt: daysAgo(5),
      ),
    ];

    // ── Barangay technician coverage ───────────────────────────────────────
    final assignments = <BarangayAssignment>[
      BarangayAssignment(
        id: 'assign-igpaho',
        barangay: 'Igpaho',
        technicianId: technicianId,
        role: UserRole.technician,
        technicianName: 'Rosario Beltran',
        contactNumber: '0929 471 8830',
        assignedAt: daysAgo(200),
      ),
      BarangayAssignment(
        id: 'assign-male',
        barangay: 'Male',
        technicianId: technicianId,
        role: UserRole.technician,
        technicianName: 'Rosario Beltran',
        contactNumber: '0929 471 8830',
        assignedAt: daysAgo(200),
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
    await cache.writeList(
        'planned_activities', planned.map((e) => e.toMap()).toList());
    await cache.writeList(
        'demand_signals', demandSignals.map((e) => e.toMap()).toList());
    await cache.writeList(
        'barangay_assignments', assignments.map((e) => e.toMap()).toList());

    await cache.writeObject(seededFlag, {'at': now.toIso8601String()});
  }
}
