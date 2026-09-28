import 'package:cobalt_analyzer/cobalt_analyzer.dart';
import 'package:code_builder/code_builder.dart';

class InjectionMixinEmitter {
  const InjectionMixinEmitter();

  String emit(CobaltInjectableClass declaration) =>
      emitFor(declaration.type, declaration.properties);

  /// The mixin for a class of [type] whose `@injected` fields are
  /// [properties] — a registration or a decorator alike.
  String emitFor(CobaltTypeRef type, List<CobaltInjectedProperty> properties) {
    final mixin = Mixin(
      (b) => b
        ..name = '_\$${type.name}'
        ..implements.add(refer('CobaltInjectable'))
        ..methods.addAll([
          for (final property in properties) _setter(property),
          _onInject(properties),
        ]),
    );

    return Library(
      (b) => b..body.add(mixin),
    ).accept(DartEmitter(useNullSafetySyntax: true)).toString();
  }

  /// The setter takes the field's own type, nullability included.
  ///
  /// An optional field is assigned null when nothing registers it, so
  /// `set _clock(Clock value)` would not compile against `late final Clock?`.
  Method _setter(CobaltInjectedProperty property) => Method(
    (m) => m
      ..name = property.field
      ..type = MethodType.setter
      ..requiredParameters.add(
        Parameter(
          (p) => p
            ..name = 'value'
            ..type = refer(_declaredTypeName(property.type)),
        ),
      ),
  );

  Method _onInject(List<CobaltInjectedProperty> properties) => Method(
    (m) => m
      ..name = 'onInject'
      ..annotations.add(refer('override'))
      ..returns = refer('void')
      ..requiredParameters.add(
        Parameter(
          (p) => p
            ..name = 'resolver'
            ..type = refer('CobaltResolver'),
        ),
      )
      ..body = Block.of([
        for (final property in properties)
          refer(property.field).assign(_resolve(property)).statement,
      ]),
  );

  Expression _resolve(CobaltInjectedProperty property) {
    final name = property.name;
    return refer('resolver')
        .property(property.type.isNullable ? 'getOrNull' : 'get')
        .call(
          const [],
          {if (name != null) 'name': literalString(name)},
          [refer(_localTypeName(property.type))],
        );
  }

  /// The type as the field declares it, `?` included.
  static String _declaredTypeName(CobaltTypeRef type) =>
      type.isNullable ? '${_localTypeName(type)}?' : _localTypeName(type);

  /// The type as a resolve asks for it: never nullable, because
  /// `CobaltResolver` bounds its type parameters to `Object`.
  static String _localTypeName(CobaltTypeRef type) {
    final buffer = StringBuffer(type.name);
    if (type.typeArguments.isNotEmpty) {
      buffer
        ..write('<')
        ..write(type.typeArguments.map(_localTypeName).join(', '))
        ..write('>');
    }
    return buffer.toString();
  }
}
