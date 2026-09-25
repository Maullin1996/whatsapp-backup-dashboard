// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'image_review_failure.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$ImageReviewFailure {





@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ImageReviewFailure);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'ImageReviewFailure()';
}


}

/// @nodoc
class $ImageReviewFailureCopyWith<$Res>  {
$ImageReviewFailureCopyWith(ImageReviewFailure _, $Res Function(ImageReviewFailure) __);
}


/// Adds pattern-matching-related methods to [ImageReviewFailure].
extension ImageReviewFailurePatterns on ImageReviewFailure {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( _SinComprobantes value)?  sinComprobantes,TResult Function( _CodigoVacio value)?  codigoVacio,TResult Function( _ComprobanteSinNumeros value)?  comprobanteSinNumeros,TResult Function( _TotalInvalido value)?  totalInvalido,required TResult orElse(),}){
final _that = this;
switch (_that) {
case _SinComprobantes() when sinComprobantes != null:
return sinComprobantes(_that);case _CodigoVacio() when codigoVacio != null:
return codigoVacio(_that);case _ComprobanteSinNumeros() when comprobanteSinNumeros != null:
return comprobanteSinNumeros(_that);case _TotalInvalido() when totalInvalido != null:
return totalInvalido(_that);case _:
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

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( _SinComprobantes value)  sinComprobantes,required TResult Function( _CodigoVacio value)  codigoVacio,required TResult Function( _ComprobanteSinNumeros value)  comprobanteSinNumeros,required TResult Function( _TotalInvalido value)  totalInvalido,}){
final _that = this;
switch (_that) {
case _SinComprobantes():
return sinComprobantes(_that);case _CodigoVacio():
return codigoVacio(_that);case _ComprobanteSinNumeros():
return comprobanteSinNumeros(_that);case _TotalInvalido():
return totalInvalido(_that);case _:
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( _SinComprobantes value)?  sinComprobantes,TResult? Function( _CodigoVacio value)?  codigoVacio,TResult? Function( _ComprobanteSinNumeros value)?  comprobanteSinNumeros,TResult? Function( _TotalInvalido value)?  totalInvalido,}){
final _that = this;
switch (_that) {
case _SinComprobantes() when sinComprobantes != null:
return sinComprobantes(_that);case _CodigoVacio() when codigoVacio != null:
return codigoVacio(_that);case _ComprobanteSinNumeros() when comprobanteSinNumeros != null:
return comprobanteSinNumeros(_that);case _TotalInvalido() when totalInvalido != null:
return totalInvalido(_that);case _:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function()?  sinComprobantes,TResult Function( int indice)?  codigoVacio,TResult Function( int indice)?  comprobanteSinNumeros,TResult Function( int indice)?  totalInvalido,required TResult orElse(),}) {final _that = this;
switch (_that) {
case _SinComprobantes() when sinComprobantes != null:
return sinComprobantes();case _CodigoVacio() when codigoVacio != null:
return codigoVacio(_that.indice);case _ComprobanteSinNumeros() when comprobanteSinNumeros != null:
return comprobanteSinNumeros(_that.indice);case _TotalInvalido() when totalInvalido != null:
return totalInvalido(_that.indice);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function()  sinComprobantes,required TResult Function( int indice)  codigoVacio,required TResult Function( int indice)  comprobanteSinNumeros,required TResult Function( int indice)  totalInvalido,}) {final _that = this;
switch (_that) {
case _SinComprobantes():
return sinComprobantes();case _CodigoVacio():
return codigoVacio(_that.indice);case _ComprobanteSinNumeros():
return comprobanteSinNumeros(_that.indice);case _TotalInvalido():
return totalInvalido(_that.indice);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function()?  sinComprobantes,TResult? Function( int indice)?  codigoVacio,TResult? Function( int indice)?  comprobanteSinNumeros,TResult? Function( int indice)?  totalInvalido,}) {final _that = this;
switch (_that) {
case _SinComprobantes() when sinComprobantes != null:
return sinComprobantes();case _CodigoVacio() when codigoVacio != null:
return codigoVacio(_that.indice);case _ComprobanteSinNumeros() when comprobanteSinNumeros != null:
return comprobanteSinNumeros(_that.indice);case _TotalInvalido() when totalInvalido != null:
return totalInvalido(_that.indice);case _:
  return null;

}
}

}

/// @nodoc


class _SinComprobantes implements ImageReviewFailure {
  const _SinComprobantes();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _SinComprobantes);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'ImageReviewFailure.sinComprobantes()';
}


}




