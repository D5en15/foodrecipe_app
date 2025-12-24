import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../app_router.dart';
import '../l10n/app_localizations.dart';
import '../models/recipe_model.dart';
import '../services/recipe_service.dart';
import '../theme/app_colors.dart';
import '../database/app_database.dart';
import '../services/category_service.dart';
import '../services/alarm_feedback_service.dart';
import '../services/notification_service.dart';

class RecipeDetailScreen extends StatefulWidget {
  const RecipeDetailScreen({super.key});

  @override
  State<RecipeDetailScreen> createState() => _RecipeDetailScreenState();
}

class _RecipeDetailScreenState extends State<RecipeDetailScreen> {
  RecipeModel? recipe;
  String? recipeId;
  String? categoryId;
  String? _categoryNamesLang;
  Map<String, String> _categoryNames = {};
  bool _isFavorite = false;
  bool _isCompleted = false;
  Set<int> _checkedIngredients = {};
  Set<int> _checkedSteps = {};
  bool _showInlineTimer = false;
  Duration _inlineInitial = Duration.zero;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final args = ModalRoute.of(context)?.settings.arguments as Map?;

    final incomingId = args?['id'] as String?;
    final incomingCategory = args?['category'] as String?;
    final isSameRecipe = recipeId == incomingId && recipe != null;

    recipeId = incomingId;
    categoryId = incomingCategory;

