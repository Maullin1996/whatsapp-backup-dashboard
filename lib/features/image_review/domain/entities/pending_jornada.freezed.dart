// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'pending_jornada.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$PendingJornada {

/// Día de la jornada (`yyyy-MM-dd`).
 String get fechaJornada;/// Mismo texto que guarda `ImageReviewRecord.shift`.
 String get shift; int get cantidad;
/// Create a copy of PendingJornada
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PendingJornadaCopyWith<PendingJornada> get copyWith => _$PendingJornadaCopyWithImpl<PendingJornada>(this as PendingJornada, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PendingJornada&&(identical(other.fechaJornada, fechaJornada) || other.fechaJornada == fechaJornada)&&(identical(other.shift, shift) || other.shift == shift)&&(identical(other.cantidad, cantidad) || other.cantidad == cantidad));
}


@override
int get hashCode => Object.hash(runtimeType,fechaJornada,shift,cantidad);

@override
String toString() {
  return 'PendingJornada(fechaJornada: $fechaJornada, shift: $shift, cantidad: $cantidad)';
}


}

/// @nodoc
abstract mixin class $PendingJornadaCopyWith<$Res>  {
  factory $PendingJornadaCopyWith(PendingJornada value, $Res Function(PendingJornada) _then) = _$PendingJornadaCopyWithImpl;
@useResult
$Res call({
 String fechaJornada, String shift, int cantidad
});




}
/// @nodoc
class _$PendingJornadaCopyWithImpl<$Res>
    implements $PendingJornadaCopyWith<$Res> {
  _$PendingJornadaCopyWithImpl(this._self, this._then);

  final PendingJornada _self;
  final $Res Function(PendingJornada) _then;

/// Create a copy of PendingJornada
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? fechaJornada = null,Object? shift = null,Object? cantidad = null,}) {
  return _then(_self.copyWith(
fechaJornada: null == fechaJornada ? _self.fechaJornada : fechaJornada // ignore: cast_nullable_to_non_nullable
as String,shift: null == shift ? _self.shift : shift // ignore: cast_nullable_to_non_nullable
as String,cantidad: null == cantidad ? _self.cantidad : cantidad // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [PendingJornada].
extension PendingJornadaPatterns on PendingJornada {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _PendingJornada value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _PendingJornada() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _PendingJornada value)  $default,){
final _that = this;
switch (_that) {
case _PendingJornada():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _PendingJornada value)?  $default,){
final _that = this;
switch (_that) {
case _PendingJornada() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String fechaJornada,  String shift,  int cantidad)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _PendingJornada() when $default != null:
return $default(_that.fechaJornada,_that.shift,_that.cantidad);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String fechaJornada,  String shift,  int cantidad)  $default,) {final _that = this;
switch (_that) {
case _PendingJornada():
return $default(_that.fechaJornada,_that.shift,_that.cantidad);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String fechaJornada,  String shift,  int cantidad)?  $default,) {final _that = this;
switch (_that) {
case _PendingJornada() when $default != null:
return $default(_that.fechaJornada,_that.shift,_that.cantidad);case _:
  return null;

}
}

}

/// @nodoc


class _PendingJornada implements PendingJornada {
  const _PendingJornada({required this.fechaJornada, required this.shift, required this.cantidad});
  

/// Día de la jornada (`yyyy-MM-dd`).
@override final  String fechaJornada;
/// Mismo texto que guarda `ImageReviewRecord.shift`.
@override final  String shift;
@override final  int cantidad;

/// Create a copy of PendingJornada
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PendingJornadaCopyWith<_PendingJornada> get copyWith => __$PendingJornadaCopyWithImpl<_PendingJornada>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _PendingJornada&&(identical(other.fechaJornada, fechaJornada) || other.fechaJornada == fechaJornada)&&(identical(other.shift, shift) || other.shift == shift)&&(identical(other.cantidad, cantidad) || other.cantidad == cantidad));
}


@override
int get hashCode => Object.hash(runtimeType,fechaJornada,shift,cantidad);

@override
String toString() {
  return 'PendingJornada(fechaJornada: $fechaJornada, shift: $shift, cantidad: $cantidad)';
}


}

/// @nodoc
abstract mixin class _$PendingJornadaCopyWith<$Res> implements $PendingJornadaCopyWith<$Res> {
  factory _$PendingJornadaCopyWith(_PendingJornada value, $Res Function(_PendingJornada) _then) = __$PendingJornadaCopyWithImpl;
@override @useResult
$Res call({
 String fechaJornada, String shift, int cantidad
});




}
/// @nodoc
class __$PendingJornadaCopyWithImpl<$Res>
    implements _$PendingJornadaCopyWith<$Res> {
  __$PendingJornadaCopyWithImpl(this._self, this._then);

  final _PendingJornada _self;
  final $Res Function(_PendingJornada) _then;

/// Create a copy of PendingJornada
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? fechaJornada = null,Object? shift = null,Object? cantidad = null,}) {
  return _then(_PendingJornada(
fechaJornada: null == fechaJornada ? _self.fechaJornada : fechaJornada // ignore: cast_nullable_to_non_nullable
as String,shift: null == shift ? _self.shift : shift // ignore: cast_nullable_to_non_nullable
as String,cantidad: null == cantidad ? _self.cantidad : cantidad // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

// dart format on
