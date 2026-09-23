// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'gallery_l10n.dart';

// ignore_for_file: type=lint

/// The translations for Russian (`ru`).
class GalleryL10nRu extends GalleryL10n {
  GalleryL10nRu([String locale = 'ru']) : super(locale);

  @override
  String get appTitle => 'Примеры Cobalt';

  @override
  String get tagline => 'внедрение зависимостей · примеры';

  @override
  String get lede =>
      'По одному примеру на возможность. Большинство открывается прямо здесь, а те, что только печатают, показывают свой вывод.';

  @override
  String get languageTooltip => 'язык';

  @override
  String get allExamples => 'Все примеры';

  @override
  String get whatItShows => 'Что показывает';

  @override
  String get openExample => 'Открыть пример';

  @override
  String get copyCommand => 'Скопировать команду';

  @override
  String get commandCopied => 'Команда скопирована';

  @override
  String get kindScreen => 'экран';

  @override
  String get kindTerminal => 'терминал';

  @override
  String get whereItLives => 'Где лежит код';

  @override
  String get consoleOutput => 'Вывод в консоль';

  @override
  String get testOutput => 'Вывод тестов';

  @override
  String get sectionStartup => 'Старт';

  @override
  String get sectionStartupBlurb =>
      'Как поднять граф и как выбрать, какой именно';

  @override
  String get sectionInjection => 'Инъекция';

  @override
  String get sectionInjectionBlurb =>
      'Как зависимости попадают в тех, кому они нужны';

  @override
  String get sectionScopes => 'Скоупы и время жизни';

  @override
  String get sectionScopesBlurb => 'Когда граф появляется и когда исчезает';

  @override
  String get sectionCodegen => 'Кодогенерация';

  @override
  String get sectionCodegenBlurb =>
      'Что пишет генератор — и то же самое руками';

  @override
  String get sectionObservability => 'Наблюдаемость';

  @override
  String get sectionObservabilityBlurb => 'Как посмотреть, что делает граф';

  @override
  String get sectionTesting => 'Тестирование';

  @override
  String get sectionTestingBlurb =>
      'Как подменять зависимости и на чём здесь спотыкаются';

  @override
  String get startupTitle => 'Двухфазный старт';

  @override
  String get startupTeaches =>
      'Bootstrap-шаги идут до того, как появится контейнер, а async-инициализаторы выполняются как граф.';

  @override
  String get startupPoint1 =>
      'Шаги фазы 0 усыновляются корневым скоупом и освобождаются вместе с ним';

  @override
  String get startupPoint2 =>
      'Шаг, который что-то открыл, закрывается последним — после всего, что построено поверх него';

  @override
  String get startupPoint3 =>
      'Фаза 1 ждёт @CobaltInit как граф, поэтому независимые ветки идут параллельно';

  @override
  String get startupPoint4 =>
      'Порядок задаёт dependsOn — саму последовательность вы не пишете никогда';

  @override
  String get environmentsTitle => 'Окружения';

  @override
  String get environmentsTeaches =>
      'Один интерфейс, своя реализация на каждую сборку.';

  @override
  String get environmentsPoint1 =>
      '@CobaltEnvironment повторяется, а не принимает список: регистрация принадлежит множеству, а старт выбирает одно';

  @override
  String get environmentsPoint2 =>
      'Две регистрации с пересекающимися окружениями роняют сборку, а не приложение';

  @override
  String get environmentsPoint3 =>
      'Если окружение не выбрано, разделённые типы просто не зарегистрированы — и промах будет громким';

  @override
  String get environmentsPoint4 =>
      'В Manual Mode пишется тот же `if`, что эмитит генератор';

  @override
  String get lazyAsyncTitle => 'Ленивый async';

  @override
  String get lazyAsyncTeaches =>
      'Дорогой объект, который строит первый попросивший экран, а не старт.';

  @override
  String get lazyAsyncPoint1 =>
      'registerLazyAsyncSingleton или @CobaltInit(lazy: true) выводит его из init(), и старт его не ждёт';

  @override
  String get lazyAsyncPoint2 =>
      'Первый getAsync строит его; все, кто спросил одновременно, ждут одну и ту же сборку';

  @override
  String get lazyAsyncPoint3 =>
      'CobaltAsyncBuilder показывает загрузку один раз — экран, открытый позже, рисует сразу';

  @override
  String get lazyAsyncPoint4 =>
      'Упавшая сборка не запоминается, поэтому повтор строит заново';

  @override
  String get lazyAsyncStarted => 'старт закончен';

  @override
  String get lazyAsyncOpen => 'Открыть поиск';