    if (!isSameRecipe) {
      loadRecipe();
    }
  }

  Future<void> _loadStatuses(String recipeId) async {
    final fav = await AppDatabase.instance.isFavorite(recipeId);
    final comp = await AppDatabase.instance.isCompleted(recipeId);
    if (!mounted) return;
    setState(() {
      _isFavorite = fav;
      _isCompleted = comp;
      if (comp && recipe != null) {
        _checkedIngredients = Set<int>.from(
          List.generate(recipe!.ingredients.length, (i) => i),
        );
        _checkedSteps = Set<int>.from(
          List.generate(recipe!.steps.length, (i) => i),
        );
      }
    });
  }

  Future<void> _loadCategoryNames(String lang) async {
    if (_categoryNamesLang == lang && _categoryNames.isNotEmpty) return;
    try {
      _categoryNames = await CategoryService.loadCategoryNameMap(lang);
      _categoryNamesLang = lang;
    } catch (_) {
      _categoryNames = {};
      _categoryNamesLang = null;
    }
  }

  void _resetChecklistForRecipe() {
    _checkedIngredients = {};
    _checkedSteps = {};
    _showInlineTimer = false;
    _inlineInitial = Duration.zero;
  }

  void _toggleIngredient(int index) {
    setState(() {
      if (_checkedIngredients.contains(index)) {
        _checkedIngredients.remove(index);
      } else {
        _checkedIngredients.add(index);
      }
    });
  }

  Future<void> _toggleFavoriteState() async {
    if (recipe == null) return;
    final newState = await AppDatabase.instance.toggleFavorite(recipe!.id);
    await AppDatabase.instance.debugCheckDatabase();
    if (!mounted) return;
    setState(() {
      _isFavorite = newState;
    });
  }

  void _toggleStep(int index) {
    setState(() {
      if (_checkedSteps.contains(index)) {
        _checkedSteps.remove(index);
      } else {
        _checkedSteps.add(index);
      }
    });
  }

  bool get _isChecklistComplete {
    if (_isCompleted) return true;
    final ingTotal = recipe?.ingredients.length ?? 0;
    final stepTotal = recipe?.steps.length ?? 0;
    final ingDone = ingTotal == 0 || _checkedIngredients.length == ingTotal;
    final stepDone = stepTotal == 0 || _checkedSteps.length == stepTotal;
    return ingDone && stepDone;
  }

  bool get _isIngredientsComplete {
    if (_isCompleted) return true;
    final ingTotal = recipe?.ingredients.length ?? 0;
    if (ingTotal == 0) return true;
    return _checkedIngredients.length == ingTotal;
  }

  bool get _isStepsComplete {
    if (_isCompleted) return true;
    final stepTotal = recipe?.steps.length ?? 0;
    if (stepTotal == 0) return true;
    return _checkedSteps.length == stepTotal;
  }

  void _toggleAllSteps() {
    if (recipe == null) return;
    final total = recipe!.steps.length;
    if (total == 0) return;
    setState(() {
      if (_checkedSteps.length == total) {
        _checkedSteps = {};
      } else {
        _checkedSteps = Set<int>.from(
          List.generate(total, (i) => i),
        );
      }
    });
  }

  void _toggleAllIngredients() {
    if (recipe == null) return;
    final total = recipe!.ingredients.length;
    if (total == 0) return;
    setState(() {
      if (_checkedIngredients.length == total) {
        _checkedIngredients = {};
      } else {
        _checkedIngredients = Set<int>.from(
          List.generate(total, (i) => i),
        );
      }
    });
  }

  Future<void> loadRecipe() async {
    if (recipeId == null) return;

    final lang = AppLocalizations.of(context)?.locale.languageCode ?? 'th';
    await _loadCategoryNames(lang);

    RecipeModel? found;
    String? resolvedCategoryId = categoryId;

    try {
      if (categoryId != null) {
        final list = await RecipeService.loadRecipes(
          languageCode: lang,
          categoryId: categoryId!,
        );
        for (final r in list) {
          if (r.id == recipeId) {
            found = r;
            break;
          }
        }
      }

      if (found == null) {
        final all = await RecipeService.loadAllRecipesWithCategories(lang);
        for (final entry in all) {
          final r = entry['recipe'] as RecipeModel;
          if (r.id == recipeId) {
            found = r;
            resolvedCategoryId = entry['categoryId'] as String?;
            break;
          }
        }
      }
    } catch (e) {
      print('ERROR loading recipe: $e');
    }

    if (!mounted) return;

    setState(() {
      recipe = found;
      categoryId = resolvedCategoryId;
      _resetChecklistForRecipe();
    });
    if (found != null) {
      _loadStatuses(found.id);
    }
  }

  bool get _hasChecklistProgress {
    return _checkedIngredients.isNotEmpty || _checkedSteps.isNotEmpty;
  }

  Future<bool> _confirmExitIfNeeded() async {
    if (!_hasChecklistProgress || !mounted) return true;
    final strings = AppLocalizations.of(context)!;
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          strings.t('detail_exit_title'),
          style: GoogleFonts.poppins(
            color: AppColors.primary,
            fontWeight: FontWeight.w600,
          ),
        ),
        content: Text(
          strings.t('detail_exit_message'),
          style: GoogleFonts.poppins(
            color: AppColors.primary.withOpacity(0.8),
            fontSize: 14,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(
              strings.t('detail_exit_stay'),
              style: GoogleFonts.poppins(
                color: AppColors.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(
              strings.t('detail_exit_leave'),
              style: GoogleFonts.poppins(
                color: AppColors.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
    final shouldLeave = result ?? false;
    if (shouldLeave) {
      unawaited(AlarmFeedbackService.instance.stopAlert());
    }
    return shouldLeave;
  }

  void _handleTimerFinished() {
    if (!mounted) return;
    setState(() {
      _showInlineTimer = false;
      _inlineInitial = Duration.zero;
    });
  }

  Future<void> _openInlineTimer() async {
    if (!_isIngredientsComplete) return;
    final selected = await showModalBottomSheet<Duration>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return _TimerPickerSheet(
          onStart: (duration) => Navigator.of(sheetContext).pop(duration),
        );
      },
    );
    if (!mounted) return;
    if (selected != null && selected.inSeconds > 0) {
      setState(() {
        _inlineInitial = selected;
        _showInlineTimer = true;
      });
    }
    unawaited(AlarmFeedbackService.instance.stopAlert());
  }

  @override
  Widget build(BuildContext context) {
    if (recipe == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final strings = AppLocalizations.of(context)!;
    final locale = strings.locale;
    return WillPopScope(
      onWillPop: _confirmExitIfNeeded,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: Column(
          children: [
            Expanded(
              child: CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: _HeaderImage(
                      imagePath: recipe!.image,
                      isFavorite: _isFavorite,
                      onBack: () async {
                        final ok = await _confirmExitIfNeeded();
                        if (ok && context.mounted) {
                          Navigator.pop(context);
                        }
                      },
                      onFavoriteToggle: _toggleFavoriteState,
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                        const SizedBox(height: 12),
                        Text(
                          recipe!.displayTitle(locale),
                          style: GoogleFonts.poppins(
                            fontSize: 26,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(height: 24),
                        _TimeChipsRow(
                          strings: strings,
                          recipe: recipe!,
                        ),
                        const SizedBox(height: 20),
                        Center(
                          child: Column(
                            children: [
                              Text(
                                strings.t('detail_timer_label'),
                                style: GoogleFonts.poppins(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.primary,
                                ),
                              ),
                              const SizedBox(height: 10),
                              if (_showInlineTimer)
                                _InlineActiveTimer(
                                  initialDuration: _inlineInitial,
                                  onFinished: _handleTimerFinished,
                                  onClose: _handleTimerFinished,
                                )
                              else
                                OutlinedButton.icon(
                                  style: OutlinedButton.styleFrom(
                                    side: const BorderSide(
                                        color: AppColors.primary),
                                    backgroundColor:
                                        AppColors.accent.withOpacity(0.6),
                                    foregroundColor: AppColors.primary,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 12,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                  ),
                                  onPressed: _isIngredientsComplete
                                      ? _openInlineTimer
                                      : null,
                                  icon: const Icon(Icons.timer),
                                  label: Text(
                                    strings.t('timer'),
                                    style: GoogleFonts.poppins(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              if (!_isIngredientsComplete && !_showInlineTimer)
                                Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: Text(
                                    strings.t('detail_timer_locked'),
                                    style: GoogleFonts.poppins(
                                      fontSize: 12,
                                      color: AppColors.primary.withOpacity(0.7),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 28),
                        Row(
                          children: [
                            Text(
                              strings.t('recipe_ingredients'),
                              style: GoogleFonts.poppins(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: AppColors.primary,
                              ),
                            ),
                            const Spacer(),
                            InkWell(
                              onTap: recipe!.ingredients.isEmpty
                                  ? null
                                  : _toggleAllIngredients,
                              borderRadius: BorderRadius.circular(16),
                              child: Row(
                                children: [
                                  Text(
                                    strings.t('recipe_select_all_ingredients'),
                                    style: GoogleFonts.poppins(
                                      fontSize: 13,
                                      color: AppColors.primary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  Checkbox(
                                    value: _isIngredientsComplete,
                                    onChanged: recipe!.ingredients.isEmpty
                                        ? null
                                        : (_) => _toggleAllIngredients(),
                                    activeColor: AppColors.primary,
                                    checkColor: AppColors.background,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ...recipe!.ingredients
                            .asMap()
                            .entries
                            .map(
                              (e) => _ChecklistTile(
                                index: e.key,
                                text: e.value,
                                checked: _checkedIngredients.contains(e.key),
                                onToggle: () => _toggleIngredient(e.key),
                              ),
                            )
                            .toList(),
                        const SizedBox(height: 24),
                        Row(
                          children: [
                            Text(
                              strings.t('recipe_steps'),
                              style: GoogleFonts.poppins(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: AppColors.primary,
                              ),
                            ),
                            const Spacer(),
                            InkWell(
                              onTap: recipe!.steps.isEmpty
                                  ? null
                                  : _toggleAllSteps,
                              borderRadius: BorderRadius.circular(16),
                              child: Row(
                                children: [
                                  Text(
                                    strings.t('recipe_select_all_steps'),
                                    style: GoogleFonts.poppins(
                                      fontSize: 13,
                                      color: AppColors.primary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  Checkbox(
                                    value: _isStepsComplete,
                                    onChanged: recipe!.steps.isEmpty
                                        ? null
                                        : (_) => _toggleAllSteps(),
                                    activeColor: AppColors.primary,
                                    checkColor: AppColors.background,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ...recipe!.steps
                            .asMap()
                            .entries
                            .map(
                              (e) => _ChecklistTile(
                                index: e.key,
                                text: e.value,
                                checked: _checkedSteps.contains(e.key),
                                onToggle: () => _toggleStep(e.key),
                              ),
                            )
                            .toList(),
                        ],
                      ),
                    ),
                  )
                ],
              ),
            ),
            _BottomDoneButton(
              label: strings.t('detail_button_finish'),
              recipe: recipe!,
              categoryId: categoryId,
              enabled: _isChecklistComplete,
              onCompleted: () async {
                await AppDatabase.instance.debugCheckDatabase();
                setState(() {
                  _isCompleted = true;
                });
                _loadStatuses(recipe!.id);
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _HeaderImage extends StatelessWidget {
  final String imagePath;
  final VoidCallback onBack;
  final VoidCallback onFavoriteToggle;
  final bool isFavorite;

  const _HeaderImage({
    required this.imagePath,
    required this.onBack,
    required this.onFavoriteToggle,
    required this.isFavorite,
  });

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    return SizedBox(
      height: 280,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(16),
              bottomRight: Radius.circular(16),
            ),
            child: Image.asset(
              imagePath,
              fit: BoxFit.cover,
            ),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppColors.overlayDark,
                    Colors.transparent,
                    AppColors.overlayMedium,
                  ],
                  stops: const [0, 0.55, 1],
                ),
              ),
            ),
          ),
          Positioned(
            top: topPadding + 12,
            left: 16,
            child: _TopActionButton(
              icon: Icons.arrow_back,
              onTap: onBack,
            ),
          ),
          Positioned(
            top: topPadding + 12,
            right: 16,
            child: _TopActionButton(
              icon: isFavorite ? Icons.favorite : Icons.favorite_border,
              onTap: onFavoriteToggle,
              backgroundColor:
                  isFavorite ? AppColors.primary : AppColors.overlayDark,
            ),
          ),
        ],
      ),
    );
  }
}

class _TopActionButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final Color? backgroundColor;
  final Color? iconColor;

  const _TopActionButton({
    required this.icon,
    required this.onTap,
    this.backgroundColor,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: backgroundColor ?? AppColors.overlayDark,
          shape: BoxShape.circle,
          border: Border.all(
            color: AppColors.background.withOpacity(0.4),
          ),
        ),
        child: Icon(
          icon,
          color: iconColor ?? AppColors.background,
        ),
      ),
    );
  }
}

class _ChecklistTile extends StatelessWidget {
  final int index;
  final String text;
  final bool checked;
  final VoidCallback onToggle;

  const _ChecklistTile({
    required this.index,
    required this.text,
    required this.checked,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final textStyle = GoogleFonts.poppins(
      fontSize: 14,
      color: AppColors.primary.withOpacity(checked ? 0.6 : 1),
      decoration: checked ? TextDecoration.lineThrough : TextDecoration.none,
      decorationThickness: 2,
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 10, left: 8, right: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: GestureDetector(
              onTap: onToggle,
              child: Text(
                "${index + 1}. $text",
                style: textStyle,
              ),
            ),
          ),
          Checkbox(
            value: checked,
            onChanged: (_) => onToggle(),
            activeColor: AppColors.primary,
            checkColor: AppColors.background,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(6),
            ),
          ),
        ],
      ),
    );
  }
}

class _TimeChipsRow extends StatelessWidget {
  final AppLocalizations strings;
  final RecipeModel recipe;

  const _TimeChipsRow({
    required this.strings,
    required this.recipe,
  });

  @override
  Widget build(BuildContext context) {
    final items = [
      (strings.t('detail_time_total'), recipe.totalTime ?? '-'),
      (strings.t('detail_time_prep'), recipe.prepTime ?? '-'),
      (strings.t('detail_time_cooking'), recipe.cookTime ?? '-'),
    ];

    return Row(
      children: items.asMap().entries.map((entry) {
        final i = entry.key;
        final item = entry.value;

        return Expanded(
          child: Container(
            margin: EdgeInsets.only(right: i == items.length - 1 ? 0 : 12),
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 5),
            decoration: BoxDecoration(
              color: AppColors.accent,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                Text(
                  item.$1,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  item.$2,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _BottomDoneButton extends StatelessWidget {
  final String label;
  final RecipeModel recipe;
  final String? categoryId;
  final bool enabled;
  final Future<void> Function() onCompleted;
  const _BottomDoneButton({
    required this.label,
    required this.recipe,
    required this.categoryId,
    required this.enabled,
    required this.onCompleted,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.background,
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 40),
      child: SizedBox(
        width: double.infinity,
        height: 56,
        child: FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.primary,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(30),
            ),
          ),
          onPressed: enabled
              ? () async {
                  await AppDatabase.instance.markCompleted(recipe.id);
                  await onCompleted();
                  if (context.mounted) {
                    Navigator.pushNamed(context, Routes.cookingComplete);
                  }
                }
              : null,
          child: Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppColors.background,
            ),
          ),
        ),
      ),
    );
  }
}

class _TimerPickerSheet extends StatefulWidget {
  final ValueChanged<Duration> onStart;

  const _TimerPickerSheet({
    required this.onStart,
  });

  @override
  State<_TimerPickerSheet> createState() => _TimerPickerSheetState();
}

class _TimerPickerSheetState extends State<_TimerPickerSheet> {
  final FixedExtentScrollController _hourController =
      FixedExtentScrollController();
  final FixedExtentScrollController _minuteController =
      FixedExtentScrollController();
  final FixedExtentScrollController _secondController =
      FixedExtentScrollController();

  @override
  void dispose() {
    _hourController.dispose();
    _minuteController.dispose();
    _secondController.dispose();
    super.dispose();
  }

  Duration _selectedDuration() {
    final hours = _hourController.selectedItem;
    final minutes = _minuteController.selectedItem;
    final seconds = _secondController.selectedItem;
    return Duration(hours: hours, minutes: minutes, seconds: seconds);
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context)!;
    return SafeArea(
      top: false,
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.2),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            _TimerWheelTimeDisplay(
              hourController: _hourController,
              minuteController: _minuteController,
              secondController: _secondController,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColors.primary),
                      foregroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(
                      strings.t('timer_close'),
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: AppColors.background,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () {
                      final duration = _selectedDuration();
                      if (duration.inSeconds == 0) return;
                      widget.onStart(duration);
                    },
                    child: Text(
                      strings.t('start'),
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _InlineActiveTimer extends StatefulWidget {
  final Duration initialDuration;
  final VoidCallback onFinished;
  final VoidCallback onClose;

  const _InlineActiveTimer({
    required this.initialDuration,
    required this.onFinished,
    required this.onClose,
  });

  @override
  State<_InlineActiveTimer> createState() => _InlineActiveTimerState();
}

class _InlineActiveTimerState extends State<_InlineActiveTimer> {
  Duration _remaining = const Duration();
  Timer? _timer;
  bool _isRunning = false;
  bool _isPaused = false;

  @override
  void initState() {
    super.initState();
    _remaining = widget.initialDuration;
    if (_remaining.inSeconds > 0) {
      _startCountdown();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    unawaited(AlarmFeedbackService.instance.stopAlert());
    super.dispose();
  }

  void _startCountdown() {
    if (_remaining.inSeconds <= 0) return;
    _timer?.cancel();
    setState(() {
      _isRunning = true;
      _isPaused = false;
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remaining.inSeconds <= 1) {
        _finishCountdown();
      } else {
        setState(() {
          _remaining -= const Duration(seconds: 1);
        });
      }
    });
  }

  void _pause() {
    _timer?.cancel();
    unawaited(AlarmFeedbackService.instance.stopAlert());
    setState(() {
      _isRunning = false;
      _isPaused = true;
    });
  }

  void _resume() {
    if (_remaining.inSeconds <= 0) {
      setState(() {
        _isRunning = false;
        _isPaused = false;
      });
      return;
    }
    _timer?.cancel();
    setState(() {
      _isRunning = true;
      _isPaused = false;
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remaining.inSeconds <= 1) {
        _finishCountdown();
      } else {
        setState(() {
          _remaining -= const Duration(seconds: 1);
        });
      }
    });
  }

  void _reset() {
    _timer?.cancel();
    unawaited(AlarmFeedbackService.instance.stopAlert());
    setState(() {
      _remaining = widget.initialDuration;
      _isRunning = false;
      _isPaused = false;
    });
  }

  String _format(Duration d) {
    final hours = d.inHours.remainder(100).toString().padLeft(2, '0');
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return "$hours:$minutes:$seconds";
  }

  Future<void> _finishCountdown() async {
    if (!mounted) return;
    _timer?.cancel();
    setState(() {
      _remaining = Duration.zero;
      _isRunning = false;
      _isPaused = false;
    });
    await _notifyCountdownComplete();
    if (mounted) {
      widget.onFinished();
    }
  }

  Future<void> _notifyCountdownComplete() async {
    if (!mounted) return;
    final strings = AppLocalizations.of(context)!;
    unawaited(AlarmFeedbackService.instance.startAlertLoop());
    unawaited(
      NotificationService.instance.showTimerDoneNotification(
        title: strings.t('timer_done_title'),
        body: strings.t('timer_done_body'),
      ),
    );

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          strings.t('timer_done_title'),
          style: GoogleFonts.poppins(
            color: AppColors.primary,
            fontWeight: FontWeight.w600,
          ),
        ),
        content: Text(
          strings.t('timer_done_body'),
          style: GoogleFonts.poppins(
            color: AppColors.primary.withOpacity(0.8),
            fontSize: 14,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              unawaited(AlarmFeedbackService.instance.stopAlert());
              Navigator.of(dialogContext).pop();
            },
            child: Text(
              strings.t('common_ok'),
              style: GoogleFonts.poppins(
                color: AppColors.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
    unawaited(AlarmFeedbackService.instance.stopAlert());
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context)!;
    return Column(
      children: [
        Text(
          _format(_remaining),
          style: GoogleFonts.poppins(
            color: AppColors.primary,
            fontSize: 36,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: _isRunning ? _pause : _startCountdown,
                child: Text(
                  _isRunning ? strings.t('pause') : strings.t('start'),
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.primary),
                  foregroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: _reset,
                child: Text(
                  strings.t('reset'),
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.primary),
                foregroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () {
                _timer?.cancel();
                unawaited(AlarmFeedbackService.instance.stopAlert());
                widget.onClose();
              },
              child: Text(
                strings.t('timer_close'),
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _TimerWheelPicker extends StatelessWidget {
  final FixedExtentScrollController controller;
  final int max;

  const _TimerWheelPicker({
    required this.controller,
    required this.max,
  });

  @override
  Widget build(BuildContext context) {
    return ListWheelScrollView.useDelegate(
      controller: controller,
      itemExtent: 48,
      physics: const FixedExtentScrollPhysics(),
      childDelegate: ListWheelChildBuilderDelegate(
        builder: (context, index) {
          if (index < 0 || index >= max) return null;
          return Center(
            child: Text(
              index.toString().padLeft(2, '0'),
              style: GoogleFonts.poppins(
                fontSize: 32,
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
              ),
            ),
          );
        },
      ),
    );
  }
}

class _TimerWheelTimeDisplay extends StatelessWidget {
  final FixedExtentScrollController hourController;
  final FixedExtentScrollController minuteController;
  final FixedExtentScrollController secondController;

  const _TimerWheelTimeDisplay({
    required this.hourController,
    required this.minuteController,
    required this.secondController,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 140,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Expanded(child: _TimerWheelPicker(controller: hourController, max: 24)),
          Text(
            ":",
            style: GoogleFonts.poppins(
              color: AppColors.primary,
              fontSize: 28,
              fontWeight: FontWeight.w700,
            ),
          ),
          Expanded(child: _TimerWheelPicker(controller: minuteController, max: 60)),
          Text(
            ":",
            style: GoogleFonts.poppins(
              color: AppColors.primary,
              fontSize: 28,
              fontWeight: FontWeight.w700,
            ),
          ),
          Expanded(child: _TimerWheelPicker(controller: secondController, max: 60)),
        ],
      ),
    );
  }
}
