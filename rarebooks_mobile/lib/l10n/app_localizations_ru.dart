// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Russian (`ru`).
class AppLocalizationsRu extends AppLocalizations {
  AppLocalizationsRu([String locale = 'ru']) : super(locale);

  @override
  String get appTitle => 'Редкие Книги';

  @override
  String get appTitleShort => 'РК';

  @override
  String get login => 'Войти';

  @override
  String get register => 'Регистрация';

  @override
  String get logout => 'Выйти из системы';

  @override
  String get email => 'Email';

  @override
  String get password => 'Пароль';

  @override
  String get confirmPassword => 'Подтвердите пароль';

  @override
  String get forgotPassword => 'Забыли пароль?';

  @override
  String get noAccount => 'Нет аккаунта?';

  @override
  String get haveAccount => 'Уже есть аккаунт?';

  @override
  String get search => 'Искать';

  @override
  String get searchByTitle => 'Поиск по названию';

  @override
  String get searchByDescription => 'Поиск по описанию';

  @override
  String get searchByPriceRange => 'Поиск по ценовому диапазону';

  @override
  String get exactMatch => 'Точное соответствие';

  @override
  String get bookTitle => 'Название книги';

  @override
  String get keywords => 'Ключевые слова';

  @override
  String get minPrice => 'Минимальная цена';

  @override
  String get maxPrice => 'Максимальная цена';

  @override
  String get home => 'Главная';

  @override
  String get catalog => 'Каталог';

  @override
  String get favorites => 'Избранное';

  @override
  String get collection => 'Коллекция';

  @override
  String get notifications => 'Уведомления';

  @override
  String get profile => 'Профиль';

  @override
  String get subscription => 'Подписка';

  @override
  String get settings => 'Настройки';

  @override
  String get mainTitle => 'Оценка антикварных книг';

  @override
  String get mainSubtitle =>
      'Узнайте рыночную стоимость вашей книги с помощью базы данных реальных продаж';

  @override
  String get advancedSearch => 'Расширенный поиск';

  @override
  String get descriptionSearchHint =>
      'Поиск книг по ключевым словам в описании';

  @override
  String get priceRangeSearchHint =>
      'Найдите книги в определенном ценовом диапазоне';

  @override
  String get subscriptionStatus => 'Статус подписки';

  @override
  String get active => 'Активна';

  @override
  String get inactive => 'Не активна';

  @override
  String get subscriptionType => 'Тип подписки';

  @override
  String get standard => 'Стандартная';

  @override
  String get validUntil => 'Действует до';

  @override
  String get getSubscription => 'Оформить подписку';

  @override
  String get bookDetails => 'Детали книги';

  @override
  String get author => 'Автор';

  @override
  String get year => 'Год издания';

  @override
  String get price => 'Цена';

  @override
  String get finalPrice => 'Итоговая цена';

  @override
  String get seller => 'Продавец';

  @override
  String get saleDate => 'Дата продажи';

  @override
  String get description => 'Описание';

  @override
  String get category => 'Категория';

  @override
  String get categories => 'Категории';

  @override
  String get noImages => 'Изображения отсутствуют';

  @override
  String get addToFavorites => 'Добавить в избранное';

  @override
  String get removeFromFavorites => 'Удалить из избранного';

  @override
  String get myCollection => 'Моя коллекция';

  @override
  String get addBook => 'Добавить книгу';

  @override
  String get editBook => 'Редактировать';

  @override
  String get deleteBook => 'Удалить';

  @override
  String get exportPdf => 'Экспорт PDF';

  @override
  String get exportJson => 'Экспорт JSON';

  @override
  String get importCollection => 'Импорт';

  @override
  String get collectionStatistics => 'Статистика коллекции';

  @override
  String get totalBooks => 'Всего книг';

  @override
  String get totalValue => 'Общая стоимость';

  @override
  String get purchaseDate => 'Дата покупки';

  @override
  String get purchasePrice => 'Цена покупки';

  @override
  String get estimatedValue => 'Оценочная стоимость';

  @override
  String get notes => 'Примечания';

  @override
  String get condition => 'Состояние';

  @override
  String get notificationSettings => 'Настройки уведомлений';

  @override
  String get telegramIntegration => 'Интеграция с Telegram';

  @override
  String get connected => 'Подключено';

  @override
  String get disconnected => 'Отключено';

  @override
  String get connectTelegram => 'Подключить Telegram';

  @override
  String get disconnectTelegram => 'Отключить';

  @override
  String get loading => 'Загрузка...';

  @override
  String get error => 'Ошибка';

  @override
  String get retry => 'Повторить';

  @override
  String get cancel => 'Отмена';

  @override
  String get save => 'Сохранить';

  @override
  String get delete => 'Удалить';

  @override
  String get confirm => 'Подтвердить';

  @override
  String get close => 'Закрыть';

  @override
  String get ok => 'OK';

  @override
  String get yes => 'Да';

  @override
  String get no => 'Нет';

  @override
  String get noResults => 'Ничего не найдено';

  @override
  String get noFavorites => 'У вас пока нет избранных книг';

  @override
  String get noCollection => 'Ваша коллекция пуста';

  @override
  String get loginRequired => 'Требуется авторизация';

  @override
  String get subscriptionRequired => 'Требуется подписка';

  @override
  String get networkError => 'Ошибка соединения';

  @override
  String get serverError => 'Ошибка сервера';

  @override
  String get unknownError => 'Неизвестная ошибка';

  @override
  String get authError => 'Ошибка авторизации';

  @override
  String get accessDenied => 'Доступ запрещен';

  @override
  String get recentSales => 'Последние продажи';

  @override
  String get priceHistory => 'История цен';

  @override
  String get similarBooks => 'Похожие книги';

  @override
  String get termsOfService => 'Публичная оферта';

  @override
  String get contacts => 'Контакты';

  @override
  String get telegramBot => 'Telegram бот';

  @override
  String get from => 'от';

  @override
  String get to => 'до';

  @override
  String get rub => '₽';

  @override
  String get rubPerMonth => '₽/месяц';

  @override
  String get pullToRefresh => 'Потяните для обновления';

  @override
  String get loadMore => 'Загрузить ещё';

  @override
  String get collectionAccessRequired =>
      'Доступ к коллекции недоступен. Пожалуйста, оформите подходящую подписку.';

  @override
  String get professionalAppraisal =>
      'Профессиональная оценка антикварных книг';

  @override
  String get salesRecords => '230 000+ продаж';

  @override
  String get tenYearArchive => 'Доступ к 10-летнему архиву аукционов';

  @override
  String get realSalesOnly => 'Только реальные продажи';

  @override
  String get flexibleSearch => 'Гибкий поиск';

  @override
  String get completeLotInfo => 'Полная информация о лотах';
}
