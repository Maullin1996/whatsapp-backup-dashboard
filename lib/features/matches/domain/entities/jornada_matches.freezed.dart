// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'jornada_matches.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$JornadaMatches {

/// Etiqueta larga en español, igual que `Message.shift`.
 String get shift;/// Números ganadores del DÍA (la misma lista en todas las jornadas de
/// ese día: se comparan contra el Revisor de todas las jornadas). Vacía
/// si el día todavía no tiene ganadores.
 List<String> get winningNumbers;/// Coincidencias encontradas en esta jornada (puede ser más de una si el
/// mismo número ganador coincide con registros de distintos grupos).
 List<MatchEntry> get matches;
/// Create a copy of JornadaMatches
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$JornadaMatchesCopyWith<JornadaMatches> get copyWith => _$JornadaMatchesCopyWithImpl<JornadaMatches>(this as JornadaMatches, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is JornadaMatches&&(identical(other.shift, shift) || other.shift == shift)&&const DeepCollectionEquality().equals(other.winningNumbers, winningNumbers)&&const DeepCollectionEquality().equals(other.matches, matches));
}


@override
int get hashCode => Object.hash(runtimeType,shift,const DeepCollectionEquality().hash(winningNumbers),const DeepCollectionEquality().hash(matches));

@override
String toString() {
  return 'JornadaMatches(shift: $shift, winningNumbers: $winningNumbers, matches: $matches)';
}


}

/// @nodoc
abstract mixin class $JornadaMatchesCopyWith<$Res>  {
  factory $JornadaMatchesCopyWith(JornadaMatches value, $Res Function(JornadaMatches) _then) = _$JornadaMatchesCopyWithImpl;
@useResult
$Res call({
 String shift, List<String> winningNumbers, List<MatchEntry> matches
});




}
/// @nodoc
class _$JornadaMatchesCopyWithImpl<$Res>
    implements $JornadaMatchesCopyWith<$Res> {
  _$JornadaMatchesCopyWithImpl(this._self, this._then);

  final JornadaMatches _self;
  final $Res Function(JornadaMatches) _then;

/// Create a copy of JornadaMatches
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? shift = null,Object? winningNumbers = null,Object? matches = null,}) {
  return _then(_self.copyWith(
shift: null == shift ? _self.shift : shift // ignore: cast_nullable_to_non_nullable
as String,winningNumbers: null == winningNumbers ? _self.winningNumbers : winningNumbers // ignore: cast_nullable_to_non_nullable
as List<String>,matches: null == matches ? _self.matches : matches // ignore: cast_nullable_to_non_nullable
as List<MatchEntry>,
  ));
}

}


/// Adds pattern-matching-related methods to [JornadaMatches].
extension JornadaMatchesPatterns on JornadaMatches {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _JornadaMatches value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _JornadaMatches() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _JornadaMatches value)  $default,){
final _that = this;
switch (_that) {
case _JornadaMatches():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _JornadaMatches value)?  $default,){
final _that = this;
switch (_that) {
case _JornadaMatches() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String shift,  List<String> winningNumbers,  List<MatchEntry> matches)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _JornadaMatches() when $default != null:
return $default(_that.shift,_that.winningNumbers,_that.matches);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String shift,  List<String> winningNumbers,  List<MatchEntry> matches)  $default,) {final _that = this;
switch (_that) {
case _JornadaMatches():
return $default(_that.shift,_that.winningNumbers,_that.matches);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String shift,  List<String> winningNumbers,  List<MatchEntry> matches)?  $default,) {final _that = this;
switch (_that) {
case _JornadaMatches() when $default != null:
return $default(_that.shift,_that.winningNumbers,_that.matches);case _:
  return null;

}
}

}

/// @nodoc


class _JornadaMatches implements JornadaMatches {
  const _JornadaMatches({required this.shift, required final  List<String> winningNumbers, required final  List<MatchEntry> matches}): _winningNumbers = winningNumbers,_matches = matches;
  

/// Etiqueta larga en español, igual que `Message.shift`.
@override final  String shift;
/// Números ganadores del DÍA (la misma lista en todas las jornadas de
/// ese día: se comparan contra el Revisor de todas las jornadas). Vacía
/// si el día todavía no tiene ganadores.
 final  List<String> _winningNumbers;
/// Números ganadores del DÍA (la misma lista en todas las jornadas de
/// ese día: se comparan contra el Revisor de todas las jornadas). Vacía
/// si el día todavía no tiene ganadores.
@override List<String> get winningNumbers {
  if (_winningNumbers is EqualUnmodifiableListView) return _winningNumbers;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_winningNumbers);
}

/// Coincidencias encontradas en esta jornada (puede ser más de una si el
/// mismo número ganador coincide con registros de distintos grupos).
 final  List<MatchEntry> _matches;
/// Coincidencias encontradas en esta jornada (puede ser más de una si el
/// mismo número ganador coincide con registros de distintos grupos).
@override List<MatchEntry> get matches {
  if (_matches is EqualUnmodifiableListView) return _matches;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_matches);
}


/// Create a copy of JornadaMatches
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$JornadaMatchesCopyWith<_JornadaMatches> get copyWith => __$JornadaMatchesCopyWithImpl<_JornadaMatches>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _JornadaMatches&&(identical(other.shift, shift) || other.shift == shift)&&const DeepCollectionEquality().equals(other._winningNumbers, _winningNumbers)&&const DeepCollectionEquality().equals(other._matches, _matches));
}


@override
int get hashCode => Object.hash(runtimeType,shift,const DeepCollectionEquality().hash(_winningNumbers),const DeepCollectionEquality().hash(_matches));

@override
String toString() {
  return 'JornadaMatches(shift: $shift, winningNumbers: $winningNumbers, matches: $matches)';
}


}

/// @nodoc
abstract mixin class _$JornadaMatchesCopyWith<$Res> implements $JornadaMatchesCopyWith<$Res> {
  factory _$JornadaMatchesCopyWith(_JornadaMatches value, $Res Function(_JornadaMatches) _then) = __$JornadaMatchesCopyWithImpl;
@override @useResult
$Res call({
 String shift, List<String> winningNumbers, List<MatchEntry> matches
});




}
/// @nodoc
class __$JornadaMatchesCopyWithImpl<$Res>
    implements _$JornadaMatchesCopyWith<$Res> {
  __$JornadaMatchesCopyWithImpl(this._self, this._then);

  final _JornadaMatches _self;
  final $Res Function(_JornadaMatches) _then;

/// Create a copy of JornadaMatches
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? shift = null,Object? winningNumbers = null,Object? matches = null,}) {
  return _then(_JornadaMatches(
shift: null == shift ? _self.shift : shift // ignore: cast_nullable_to_non_nullable
as String,winningNumbers: null == winningNumbers ? _self._winningNumbers : winningNumbers // ignore: cast_nullable_to_non_nullable
as List<String>,matches: null == matches ? _self._matches : matches // ignore: cast_nullable_to_non_nullable
as List<MatchEntry>,
  ));
}


}

// dart format on
