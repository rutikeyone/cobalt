<p align="center">
  <a href="MIGRATION.md">English</a> · <a href="MIGRATION.ru.md">Русский</a> · <a href="MIGRATION.zh-CN.md">中文</a>
</p>

> Перевод [MIGRATION.md](MIGRATION.md). Канонический текст — английский: при расхождении верен он.

# Миграция на Cobalt

Никто не начинает Flutter-приложение без DI, чтобы потом пойти выбирать фреймворк. Вы здесь потому,
что у вас уже есть `get_it` — или `get_it` + `injectable` — и что-то в нём перестало масштабироваться.

Гайд состоит из двух половин: что во что переводится и что не переводится вовсе. Полезна вторая.

## Единственное правило, с которым миграция переживаема

**Двигайтесь от листьев внутрь.** Сначала регистрируйте то, от чего не зависит ничто; дайте Cobalt и
старому контейнеру сосуществовать; и переводите корень только тогда, когда всё под ним уже принадлежит
Cobalt.

Manual Mode существует ровно для этого. Сгенерированный контейнер и рукописный — один и тот же
рантайм, поэтому наполовину смигрированное приложение это нормальное состояние, а не сломанное:

```dart
final app = await CobaltApplication.start(root: const AppScope());

// Всё, что ещё не переехало, по-прежнему приходит из get_it. Одна строка, удаляется последней.
GetIt.I.registerSingleton<Database>(app.get<Database>());
```

Не поддавайтесь искушению перевести корневой компонент первым. У него больше всего рёбер, и пока его
зависимости не принадлежат Cobalt, вы не выигрываете ничего.

## get_it → Cobalt

### Регистрация

| get_it | Cobalt |
|---|---|
| `registerFactory<T>(() => T())` | `registerFactory<T>(const TFactory())` |
| `registerSingleton<T>(instance)` | `registerSingleton<T>(instance)` |
| `registerLazySingleton<T>(() => T())` | `registerLazySingleton<T>(const TFactory())` |
| `registerSingletonAsync<T>(() async => …)` | `registerAsyncSingleton<T>(const TFactory())` |
| `registerSingletonWithDependencies<T>(…, dependsOn: [A])` | `registerAsyncSingleton<T>(…, dependsOn: {CobaltKey(A)})` |
| `registerLazySingletonAsync<T>(() async => …)` | `registerLazyAsyncSingleton<T>(const TFactory())` |
| `registerFactoryParam<T, P, void>((p, _) => …)` | `registerParamFactory<T, P>(const TFactory())` |
| `getIt<T>()` / `getIt.get<T>()` | `scope.get<T>()` |
| `getIt<T>(instanceName: 'a')` | `scope.get<T>(name: 'a')` |
| `await getIt.getAsync<T>()` | `await scope.getAsync<T>()` |
| `getIt.isRegistered<T>()` | `scope.isRegistered<T>()` |
| `pushNewScope(...)` | `scope.push('name')` |
| `popScope()` | `await child.dispose()` |
| `reset()` | `await root.dispose()` |

Видимое отличие — **объект-фабрика вместо замыкания**. Это покупает две вещи: регистрация может быть
`const`, а граф становится инспектируемым значением вместо захваченного состояния — именно это
позволяет генератору его эмитить, а линтеру читать.

### Жизненный цикл

У `allReady()` и `isReady<T>()` нет аналога, и он не нужен. `CobaltApplication.start` возвращается
только когда весь асинхронный граф поднят, так что опрашивать нечего и таймаут подбирать не надо:

```dart
// get_it
GetIt.I.registerSingletonAsync<Database>(() => Database.open());
await GetIt.I.allReady(timeout: const Duration(seconds: 30));

// Cobalt
final app = await CobaltApplication.start(root: const AppScope());
```

У `signalReady` и режима ручной сигнализации аналога тоже нет. Cobalt выводит готовность из графа, а не
из вашего объявления о ней.

### Скоупы — дерево, а не стек

Это то изменение, которое действительно важно, и то, на котором механический перенос ошибается.

Скоупы get_it — **плоский LIFO-стек**: `pushNewScope` всегда кладёт в один и тот же стек, а `get<T>()`
идёт по нему сверху вниз. Два независимых поддерева — скажем, две вкладки со своими сессиями —
невыразимы.

Скоупы Cobalt образуют **дерево**. `push` создаёт ребёнка *этого* скоупа, а резолв поднимается к корню
через родителей. То есть:

```dart
final tabA = app.push('tab:a');
final tabB = app.push('tab:b');   // сосед, а не «сверху на tabA»
```

Практические следствия при переносе:

