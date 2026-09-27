// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'jornada_summary.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$JornadaSummary {

 String get chatJid;/// Nombre del grupo, para mostrarlo sin ir a buscarlo.
 String get groupName;/// Día de la jornada (`yyyy-MM-dd`, el mismo formato que
/// `ImageReviewRecord.fechaJornada`).
 String get fechaJornada;/// Mismo texto que guarda `ImageReviewRecord.shift`.
 String get shift; RoleSummary get revisor; RoleSummary get sumador;
/// Create a copy of JornadaSummary
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$JornadaSummaryCopyWith<JornadaSummary> get copyWith => _$JornadaSummaryCopyWithImpl<JornadaSummary>(this as JornadaSummary, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is JornadaSummary&&(identical(other.chatJid, chatJid) || other.chatJid == chatJid)&&(identical(other.groupName, groupName) || other.groupName == groupName)&&(identical(other.fechaJornada, fechaJornada) || other.fechaJornada == fechaJornada)&&(identical(other.shift, shift) || other.shift == shift)&&(identical(other.revisor, revisor) || other.revisor == revisor)&&(identical(other.sumador, sumador) || other.sumador == sumador));
}


@override
int get hashCode => Object.hash(runtimeType,chatJid,groupName,fechaJornada,shift,revisor,sumador);

@override
String toString() {
  return 'JornadaSummary(chatJid: $chatJid, groupName: $groupName, fechaJornada: $fechaJornada, shift: $shift, revisor: $revisor, sumador: $sumador)';
}


}

/// @nodoc
abstract mixin class $JornadaSummaryCopyWith<$Res>  {
  factory $JornadaSummaryCopyWith(JornadaSummary value, $Res Function(JornadaSummary) _then) = _$JornadaSummaryCopyWithImpl;
@useResult
$Res call({
 String chatJid, String groupName, String fechaJornada, String shift, RoleSummary revisor, RoleSummary sumador
});


$RoleSummaryCopyWith<$Res> get revisor;$RoleSummaryCopyWith<$Res> get sumador;

}
/// @nodoc
class _$JornadaSummaryCopyWithImpl<$Res>
    implements $JornadaSummaryCopyWith<$Res> {
  _$JornadaSummaryCopyWithImpl(this._self, this._then);

  final JornadaSummary _self;
  final $Res Function(JornadaSummary) _then;

/// Create a copy of JornadaSummary
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? chatJid = null,Object? groupName = null,Object? fechaJornada = null,Object? shift = null,Object? revisor = null,Object? sumador = null,}) {
  return _then(_self.copyWith(
chatJid: null == chatJid ? _self.chatJid : chatJid // ignore: cast_nullable_to_non_nullable
as String,groupName: null == groupName ? _self.groupName : groupName // ignore: cast_nullable_to_non_nullable
as String,fechaJornada: null == fechaJornada ? _self.fechaJornada : fechaJornada // ignore: cast_nullable_to_non_nullable
as String,shift: null == shift ? _self.shift : shift // ignore: cast_nullable_to_non_nullable
as String,revisor: null == revisor ? _self.revisor : revisor // ignore: cast_nullable_to_non_nullable
as RoleSummary,sumador: null == sumador ? _self.sumador : sumador // ignore: cast_nullable_to_non_nullable
as RoleSummary,
  ));
}
/// Create a copy of JornadaSummary
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$RoleSummaryCopyWith<$Res> get revisor {
  
  return $RoleSummaryCopyWith<$Res>(_self.revisor, (value) {
    return _then(_self.copyWith(revisor: value));
  });
}/// Create a copy of JornadaSummary
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$RoleSummaryCopyWith<$Res> get sumador {
  
  return $RoleSummaryCopyWith<$Res>(_self.sumador, (value) {
    return _then(_self.copyWith(sumador: value));
  });
}
}


/// Adds pattern-matching-related methods to [JornadaSummary].
extension JornadaSummaryPatterns on JornadaSummary {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _JornadaSummary value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _JornadaSummary() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _JornadaSummary value)  $default,){
final _that = this;
switch (_that) {
case _JornadaSummary():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _JornadaSummary value)?  $default,){
final _that = this;
switch (_that) {
case _JornadaSummary() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String chatJid,  String groupName,  String fechaJornada,  String shift,  RoleSummary revisor,  RoleSummary sumador)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _JornadaSummary() when $default != null:
return $default(_that.chatJid,_that.groupName,_that.fechaJornada,_that.shift,_that.revisor,_that.sumador);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String chatJid,  String groupName,  String fechaJornada,  String shift,  RoleSummary revisor,  RoleSummary sumador)  $default,) {final _that = this;
switch (_that) {
case _JornadaSummary():
return $default(_that.chatJid,_that.groupName,_that.fechaJornada,_that.shift,_that.revisor,_that.sumador);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String chatJid,  String groupName,  String fechaJornada,  String shift,  RoleSummary revisor,  RoleSummary sumador)?  $default,) {final _that = this;
switch (_that) {
case _JornadaSummary() when $default != null:
return $default(_that.chatJid,_that.groupName,_that.fechaJornada,_that.shift,_that.revisor,_that.sumador);case _:
  return null;

}
}

}

