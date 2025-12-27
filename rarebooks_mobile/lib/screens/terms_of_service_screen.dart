import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../config/theme.dart';
import '../l10n/app_localizations.dart';

/// Terms of Service screen
class TermsOfServiceScreen extends StatelessWidget {
  const TermsOfServiceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.termsOfService),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(
            'ПУБЛИЧНАЯ ОФЕРТА',
            style: AppTheme.headlineMedium.copyWith(
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'на оказание информационных услуг',
            style: AppTheme.bodyMedium.copyWith(
              color: AppTheme.textHint,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),

          _buildSection(
            '1. ОБЩИЕ ПОЛОЖЕНИЯ',
            '''1.1. Настоящая публичная оферта (далее — «Оферта») является официальным предложением Сервиса «Редкие Книги» (далее — «Сервис») заключить договор на оказание информационных услуг на условиях, изложенных в настоящей Оферте.

1.2. Акцептом (принятием) настоящей Оферты является регистрация на сайте Сервиса и/или оплата услуг Сервиса.

1.3. Совершая акцепт, Пользователь подтверждает, что полностью ознакомился с условиями Оферты и принимает их в полном объёме.''',
          ),

          _buildSection(
            '2. ПРЕДМЕТ ОФЕРТЫ',
            '''2.1. Сервис предоставляет Пользователю доступ к базе данных аукционных продаж редких и антикварных книг для информационных целей.

2.2. Информация в базе данных носит справочный характер и не является экспертной оценкой стоимости.

2.3. Сервис обязуется предоставить доступ к функционалу в соответствии с выбранным тарифным планом.''',
          ),

          _buildSection(
            '3. ПРАВА И ОБЯЗАННОСТИ СТОРОН',
            '''3.1. Сервис обязуется:
— обеспечить доступ к сервису 24/7, за исключением периодов технического обслуживания;
— обеспечить сохранность персональных данных Пользователя;
— своевременно информировать Пользователя об изменениях в условиях использования.

3.2. Пользователь обязуется:
— предоставить достоверные данные при регистрации;
— не передавать данные доступа третьим лицам;
— не использовать автоматизированные средства для копирования базы данных.''',
          ),

          _buildSection(
            '4. СТОИМОСТЬ И ПОРЯДОК ОПЛАТЫ',
            '''4.1. Стоимость услуг определяется действующими тарифными планами, опубликованными на сайте Сервиса.

4.2. Оплата производится авансом на выбранный период.

4.3. Возврат средств осуществляется в соответствии с законодательством РФ.''',
          ),

          _buildSection(
            '5. ОГРАНИЧЕНИЕ ОТВЕТСТВЕННОСТИ',
            '''5.1. Сервис не несёт ответственности за решения, принятые Пользователем на основе информации из базы данных.

5.2. Информация в базе данных предоставляется «как есть» без каких-либо гарантий.

5.3. Сервис не несёт ответственности за убытки, возникшие в результате использования или невозможности использования сервиса.''',
          ),

          _buildSection(
            '6. ЗАКЛЮЧИТЕЛЬНЫЕ ПОЛОЖЕНИЯ',
            '''6.1. Настоящая Оферта вступает в силу с момента её акцепта.

6.2. Сервис вправе в одностороннем порядке изменять условия Оферты с уведомлением Пользователей.

6.3. Все споры разрешаются путём переговоров, а при недостижении согласия — в судебном порядке по месту нахождения Сервиса.''',
          ),

          const SizedBox(height: 32),
          
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.backgroundColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.info_outline,
                  color: AppTheme.textHint,
                ),
                const SizedBox(height: 8),
                Text(
                  'Последнее обновление: 01.01.2025',
                  style: AppTheme.bodySmall.copyWith(
                    color: AppTheme.textHint,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(String title, String content) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: AppTheme.titleMedium.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            content,
            style: AppTheme.bodyMedium.copyWith(
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}