- Пара `pushNewScope`/`popScope`, которая на деле означала «временная подмена», переносится напрямую.
  Та, что полагалась на порядок в стеке между несвязанными фичами, скорее всего прятала баг, который
  дерево делает невозможным.
- Разбор идёт LIFO **по порядку создания**, а не по порядку объявления. Если ваш старый teardown зависел
  от порядка объявления полей, он уже был хрупким.
- Кто скоуп создал, тот его и разбирает. Никакого «текущего скоупа» в воздухе нет.

### Чего у Cobalt нет

Знайте это до того, как решитесь переезжать:

- **`registerFactoryParam<T, P1, P2>`** — у Cobalt `registerParamFactory<T, P>` берёт один параметр,
  и несколько превращаются в одну запись (record). Берите **именованную** форму,
  `({int id, String title})`: она сохраняет имена и на месте вызова, и в фабрике, чего позиционная
  не делает. В запись едут только значения, которых контейнер знать не может, — зависимости
  по-прежнему приходят из резолвера, поэтому запись обычно короче списка параметров, который она
  заменяет. В Code-Gen Mode всё это писать не нужно: пометьте параметры `@CobaltParam`, и генератор
  сам напишет тип записи, фабрику и регистрацию.
- **`registerFactoryAsync`** — новая async-сборка на каждый вызов. У Cobalt есть ленивый async-
  *синглтон* (`registerLazyAsyncSingleton`, читается через `getAsync`): строится первым вызовом и
  удерживается; async-фабрики на каждый вызов нет. Постройте значение у вызывающего или
  зарегистрируйте ленивый синглтон, который выдаёт то, что нужно каждому вызову.
- **`resetLazySingletons`** — вместо этого разберите скоуп. Сброс инстансов под живыми держателями это
  ровно тот класс багов, ради предотвращения которого скоупы и существуют.
- **Глобальный инстанс.** Никакого `GetIt.I` нет. Скоуп передают, инжектят или читают из дерева виджетов
  через `context.cobalt<T>()`. Это осознанно: именно глобал делает графы get_it непригодными для
  параллельного тестирования.

## injectable → Cobalt

### Аннотации

| injectable | Cobalt |
|---|---|
| `@injectable` | `@cobaltTransient` — свежий инстанс на каждый резолв |
| `@singleton` | `@cobaltSingleton` — eager, строится при сборке контейнера |
| `@lazySingleton` | `@cobaltInject` — дефолт, и чаще всего именно он вам и нужен |
| `@Injectable(as: Foo)` | `@CobaltInject(exposeAs: Foo)` |
| `@Named('a')` | `@Named('a')` |
| `@Environment(Environment.dev)` | `@CobaltEnvironment.dev` — повторите аннотацию для нескольких |
| `@preResolve` | `@CobaltInit()` |
| `@disposeMethod` | `implements Disposable` / `AsyncDisposable` |
| `@factoryMethod` | первый публичный генеративный конструктор, а если нужен не он — член `@CobaltModule` |
| `@factoryParam` | `@CobaltParam` на параметре конструктора |
| `@InjectableInit()` + `configureDependencies()` | `@CobaltScopeRoot()` + сгенерированный `$startCobalt()` |

### Что меняет форму

**`@module` становится `@CobaltModule` и остаётся почти таким же.** Форма переносится без изменений —
класс, чьи члены отдают типы, которые вы не писали:

```dart
// injectable
@module
abstract class AppModule {
  @lazySingleton
  Dio get dio => Dio();
}

// Cobalt
@cobaltModule
class AppModule {
  const AppModule();

  @cobaltInject
  Dio get dio => Dio();
}
```

Три отличия. Класс **конкретный, с `const` конструктором**, а не абстрактный: Cobalt зовёт член на
`const AppModule()`, а не генерирует подкласс. **Абстрактные члены отвергаются** — у injectable они
значат «собери из собственного конструктора», а это ровно то, что уже значит `@CobaltInject` на
классе, привязка же к интерфейсу — это `exposeAs`. И асинхронность помечается одним лишь
`Future<T>`: `@preResolve` не нужен.

**`dispose:` заменяет `@disposeMethod` для чужих типов.** Свой класс реализует `Disposable`, а `Dio`
не может, поэтому способ закрытия называет регистрация: `@CobaltInject(dispose: closeClient)`.

**`@Order` исчезает.** injectable заставляет объявлять порядок; Cobalt его вычисляет. Регистрации
сортируются компайл-тайм топологической сортировкой, где поля с property injection считаются рёбрами
графа, а цикл валит сборку, называя цикл, а не рекурсирует до переполнения стека.

