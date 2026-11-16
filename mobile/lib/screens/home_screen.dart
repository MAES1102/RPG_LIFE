import 'package:flutter/material.dart';
import '../models/rpg_models.dart';
import '../services/api_service.dart';
import '../services/health_sync_service.dart';
import '../widgets/raid_focus_timer_sheet.dart';
import '../widgets/rive_hero_stage.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ApiService _api = ApiService();
  final HealthSyncService _healthService = HealthSyncService();
  final TextEditingController _aiPromptController = TextEditingController();

  int _heroLevel = 1;
  int _heroXp = 150;
  int _heroXpNext = 500;
  int _gold = 120;
  int _streakDays = 3;
  bool _streakFreezeActive = false;
  String _activePreset = 'student';
  EquippedState _equipped = const EquippedState();

  QuestDifficulty? _selectedDifficultyOverride;
  bool _isCreatingQuest = false;

  late List<SphereModel> _spheres;
  late List<QuestModel> _quests;
  late List<ShopItemModel> _shopCatalog;

  @override
  void initState() {
    super.initState();
    _initLocalDefaults();
    _syncFromBackend();
  }

  void _initLocalDefaults() {
    _spheres = [
      SphereModel(id: 'sp-brain', code: 'brain', name: 'Мозг', icon: '🧠', level: 1, currentXp: 120),
      SphereModel(id: 'sp-body', code: 'body', name: 'Тело', icon: '💪', level: 1, currentXp: 180),
      SphereModel(id: 'sp-energy', code: 'energy', name: 'Энергия', icon: '⚡', level: 1, currentXp: 80),
      SphereModel(id: 'sp-soul', code: 'soul', name: 'Душа', icon: '🎨', level: 1, currentXp: 50),
    ];

    _quests = [
      QuestModel(
        id: 'q-1',
        sphereId: 'sp-brain',
        sphereCode: 'brain',
        sphereName: 'Мозг',
        sphereIcon: '🧠',
        title: 'Нейро-рейд: Глубокий фокус над учебой',
        description: 'Встроенный игровой рейд-таймер фокуса (25 мин)',
        difficulty: QuestDifficulty.normal,
        trackingType: TrackingType.timer,
        targetValue: 25,
        targetUnit: 'мин',
        estimatedXp: 173,
        estimatedGold: 34,
      ),
      QuestModel(
        id: 'q-2',
        sphereId: 'sp-body',
        sphereCode: 'body',
        sphereName: 'Тело',
        sphereIcon: '💪',
        title: 'Кибер-атлетика: Бег 3 км',
        description: 'Авто-синхронизация с Apple Health / Google Fit',
        difficulty: QuestDifficulty.normal,
        trackingType: TrackingType.healthApi,
        targetValue: 3.0,
        targetUnit: 'км',
        frequency: '3x_week',
        healthMetricKey: 'distance_km',
        estimatedXp: 173,
        estimatedGold: 34,
      ),
      QuestModel(
        id: 'q-3',
        sphereId: 'sp-energy',
        sphereCode: 'energy',
        sphereName: 'Энергия',
        sphereIcon: '⚡',
        title: 'Энерго-контур: Утренняя разминка и вода',
        description: 'Быстрая отметка выполнения в 1 тап',
        difficulty: QuestDifficulty.easy,
        trackingType: TrackingType.manual,
        targetValue: 1,
        targetUnit: 'раз',
        estimatedXp: 115,
        estimatedGold: 23,
      ),
    ];

    _shopCatalog = const [
      ShopItemModel(
        id: 's1',
        code: 'skin_neon_samurai',
        name: 'Экзокостюм «Неоновый Самурай»',
        description: 'Кибер-броня с голографической катаной.',
        category: 'skin',
        priceGold: 120,
        riveAssetKey: 'skin_neon_samurai',
        icon: '🥷',
      ),
      ShopItemModel(
        id: 's2',
        code: 'decor_holo_monolith',
        name: 'Голографический Терминал v2.0',
        description: 'Тактическая станция для твоей базы.',
        category: 'base_decor',
        priceGold: 150,
        riveAssetKey: 'decor_holo_monolith',
        icon: '🖥️',
      ),
      ShopItemModel(
        id: 's3',
        code: 'pet_cyber_fox',
        name: 'Кибер-Лис «Кицунэ-09»',
        description: 'Дрон-компаньон, реагирующий на твои левел-апы.',
        category: 'pet',
        priceGold: 200,
        riveAssetKey: 'pet_cyber_fox',
        icon: '🦊',
      ),
      ShopItemModel(
        id: 's4',
        code: 'booster_streak_freeze',
        name: 'Щит заморозки стрика',
        description: 'Сохраняет бонус стрика (+5%/день) при пропуске 1 дня.',
        category: 'booster',
        priceGold: 60,
        riveAssetKey: 'booster_streak_freeze',
        icon: '🛡️',
      ),
    ];
  }

  Future<void> _syncFromBackend() async {
    final data = await _api.fetchProfile();
    if (data != null && mounted) {
      _applyProfileJson(data);
    }
  }

  void _applyProfileJson(Map<String, dynamic> data) {
    setState(() {
      _heroLevel = data['level'] as int? ?? _heroLevel;
      _heroXp = data['current_xp'] as int? ?? _heroXp;
      _heroXpNext = data['xp_next'] as int? ?? _heroXpNext;
      _gold = data['gold'] as int? ?? _gold;
      _streakDays = data['streak_days'] as int? ?? _streakDays;
      _streakFreezeActive = data['streak_freeze_active'] as bool? ?? _streakFreezeActive;
      _activePreset = data['hero_preset'] as String? ?? _activePreset;
      if (data['equipped_state'] is Map<String, dynamic>) {
        _equipped = EquippedState.fromJson(data['equipped_state'] as Map<String, dynamic>);
      }
      if (data['spheres'] is List) {
        _spheres = (data['spheres'] as List)
            .map((e) => SphereModel.fromJson(e as Map<String, dynamic>))
            .toList();
      }
      if (data['active_quests'] is List) {
        _quests = (data['active_quests'] as List)
            .map((e) => QuestModel.fromJson(e as Map<String, dynamic>))
            .toList();
      }
    });
  }

  Future<void> _createQuestFromSingleLine() async {
    final prompt = _aiPromptController.text.trim();
    if (prompt.isEmpty) return;

    setState(() => _isCreatingQuest = true);

    final created = await _api.createQuestFromOneLineAi(
      prompt: prompt,
      overrideDifficulty: _selectedDifficultyOverride,
    );

    if (created != null) {
      setState(() {
        _quests.insert(0, created);
        _aiPromptController.clear();
        _isCreatingQuest = false;
      });
      return;
    }

    // Локальный ИИ-фоллбэк, если бэкенд не запущен
    final lower = prompt.toLowerCase();
    final isSport = lower.contains('бег') || lower.contains('км') || lower.contains('шаг') || lower.contains('зал');
    final isStudy = lower.contains('уч') || lower.contains('книг') || lower.contains('код') || lower.contains('мин');
    final sphere = isSport ? _spheres[1] : (isStudy ? _spheres[0] : _spheres[2]);
    final diff = _selectedDifficultyOverride ?? QuestDifficulty.normal;
    final tracking = isSport
        ? TrackingType.healthApi
        : (isStudy ? TrackingType.timer : TrackingType.manual);
    final xp = ProgressionMath.computeXpAction(
      difficulty: diff,
      streakDays: _streakDays,
      actualValue: 1,
      targetValue: 1,
    );

    setState(() {
      _quests.insert(
        0,
        QuestModel(
          id: 'local-${DateTime.now().millisecondsSinceEpoch}',
          sphereId: sphere.id,
          sphereCode: sphere.code,
          sphereName: sphere.name,
          sphereIcon: sphere.icon,
          title: '${sphere.name}: $prompt',
          description: tracking == TrackingType.healthApi
              ? 'Авто-синхронизация с Apple Health / Google Fit'
              : (tracking == TrackingType.timer
                  ? 'Встроенный игровой рейд-таймер фокуса'
                  : 'Отметка в 1 тап'),
          difficulty: diff,
          trackingType: tracking,
          targetValue: isSport ? 3.0 : (isStudy ? 25.0 : 1.0),
          targetUnit: isSport ? 'км' : (isStudy ? 'мин' : 'раз'),
          healthMetricKey: isSport ? 'distance_km' : null,
          estimatedXp: xp,
          estimatedGold: ProgressionMath.computeGold(xp),
        ),
      );
      _aiPromptController.clear();
      _isCreatingQuest = false;
    });
  }

  Future<void> _handleCompleteQuest(QuestModel quest, {double? customActualValue}) async {
    final actual = customActualValue ?? quest.targetValue;

    final remoteResp = await _api.completeQuest(
      questId: quest.id,
      actualValue: actual,
    );

    if (remoteResp != null && remoteResp['profile'] is Map<String, dynamic>) {
      final xpEarned = remoteResp['xp_earned'] as int? ?? quest.estimatedXp;
      final goldEarned = remoteResp['gold_earned'] as int? ?? quest.estimatedGold;
      _applyProfileJson(remoteResp['profile'] as Map<String, dynamic>);
      _showRewardBanner(quest.title, xpEarned, goldEarned);
      return;
    }

    // Локальный расчет по формуле: XP_action = 100 * D * M_streak * M_overachieve
    final xpEarned = ProgressionMath.computeXpAction(
      difficulty: quest.difficulty,
      streakDays: _streakDays,
      actualValue: actual,
      targetValue: quest.targetValue,
    );
    final goldEarned = ProgressionMath.computeGold(xpEarned);

    setState(() {
      _gold += goldEarned;
      _heroXp += xpEarned;
      while (_heroXp >= _heroXpNext) {
        _heroXp -= _heroXpNext;
        _heroLevel += 1;
        _heroXpNext = ProgressionMath.xpNextForLevel(_heroLevel);
      }

      for (final sp in _spheres) {
        if (sp.id == quest.sphereId || sp.code == quest.sphereCode) {
          sp.currentXp += xpEarned;
          while (sp.currentXp >= sp.xpNext) {
            sp.currentXp -= sp.xpNext;
            sp.level += 1;
            sp.xpNext = ProgressionMath.xpNextForLevel(sp.level);
          }
        }
      }
    });

    _showRewardBanner(quest.title, xpEarned, goldEarned);
  }

  void _showRewardBanner(String title, int xp, int gold) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFF1F2238),
        behavior: SnackBarBehavior.floating,
        content: Text(
          '⚡ Квест выполнен! +$xp XP  |  +$gold 🪙 золота ($title)',
          style: const TextStyle(color: Color(0xFF00F5D4), fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  void _openEditSphereDialog(SphereModel sphere) {
    final nameCtrl = TextEditingController(text: sphere.name);
    final iconCtrl = TextEditingController(text: sphere.icon);

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF181A2E),
        title: const Text('Кастомизация сферы', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: iconCtrl,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'Иконка (эмодзи)',
                labelStyle: TextStyle(color: Colors.white70),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: nameCtrl,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'Название сферы',
                labelStyle: TextStyle(color: Colors.white70),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                sphere.name = nameCtrl.text.trim().isEmpty ? sphere.name : nameCtrl.text.trim();
                sphere.icon = iconCtrl.text.trim().isEmpty ? sphere.icon : iconCtrl.text.trim();
              });
              Navigator.of(ctx).pop();
            },
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );
  }

  void _openShopSheet() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF121324),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    '🏪 Кибер-Магазин (Только внутриигровой лут)',
                    style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    '🪙 $_gold',
                    style: const TextStyle(
                      color: Color(0xFFFEE440),
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              const Text(
                'Отдых — базовое право, его не нужно покупать. Трать золото на скины, апгрейд базы, питомцев и бустеры.',
                style: TextStyle(color: Colors.white60, fontSize: 12),
              ),
              const SizedBox(height: 14),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: _shopCatalog.length,
                  separatorBuilder: (_, __) => const Divider(color: Colors.white12),
                  itemBuilder: (_, i) {
                    final item = _shopCatalog[i];
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Text(item.icon, style: const TextStyle(fontSize: 30)),
                      title: Text(item.name, style: const TextStyle(color: Colors.white)),
                      subtitle: Text(
                        item.description,
                        style: const TextStyle(color: Colors.white60, fontSize: 12),
                      ),
                      trailing: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFEE440),
                          foregroundColor: Colors.black,
                        ),
                        onPressed: () {
                          if (_gold < item.priceGold) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Недостаточно золота! Выполни пару квестов.')),
                            );
                            return;
                          }
                          setState(() {
                            _gold -= item.priceGold;
                            if (item.category == 'skin') {
                              _equipped = EquippedState(
                                skin: item.riveAssetKey,
                                baseDecor: _equipped.baseDecor,
                                pet: _equipped.pet,
                              );
                            } else if (item.category == 'base_decor') {
                              _equipped = EquippedState(
                                skin: _equipped.skin,
                                baseDecor: item.riveAssetKey,
                                pet: _equipped.pet,
                              );
                            } else if (item.category == 'pet') {
                              _equipped = EquippedState(
                                skin: _equipped.skin,
                                baseDecor: _equipped.baseDecor,
                                pet: item.riveAssetKey,
                              );
                            } else if (item.category == 'booster') {
                              _streakFreezeActive = true;
                            }
                          });
                          Navigator.of(ctx).pop();
                        },
                        child: Text('🪙 ${item.priceGold}'),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final xpProgress = _heroXpNext > 0 ? (_heroXp / _heroXpNext).clamp(0.0, 1.0) : 0.0;
    final streakBonusPercent = (_streakDays * 5).clamp(0, 50);

    return Scaffold(
      backgroundColor: const Color(0xFF0B0C17),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0B0C17),
        elevation: 0,
        title: const Text(
          'RPG_LIFE // CYBER-TERMINAL',
          style: TextStyle(
            color: Color(0xFF00F5D4),
            fontWeight: FontWeight.bold,
            fontSize: 16,
            letterSpacing: 1.2,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Center(
              child: Text(
                '🔥 $_streakDays дн. (+$streakBonusPercent% XP)',
                style: const TextStyle(color: Color(0xFFFF6B6B), fontWeight: FontWeight.w600),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Text(
                '🪙 $_gold',
                style: const TextStyle(
                  color: Color(0xFFFEE440),
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Прогресс-бар уровня героя (Первый левел-ап за 500 XP)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Уровень героя: $_heroLevel',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
                Text(
                  '$_heroXp / $_heroXpNext XP',
                  style: const TextStyle(color: Color(0xFF00F5D4), fontSize: 13),
                ),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: xpProgress,
                minHeight: 10,
                backgroundColor: Colors.white12,
                valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF00F5D4)),
              ),
            ),
            const SizedBox(height: 16),

            // 2D / Rive-сцена с персонажем, базой и питомцем
            RiveHeroStage(
              heroLevel: _heroLevel,
              equipped: _equipped,
              streakFreezeActive: _streakFreezeActive,
              onOpenShop: _openShopSheet,
            ),
            const SizedBox(height: 16),

            // Готовые стартовые пресеты в 1 тап (чтобы избежать пустого экрана)
            Row(
              children: [
                const Text(
                  'Пресет:',
                  style: TextStyle(color: Colors.white70, fontSize: 13),
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text('🎓 Студент'),
                  selected: _activePreset == 'student',
                  onSelected: (_) async {
                    setState(() => _activePreset = 'student');
                    final data = await _api.applyPreset('student');
                    if (data != null) _applyProfileJson(data);
                  },
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text('🏃 Спортсмен'),
                  selected: _activePreset == 'athlete',
                  onSelected: (_) async {
                    setState(() => _activePreset = 'athlete');
                    final data = await _api.applyPreset('athlete');
                    if (data != null) _applyProfileJson(data);
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),

            // 4 кастомные сферы развития (нажми, чтобы переименовать или сменить иконку)
            const Text(
              '4 СФЕРЫ РАЗВИТИЯ (тап для кастомизации)',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.1,
              ),
            ),
            const SizedBox(height: 8),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _spheres.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 2.3,
              ),
              itemBuilder: (_, index) {
                final sp = _spheres[index];
                return InkWell(
                  onTap: () => _openEditSphereDialog(sp),
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF16192B),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '${sp.icon} ${sp.name}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              'Ур. ${sp.level}',
                              style: const TextStyle(color: Color(0xFF9B5DE5), fontSize: 12),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        LinearProgressIndicator(
                          value: sp.progress,
                          minHeight: 6,
                          backgroundColor: Colors.white10,
                          valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF9B5DE5)),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 20),

            // Создание квеста через ИИ за 10 секунд (ввод в одну строку + 3 кнопки сложности)
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF15182B),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF9B5DE5).withOpacity(0.5)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '✨ ИИ-ГЕНЕРАТОР КВЕСТА (ВВОД В ОДНУ СТРОКУ — 10 СЕКУНД)',
                    style: TextStyle(
                      color: Color(0xFF00F5D4),
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _aiPromptController,
                          style: const TextStyle(color: Colors.white),
                          onSubmitted: (_) => _createQuestFromSingleLine(),
                          decoration: InputDecoration(
                            hintText: 'Например: Бегать по 3 км три раза в неделю',
                            hintStyle: const TextStyle(color: Colors.white38, fontSize: 13),
                            filled: true,
                            fillColor: Colors.black26,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF00F5D4),
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        ),
                        onPressed: _isCreatingQuest ? null : _createQuestFromSingleLine,
                        child: _isCreatingQuest
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Text('Создать', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  // 3 простые кнопки сложности (Легко / Нормально / Хардкор)
                  Wrap(
                    spacing: 8,
                    children: [
                      ChoiceChip(
                        label: const Text('Авто (ИИ)'),
                        selected: _selectedDifficultyOverride == null,
                        onSelected: (_) => setState(() => _selectedDifficultyOverride = null),
                      ),
                      ...QuestDifficulty.values.map(
                        (d) => ChoiceChip(
                          label: Text(QuestModel.difficultyLabelRu(d)),
                          selected: _selectedDifficultyOverride == d,
                          onSelected: (_) => setState(() => _selectedDifficultyOverride = d),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Список активных квестов
            const Text(
              'АКТИВНЫЕ КВЕСТЫ И РЕЙДЫ',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.1,
              ),
            ),
            const SizedBox(height: 8),
            ..._quests.map((quest) => _buildQuestCard(quest)),
          ],
        ),
      ),
    );
  }

  Widget _buildQuestCard(QuestModel quest) {
    IconData actionIcon;
    String actionLabel;

    switch (quest.trackingType) {
      case TrackingType.healthApi:
        actionIcon = Icons.favorite;
        actionLabel = 'Синхр. Health';
        break;
      case TrackingType.timer:
        actionIcon = Icons.timer;
        actionLabel = 'В рейд фокуса';
        break;
      case TrackingType.manual:
        actionIcon = Icons.check_circle_outline;
        actionLabel = 'Выполнить';
        break;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF16192B),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        children: [
          Text(quest.sphereIcon, style: const TextStyle(fontSize: 28)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  quest.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  quest.description,
                  style: const TextStyle(color: Colors.white60, fontSize: 12),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.white10,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        QuestModel.difficultyLabelRu(quest.difficulty),
                        style: const TextStyle(color: Colors.white70, fontSize: 11),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '+${quest.estimatedXp} XP  •  +${quest.estimatedGold} 🪙',
                      style: const TextStyle(
                        color: Color(0xFF00F5D4),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF9B5DE5),
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              if (quest.trackingType == TrackingType.timer) {
                showModalBottomSheet<void>(
                  context: context,
                  backgroundColor: Colors.transparent,
                  builder: (_) => RaidFocusTimerSheet(
                    quest: quest,
                    onRaidCompleted: (actualMinutes) {
                      _handleCompleteQuest(quest, customActualValue: actualMinutes);
                    },
                  ),
                );
              } else if (quest.trackingType == TrackingType.healthApi) {
                final syncedValue = await _healthService.fetchTodayMetric(
                  quest.healthMetricKey,
                  fallbackTarget: quest.targetValue,
                );
                await _handleCompleteQuest(quest, customActualValue: syncedValue);
              } else {
                await _handleCompleteQuest(quest);
              }
            },
            icon: Icon(actionIcon, size: 16),
            label: Text(actionLabel, style: const TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }
}
