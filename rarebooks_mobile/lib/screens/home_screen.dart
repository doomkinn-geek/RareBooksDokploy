import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../config/theme.dart';
import '../providers/providers.dart';
import '../widgets/search_bar_widget.dart';
import '../widgets/subscription_status_widget.dart';
import '../l10n/app_localizations.dart';

/// Home screen with search functionality
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    // Load categories and recent sales
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<BooksProvider>().loadCategories();
      context.read<BooksProvider>().loadRecentSales();
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final authProvider = context.watch<AuthProvider>();
    final booksProvider = context.watch<BooksProvider>();

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // App Bar
          SliverAppBar(
            expandedHeight: 200,
            floating: false,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                l10n.appTitle,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  shadows: [
                    Shadow(
                      offset: Offset(1, 1),
                      blurRadius: 3,
                      color: Colors.black45,
                    ),
                  ],
                ),
              ),
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      AppTheme.primaryColor,
                      AppTheme.primaryDark,
                    ],
                  ),
                ),
                child: Stack(
                  children: [
                    // Background pattern
                    Positioned.fill(
                      child: Opacity(
                        opacity: 0.1,
                        child: Icon(
                          Icons.menu_book,
                          size: 200,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    // Subtitle
                    Positioned(
                      left: 16,
                      right: 16,
                      bottom: 60,
                      child: Text(
                        l10n.mainSubtitle,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              // Language toggle
              IconButton(
                icon: Text(
                  context.watch<LanguageProvider>().isRussian ? 'EN' : 'RU',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                onPressed: () {
                  context.read<LanguageProvider>().toggleLanguage();
                },
              ),
              // Profile/Login button
              IconButton(
                icon: const Icon(Icons.person, color: Colors.white),
                onPressed: () {
                  if (authProvider.isAuthenticated) {
                    context.push('/profile');
                  } else {
                    context.push('/login');
                  }
                },
              ),
            ],
          ),

          // Content
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Search bar
                  const SearchBarWidget(),
                  const SizedBox(height: 24),

                  // Subscription status for logged in users
                  if (authProvider.isAuthenticated) ...[
                    const SubscriptionStatusWidget(),
                    const SizedBox(height: 24),
                  ],

                  // Features section
                  _buildFeaturesSection(context, l10n),
                  const SizedBox(height: 24),

                  // Recent sales
                  if (booksProvider.recentSales.isNotEmpty) ...[
                    _buildRecentSalesSection(context, l10n, booksProvider),
                    const SizedBox(height: 24),
                  ],

                  // Login/Register prompt for guests
                  if (!authProvider.isAuthenticated)
                    _buildAuthPrompt(context, l10n),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeaturesSection(BuildContext context, AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.professionalAppraisal,
          style: AppTheme.headlineSmall,
        ),
        const SizedBox(height: 16),
        
        // Feature cards
        _buildFeatureCard(
          icon: Icons.search,
          title: l10n.salesRecords,
          description: l10n.realSalesOnly,
          color: AppTheme.primaryColor,
        ),
        const SizedBox(height: 12),
        
        _buildFeatureCard(
          icon: Icons.history,
          title: l10n.tenYearArchive,
          description: l10n.completeLotInfo,
          color: AppTheme.secondaryColor,
        ),
        const SizedBox(height: 12),
        
        _buildFeatureCard(
          icon: Icons.tune,
          title: l10n.flexibleSearch,
          description: l10n.advancedSearch,
          color: AppTheme.successColor,
        ),
      ],
    );
  }

  Widget _buildFeatureCard({
    required IconData icon,
    required String title,
    required String description,
    required Color color,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTheme.titleMedium.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: AppTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentSalesSection(
    BuildContext context,
    AppLocalizations l10n,
    BooksProvider booksProvider,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.recentSales,
          style: AppTheme.headlineSmall,
        ),
        const SizedBox(height: 16),
        
        SizedBox(
          height: 160,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: booksProvider.recentSales.length,
            itemBuilder: (context, index) {
              final sale = booksProvider.recentSales[index];
              return Container(
                width: 140,
                margin: EdgeInsets.only(
                  right: index < booksProvider.recentSales.length - 1 ? 12 : 0,
                ),
                child: Card(
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: () {
                      context.push('/book/${sale.id}');
                    },
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Container(
                            color: AppTheme.backgroundColor,
                            child: Center(
                              child: Icon(
                                Icons.menu_book,
                                size: 48,
                                color: AppTheme.textHint,
                              ),
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                sale.title ?? 'Книга',
                                style: AppTheme.bodySmall.copyWith(
                                  fontWeight: FontWeight.w500,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${sale.finalPrice?.toStringAsFixed(0) ?? '?'} ₽',
                                style: TextStyle(
                                  color: AppTheme.primaryColor,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildAuthPrompt(BuildContext context, AppLocalizations l10n) {
    return Card(
      color: AppTheme.primaryColor.withOpacity(0.1),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Icon(
              Icons.lock_open,
              size: 48,
              color: AppTheme.primaryColor,
            ),
            const SizedBox(height: 16),
            Text(
              l10n.loginRequired,
              style: AppTheme.titleLarge.copyWith(
                color: AppTheme.primaryColor,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Войдите, чтобы получить доступ к поиску и оценке книг',
              style: AppTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                OutlinedButton(
                  onPressed: () => context.push('/login'),
                  child: Text(l10n.login),
                ),
                const SizedBox(width: 16),
                ElevatedButton(
                  onPressed: () => context.push('/register'),
                  child: Text(l10n.register),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

