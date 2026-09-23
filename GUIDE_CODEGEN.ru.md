<p align="center">
  <a href="GUIDE_CODEGEN.md">English</a> · <a href="GUIDE_CODEGEN.ru.md">Русский</a> · <a href="GUIDE_CODEGEN.zh-CN.md">中文</a>
</p>

> Перевод [GUIDE_CODEGEN.md](GUIDE_CODEGEN.md). Канонический текст — английский: при расхождении верен он.

# Code-Gen Mode

Cobalt с генератором: вы размечаете классы, `build_runner` пишет контейнер, и граф проверяется до
того, как соберётся. На выходе — обычный Dart, не использующий ничего, кроме публичного API `cobalt`:
его можно прочитать, и всё в нём можно было бы написать руками.

Это стоящий инвариант проекта, и у него есть практическое следствие, которым вы будете
пользоваться: сгенерированный контейнер — такой же `CobaltScopeBuilder`, как любой другой, поэтому
рукописные регистрации композируются с ним в одном графе. Ничего здесь не «всё или ничего».

Что покупает шаг сборки и о чём в основном этот документ:

- **граф проверяется на сборке** — зависимость, которую никто не регистрирует, валит сборку, называя
  все пробелы разом, вместо того чтобы упасть на том экране, который первым до неё дойдёт;
- **property injection** — поля `late final`, заполняемые сгенерированным миксином, так что у класса
  с пятью зависимостями пустой конструктор;
- **четырнадцать правил линтера**, ловящих остальное в редакторе.

Если ничего из этого не нужно или вы постепенно мигрируете существующий контейнер — всё работает и
без генератора: [GUIDE_MANUAL.ru.md](GUIDE_MANUAL.ru.md).

---

## Содержание

