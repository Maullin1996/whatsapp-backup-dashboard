// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'day_matches.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$DayMatches {

/// Día consultado (`yyyy-MM-dd`).
 String get fechaJornada; List<JornadaMatches> get jornadas;
/// Create a copy of DayMatches
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$DayMatchesCopyWith<DayMatches> get copyWith => _$DayMatchesCopyWithImpl<DayMatches>(this as DayMatches, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is DayMatches&&(identical(other.fechaJornada, fechaJornada) || other.fechaJornada == fechaJornada)&&const DeepCollectionEquality().equals(other.jornadas, jornadas));
}


@override
int get hashCode => Object.hash(runtimeType,fechaJornada,const DeepCollectionEquality().hash(jornadas));

@override
String toString() {
  return 'DayMatches(fechaJornada: $fechaJornada, jornadas: $jornadas)';
}


}

/// @nodoc
abstract mixin class $DayMatchesCopyWith<$Res>  {
  factory $DayMatchesCopyWith(DayMatches value, $Res Function(DayMatches) _then) = _$DayMatchesCopyWithImpl;
@useResult
$Res call({
 String fechaJornada, List<JornadaMatches> jornadas
});




}
/// @nodoc
class _$DayMatchesCopyWithImpl<$Res>
    implements $DayMatchesCopyWith<$Res> {
  _$DayMatchesCopyWithImpl(this._self, this._then);

  final DayMatches _self;
  final $Res Function(DayMatches) _then;

/// Create a copy of DayMatches
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? fechaJornada = null,Object? jornadas = null,}) {
  return _then(_self.copyWith(
fechaJornada: null == fechaJornada ? _self.fechaJornada : fechaJornada // ignore: cast_nullable_to_non_nullable
as String,jornadas: null == jornadas ? _self.jornadas : jornadas // ignore: cast_nullable_to_non_nullable
as List<JornadaMatches>,
  ));
}

}


/// Adds pattern-matching-related methods to [DayMatches].
extension DayMatchesPatterns on DayMatches {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _DayMatches value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _DayMatches() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _DayMatches value)  $default,){
final _that = this;
switch (_that) {
case _DayMatches():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _DayMatches value)?  $default,){
final _that = this;
switch (_that) {
case _DayMatches() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String fechaJornada,  List<JornadaMatches> jornadas)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _DayMatches() when $default != null:
return $default(_that.fechaJornada,_that.jornadas);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String fechaJornada,  List<JornadaMatches> jornadas)  $default,) {final _that = this;
switch (_that) {
case _DayMatches():
return $default(_that.fechaJornada,_that.jornadas);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String fechaJornada,  List<JornadaMatches> jornadas)?  $default,) {final _that = this;
switch (_that) {
case _DayMatches() when $default != null:
return $default(_that.fechaJornada,_that.jornadas);case _:
  return null;

}
}

}

/// @nodoc


class _DayMatches extends DayMatches {
  const _DayMatches({required this.fechaJornada, required final  List<JornadaMatches> jornadas}): _jornadas = jornadas,super._();
  

/// Día consultado (`yyyy-MM-dd`).
@override final  String fechaJornada;
 final  List<JornadaMatches> _jornadas;
@override List<JornadaMatches> get jornadas {
  if (_jornadas is EqualUnmodifiableListView) return _jornadas;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_jornadas);
}


/// Create a copy of DayMatches
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$DayMatchesCopyWith<_DayMatches> get copyWith => __$DayMatchesCopyWithImpl<_DayMatches>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _DayMatches&&(identical(other.fechaJornada, fechaJornada) || other.fechaJornada == fechaJornada)&&const DeepCollectionEquality().equals(other._jornadas, _jornadas));
}


@override
int get hashCode => Object.hash(runtimeType,fechaJornada,const DeepCollectionEquality().hash(_jornadas));

@override
String toString() {
  return 'DayMatches(fechaJornada: $fechaJornada, jornadas: $jornadas)';
}


}

/// @nodoc
abstract mixin class _$DayMatchesCopyWith<$Res> implements $DayMatchesCopyWith<$Res> {
  factory _$DayMatchesCopyWith(_DayMatches value, $Res Function(_DayMatches) _then) = __$DayMatchesCopyWithImpl;
@override @useResult
$Res call({
 String fechaJornada, List<JornadaMatches> jornadas
});




}
/// @nodoc
class __$DayMatchesCopyWithImpl<$Res>
    implements _$DayMatchesCopyWith<$Res> {
  __$DayMatchesCopyWithImpl(this._self, this._then);

  final _DayMatches _self;
  final $Res Function(_DayMatches) _then;

/// Create a copy of DayMatches
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? fechaJornada = null,Object? jornadas = null,}) {
  return _then(_DayMatches(
fechaJornada: null == fechaJornada ? _self.fechaJornada : fechaJornada // ignore: cast_nullable_to_non_nullable
as String,jornadas: null == jornadas ? _self._jornadas : jornadas // ignore: cast_nullable_to_non_nullable
as List<JornadaMatches>,
  ));
}


}

// dart format on
