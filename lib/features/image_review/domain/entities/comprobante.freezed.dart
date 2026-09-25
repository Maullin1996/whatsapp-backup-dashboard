// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'comprobante.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$Comprobante {

 String get codigo;/// Se guardan como String para conservar ceros a la izquierda
/// ("0123" != "123").
 List<String> get numeros;/// Pesos, sin decimales.
 int get total;
/// Create a copy of Comprobante
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ComprobanteCopyWith<Comprobante> get copyWith => _$ComprobanteCopyWithImpl<Comprobante>(this as Comprobante, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Comprobante&&(identical(other.codigo, codigo) || other.codigo == codigo)&&const DeepCollectionEquality().equals(other.numeros, numeros)&&(identical(other.total, total) || other.total == total));
}


@override
int get hashCode => Object.hash(runtimeType,codigo,const DeepCollectionEquality().hash(numeros),total);

@override
String toString() {
  return 'Comprobante(codigo: $codigo, numeros: $numeros, total: $total)';
}


}

/// @nodoc
abstract mixin class $ComprobanteCopyWith<$Res>  {
  factory $ComprobanteCopyWith(Comprobante value, $Res Function(Comprobante) _then) = _$ComprobanteCopyWithImpl;
@useResult
$Res call({
 String codigo, List<String> numeros, int total
});




}
/// @nodoc
class _$ComprobanteCopyWithImpl<$Res>
    implements $ComprobanteCopyWith<$Res> {
  _$ComprobanteCopyWithImpl(this._self, this._then);

  final Comprobante _self;
  final $Res Function(Comprobante) _then;

/// Create a copy of Comprobante
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? codigo = null,Object? numeros = null,Object? total = null,}) {
  return _then(_self.copyWith(
codigo: null == codigo ? _self.codigo : codigo // ignore: cast_nullable_to_non_nullable
as String,numeros: null == numeros ? _self.numeros : numeros // ignore: cast_nullable_to_non_nullable
as List<String>,total: null == total ? _self.total : total // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [Comprobante].
extension ComprobantePatterns on Comprobante {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Comprobante value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Comprobante() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Comprobante value)  $default,){
final _that = this;
switch (_that) {
case _Comprobante():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Comprobante value)?  $default,){
final _that = this;
switch (_that) {
case _Comprobante() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String codigo,  List<String> numeros,  int total)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Comprobante() when $default != null:
return $default(_that.codigo,_that.numeros,_that.total);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String codigo,  List<String> numeros,  int total)  $default,) {final _that = this;
switch (_that) {
case _Comprobante():
return $default(_that.codigo,_that.numeros,_that.total);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String codigo,  List<String> numeros,  int total)?  $default,) {final _that = this;
switch (_that) {
case _Comprobante() when $default != null:
return $default(_that.codigo,_that.numeros,_that.total);case _:
  return null;

}
}

}

/// @nodoc


class _Comprobante implements Comprobante {
  const _Comprobante({required this.codigo, required final  List<String> numeros, required this.total}): _numeros = numeros;
  

@override final  String codigo;
/// Se guardan como String para conservar ceros a la izquierda
/// ("0123" != "123").
 final  List<String> _numeros;
/// Se guardan como String para conservar ceros a la izquierda
/// ("0123" != "123").
@override List<String> get numeros {
  if (_numeros is EqualUnmodifiableListView) return _numeros;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_numeros);
}

/// Pesos, sin decimales.
@override final  int total;

/// Create a copy of Comprobante
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ComprobanteCopyWith<_Comprobante> get copyWith => __$ComprobanteCopyWithImpl<_Comprobante>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Comprobante&&(identical(other.codigo, codigo) || other.codigo == codigo)&&const DeepCollectionEquality().equals(other._numeros, _numeros)&&(identical(other.total, total) || other.total == total));
}


@override
int get hashCode => Object.hash(runtimeType,codigo,const DeepCollectionEquality().hash(_numeros),total);

@override
String toString() {
  return 'Comprobante(codigo: $codigo, numeros: $numeros, total: $total)';
}


}

/// @nodoc
abstract mixin class _$ComprobanteCopyWith<$Res> implements $ComprobanteCopyWith<$Res> {
  factory _$ComprobanteCopyWith(_Comprobante value, $Res Function(_Comprobante) _then) = __$ComprobanteCopyWithImpl;
@override @useResult
$Res call({
 String codigo, List<String> numeros, int total
});




}
/// @nodoc
class __$ComprobanteCopyWithImpl<$Res>
    implements _$ComprobanteCopyWith<$Res> {
  __$ComprobanteCopyWithImpl(this._self, this._then);

  final _Comprobante _self;
  final $Res Function(_Comprobante) _then;

/// Create a copy of Comprobante
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? codigo = null,Object? numeros = null,Object? total = null,}) {
  return _then(_Comprobante(
codigo: null == codigo ? _self.codigo : codigo // ignore: cast_nullable_to_non_nullable
as String,numeros: null == numeros ? _self._numeros : numeros // ignore: cast_nullable_to_non_nullable
as List<String>,total: null == total ? _self.total : total // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

// dart format on
