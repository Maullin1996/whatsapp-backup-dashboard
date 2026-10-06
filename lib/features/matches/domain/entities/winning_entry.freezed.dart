// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'winning_entry.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$WinningEntry {

/// Identificador de la lotería (clave de `lotteryKey`; ver
/// `lib/core/lotteries/lotteries.dart`). Puede venir fuera de la lista o
/// vacío (entrada sin slug): esa no coincide con nada.
 String get loteria;/// El número ganador, tal cual (conserva ceros a la izquierda).
 String get numero;
/// Create a copy of WinningEntry
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$WinningEntryCopyWith<WinningEntry> get copyWith => _$WinningEntryCopyWithImpl<WinningEntry>(this as WinningEntry, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is WinningEntry&&(identical(other.loteria, loteria) || other.loteria == loteria)&&(identical(other.numero, numero) || other.numero == numero));
}


@override
int get hashCode => Object.hash(runtimeType,loteria,numero);

@override
String toString() {
  return 'WinningEntry(loteria: $loteria, numero: $numero)';
}


}

/// @nodoc
abstract mixin class $WinningEntryCopyWith<$Res>  {
  factory $WinningEntryCopyWith(WinningEntry value, $Res Function(WinningEntry) _then) = _$WinningEntryCopyWithImpl;
@useResult
$Res call({
 String loteria, String numero
});




}
/// @nodoc
class _$WinningEntryCopyWithImpl<$Res>
    implements $WinningEntryCopyWith<$Res> {
  _$WinningEntryCopyWithImpl(this._self, this._then);

  final WinningEntry _self;
  final $Res Function(WinningEntry) _then;

/// Create a copy of WinningEntry
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? loteria = null,Object? numero = null,}) {
  return _then(_self.copyWith(
loteria: null == loteria ? _self.loteria : loteria // ignore: cast_nullable_to_non_nullable
as String,numero: null == numero ? _self.numero : numero // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [WinningEntry].
extension WinningEntryPatterns on WinningEntry {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _WinningEntry value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _WinningEntry() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _WinningEntry value)  $default,){
final _that = this;
switch (_that) {
case _WinningEntry():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _WinningEntry value)?  $default,){
final _that = this;
switch (_that) {
case _WinningEntry() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String loteria,  String numero)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _WinningEntry() when $default != null:
return $default(_that.loteria,_that.numero);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String loteria,  String numero)  $default,) {final _that = this;
switch (_that) {
case _WinningEntry():
return $default(_that.loteria,_that.numero);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String loteria,  String numero)?  $default,) {final _that = this;
switch (_that) {
case _WinningEntry() when $default != null:
return $default(_that.loteria,_that.numero);case _:
  return null;

}
}

}

/// @nodoc


class _WinningEntry implements WinningEntry {
  const _WinningEntry({required this.loteria, required this.numero});
  

/// Identificador de la lotería (clave de `lotteryKey`; ver
/// `lib/core/lotteries/lotteries.dart`). Puede venir fuera de la lista o
/// vacío (entrada sin slug): esa no coincide con nada.
@override final  String loteria;
/// El número ganador, tal cual (conserva ceros a la izquierda).
@override final  String numero;

/// Create a copy of WinningEntry
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$WinningEntryCopyWith<_WinningEntry> get copyWith => __$WinningEntryCopyWithImpl<_WinningEntry>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _WinningEntry&&(identical(other.loteria, loteria) || other.loteria == loteria)&&(identical(other.numero, numero) || other.numero == numero));
}


@override
int get hashCode => Object.hash(runtimeType,loteria,numero);

@override
String toString() {
  return 'WinningEntry(loteria: $loteria, numero: $numero)';
}


}

/// @nodoc
abstract mixin class _$WinningEntryCopyWith<$Res> implements $WinningEntryCopyWith<$Res> {
  factory _$WinningEntryCopyWith(_WinningEntry value, $Res Function(_WinningEntry) _then) = __$WinningEntryCopyWithImpl;
@override @useResult
$Res call({
 String loteria, String numero
});




}
/// @nodoc
class __$WinningEntryCopyWithImpl<$Res>
    implements _$WinningEntryCopyWith<$Res> {
  __$WinningEntryCopyWithImpl(this._self, this._then);

  final _WinningEntry _self;
  final $Res Function(_WinningEntry) _then;

/// Create a copy of WinningEntry
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? loteria = null,Object? numero = null,}) {
  return _then(_WinningEntry(
loteria: null == loteria ? _self.loteria : loteria // ignore: cast_nullable_to_non_nullable
as String,numero: null == numero ? _self.numero : numero // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

// dart format on