**Дженерик-классы отвергаются.** `@CobaltInject class Cache<T>` — ошибка сборки, потому что ничто не
сообщает генератору, какие инстанциации регистрировать. Аннотируйте конкретный подтип или выставьте
его: `@CobaltInject(exposeAs: Cache<Note>)`. Дженерик-*зависимости* работают нормально —
`Repository<User>` и `Repository<Order>` это разные регистрации.

### Что вы получаете

**Property injection** — то, ради чего стоит переезжать, если у ваших контроллеров от пяти до
четырнадцати аргументов конструктора:

```dart
// было
class NotesCubit extends Cubit<NotesState> {
  NotesCubit({
    required this.repository,
    required this.telemetry,
    required this.session,
    required this.formatter,
    required this.config,
  }) : super(const NotesState());
  …
}

// стало
@cobaltTransient
class NotesCubit extends Cubit<NotesState> with _$NotesCubit {
  NotesCubit() : super(const NotesState());

  @injected
  late final NoteStore _repository;

  @injected
  late final Telemetry _telemetry;
}
```

Миксин генерируется рядом с классом и заполняет поля сразу после конструктора. Поля могут быть
приватными — part-файл лежит в той же библиотеке. `late final` обязателен, поэтому повторное
присваивание бросит исключение, а не подменит зависимость молча.

**Настоящий разбор.** Скоуп владеет тем, что создал, и разбирает это в обратном порядке создания.
Выход из аккаунта становится `await sessionScope.dispose()` — ни одного слушателя сессии и ни одного
`reset()`, прибитого к доменным интерфейсам.

## flutter_bloc и provider → Cobalt

Ни то ни другое не заменяется целиком, и пути у них разные.

**`provider` — это то, чем `CobaltScopeProvider` уже является.** Если он у вас только для того, чтобы
пробросить контейнер вниз по дереву — а рукописный DI делает именно это, — такое применение
исчезает: `CobaltAppScope` публикует корень, а `context.cobalt<T>()` его читает. Если
`ChangeNotifierProvider` даёт поддереву объект со временем жизни — это `CobaltScopeWidget`, и время
жизни становится скоуповым, а не ручной бухгалтерией виджета.

**`flutter_bloc` не заменяется вовсе.** Блок строит Cobalt, рисует его по-прежнему `BlocBuilder`.
Резолвите там, где раньше создавали:

```dart
BlocProvider.value(
  value: context.cobalt<CounterCubit>(),
  child: const CounterView(),
)
```

Вслух стоит сказать про разбор. Скоуп освобождает то, что реализует `Disposable` или
`AsyncDisposable`, а `Cubit` закрывается через `Future<void> close()` — это не то и не другое.
Мостик пишется один раз на класс:

```dart
class CounterCubit extends Cubit<int> with CobaltBloc {}
```

Этот миксин — [`cobalt_bloc`](https://pub.dev/packages/cobalt_bloc), пакет существует ради одной этой
фразы; написать `implements AsyncDisposable` и `Future<void> dispose() => close();` руками — то же
самое. Для блока, в который не примешаться, называется функция:
`@CobaltInject(dispose: closeBloc)`. И провайдить через `BlocProvider.value`, а не
`BlocProvider(create: ...)`: второй закрывает то, что ему передали, а владеет этим скоуп.

`ChangeNotifier` требует ещё меньше: его `dispose` уже совпадает по сигнатуре, так что
`implements Disposable` — вся правка. Пропустите любое из двух — и объект построится, поработает и
не закроется никогда, молча. Полная таблица — в
[README `cobalt_flutter`](packages/cobalt_flutter/README.md).

## Разобранный порядок действий

1. Добавьте `cobalt` и `cobalt_annotations`; старый контейнер оставьте на месте.
2. Напишите корневой `CobaltScopeBuilder` с двумя-тремя листовыми сервисами, от которых не зависит ничто.
   Стартуйте его в `main` рядом со старым контейнером.
3. Мост: зарегистрируйте эти инстансы в старом контейнере, чтобы существующие места вызова продолжали
   работать.
4. Переводите потребителей этих листьев. Каждый переведённый убирает строку из моста.
5. Повторяйте, двигаясь внутрь. Мост монотонно сокращается — если он перестал сокращаться, оставшиеся
   рёбра что-то говорят вам о дизайне.
6. Когда мост опустеет, удалите старый контейнер и переведите приложение на `CobaltAppScope`.
7. Только теперь думайте о кодогенерации: добавьте `cobalt_generator` и заменяйте рукописные регистрации
   аннотациями по одному файлу за раз.

Шаг 7 намеренно последний. Генерация — это удобство поверх рантайма, которому вы уже должны доверять.
