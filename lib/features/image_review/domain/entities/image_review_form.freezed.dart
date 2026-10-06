// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'image_review_form.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$ImageReviewForm {

/// Código de la imagen: UNO por foto, vale para todos sus comprobantes.
/// Obligatorio al guardar (`validateImageReviewForm`); null solo en
/// registros guardados antes de este campo, que no se pueden subir
/// hasta volver a guardarlos.
 String? get codigo; List<Comprobante> get comprobantes;/// Opcional.
 String? get anotaciones;
/// Create a copy of ImageReviewForm
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ImageReviewFormCopyWith<ImageReviewForm> get copyWith => _$ImageReviewFormCopyWithImpl<ImageReviewForm>(this as ImageReviewForm, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ImageReviewForm&&(identical(other.codigo, codigo) || other.codigo == codigo)&&const DeepCollectionEquality().equals(other.comprobantes, comprobantes)&&(identical(other.anotaciones, anotaciones) || other.anotaciones == anotaciones));
}


@override
int get hashCode => Object.hash(runtimeType,codigo,const DeepCollectionEquality().hash(comprobantes),anotaciones);

@override
String toString() {
  return 'ImageReviewForm(codigo: $codigo, comprobantes: $comprobantes, anotaciones: $anotaciones)';
}


}

/// @nodoc
abstract mixin class $ImageReviewFormCopyWith<$Res>  {
  factory $ImageReviewFormCopyWith(ImageReviewForm value, $Res Function(ImageReviewForm) _then) = _$ImageReviewFormCopyWithImpl;
@useResult
$Res call({
 String? codigo, List<Comprobante> comprobantes, String? anotaciones
});




}
/// @nodoc
class _$ImageReviewFormCopyWithImpl<$Res>
    implements $ImageReviewFormCopyWith<$Res> {
  _$ImageReviewFormCopyWithImpl(this._self, this._then);

  final ImageReviewForm _self;
  final $Res Function(ImageReviewForm) _then;

/// Create a copy of ImageReviewForm
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? codigo = freezed,Object? comprobantes = null,Object? anotaciones = freezed,}) {
  return _then(_self.copyWith(
codigo: freezed == codigo ? _self.codigo : codigo // ignore: cast_nullable_to_non_nullable
as String?,comprobantes: null == comprobantes ? _self.comprobantes : comprobantes // ignore: cast_nullable_to_non_nullable
as List<Comprobante>,anotaciones: freezed == anotaciones ? _self.anotaciones : anotaciones // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [ImageReviewForm].
extension ImageReviewFormPatterns on ImageReviewForm {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ImageReviewForm value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ImageReviewForm() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ImageReviewForm value)  $default,){
final _that = this;
switch (_that) {
case _ImageReviewForm():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ImageReviewForm value)?  $default,){
final _that = this;
switch (_that) {
case _ImageReviewForm() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String? codigo,  List<Comprobante> comprobantes,  String? anotaciones)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ImageReviewForm() when $default != null:
return $default(_that.codigo,_that.comprobantes,_that.anotaciones);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String? codigo,  List<Comprobante> comprobantes,  String? anotaciones)  $default,) {final _that = this;
switch (_that) {
case _ImageReviewForm():
return $default(_that.codigo,_that.comprobantes,_that.anotaciones);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String? codigo,  List<Comprobante> comprobantes,  String? anotaciones)?  $default,) {final _that = this;
switch (_that) {
case _ImageReviewForm() when $default != null:
return $default(_that.codigo,_that.comprobantes,_that.anotaciones);case _:
  return null;

}
}

}

/// @nodoc


class _ImageReviewForm implements ImageReviewForm {
  const _ImageReviewForm({this.codigo, required final  List<Comprobante> comprobantes, this.anotaciones}): _comprobantes = comprobantes;
  

/// Código de la imagen: UNO por foto, vale para todos sus comprobantes.
/// Obligatorio al guardar (`validateImageReviewForm`); null solo en
/// registros guardados antes de este campo, que no se pueden subir
/// hasta volver a guardarlos.
@override final  String? codigo;
 final  List<Comprobante> _comprobantes;
@override List<Comprobante> get comprobantes {
  if (_comprobantes is EqualUnmodifiableListView) return _comprobantes;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_comprobantes);
}

/// Opcional.
@override final  String? anotaciones;

/// Create a copy of ImageReviewForm
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ImageReviewFormCopyWith<_ImageReviewForm> get copyWith => __$ImageReviewFormCopyWithImpl<_ImageReviewForm>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ImageReviewForm&&(identical(other.codigo, codigo) || other.codigo == codigo)&&const DeepCollectionEquality().equals(other._comprobantes, _comprobantes)&&(identical(other.anotaciones, anotaciones) || other.anotaciones == anotaciones));
}


@override
int get hashCode => Object.hash(runtimeType,codigo,const DeepCollectionEquality().hash(_comprobantes),anotaciones);

@override
String toString() {
  return 'ImageReviewForm(codigo: $codigo, comprobantes: $comprobantes, anotaciones: $anotaciones)';
}


}

/// @nodoc
abstract mixin class _$ImageReviewFormCopyWith<$Res> implements $ImageReviewFormCopyWith<$Res> {
  factory _$ImageReviewFormCopyWith(_ImageReviewForm value, $Res Function(_ImageReviewForm) _then) = __$ImageReviewFormCopyWithImpl;
@override @useResult
$Res call({
 String? codigo, List<Comprobante> comprobantes, String? anotaciones
});




}
/// @nodoc
class __$ImageReviewFormCopyWithImpl<$Res>
    implements _$ImageReviewFormCopyWith<$Res> {
  __$ImageReviewFormCopyWithImpl(this._self, this._then);

  final _ImageReviewForm _self;
  final $Res Function(_ImageReviewForm) _then;

/// Create a copy of ImageReviewForm
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? codigo = freezed,Object? comprobantes = null,Object? anotaciones = freezed,}) {
  return _then(_ImageReviewForm(
codigo: freezed == codigo ? _self.codigo : codigo // ignore: cast_nullable_to_non_nullable
as String?,comprobantes: null == comprobantes ? _self._comprobantes : comprobantes // ignore: cast_nullable_to_non_nullable
as List<Comprobante>,anotaciones: freezed == anotaciones ? _self.anotaciones : anotaciones // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