/// @nodoc


class _JornadaSummary extends JornadaSummary {
  const _JornadaSummary({required this.chatJid, required this.groupName, required this.fechaJornada, required this.shift, required this.revisor, required this.sumador}): super._();
  

@override final  String chatJid;
/// Nombre del grupo, para mostrarlo sin ir a buscarlo.
@override final  String groupName;
/// Día de la jornada (`yyyy-MM-dd`, el mismo formato que
/// `ImageReviewRecord.fechaJornada`).
@override final  String fechaJornada;
/// Mismo texto que guarda `ImageReviewRecord.shift`.
@override final  String shift;
@override final  RoleSummary revisor;
@override final  RoleSummary sumador;

/// Create a copy of JornadaSummary
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$JornadaSummaryCopyWith<_JornadaSummary> get copyWith => __$JornadaSummaryCopyWithImpl<_JornadaSummary>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _JornadaSummary&&(identical(other.chatJid, chatJid) || other.chatJid == chatJid)&&(identical(other.groupName, groupName) || other.groupName == groupName)&&(identical(other.fechaJornada, fechaJornada) || other.fechaJornada == fechaJornada)&&(identical(other.shift, shift) || other.shift == shift)&&(identical(other.revisor, revisor) || other.revisor == revisor)&&(identical(other.sumador, sumador) || other.sumador == sumador));
}


@override
int get hashCode => Object.hash(runtimeType,chatJid,groupName,fechaJornada,shift,revisor,sumador);

@override
String toString() {
  return 'JornadaSummary(chatJid: $chatJid, groupName: $groupName, fechaJornada: $fechaJornada, shift: $shift, revisor: $revisor, sumador: $sumador)';
}


}

/// @nodoc
abstract mixin class _$JornadaSummaryCopyWith<$Res> implements $JornadaSummaryCopyWith<$Res> {
  factory _$JornadaSummaryCopyWith(_JornadaSummary value, $Res Function(_JornadaSummary) _then) = __$JornadaSummaryCopyWithImpl;
@override @useResult
$Res call({
 String chatJid, String groupName, String fechaJornada, String shift, RoleSummary revisor, RoleSummary sumador
});


@override $RoleSummaryCopyWith<$Res> get revisor;@override $RoleSummaryCopyWith<$Res> get sumador;

}
/// @nodoc
class __$JornadaSummaryCopyWithImpl<$Res>
    implements _$JornadaSummaryCopyWith<$Res> {
  __$JornadaSummaryCopyWithImpl(this._self, this._then);

  final _JornadaSummary _self;
  final $Res Function(_JornadaSummary) _then;

/// Create a copy of JornadaSummary
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? chatJid = null,Object? groupName = null,Object? fechaJornada = null,Object? shift = null,Object? revisor = null,Object? sumador = null,}) {
  return _then(_JornadaSummary(
chatJid: null == chatJid ? _self.chatJid : chatJid // ignore: cast_nullable_to_non_nullable
as String,groupName: null == groupName ? _self.groupName : groupName // ignore: cast_nullable_to_non_nullable
as String,fechaJornada: null == fechaJornada ? _self.fechaJornada : fechaJornada // ignore: cast_nullable_to_non_nullable
as String,shift: null == shift ? _self.shift : shift // ignore: cast_nullable_to_non_nullable
as String,revisor: null == revisor ? _self.revisor : revisor // ignore: cast_nullable_to_non_nullable
as RoleSummary,sumador: null == sumador ? _self.sumador : sumador // ignore: cast_nullable_to_non_nullable
as RoleSummary,
  ));
}

/// Create a copy of JornadaSummary
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$RoleSummaryCopyWith<$Res> get revisor {
  
  return $RoleSummaryCopyWith<$Res>(_self.revisor, (value) {
    return _then(_self.copyWith(revisor: value));
  });
}/// Create a copy of JornadaSummary
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$RoleSummaryCopyWith<$Res> get sumador {
  
  return $RoleSummaryCopyWith<$Res>(_self.sumador, (value) {
    return _then(_self.copyWith(sumador: value));
  });
}
}

// dart format on
