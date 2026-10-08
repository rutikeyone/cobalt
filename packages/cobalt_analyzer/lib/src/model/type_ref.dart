class CobaltTypeRef {
  const CobaltTypeRef({
    required this.name,
    required this.import,
    this.typeArguments = const [],
    this.isNullable = false,
  });

  factory CobaltTypeRef.fromJson(Map<String, dynamic> json) => CobaltTypeRef(
    name: json['name'] as String,
    import: json['import'] as String?,
    typeArguments: [
      for (final arg in json['typeArguments'] as List<dynamic>)
        CobaltTypeRef.fromJson(arg as Map<String, dynamic>),
    ],
    isNullable: json['isNullable'] as bool? ?? false,
  );

  final String name;
  final String? import;
  final List<CobaltTypeRef> typeArguments;
  final bool isNullable;

  /// Identity of the registration this type refers to.
  ///
  /// Type arguments are part of it, because `Repository<User>` and
  /// `Repository<Order>` are separate registrations at runtime — `CobaltKey`
  /// is built from `Type`, and those are different types. Nullability is not,
  /// because it is never emitted into a resolve: a `Foo?` dependency reads the
  /// `Foo` registration. That holds for the outermost type only: a type
  /// argument keeps its `?`, since `Cache<Note?>` and `Cache<Note>` are
  /// different types at runtime. Keeping the two rules together is the point
  /// of this getter: they used to be stated separately in the model and in
  /// the generator, and disagreed.
  String get signature {
    final buffer = StringBuffer('$import#$name');
    if (typeArguments.isNotEmpty) {
      buffer
        ..write('<')
        ..write(
          typeArguments
              .map((a) => a.isNullable ? '${a.signature}?' : a.signature)
              .join(','),
        )
        ..write('>');
    }
    return buffer.toString();
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'import': import,
    'typeArguments': [for (final a in typeArguments) a.toJson()],
    'isNullable': isNullable,
  };

  @override
  bool operator ==(Object other) =>
      other is CobaltTypeRef && other.signature == signature;

  @override
  int get hashCode => signature.hashCode;

  @override
  String toString() {
    final buffer = StringBuffer(name);
    if (typeArguments.isNotEmpty) {
      buffer
        ..write('<')
        ..write(typeArguments.join(', '))
        ..write('>');
    }
    if (isNullable) buffer.write('?');
    return buffer.toString();
  }
}
