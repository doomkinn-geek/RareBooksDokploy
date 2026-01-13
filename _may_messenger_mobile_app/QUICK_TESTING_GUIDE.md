# 🚀 Быстрое руководство: Тестирование и публикация iOS

## ⚠️ Главное правило

**IPA из `flutter build ipa` предназначен ТОЛЬКО для App Store Connect!**

---

## 📱 Для тестирования на подключенном iPhone

```bash
cd /Users/janaplett/RareBooksDokploy/_may_messenger_mobile_app

# Сборка и установка одной командой
flutter run --release

# Или поэтапно:
flutter build ios --release
flutter install
```

✅ **Приложение установлено на ваш iPhone!**

---

## 🏪 Для загрузки в App Store / TestFlight

```bash
cd /Users/janaplett/RareBooksDokploy/_may_messenger_mobile_app

# Создать IPA для App Store
flutter build ipa --release

# Открыть папку с IPA
open build/ios/ipa/
```

Перетащите `maymessenger.ipa` в **Apple Transporter** → Загрузится в App Store Connect.

✅ **Через 15-30 минут билд появится в TestFlight!**

---

## 📋 Два разных файла - две разные цели

| Файл | Команда | Для чего |
|------|---------|----------|
| `build/ios/iphoneos/Runner.app` | `flutter build ios` | 📱 Установка на подключенный iPhone |
| `build/ios/ipa/maymessenger.ipa` | `flutter build ipa` | 🏪 Загрузка в App Store Connect |

---

## ❓ Что если нужно распространить нескольким тестировщикам?

### Вариант 1: TestFlight (рекомендуется)
1. Загрузите IPA через Apple Transporter
2. Откройте https://appstoreconnect.apple.com
3. My Apps → Депеша → TestFlight → Add Testers
4. Тестировщики установят через TestFlight app

### Вариант 2: Ad Hoc через Xcode
1. `open ios/Runner.xcworkspace`
2. Product → Archive
3. Distribute App → Ad Hoc
4. Отправьте IPA тестировщикам (требуется добавить их UDID в Developer Portal)

---

**Подробнее:** См. `IOS_TESTING_GUIDE.md`