  @override
  String get lazyAsyncOpenDetail =>
      'первый заход строит движок, следующие находят его готовым';

  @override
  String get lazyAsyncSearchTitle => 'Поиск';

  @override
  String get lazyAsyncBuilding => 'движок строится…';

  @override
  String lazyAsyncBuilds(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'движок построен $count раза',
      many: 'движок построен $count раз',
      few: 'движок построен $count раза',
      one: 'движок построен один раз',
      zero: 'движок ещё не построен',
    );
    return '$_temp0';
  }

  @override
  String lazyAsyncReady(String instance) {
    return 'движок готов · инстанс $instance';
  }

  @override
  String get propertyTitle => 'Инъекция в поля';

  @override
  String get propertyTeaches =>
      'Контроллер с пустым конструктором, поля которого заполняет граф.';

  @override
  String get propertyPoint1 =>
      'Миксин генерируется рядом с классом и заполняет поля сразу после конструктора';

  @override
  String get propertyPoint2 =>
      'Поля могут быть приватными: part-файл лежит в той же библиотеке';

  @override
  String get propertyPoint3 =>
      'late final соблюдается, поэтому повторное присваивание бросает, а не подменяет зависимость молча';

  @override
  String get propertyPoint4 =>
      'Именно это убирает от пяти до четырнадцати аргументов конструктора';

  @override
  String get namedTitle => 'Именованные и множественная инъекция';

  @override
  String get namedTeaches =>
      'Несколько реализаций за одним интерфейсом, различаемых по имени.';

  @override
  String get namedPoint1 =>
      '@Named выбирает одну регистрацию из нескольких для одного типа';

  @override
  String get namedPoint2 =>
      'getAll возвращает все регистрации типа в порядке регистрации';

  @override
  String get namedPoint3 =>
      'Дубликат того же ключа в одном скоупе — ошибка, а не молчаливое «побеждает последний»';

  @override
  String get widgetScopeTitle => 'Скоуп, которым владеет виджет';

  @override
  String get widgetScopeTeaches =>
      'Граф, который живёт ровно столько, сколько один экран.';

  @override
  String get widgetScopePoint1 =>
      'CobaltScopedStatefulWidget регистрирует в скоуп, которым владеет сам';

  @override
  String get widgetScopePoint2 =>
      'Уход с экрана разбирает всё, что экран построил';

  @override
  String get widgetScopePoint3 =>
      'registerParamFactory передаёт значение в конструктор';

  @override
  String get widgetScopePoint4 =>
      'Родительский граф не трогается: это ребёнок, а не изменение';

  @override
  String get sessionTitle => 'Сессионный скоуп';

  @override
  String get sessionTeaches => 'Логаут — это один dispose() и больше ничего.';

  @override
  String get sessionPoint1 =>
      'Всё, что построила сессия, уходит вместе с сессионным скоупом';

  @override
  String get sessionPoint2 =>
      'Ни один репозиторий не реализует reset(), и никто не подписан на сессию';

  @override
  String get sessionPoint3 =>
      'Это и есть аргумент за дерево скоупов вместо плоского стека';

  @override
  String get scopeTreeTitle => 'Дерево скоупов';

  @override
  String get scopeTreeTeaches =>
      'Живая иерархия, нарисованная по самим скоупам.';

  @override
  String get scopeTreePoint1 =>
      'CobaltScope.children публичен, поэтому дерево можно осмотреть в рантайме';

  @override
  String get scopeTreePoint2 =>
      'Откройте два примера — их деревья не связаны, у каждого свой корень';

  @override
  String get scopeTreePoint3 =>
      'Глубина и родитель лежат на самом скоупе — это и читает диагностика';

  @override
  String get flowTitle => 'Навигационные флоу';

  @override
  String get flowTeaches =>
      'Скоуп, живущий ровно столько, сколько открыт навигационный флоу.';

  @override
  String get flowPoint1 =>
      'CobaltShellRoute: вошли во флоу — скоуп появился, вышли — исчез';

  @override
  String get flowPoint2 =>
      'identity пересоздаёт скоуп, когда меняется предмет флоу';

  @override
  String get flowPoint3 =>
      'Вкладки: ветка держится живой, а не видимой, поэтому переключение ничего не разбирает';

  @override
  String get flowPoint4 =>
      'Ни одной подписки на роутер: владение принадлежит дереву виджетов';

  @override
  String get teardownTitle => 'Разбор графа';

  @override
  String get teardownTeaches =>
      'Что на самом деле гарантирует разбор: порядок, сбои, таймауты, усыновление.';

  @override
  String get teardownPoint1 =>
      'LIFO по порядку создания, а не по порядку объявления';

  @override
  String get teardownPoint2 =>
      'Упавший dispose записывается, остальные всё равно выполняются';

  @override
  String get teardownPoint3 =>
      'Зависший dispose упирается в дедлайн и попадает в отчёт, а не ждётся вечно';

  @override
  String get teardownPoint4 =>
      'adopt() привязывает к скоупу время жизни объекта, который не является зависимостью';

  @override
  String get codegenTitle => 'Сгенерированный контейнер';

  @override
  String get codegenTeaches =>
      'Наименьшая возможная генерируемая обвязка — и что она пишет.';

  @override
  String get codegenPoint1 =>
      'Поставьте @cobaltInject на класс — и появится lib/cobalt.g.dart';

  @override
  String get codegenPoint2 =>
      'В выходе — именованные const-классы фабрик, никогда не замыкания';

  @override
  String get codegenPoint3 =>
      'Регистрации упорядочены топологической сортировкой на этапе сборки';

  @override
  String get codegenPoint4 =>
      'Цикл зависимостей роняет сборку, называя сам цикл';

  @override
  String get manualTitle => 'Ручной режим';

  @override
  String get manualTeaches => 'Тот же граф без генерации и без Flutter.';

  @override
  String get manualPoint1 =>
      'Генератор пишет ровно это, пользуясь только публичным API';

  @override
  String get manualPoint2 =>
      'Чистый Dart: работает в CLI, на сервере, в обычном тесте';

  @override
  String get manualPoint3 =>
      'CobaltScopeBuilder композируется — именно это заменяет модули';

  @override
  String get manualPoint4 =>
      'Если генерации однажды понадобится то, чего здесь не выразить, — это два фреймворка под одним именем';

  @override
  String get eventsTitle => 'События графа';

  @override
  String get eventsTeaches =>
      'Граф рассказывает о себе, и это уходит в логгер, которым вы уже пользуетесь.';

  @override
  String get eventsPoint1 =>
      'События CobaltObserver: пуш скоупа, создание объекта, падение разбора';

  @override
  String get eventsPoint2 =>
      'Одна строка, чтобы подключить talker, logging, logger или любой другой логгер';

  @override
  String get eventsPoint3 =>
      'CobaltMultiSink раздаёт запись веером; упавший приёмник не заглушает остальные';

  @override
  String get eventsPoint4 =>
      'Резолв намеренно не логируется: попадание в кэш — горячий путь';

  @override
  String get inspectorTitle => 'Инспектор внутри приложения';

  @override
  String get inspectorTeaches =>
      'Живое дерево, что построено и с каким временем жизни — на экране внутри приложения.';

  @override
  String get inspectorPoint1 =>
      'Дерево обходится по живым скоупам, а не собирается заново по событиям';

  @override
  String get inspectorPoint2 =>
      'Каждая регистрация несёт своё время жизни, читаемое через debugKindOf';

  @override
  String get inspectorPoint3 =>
      'Нажатие показывает факты; создание — отдельное действие, которое называет свою цену';

  @override
  String get inspectorPoint4 =>
      'Eager-синглтон виден в дереве и никогда — в списке созданного';

  @override
  String get testingTitle => 'Приёмы тестирования';

  @override
  String get testingTeaches =>
      'Как подменять зависимости в тесте и на чём здесь спотыкаются.';

  @override
  String get testingPoint1 =>
      'Подмена — это пуш дочернего скоупа и повторная регистрация: затенение, а не мутация';

  @override
  String get testingPoint2 =>
      'Стройте граф в setUp: testWidgets работает в fake-async зоне';

  @override
  String get testingPoint3 =>
      'Глобального контейнера нет, поэтому один тест не протечёт в следующий';

  @override
  String get testingPoint4 =>
      'Дубликат в одном скоупе — ошибка; затенение из ребёнка — поддерживаемый путь';

  @override
  String get demoTitle => 'Cobalt · инспектор';

  @override
  String get demoInspect => 'осмотреть граф';

  @override
  String get demoOpenSession => 'Открыть сессионный скоуп';

  @override
  String get demoOpenSessionHint =>
      'пуш, async-инициализация, несколько объектов';

  @override
  String get demoCloseSession => 'Закрыть сессию';

  @override
  String get demoNothingOpen => 'ничего не открыто';

  @override
  String get demoTearsItDown => 'разберёт её';

  @override
  String get demoThenOpen => 'Затем откройте инспектор из шапки';

  @override
  String get demoThenOpenHint => 'дерево, созданное и всё, о чём сообщил граф';

  @override
  String get hostFailed => 'Пример не запустился';

  @override
  String get hostRetry => 'Повторить';
}
