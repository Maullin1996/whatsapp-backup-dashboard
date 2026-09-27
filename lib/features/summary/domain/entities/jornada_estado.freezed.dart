// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'jornada_estado.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$JornadaEstado {





@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is JornadaEstado);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'JornadaEstado()';
}


}

/// @nodoc
class $JornadaEstadoCopyWith<$Res>  {
$JornadaEstadoCopyWith(JornadaEstado _, $Res Function(JornadaEstado) __);
}


/// Adds pattern-matching-related methods to [JornadaEstado].
extension JornadaEstadoPatterns on JornadaEstado {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( JornadaCuadra value)?  cuadra,TResult Function( JornadaDescuadre value)?  descuadre,TResult Function( JornadaPendiente value)?  pendiente,required TResult orElse(),}){
final _that = this;
switch (_that) {
case JornadaCuadra() when cuadra != null:
return cuadra(_that);case JornadaDescuadre() when descuadre != null:
return descuadre(_that);case JornadaPendiente() when pendiente != null:
return pendiente(_that);case _:
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

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( JornadaCuadra value)  cuadra,required TResult Function( JornadaDescuadre value)  descuadre,required TResult Function( JornadaPendiente value)  pendiente,}){
final _that = this;
switch (_that) {
case JornadaCuadra():
return cuadra(_that);case JornadaDescuadre():
return descuadre(_that);case JornadaPendiente():
return pendiente(_that);}
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( JornadaCuadra value)?  cuadra,TResult? Function( JornadaDescuadre value)?  descuadre,TResult? Function( JornadaPendiente value)?  pendiente,}){
final _that = this;
switch (_that) {
case JornadaCuadra() when cuadra != null:
return cuadra(_that);case JornadaDescuadre() when descuadre != null:
return descuadre(_that);case JornadaPendiente() when pendiente != null:
return pendiente(_that);case _:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function()?  cuadra,TResult Function( int diferencia)?  descuadre,TResult Function( Set<ReviewRole> faltan)?  pendiente,required TResult orElse(),}) {final _that = this;
switch (_that) {
case JornadaCuadra() when cuadra != null:
return cuadra();case JornadaDescuadre() when descuadre != null:
return descuadre(_that.diferencia);case JornadaPendiente() when pendiente != null:
return pendiente(_that.faltan);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function()  cuadra,required TResult Function( int diferencia)  descuadre,required TResult Function( Set<ReviewRole> faltan)  pendiente,}) {final _that = this;
switch (_that) {
case JornadaCuadra():
return cuadra();case JornadaDescuadre():
return descuadre(_that.diferencia);case JornadaPendiente():
return pendiente(_that.faltan);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function()?  cuadra,TResult? Function( int diferencia)?  descuadre,TResult? Function( Set<ReviewRole> faltan)?  pendiente,}) {final _that = this;
switch (_that) {
case JornadaCuadra() when cuadra != null:
return cuadra();case JornadaDescuadre() when descuadre != null:
return descuadre(_that.diferencia);case JornadaPendiente() when pendiente != null:
return pendiente(_that.faltan);case _:
  return null;

}
}

}

/// @nodoc


class JornadaCuadra implements JornadaEstado {
  const JornadaCuadra();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is JornadaCuadra);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'JornadaEstado.cuadra()';
}


}




/// @nodoc


class JornadaDescuadre implements JornadaEstado {
  const JornadaDescuadre({required this.diferencia});
  

 final  int diferencia;

/// Create a copy of JornadaEstado
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$JornadaDescuadreCopyWith<JornadaDescuadre> get copyWith => _$JornadaDescuadreCopyWithImpl<JornadaDescuadre>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is JornadaDescuadre&&(identical(other.diferencia, diferencia) || other.diferencia == diferencia));
}


@override
int get hashCode => Object.hash(runtimeType,diferencia);

@override
String toString() {
  return 'JornadaEstado.descuadre(diferencia: $diferencia)';
}


}

/// @nodoc
abstract mixin class $JornadaDescuadreCopyWith<$Res> implements $JornadaEstadoCopyWith<$Res> {
  factory $JornadaDescuadreCopyWith(JornadaDescuadre value, $Res Function(JornadaDescuadre) _then) = _$JornadaDescuadreCopyWithImpl;
@useResult
$Res call({
 int diferencia
});




}
/// @nodoc
class _$JornadaDescuadreCopyWithImpl<$Res>
    implements $JornadaDescuadreCopyWith<$Res> {
  _$JornadaDescuadreCopyWithImpl(this._self, this._then);

  final JornadaDescuadre _self;
  final $Res Function(JornadaDescuadre) _then;

/// Create a copy of JornadaEstado
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? diferencia = null,}) {
  return _then(JornadaDescuadre(
diferencia: null == diferencia ? _self.diferencia : diferencia // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

/// @nodoc


class JornadaPendiente implements JornadaEstado {
  const JornadaPendiente({required final  Set<ReviewRole> faltan}): _faltan = faltan;
  

 final  Set<ReviewRole> _faltan;
 Set<ReviewRole> get faltan {
  if (_faltan is EqualUnmodifiableSetView) return _faltan;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableSetView(_faltan);
}


/// Create a copy of JornadaEstado
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$JornadaPendienteCopyWith<JornadaPendiente> get copyWith => _$JornadaPendienteCopyWithImpl<JornadaPendiente>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is JornadaPendiente&&const DeepCollectionEquality().equals(other._faltan, _faltan));
}


@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_faltan));

@override
String toString() {
  return 'JornadaEstado.pendiente(faltan: $faltan)';
}


}

/// @nodoc
abstract mixin class $JornadaPendienteCopyWith<$Res> implements $JornadaEstadoCopyWith<$Res> {
  factory $JornadaPendienteCopyWith(JornadaPendiente value, $Res Function(JornadaPendiente) _then) = _$JornadaPendienteCopyWithImpl;
@useResult
$Res call({
 Set<ReviewRole> faltan
});




}
/// @nodoc
class _$JornadaPendienteCopyWithImpl<$Res>
    implements $JornadaPendienteCopyWith<$Res> {
  _$JornadaPendienteCopyWithImpl(this._self, this._then);

  final JornadaPendiente _self;
  final $Res Function(JornadaPendiente) _then;

/// Create a copy of JornadaEstado
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? faltan = null,}) {
  return _then(JornadaPendiente(
faltan: null == faltan ? _self._faltan : faltan // ignore: cast_nullable_to_non_nullable
as Set<ReviewRole>,
  ));
}


}

// dart format on