/// @nodoc


class _CodigoVacio implements ImageReviewFailure {
  const _CodigoVacio(this.indice);
  

 final  int indice;

/// Create a copy of ImageReviewFailure
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$CodigoVacioCopyWith<_CodigoVacio> get copyWith => __$CodigoVacioCopyWithImpl<_CodigoVacio>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _CodigoVacio&&(identical(other.indice, indice) || other.indice == indice));
}


@override
int get hashCode => Object.hash(runtimeType,indice);

@override
String toString() {
  return 'ImageReviewFailure.codigoVacio(indice: $indice)';
}


}

/// @nodoc
abstract mixin class _$CodigoVacioCopyWith<$Res> implements $ImageReviewFailureCopyWith<$Res> {
  factory _$CodigoVacioCopyWith(_CodigoVacio value, $Res Function(_CodigoVacio) _then) = __$CodigoVacioCopyWithImpl;
@useResult
$Res call({
 int indice
});




}
/// @nodoc
class __$CodigoVacioCopyWithImpl<$Res>
    implements _$CodigoVacioCopyWith<$Res> {
  __$CodigoVacioCopyWithImpl(this._self, this._then);

  final _CodigoVacio _self;
  final $Res Function(_CodigoVacio) _then;

/// Create a copy of ImageReviewFailure
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? indice = null,}) {
  return _then(_CodigoVacio(
null == indice ? _self.indice : indice // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

/// @nodoc


class _ComprobanteSinNumeros implements ImageReviewFailure {
  const _ComprobanteSinNumeros(this.indice);
  

 final  int indice;

/// Create a copy of ImageReviewFailure
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ComprobanteSinNumerosCopyWith<_ComprobanteSinNumeros> get copyWith => __$ComprobanteSinNumerosCopyWithImpl<_ComprobanteSinNumeros>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ComprobanteSinNumeros&&(identical(other.indice, indice) || other.indice == indice));
}


@override
int get hashCode => Object.hash(runtimeType,indice);

@override
String toString() {
  return 'ImageReviewFailure.comprobanteSinNumeros(indice: $indice)';
}


}

/// @nodoc
abstract mixin class _$ComprobanteSinNumerosCopyWith<$Res> implements $ImageReviewFailureCopyWith<$Res> {
  factory _$ComprobanteSinNumerosCopyWith(_ComprobanteSinNumeros value, $Res Function(_ComprobanteSinNumeros) _then) = __$ComprobanteSinNumerosCopyWithImpl;
@useResult
$Res call({
 int indice
});




}
/// @nodoc
class __$ComprobanteSinNumerosCopyWithImpl<$Res>
    implements _$ComprobanteSinNumerosCopyWith<$Res> {
  __$ComprobanteSinNumerosCopyWithImpl(this._self, this._then);

  final _ComprobanteSinNumeros _self;
  final $Res Function(_ComprobanteSinNumeros) _then;

/// Create a copy of ImageReviewFailure
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? indice = null,}) {
  return _then(_ComprobanteSinNumeros(
null == indice ? _self.indice : indice // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

/// @nodoc


class _TotalInvalido implements ImageReviewFailure {
  const _TotalInvalido(this.indice);
  

 final  int indice;

/// Create a copy of ImageReviewFailure
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$TotalInvalidoCopyWith<_TotalInvalido> get copyWith => __$TotalInvalidoCopyWithImpl<_TotalInvalido>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _TotalInvalido&&(identical(other.indice, indice) || other.indice == indice));
}


@override
int get hashCode => Object.hash(runtimeType,indice);

@override
String toString() {
  return 'ImageReviewFailure.totalInvalido(indice: $indice)';
}


}

/// @nodoc
abstract mixin class _$TotalInvalidoCopyWith<$Res> implements $ImageReviewFailureCopyWith<$Res> {
  factory _$TotalInvalidoCopyWith(_TotalInvalido value, $Res Function(_TotalInvalido) _then) = __$TotalInvalidoCopyWithImpl;
@useResult
$Res call({
 int indice
});




}
/// @nodoc
class __$TotalInvalidoCopyWithImpl<$Res>
    implements _$TotalInvalidoCopyWith<$Res> {
  __$TotalInvalidoCopyWithImpl(this._self, this._then);

  final _TotalInvalido _self;
  final $Res Function(_TotalInvalido) _then;

/// Create a copy of ImageReviewFailure
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? indice = null,}) {
  return _then(_TotalInvalido(
null == indice ? _self.indice : indice // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

// dart format on