1. [Установка](#1-установка)
2. [Первый сгенерированный граф](#2-первый-сгенерированный-граф)
3. [Что выходит на выходе](#3-что-выходит-на-выходе)
4. [Property injection](#4-property-injection)
5. [Граф обязан быть полным](#5-граф-обязан-быть-полным)
6. [Композиция поверх сгенерированного корня](#6-композиция-поверх-сгенерированного-корня)
7. [Запуск Flutter-приложения](#7-запуск-flutter-приложения)
8. [Чтение из графа в виджете](#8-чтение-из-графа-в-виджете)
9. [Скоупы, которые кончаются раньше приложения](#9-скоупы-которые-кончаются-раньше-приложения)
10. [Как закрывается то, что вы зарегистрировали](#10-как-закрывается-то-что-вы-зарегистрировали)
11. [Работа, которая обязана завершиться до старта](#11-работа-которая-обязана-завершиться-до-старта)
12. [Значения, приходящие с места вызова](#12-значения-приходящие-с-места-вызова)
13. [Опциональные зависимости](#13-опциональные-зависимости)
14. [Типы, которые написали не вы](#14-типы-которые-написали-не-вы)
15. [Один граф, несколько сборок](#15-один-граф-несколько-сборок)
16. [Плагин линтера](#16-плагин-линтера)
17. [Наблюдение за графом](#17-наблюдение-за-графом)
18. [Тесты](#18-тесты)
19. [Ошибки, о которых стоит знать заранее](#19-ошибки-о-которых-стоит-знать-заранее)

---

## 1. Установка

Рантайм уезжает в приложение, генератор — никогда.

```yaml
environment:
  sdk: ^3.10.0
  flutter: ">=3.38.0"

dependencies:
  cobalt: ^0.2.0
  cobalt_flutter: ^0.2.0

dev_dependencies:
  cobalt_generator: ^0.2.0
  build_runner: ^2.15.0
  cobalt_lint: ^0.2.0
  cobalt_test: ^0.2.0
  cobalt_test_flutter: ^0.2.0
```

**Пол здесь тот же, что и в другом режиме**, поэтому приложение на Flutter 3.38 может начинать
сразу отсюда, а не начинать с [GUIDE_MANUAL.ru.md](GUIDE_MANUAL.ru.md) и потом мигрировать.

Вместе с ним приезжает одно следствие: на Flutter 3.38 ваш проект резолвит `analyzer 10.0.1` и
`build_runner 2.15.1`, потому что Flutter там пиннит `meta 1.17.0`, а анализатор новее просит
`^1.18.0`. На свежем Flutter резолвится 12.1.0, и сгенерированный код в обоих случаях один и тот же.
Вся строка — в разделе **Требования** в [README.ru.md](README.ru.md).

Пакет на чистом Dart — CLI, сервер, пакет без виджетов — выбрасывает `cobalt_flutter` и
`cobalt_test_flutter`. Рантайму Flutter не нужен нигде.

Аннотации приезжают вместе с `cobalt`, который их реэкспортирует, поэтому одного импорта достаточно:

```dart
import 'package:cobalt/cobalt.dart';
```

Опционально и только если нужно: `cobalt_go_router`, `cobalt_bloc`, `cobalt_inspector` и один из
`cobalt_talker` / `cobalt_logging` / `cobalt_logger`.

---

## 2. Первый сгенерированный граф

Разметьте классы. Зависимости — это параметры конструктора, а что чем резолвится, вычисляет
генератор.

```dart
import 'package:cobalt/cobalt.dart';

@cobaltInject
class Config {
  Config();

  final String environment = 'test';
}

@cobaltInject
class Repository {
  Repository(this.config);

  final Config config;
}

@cobaltInject
class Telemetry implements Disposable {
  Telemetry();

  final events = <String>[];

  void record(String event) => events.add(event);

  @override
  void dispose() => events.clear();
}
```

`@cobaltInject` — ленивый синглтон: строится при первом резолве, удерживается скоупом. У остальных
времён жизни свои константы, а полная форма принимает всё прочее:

| Аннотация | Время жизни |
|---|---|
| `@cobaltInject` | ленивый синглтон |
| `@cobaltSingleton` | eager-синглтон, строится вместе с графом |
| `@cobaltTransient` | новый инстанс на каждый резолв, не удерживается никем |

```dart
@CobaltInject(exposeAs: ApiClient, name: 'live', dispose: closeClient)
class LiveApiClient implements ApiClient { ... }
```

`exposeAs` регистрирует класс под интерфейсом — так потребитель зависит от `ApiClient`, а не от
реализации. `name` — квалификатор, поэтому вторая регистрация того же типа законна и читается через
`get<Logger>(name: 'audit')`.

Корень называется один раз, в любом месте пакета:

```dart
@CobaltScopeRoot(name: 'app')
class AppScope {
  const AppScope();
}
```

Дальше — генерация:

```bash
dart run build_runner build
```

Во время работы — `dart run build_runner watch`. Вывод коммитьте: CI перегенерирует и падает на
диффе, и так устаревший сгенерированный код ловится, а не уезжает в релиз.

**Один корень на пакет.** `cobalt_container` агрегирует весь пакет в единственный `$CobaltRootScope`;
два `@CobaltScopeRoot` в одном пакете — ошибка генерации. Значит два независимых сгенерированных
графа требуют двух пакетов — ровно поэтому примеры в этом репозитории отдельные пакеты, а не папки.

---

## 3. Что выходит на выходе

`lib/cobalt.g.dart`, и его стоит прочитать один раз, чтобы режим перестал быть чёрным ящиком:

```dart
final class _RepositoryFactory implements CobaltFactory<Repository> {
  const _RepositoryFactory();

  @override
  Repository create(CobaltResolver resolver) => Repository(resolver.get<Config>());
}

final class $CobaltRootScope implements CobaltScopeBuilder {
  const $CobaltRootScope();

  @override
  void build(CobaltScope scope) {
    scope.registerLazySingleton<Config>(const _ConfigFactory());
    scope.registerLazySingleton<Telemetry>(const _TelemetryFactory());
    scope.registerLazySingleton<Repository>(const _RepositoryFactory());
  }
}

const String $cobaltRootScopeName = 'app';

Future<CobaltScope> $startCobalt() => CobaltApplication.start(
  root: const $CobaltRootScope(),
  rootName: $cobaltRootScopeName,
);
```

```dart
final scope = await $startCobalt();
```

Здесь они для читаемости опущены, но в настоящем файле каждое импортированное имя носит префикс,
выведенный из хеша URL библиотеки: `_i178.CobaltFactory`. Именно хеш, а не счётчик, — чтобы
добавление одного импорта не перенумеровало все остальные и не превратило правку в одну строку в
дифф на весь файл.

Четыре свойства этого вывода сознательны:

- **Приватные const-классы-фабрики, а не замыкания.** `const`-фабрика не носит захваченного
  состояния, поэтому второй старт не может переиспользовать объекты первого графа.
- **Регистрации в топологическом порядке**, вычисленном на сборке. Инъектируемые поля тоже рёбра,
  поэтому блок всегда регистрируется после того, что он инъектирует.
- **Ни рефлексии, ни сканирования в рантайме.** Что лежит в файле — то и есть весь граф.
- **`$cobaltBootstrap` — геттер**, а не хранимый список, поэтому рестарт получает свежие шаги — см.
  [§11](#11-работа-которая-обязана-завершиться-до-старта).

Генератор форматирует свой вывод той же версией `dart_style`, которой пользуется ваша проверка
формата, — расходиться им негде.

---

## 4. Property injection

Классу с пятью зависимостями не нужны пять аргументов конструктора. Объявите поля и подмешайте то,
что генератор напишет рядом:

```dart
part 'counter_bloc.g.dart';

@cobaltTransient
class CounterBloc with _$CounterBloc {
  CounterBloc();

  @injected
  late final Repository _repository;

  @injected
  late final Telemetry _telemetry;

  void increment() => _telemetry.record('${_repository.hashCode}');
}
```

Три вещи делают это надёжным, а не магическим:

- Поля `late final`, то есть **пишутся один раз** — повторное присваивание даёт `LateError`.
- Они могут быть **приватными**: сгенерированный миксин — `part` той же библиотеки и потому их
  видит.
- Они — **рёбра графа** наравне с остальными, поэтому участвуют и в упорядочивании, и в проверке
  полноты.

Директиву `part` и `with _$ClassName` пишете вы. Забудете миксин — `cobalt_missing_injection_mixin`
скажет об этом в редакторе; поставите `@injected` на класс, который контейнер не регистрирует, —
скажет уже `cobalt_injected_field_needs_an_injectable`, потому что чинятся эти две ошибки по-разному.

---

## 5. Граф обязан быть полным

Ради этого шаг сборки и нужен. Зависимость, которую никто не регистрирует, валит сборку, называя все
пробелы разом, а не по одному на пересборку:

```
The graph is missing 2 registrations.
  CatalogService requires Repository<User>
  ApiGateway requires HttpClient in dev, test
Annotate the classes that provide them with @CobaltInject, or name them in
@CobaltScopeRoot(provides: [...]) when something outside the generated container
registers them.
```

Зависимостями считается всё: параметры конструктора, `@injected`-поля и `@CobaltInit(dependsOn:)`.
Квалификатор `@Named` входит в ключ, поэтому запрос `@Named('audit') Logger` там, где есть только
безымянный `Logger`, — это пробел. Каждое окружение проверяется отдельно, поэтому `dev`-регистрация
не удовлетворит зависимого, который работает и в `prod`.

Отвергается на сборке и остальное: дубликаты одного ключа, циклы зависимостей (с указанием цикла),
два `@CobaltScopeRoot` в пакете, `@CobaltInject` на абстрактном классе или на классе без публичного
генеративного конструктора, и `@CobaltInject` на **generic-классе** — генератору никто не говорит,
какие инстанциации регистрировать, поэтому разметьте конкретный подтип или выставьте его через
`exposeAs`.

Во всём остальном дженерики работают. `Repository<User>` и `Repository<Order>` — две отдельные
регистрации, потому что `CobaltKey` строится из `Type`, а это разные типы.

Границу стоит назвать честно: проверка покрывает то, что генератор сгенерировал. Рукописная фабрика
резолвит внутри `create`, поэтому статически не видно, что она попросит, — для таких проверкой
служит `expectGraphResolves` из `cobalt_test`, см. [§18](#18-тесты).

---

**Рукописная регистрация, скомпонованная вокруг контейнера, подчиняется тому же правилу.** Ленивая
может стоять выше `$CobaltRootScope().build(scope)` и всё равно отрезолвит то, что зарегистрировал
генератор; жадная — нет, и ошибка это скажет: назовёт недостающий тип и добавит, что скоуп ещё
собирается.

## 6. Композиция поверх сгенерированного корня

Генератор видит только аннотации своего пакета. Всё прочее — значение из `--dart-define`, объект,
которому нужен сам скоуп, провайдер из чужого пакета — кладётся в билдер, оборачивающий
сгенерированный:

```dart
class NotesScope implements CobaltScopeBuilder {
  const NotesScope(this.environment);

  final CobaltEnvironment environment;

  @override
  void build(CobaltScope scope) {
    $CobaltRootScope(environment: environment).build(scope);
    scope
      ..registerSingleton<CobaltEnvironment>(environment)
      ..registerSingleton<SessionManager>(SessionManager(scope));
  }
}
```

Обёртка, а не регистрация после возврата из `$startCobalt()`, — это то, что держит их внутри фазы 1:
зарегистрированы до запуска async-инициализаторов, а не приколочены после того, как граф уже поднят.

Теперь скажите об этом проверке полноты, иначе она сочтёт их отсутствующими:

```dart
@CobaltScopeRoot(name: 'app', provides: [SessionManager, CobaltEnvironment])
class AppScope {
  const AppScope();
}
```

Обещание ничего не регистрирует — оно только говорит, что это сделает кто-то другой.
`CobaltProvided(Logger, name: 'audit')` обещает именованную. Пообещать и не зарегистрировать — значит
вернуться к отказу в рантайме: этот список ваше утверждение, а не то, что генератор может проверить.

---

## 7. Запуск Flutter-приложения

Корнем владеет `CobaltAppScope`: строит граф, публикует его в дерево, разбирает при размонтировании и
превращает упавший старт в экран с повтором вместо приложения, которое умерло до первого кадра.

Ставьте его в `MaterialApp.builder`, а не над `MaterialApp`. Там он оказывается ниже `Theme`,
`Directionality` и `Localizations`, поэтому `loading` и `errorBuilder` — обычные экраны, а не второй
`MaterialApp`:

```dart
void main() => runApp(
  MaterialApp(
    theme: appTheme,
    builder: CobaltAppScope.builder(
      root: const NotesScope(notesEnvironment),
      bootstrap: () => $cobaltBootstrap(notesEnvironment),
      rootName: $cobaltRootScopeName,
      loading: const Scaffold(body: Center(child: CircularProgressIndicator())),
      errorBuilder: (context, error, retry) => StartupFailed(error: error, retry: retry),
    ),
    home: const HomeScreen(),
  ),
);
```

`bootstrap` — функция, а не список, и генератор эмитит `$cobaltBootstrap` геттером по той же причине:
шаги держат ресурсы, и рестарт обязан получить новые.

`CobaltAppScope.of(context).restart()` пересобирает граф — тот же вызов повторяет упавший старт.

Вне Flutter всё сводится к `await $startCobalt()`.

---

## 8. Чтение из графа в виджете

```dart
final repository = context.cobalt<Repository>();
final formatters = context.cobaltAll<NoteFormatter>();
final editor = context.cobaltWithParam<NoteEditor, $NoteEditorArgs>((id: 7, draft: true));
final scope = context.cobaltScope;
```

Каждый резолвит из **ближайшего** скоупа над виджетом и дальше идёт вверх, поэтому регистрация во
флоу или сессионном скоупе затеняет корневую для всего, что внутри.

Об одном стоит знать до того, как оно случится: `Navigator.push` строит новый маршрут из контекста
навигатора, а не из виджета, который его толкнул. Экран, прекрасно резолвящий на своём месте,
бросит `CobaltNoScopeError`, если тот же виджет открыть пушем, а провайдер, из которого он читал,
живёт **внутри** толкающего экрана. Передавайте скоуп явно или пушьте ниже провайдера.

---

## 9. Скоупы, которые кончаются раньше приложения

Генератор пишет **корень**. Скоупы короче приложения — сессия, флоу, экран — это
`CobaltScopeBuilder`'ы, которые пишете вы, и регистрируют они через тот же публичный API, которым
пользуется сгенерированный файл. Это не пробел генератора: что положить в сессионный скоуп — решение
о времени жизни, а никакая аннотация не говорит, когда сессия кончается.

### Сессия

```dart
class SessionManager {
  SessionManager(this._root);

  final CobaltScope _root;
  CobaltScope? _session;

  Future<void> signIn(User user) async {
    _session = _root.push('session:${user.id}')
      ..registerLazySingleton<Draft>(const DraftFactory());
    await _session!.init();
  }

  Future<void> signOut() async {
    await _session?.dispose();
    _session = null;
  }
}
```

Логаут — это `await scope.dispose()`. Ни один репозиторий не подписывается на сессионный стрим, и ни
один доменный интерфейс не обрастает методом `reset()`, которого он не хотел.

### Экран

```dart
CobaltScopeWidget(
  name: 'counter-screen',
  builder: const ScreenScope(),
  child: const Counter(),
)
```

Создаётся при монтировании, разбирается при размонтировании. Скоуп публикуется только после
`init()`, поэтому даже полностью синхронный граф даёт один кадр `loading`.

Здесь `@cobaltTransient` и оправдывает своё существование: транзиент пересоздаётся на каждый резолв и
не удерживается никем, поэтому собственный скоуп — это то, что даёт ему время жизни и точку разбора.

### Навигационный флоу

С `cobalt_go_router` время жизни задаёт флоу, а не виджет, который вы не забыли поставить:

```dart
class OrderFlowRoute extends CobaltShellRoute {
  OrderFlowRoute()
    : super(
        name: 'order',
        identity: _orderId,
        scope: (state) => OrderFlowScope(_orderId(state)),
        routes: [
          GoRoute(
            path: '/orders/:orderId/summary',
            builder: (_, state) => OrderSummaryScreen(orderId: _orderId(state)),
          ),
          GoRoute(
            path: '/orders/:orderId/payment',
            builder: (_, state) => OrderPaymentScreen(orderId: _orderId(state)),
          ),
        ],
      );

  static String _orderId(GoRouterState state) => state.pathParameters['orderId']!;
}
```

Навигация между `summary` и `payment` сохраняет один скоуп. Выход из флоу его разбирает. `identity`
отвечает на единственный вопрос, который роутер решить не может: одно ли это флоу — `/orders/1` и
`/orders/2`.

Таблицу роутов стройте **один раз**, вместе с роутером. Новый экземпляр `CobaltShellRoute` — это
другой флоу с точки зрения go_router, поэтому пересборка списка на каждом кадре разбирала бы скоуп
на каждом кадре.

Вкладки устроены так же — `CobaltStatefulShellRoute` и `CobaltStatefulShellBranch`, — с одной
особенностью: ветка держится **живой**, а не **видимой**. go_router сохраняет навигаторы веток за
экраном, поэтому скоуп вкладки живёт до закрытия шелла, а не до переключения с неё.

---

## 10. Как закрывается то, что вы зарегистрировали

Скоуп освобождает удержанное в обратном порядке **создания**, а не объявления, — именно это различие
баг рукописных контейнеров. В Dart нет структурной типизации, поэтому совпадающего метода
`dispose()` самого по себе недостаточно:

```dart
@cobaltInject
class Cache implements Disposable {
  @override
  void dispose() { ... }
}

@cobaltInit
class Database implements AsyncInitializable, AsyncDisposable {
  @override
  Future<void> init() async { ... }

  @override
  Future<void> dispose() async { ... }
}
```

Для типа, который вам не изменить — из SDK, из чужого пакета, за базовым классом, — назовите
teardown в аннотации. Она принимает top-level-функцию, потому что аргумент аннотации обязан быть
константой:

```dart
Future<void> closeClient(http.Client client) => client.close();

@CobaltInject(dispose: closeClient)
class ApiClientHolder { ... }
```

`dispose:` что-то значит только у регистрации, которую скоуп удерживает. На `@cobaltTransient` или на
классе с `@CobaltParam` это ошибка сборки, а не колбэк, который никогда не вызовут: транзиент
закрывать не скоупу.

### Flutter-типы, которые выглядят закрываемыми и не являются

`ChangeNotifier.dispose` совпадает с `Disposable.dispose` дословно — и всё равно скоупу невидим.
Скажите об этом:

```dart
@cobaltInject
class Filters extends ChangeNotifier implements Disposable {}
```

Для блоков `cobalt_bloc` — это одна строка:

```dart
@cobaltInject
class CounterCubit extends Cubit<int> with CobaltBloc {
  CounterCubit() : super(0);
}
```

или, где миксин не достанет, `@CobaltInject(dispose: closeBloc)`.

Дальше отдавайте блок в дерево виджетов через `BlocProvider.value` и никогда через
`BlocProvider(create:)`: второй закрывает то, что ему передали, при размонтировании, тогда как скоуп
всё ещё держит объект и на следующем резолве отдаст мёртвый.

`cobalt_registration_is_never_released` ловит всё это в редакторе: зарегистрированный класс с
`dispose()` или `close()`, которых скоуп не видит.

### Когда разбор идёт не так

Он best-effort по замыслу. Упавший шаг записывается, остальные всё равно выполняются; у всего дерева
один дедлайн; скоуп всегда доходит до `disposed`. Несделанное перечисляется в `CobaltDisposeError` —
`failures`, `timeouts`, `hasTimeout`.

`adopt` привязывает к жизни скоупа объект, не являющийся зависимостью:

```dart
scope.adopt(subscription, dispose: (it) => it.cancel());
```

---

## 11. Работа, которая обязана завершиться до старта

Две фазы, отвечают на разные вопросы.

**Фаза 0 — `@CobaltBootstrap`.** До того, как контейнер существует: платформенные биндинги, удалённый
конфиг, всё, что нужно самому графу. Шаги идут строго по порядку — сначала `order`, затем имя, чтобы
вывод был стабильным — и не могут ничего инъектировать: инъектировать пока неоткуда. Bootstrap-шаг,
чей конструктор берёт обязательные параметры, — ошибка сборки, а `cobalt_bootstrap_step_cannot_inject`
скажет об этом раньше.

```dart
@CobaltBootstrap(order: 0)
class BindPlatform implements CobaltBootstrapStep {
  const BindPlatform();

  @override
  String get name => 'bind-platform';

  @override
  Future<void> run() async => WidgetsFlutterBinding.ensureInitialized();
}
```

Отработав, шаги усыновляются корневым скоупом: шаг, который что-то открыл, закрывается вместе с ним
— последним, после всего, что построено поверх. Если шаг падает, уже отработавшие освобождаются в
обратном порядке до того, как ошибка будет переброшена.

**Фаза 1 — `@CobaltInit`.** Внутри контейнера: асинхронные синглтоны в порядке зависимостей.

```dart
@CobaltInit(dependsOn: [Database])
class SearchIndex implements AsyncInitializable {
  SearchIndex(this._database);

  final Database _database;
  final _terms = <String>[];

  @override
  Future<void> init() async => _terms.addAll(await _database.terms());
}
```

`AsyncInitializable` — интерфейс, который подразумевает аннотация. Обязателен только сам *метод*
`init()` — и парсер, и правило линтера ищут его по имени, — но объявленный интерфейс делает контракт
видимым читателю, и именно это советует каждое сообщение об отсутствующем `init()`.

Сгенерированная фабрика конструирует объект, дожидается `init()` и регистрирует его async-синглтоном
с `dependsOn`, переведённым в `CobaltKey`. Независимые инициализаторы одного уровня едут вместе через
`Future.wait`; ждёт только тот, кто действительно зависит.

`dependsOn` — ребро порядка, а не инъекция: зависимость вы берёте в конструктор как обычно. Указание
ключа, который зарегистрирован, но **не** async, — ошибка сборки, а не тихий no-op, на который это
похоже: ждать нечего.

`CobaltApplication.start` возвращается, когда обе фазы закончены, поэтому нет ни `allReady()`, ни
состояния «зарегистрировано, но не готово».

### Построить, когда впервые попросят

Фаза 1 строит всё на старте. Для дорогого объекта, который живёт всё приложение, но нужен немногим
экранам, пометьте его ленивым — и ничего не построится до первого `getAsync`:

```dart
@CobaltInit(lazy: true)   // или @cobaltLazyInit
class SearchEngine implements AsyncInitializable {
  SearchEngine(this._index, this._clock);

  final Model _index;     // тоже ленивый — сгенерированная фабрика его дождётся
  final Clock _clock;     // обычная регистрация, читается как всегда

  @override
  Future<void> init() async => _index.warmUp();
}
```

На члене модуля, возвращающем `Future`, то же самое — `@CobaltInject(lazyInit: true)`.

Генератор регистрирует такой класс через `registerLazyAsyncSingleton`, а его фабрика ждёт
`getAsync` для каждой зависимости, которая тоже ленивая. Три вещи — ошибки сборки, потому что каждая
иначе упала бы на устройстве:

- синхронный или eager-async класс, внедряющий ленивый, — передать ему нечего, пока никто не
  дождался; сделайте зависимого тоже ленивым или резолвьте через `getAsync` там, где он нужен;
- `@injected`-поле ленивого типа на любом классе — поля заполняются синхронно;
- `dependsOn`, указывающий на ленивую регистрацию или объявленный на ней, — `dependsOn` упорядочивает
  `init()`, а ленивую регистрацию строит не `init()`.

В рантайме она ведёт себя так, как описано в руководстве по ручному режиму: одновременные вызовы
делят одну сборку, упавшую сборку повторит следующий вызов, `get` до первого `getAsync` бросает
`CobaltLazyAsyncError`, а разбор дожидается сборки в полёте. В виджете
`CobaltAsyncBuilder<SearchEngine>` показывает `loading`, пока первый экран строит объект, и рисует
сразу на каждом следующем.

---

## 12. Значения, приходящие с места вызова

Половина объекта приходит из графа, половина — от того, кто его строит. Разметьте ту половину,
которой контейнер знать не может:

```dart
@cobaltInject
class Greeting {
  Greeting(this._config, {@cobaltParam required this.name, @cobaltParam required this.loud});

  final Config _config;
  final String name;
  final bool loud;
}
```

**Помеченный параметр всегда приходит с места вызова — даже если контейнер умеет его построить.**
`@cobaltParam Draft draft` кладёт `Draft` в запись независимо от того, зарегистрирован ли `Draft`, и
проверка полноты перестаёт его требовать. Это и значит пометка, и диагностики на «пометил то, что
граф уже умеет» нет — поэтому если значение перестало приходить, смотрите сюда раньше, чем на
регистрацию.

Генератор пишет тип аргумента рядом с контейнером как именованную запись и регистрирует
параметризованную фабрику:

```dart
// typedef $GreetingArgs = ({String name, bool loud});
final greeting = context.cobaltWithParam<Greeting, $GreetingArgs>((name: 'Cobalt', loud: false));
```

Именованная запись, а не позиционная, даже для одного аргумента: добавление второго меняет
содержимое типа, а не его имя и не форму вызова.

Два правила, которые генератор проверяет:

- Помеченные параметры **не участвуют** ни в проверке полноты, ни в упорядочивании. `String` никто
  не регистрирует, и не должен пытаться.
- Они обязаны быть **required или нуллабельными**. У записи нет значений по умолчанию, поэтому
  `@cobaltParam this.draft = false` оставил бы вызывающего обязанным передать `draft`, а написанный
  дефолт — мёртвым. Это ошибка сборки, а не сюрприз.

Резолв такой регистрации обычным `get<T>()` бросает `CobaltParamRequiredError`; неверный тип —
`CobaltParamTypeError` с ключом и обоими типами.

---

## 13. Опциональные зависимости

Вся запись — это `?` на типе; отдельной аннотации нет, потому что без `?` поле всё равно не примет
null:

```dart
@cobaltInject
class Reporter {
  Reporter(this.clock, this.telemetry);

  final Clock clock;
  final Telemetry? telemetry;
}

@cobaltInject
class Dashboard with _$Dashboard {
  Dashboard();

  @injected
  late final Telemetry? _telemetry;
}
```

Оба резолвятся через `getOrNull`, поэтому граф, в котором `Telemetry` не зарегистрирована, получит
null вместо падения сборки.

Нуллабельность не входит в **ключ** регистрации — `Foo?` по-прежнему читает регистрацию `Foo`, — а
опциональная зависимость остаётся ребром порядка, если её всё-таки кто-то регистрирует. `getOrNull`
отдаёт null только на «не зарегистрировано»: async-синглтон, спрошенный до `init()`, по-прежнему
бросает, потому что «не готово» и «нет вовсе» — разные факты.

---

## 14. Типы, которые написали не вы

`@CobaltInject` вешается на класс, поэтому достаёт только до ваших классов. Для всего остального вход
— модуль: клиент из чужого пакета, значение, которое отдаёт SDK.

```dart
Future<void> closeClient(http.Client client) => client.close();

@cobaltModule
class NetworkModule {
  const NetworkModule();

  @cobaltInject
  Dio dio(AppConfig config) => Dio(BaseOptions(baseUrl: config.apiBase));

  @CobaltInject(dispose: closeClient)
  http.Client client() => http.Client();

  @cobaltSingleton
  Future<SharedPreferences> get prefs => SharedPreferences.getInstance();
}
```

Аннотация на классе не несёт ничего: каждый член настраивает свою регистрацию теми же аннотациями,
что и класс, — время жизни, `name`, `exposeAs`, `dispose`, окружения, — а его параметры резолвятся
как параметры конструктора.

Правила, и у каждого своя причина:

- Классу нужен публичный **`const`-конструктор без аргументов** — тогда сгенерированная фабрика
  держит `const NetworkModule()` и не носит состояния.
- Возврат **`Future<T>` — единственный признак асинхронности.** Такой член становится
  async-синглтоном, а порядок между async-членами вычисляет генератор, а не вы руками.
- Члены **не могут быть абстрактными.** «Собрать класс из его же конструктора» — это то, что уже
  значит `@CobaltInject`; второго способа сказать то же самое не нужно.
- `@CobaltParam` на члене **запрещён.** Модуль регистрирует типы, которые написали не вы, а значение
  с места вызова принадлежит классу, который написали вы.

Члены участвуют во всём, в чём участвует класс: в детекте дубликатов, в топологической сортировке и
в проверке полноты.

---

## 15. Один граф, несколько сборок

Пропустите это, пока одной сборке действительно не понадобится другая реализация, чем другой.
Проект, никогда не пишущий `@CobaltEnvironment`, имеет один граф, все регистрации принадлежат ему, а
`$startCobalt()` не берёт аргументов вовсе.

```dart
@CobaltInject(exposeAs: ApiClient)
@CobaltEnvironment.prod
@CobaltEnvironment.stage
class LiveApiClient implements ApiClient { ... }

@CobaltInject(exposeAs: ApiClient)
@CobaltEnvironment.dev
@CobaltEnvironment.test
class FakeApiClient implements ApiClient { ... }
```

```dart
final scope = await $startCobalt(environment: CobaltEnvironment.prod);
```

Аннотация повторяется, а не принимает список: регистрация принадлежит *множеству* окружений, а старт
выбирает ровно *одно*. `dev`, `stage`, `prod` и `test` — константы, а не закрытое множество:
`@CobaltEnvironment('canary')` ведёт себя точно так же.

Сгенерированный контейнер принимает выбор полем и оборачивает `if` только ограниченные регистрации —
ровно то, что вы написали бы руками:

```dart
if (environment.matches(const <String>{'dev', 'test'})) {
  scope.registerLazySingleton<ApiClient>(const _FakeApiClientFactory());
}
```

Отсюда три следствия:

- **Это остаётся опциональным до конца.** Параметр появляется, только когда что-то называет
  окружение, и даже тогда у него дефолт `CobaltEnvironment.defaultEnvironment` — то единственное
  окружение, в котором живёт неразделённый граф. Этот дефолт матчит только неограниченные
  регистрации, поэтому старт разделённого графа без выбора оставляет разделённые типы
  незарегистрированными, и первый же резолв падает, сообщая об этом, а не отдаёт молча не тот класс.
- **Ничто не регистрируется дважды.** Две регистрации одного ключа с пересекающимися окружениями —
  ошибка сборки, называющая обе; сюда входит и случай, когда одна не называет окружения вовсе, ведь
  неограниченная регистрация присутствует везде.
- **Полнота проверяется по каждому окружению отдельно**, поэтому `dev`-регистрация не удовлетворит
  зависимого, который работает и в `prod`.

Bootstrap-шаги тоже принимают окружения. Когда хоть один это делает, `$cobaltBootstrap` становится
функцией выбранного окружения, а пропущенные шаги не запускаются и не усыновляются.

`cobalt_environment_needs_a_registration` ловит случай, когда `@CobaltEnvironment` стоит на классе,
который никто не регистрирует, — там она молча ничего не делает.

---

## 16. Плагин линтера

Четырнадцать правил на том же слое разбора, которым пользуется генератор, — ошибка видна в редакторе,
а не только когда отработает `build_runner`.

```yaml
# analysis_options.yaml
plugins:
  cobalt_lint: ^0.2.0
```

| Правило | Что ловит |
|---|---|
| `cobalt_missing_injection_mixin` | `@injected`-поля без `with _$ClassName` на классе, который контейнер регистрирует |
| `cobalt_injected_field_needs_an_injectable` | `@injected`-поля на классе, который контейнер не регистрирует вовсе |
| `cobalt_param_needs_an_injectable` | `@CobaltParam` на классе, который контейнер не регистрирует вовсе |
| `cobalt_injected_field_must_be_late_final` | `@injected` на изменяемом, не-late или статическом поле |
| `cobalt_injectable_must_be_constructible` | `@CobaltInject` на абстрактном классе или классе без публичного генеративного конструктора |
| `cobalt_init_requires_init_method` | `@CobaltInit` на классе без `init()` |
| `cobalt_bootstrap_requires_run_method` | `@CobaltBootstrap` на классе без `run()` |
| `cobalt_bootstrap_step_cannot_inject` | bootstrap-шаг, чей конструктор берёт обязательные параметры |
| `cobalt_environment_needs_a_registration` | `@CobaltEnvironment` на классе, который никто не регистрирует |
| `cobalt_dependency_is_not_registered` | инъектируемая зависимость, которую ничто в пакете не регистрирует |
| `cobalt_dependency_cycle` | инъектируемый класс, который в итоге зависит от самого себя |
| `cobalt_registration_is_never_released` | зарегистрированный класс с `dispose()` или `close()`, которых скоуп не видит |
| `cobalt_resource_is_never_closed` | Регистрация держит то, что надо закрывать, и не предлагает способа закрыть |
| `cobalt_lazy_registration_injected_synchronously` | ленивая async-регистрация внедрена туда, где её некому ждать, — в синхронный или eager-конструктор или в `@injected`-поле |

Две вещи про подключение стоят реального времени:

1. Секция `plugins:` **работает только в корне пакета или workspace**. Во вложенном
   `analysis_options.yaml` она молча игнорируется — ни ошибки, ни диагностик. По той же причине
   `dart analyze <вложенный/каталог>` её не применяет; анализируйте корень workspace.
2. Сервер анализа кэширует сборку плагина на контекст. «Правило не срабатывает» чаще означает
   устаревшую сборку, чем неверное правило: тронь файл плагина или перезапусти сервер.

Последние два правила отвечают на те же вопросы, что и генератор, только раньше и без полной сборки.
Они сознательно тише генератора: читают синтаксический индекс пакета, поэтому там, где индекс не
может быть уверен, они молчат, а не сообщают о том, что на самом деле в порядке. Авторитет — сборка;
редактор — быстрый путь.

---

## 17. Наблюдение за графом

Наблюдатели видят появление скоупов, построение инстансов, завершение старта, падение разбора.
Передавайте их туда, где создаётся граф; каждый скоуп, поднятый ниже, их наследует.

`$startCobalt()` наблюдателей не принимает — это короткий путь. Как только они понадобились,
идите через билдер, который вы и так композируете:

```dart
final scope = await CobaltApplication.start(
  root: const NotesScope(notesEnvironment),
  bootstrap: $cobaltBootstrap(notesEnvironment),
  rootName: $cobaltRootScopeName,
  observers: [CobaltLogObserver(const CobaltDeveloperLogSink())],
);
```

Во Flutter-приложении это параметр `observers:` у `CobaltAppScope.builder`.

В колбэки приходят `CobaltScopeRef` и `CobaltKey` — описатели, а не живые объекты, — и исключение из
колбэка проглатывается: наблюдение не должно ломать наблюдаемое. Резолв не логируется: попадание в
кэш — горячий путь, а видеть стоит **построение** инстанса.

| Пакет | Форма |
|---|---|
| `cobalt_talker` | наблюдатель, свой цветной тип лога на семейство событий |
| `cobalt_logging` | sink поверх `logging` с dart.dev |
| `cobalt_logger` | sink поверх `logger` |

Всё остальное — один колбэк, поэтому ни один логгер не остаётся за бортом из-за отсутствия пакета:

```dart
CobaltLogObserver(CobaltLogSink.from((r) => myLogger.debug(r.message)))
CobaltLogObserver(CobaltLogSink.from((r) => gelf.send(r.toStructured())))
```

Запись — не просто строка: в ней `level`, `scope`, `key`, `error`, `stackTrace` и `kind`, причём
`kind` — значение (`CobaltEventKind.scopeInitFailed`), а не предложение, которое пришлось бы
разбирать.

### Крашрепортинг — другая форма

Отчёт делает полезным не исключение, а то, что граф делал перед этим.

```dart
observers: [
  CobaltErrorObserver(
    CobaltErrorSink.from((report) => Sentry.captureException(
      report.error,
      stackTrace: report.stackTrace,
      withScope: (scope) => scope.setContexts('cobalt', report.toStructured()),
    )),
  ),
],
```

След — кольцо из 20 записей, копящееся на всех уровнях, включая поинстансные, которые лог-sink
отбрасывает. Порог — `error`, а не `warning`: упавший разбор действительно означает утечку, но
дёргать платный сервис на каждую заминку — верный способ добиться, чтобы отчёты перестали читать.
Понижается через `reportAt`.

### На экране, пока приложение работает

```dart
final log = CobaltInspectorLog();

// observers: [log]

CobaltInspectorScreen(log: log, scope: context.cobaltScope)
```

Три вкладки: живое дерево скоупов с временем жизни каждой регистрации и её владельцем; то, что
действительно построено; и всё, о чём сообщили, — с поиском и паузой. Открытие дерева ничего не
строит: материализовать ленивый синглтон ради показа значило бы изменить то, на что вы пришли
посмотреть.

---

## 18. Тесты

Первое, что надо знать, — это ловушка, а не API. `testWidgets` выполняет своё тело в fake-async
зоне, где `Future.delayed` в инициализаторе не завершается никогда. **Стройте граф в `setUp`**, а
утверждения обо всём графе держите в обычном `test`.

```dart
late CobaltScope scope;

setUp(() async {
  scope = await cobaltTestScope(root: const $CobaltRootScope());
});
```

Сгенерированный билдер идёт туда напрямую — ровно так же, как им пользуется приложение.
`cobaltTestScope` и `cobaltTestRoot` разбираются вместе с тестом: это как раз та часть, которую легко
забыть, а забытая она не падает, а протекает в следующий тест.

### Подмена

Отдайте замену сгенерированной функции старта или тестовому хелперу, который её вызывает. Она
попадает в корень, где зарегистрировано всё сгенерированное, а сгенерированная регистрация того же
ключа пропускается, а не падает как дубликат:

```dart
final scope = await cobaltTestScope(
  root: const $CobaltRootScope(),
  overrides: [CobaltOverride<ApiClient>.value(FakeApiClient())],
);
```

Тот же список принимает `$startCobalt(overrides: [...])`, а `CobaltAppScope(overrides: () => [...])` —
функцию, которую вызывает на каждом старте, чтобы рестарт не получил значение, уже закрытое прошлым
графом; в приложении это флейвор или debug-меню. `.value` принимает готовый объект, `.lazy` и `.transient` —
фабрику, `CobaltParamOverride<T, P>` — параметризованную. Eager-синглтон эмитится как
`registerEagerSingleton`, поэтому подменённый не строится вовсе.

Подмена никогда не бывает тихой: наблюдатели получают `onRegistrationOverridden`, а
`overriddenKeys` перечисляет подменённое. Указывайте аргумент типа — внутри списка Dart выводит его
как `Object`, и скоуп отвергает такой override сразу при создании.

Затенение из дочернего скоупа по-прежнему работает и достаёт только до того, что резолвится из
дочернего скоупа:

```dart
final overrides = scope.pushForTest()
  ..registerSingleton<ApiClient>(FakeApiClient());
```

**Фабрика выполняется на скоупе, которому принадлежит её собственная регистрация**, а всё
сгенерированное живёт в корне, поэтому каждый сгенерированный потребитель получает настоящий
`ApiClient`. `ownerOf<T>()` говорит об этом раньше, чем тест:

```dart
expect(scope.ownerOf<Repository>(), same(scope.root));
```

### Что всё ещё требует проверки в рантайме

Проверка полноты покрывает сгенерированный контейнер. Две вещи лежат вне неё и стоят теста:

```dart
await expectGraphResolves(scope);
```

Первая — всё, что вы пообещали через `provides:`: проверка вам поверила. Вторая — любая рукописная
регистрация, которую вы вкомпоновали ([§6](#6-композиция-поверх-сгенерированного-корня)).

Он терминален: резолв **и есть** проверка, поэтому после него каждый ленивый синглтон построен, а
порядок разбора другой. Держите его в отдельном тесте. Параметризованная регистрация попадает в
отчёт поимённо как `unchecked`, а не пропускается молча, — дайте ей образец, чтобы покрыть:

```dart
await expectGraphResolves(scope, params: {CobaltKey(Greeting): (name: 'x', loud: false)});
```

### Фикстуры

```dart
final scope = cobaltTestRoot()
  ..registerLazySingleton<Clock>(FnFactory((_) => FixedClock(DateTime(2026))))
  ..registerSingleton<Config>(const Config())
  ..registerAsyncSingleton<Db>(AsyncFnFactory((_) async => Db()));

await scope.init();
```

Они избавляют от класса-фабрики на каждую заглушку в тестах, которым не нужен весь сгенерированный
граф. Async-регистрации обязаны существовать **до** `init()` — поэтому фикстуры кладутся в свежий
корень, а не в уже запущенный скоуп.

`DisposeRecorder` — фикстура для утверждений о разборе, с журналом на инстанс, а не общим: скоуп,
разобравшийся после своего теста, не сможет отчитаться в следующий. `CapturingObserver` собирает
события для утверждений о том, что граф делал.

### Виджет-тесты

`cobalt_test_flutter` несёт два хелпера, у которых очевидное написание — неверное:

```dart
await settle(tester);                    // не pumpAndSettle: он крутится вечно на индикаторе загрузки
final scope = mountedRootScope(tester);  // граф приложения, из-под билдера MaterialApp
```

### Как держать сгенерированный код честным в CI

Перегенерировать и упасть на диффе:

```bash
dart run build_runner build
git diff --exit-code
```

Без этого вывод генератора расходится с аннотациями, и никто не замечает, пока граф не окажется
неверным в рантайме.

---

## 19. Ошибки, о которых стоит знать заранее

Каждая найдена дорого — в этом репозитории или в приложениях, ради которых он писался.

- **Не закоммитить `cobalt.g.dart` или закоммитить устаревший.** Перегенерируйте в CI и сверяйте
  диффом. Это единственная реальная обязанность по обслуживанию в этом режиме.
- **Два `@CobaltScopeRoot` в одном пакете.** Ошибка сборки, и лечится она двумя пакетами:
  `cobalt_container` агрегирует весь пакет в один корень.
- **`@CobaltInject` на generic-классе.** Отвергается: генератору никто не говорит, какие
  инстанциации регистрировать. Разметьте конкретный подтип или выставьте его через `exposeAs`.
  Дженерики прекрасно работают как зависимости и как цели `exposeAs`.
- **`@injected` без `with _$ClassName`.** Поля остаются незаполненными, и первое же чтение даёт
  `LateError`. Линтер скажет раньше.
- **Пообещать через `provides:` и не зарегистрировать.** Проверка вам поверила, поэтому отказ уехал
  в рантайм. Покрывайте `expectGraphResolves`.
- **Построение графа внутри `testWidgets`.** Fake-async, ничего не завершается, таймаут, которому
  нечего предъявить. `setUp`.
- **Подмена ниже потребителя.** Фабрика выполняется на скоупе-владельце. `ownerOf<T>()` скажет об
  этом раньше, чем ассерт.
- **`BlocProvider(create:)` для блока, которым владеет скоуп.** Два владельца, и виджет успевает
  первым. `BlocProvider.value`.
- **`ChangeNotifier` или `Cubit`, зарегистрированный без объявления закрываемости.** Построен,
  использован, никогда не закрыт, молча. `implements Disposable`, `with CobaltBloc` или `dispose:`.
- **Старый `dart` первым в PATH.** Ломается негромко и не там: `dart analyze` выдаёт фантомные issue
  против чужого анализатора, а вывод генератора смещается между версиями форматтера. Проверяйте
  `dart --version`, прежде чем верить прогону.

---

## Куда дальше

- [GUIDE_MANUAL.ru.md](GUIDE_MANUAL.ru.md) — тот же рантайм без шага сборки и что с чем
  композируется.
- [README.ru.md](README.ru.md) — что такое Cobalt и почему каждое решение принято именно так.
- [MIGRATION.ru.md](MIGRATION.ru.md) — с `get_it` и `injectable`, включая то, что не переводится.
- `examples/codegen_basics` — наименьшая генерируемая обвязка, `examples/notes_app` — наибольшая.
  Оба запускаются из галереи: `cd examples/gallery && flutter run`.
