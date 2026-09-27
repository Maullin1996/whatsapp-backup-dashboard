// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'role_summary.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$RoleSummary {

/// false si ese rol todavía no registró nada en la jornada (los demás
/// campos van en 0).
 bool get registrado; int get cantidadImagenes; int get cantidadTickets;/// Suma de los totales de todos sus comprobantes, en pesos.
 int get totalSuma;
/// Create a copy of RoleSummary
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$RoleSummaryCopyWith<RoleSummary> get copyWith => _$RoleSummaryCopyWithImpl<RoleSummary>(this as RoleSummary, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is RoleSummary&&(identical(other.registrado, registrado) || other.registrado == registrado)&&(identical(other.cantidadImagenes, cantidadImagenes) || other.cantidadImagenes == cantidadImagenes)&&(identical(other.cantidadTickets, cantidadTickets) || other.cantidadTickets == cantidadTickets)&&(identical(other.totalSuma, totalSuma) || other.totalSuma == totalSuma));
}


@override
int get hashCode => Object.hash(runtimeType,registrado,cantidadImagenes,cantidadTickets,totalSuma);

@override
String toString() {
  return 'RoleSummary(registrado: $registrado, cantidadImagenes: $cantidadImagenes, cantidadTickets: $cantidadTickets, totalSuma: $totalSuma)';
}


}

/// @nodoc
abstract mixin class $RoleSummaryCopyWith<$Res>  {
  factory $RoleSummaryCopyWith(RoleSummary value, $Res Function(RoleSummary) _then) = _$RoleSummaryCopyWithImpl;
@useResult
$Res call({
 bool registrado, int cantidadImagenes, int cantidadTickets, int totalSuma
});




}
/// @nodoc
class _$RoleSummaryCopyWithImpl<$Res>
    implements $RoleSummaryCopyWith<$Res> {
  _$RoleSummaryCopyWithImpl(this._self, this._then);

  final RoleSummary _self;
  final $Res Function(RoleSummary) _then;

/// Create a copy of RoleSummary
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? registrado = null,Object? cantidadImagenes = null,Object? cantidadTickets = null,Object? totalSuma = null,}) {
  return _then(_self.copyWith(
registrado: null == registrado ? _self.registrado : registrado // ignore: cast_nullable_to_non_nullable
as bool,cantidadImagenes: null == cantidadImagenes ? _self.cantidadImagenes : cantidadImagenes // ignore: cast_nullable_to_non_nullable
as int,cantidadTickets: null == cantidadTickets ? _self.cantidadTickets : cantidadTickets // ignore: cast_nullable_to_non_nullable
as int,totalSuma: null == totalSuma ? _self.totalSuma : totalSuma // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [RoleSummary].
extension RoleSummaryPatterns on RoleSummary {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _RoleSummary value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _RoleSummary() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _RoleSummary value)  $default,){
final _that = this;
switch (_that) {
case _RoleSummary():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _RoleSummary value)?  $default,){
final _that = this;
switch (_that) {
case _RoleSummary() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( bool registrado,  int cantidadImagenes,  int cantidadTickets,  int totalSuma)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _RoleSummary() when $default != null:
return $default(_that.registrado,_that.cantidadImagenes,_that.cantidadTickets,_that.totalSuma);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( bool registrado,  int cantidadImagenes,  int cantidadTickets,  int totalSuma)  $default,) {final _that = this;
switch (_that) {
case _RoleSummary():
return $default(_that.registrado,_that.cantidadImagenes,_that.cantidadTickets,_that.totalSuma);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( bool registrado,  int cantidadImagenes,  int cantidadTickets,  int totalSuma)?  $default,) {final _that = this;
switch (_that) {
case _RoleSummary() when $default != null:
return $default(_that.registrado,_that.cantidadImagenes,_that.cantidadTickets,_that.totalSuma);case _:
  return null;

}
}

}

/// @nodoc


class _RoleSummary extends RoleSummary {
  const _RoleSummary({required this.registrado, required this.cantidadImagenes, required this.cantidadTickets, required this.totalSuma}): super._();
  

/// false si ese rol todavía no registró nada en la jornada (los demás
/// campos van en 0).
@override final  bool registrado;
@override final  int cantidadImagenes;
@override final  int cantidadTickets;
/// Suma de los totales de todos sus comprobantes, en pesos.
@override final  int totalSuma;

/// Create a copy of RoleSummary
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$RoleSummaryCopyWith<_RoleSummary> get copyWith => __$RoleSummaryCopyWithImpl<_RoleSummary>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _RoleSummary&&(identical(other.registrado, registrado) || other.registrado == registrado)&&(identical(other.cantidadImagenes, cantidadImagenes) || other.cantidadImagenes == cantidadImagenes)&&(identical(other.cantidadTickets, cantidadTickets) || other.cantidadTickets == cantidadTickets)&&(identical(other.totalSuma, totalSuma) || other.totalSuma == totalSuma));
}


@override
int get hashCode => Object.hash(runtimeType,registrado,cantidadImagenes,cantidadTickets,totalSuma);

@override
String toString() {
  return 'RoleSummary(registrado: $registrado, cantidadImagenes: $cantidadImagenes, cantidadTickets: $cantidadTickets, totalSuma: $totalSuma)';
}


}

/// @nodoc
abstract mixin class _$RoleSummaryCopyWith<$Res> implements $RoleSummaryCopyWith<$Res> {
  factory _$RoleSummaryCopyWith(_RoleSummary value, $Res Function(_RoleSummary) _then) = __$RoleSummaryCopyWithImpl;
@override @useResult
$Res call({
 bool registrado, int cantidadImagenes, int cantidadTickets, int totalSuma
});




}
/// @nodoc
class __$RoleSummaryCopyWithImpl<$Res>
    implements _$RoleSummaryCopyWith<$Res> {
  __$RoleSummaryCopyWithImpl(this._self, this._then);

  final _RoleSummary _self;
  final $Res Function(_RoleSummary) _then;

/// Create a copy of RoleSummary
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? registrado = null,Object? cantidadImagenes = null,Object? cantidadTickets = null,Object? totalSuma = null,}) {
  return _then(_RoleSummary(
registrado: null == registrado ? _self.registrado : registrado // ignore: cast_nullable_to_non_nullable
as bool,cantidadImagenes: null == cantidadImagenes ? _self.cantidadImagenes : cantidadImagenes // ignore: cast_nullable_to_non_nullable
as int,cantidadTickets: null == cantidadTickets ? _self.cantidadTickets : cantidadTickets // ignore: cast_nullable_to_non_nullable
as int,totalSuma: null == totalSuma ? _self.totalSuma : totalSuma // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

// dart format on
