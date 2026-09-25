// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'review_draft_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$ComprobanteDraft {

 int get id; String get codigo; List<String> get numeros;/// Texto tipeado en el campo de número que aún no se agregó como chip.
 String get numeroPendiente;/// Solo dígitos (el input aplica `digitsOnly`).
 String get total;
/// Create a copy of ComprobanteDraft
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ComprobanteDraftCopyWith<ComprobanteDraft> get copyWith => _$ComprobanteDraftCopyWithImpl<ComprobanteDraft>(this as ComprobanteDraft, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ComprobanteDraft&&(identical(other.id, id) || other.id == id)&&(identical(other.codigo, codigo) || other.codigo == codigo)&&const DeepCollectionEquality().equals(other.numeros, numeros)&&(identical(other.numeroPendiente, numeroPendiente) || other.numeroPendiente == numeroPendiente)&&(identical(other.total, total) || other.total == total));
}


@override
int get hashCode => Object.hash(runtimeType,id,codigo,const DeepCollectionEquality().hash(numeros),numeroPendiente,total);

@override
String toString() {
  return 'ComprobanteDraft(id: $id, codigo: $codigo, numeros: $numeros, numeroPendiente: $numeroPendiente, total: $total)';
}


}

/// @nodoc
abstract mixin class $ComprobanteDraftCopyWith<$Res>  {
  factory $ComprobanteDraftCopyWith(ComprobanteDraft value, $Res Function(ComprobanteDraft) _then) = _$ComprobanteDraftCopyWithImpl;
@useResult
$Res call({
 int id, String codigo, List<String> numeros, String numeroPendiente, String total
});




}
/// @nodoc
class _$ComprobanteDraftCopyWithImpl<$Res>
    implements $ComprobanteDraftCopyWith<$Res> {
  _$ComprobanteDraftCopyWithImpl(this._self, this._then);

  final ComprobanteDraft _self;
  final $Res Function(ComprobanteDraft) _then;

/// Create a copy of ComprobanteDraft
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? codigo = null,Object? numeros = null,Object? numeroPendiente = null,Object? total = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,codigo: null == codigo ? _self.codigo : codigo // ignore: cast_nullable_to_non_nullable
as String,numeros: null == numeros ? _self.numeros : numeros // ignore: cast_nullable_to_non_nullable
as List<String>,numeroPendiente: null == numeroPendiente ? _self.numeroPendiente : numeroPendiente // ignore: cast_nullable_to_non_nullable
as String,total: null == total ? _self.total : total // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [ComprobanteDraft].
extension ComprobanteDraftPatterns on ComprobanteDraft {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ComprobanteDraft value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ComprobanteDraft() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ComprobanteDraft value)  $default,){
final _that = this;
switch (_that) {
case _ComprobanteDraft():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ComprobanteDraft value)?  $default,){
final _that = this;
switch (_that) {
case _ComprobanteDraft() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int id,  String codigo,  List<String> numeros,  String numeroPendiente,  String total)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ComprobanteDraft() when $default != null:
return $default(_that.id,_that.codigo,_that.numeros,_that.numeroPendiente,_that.total);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int id,  String codigo,  List<String> numeros,  String numeroPendiente,  String total)  $default,) {final _that = this;
switch (_that) {
case _ComprobanteDraft():
return $default(_that.id,_that.codigo,_that.numeros,_that.numeroPendiente,_that.total);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int id,  String codigo,  List<String> numeros,  String numeroPendiente,  String total)?  $default,) {final _that = this;
switch (_that) {
case _ComprobanteDraft() when $default != null:
return $default(_that.id,_that.codigo,_that.numeros,_that.numeroPendiente,_that.total);case _:
  return null;

}
}

}

/// @nodoc


class _ComprobanteDraft extends ComprobanteDraft {
  const _ComprobanteDraft({required this.id, this.codigo = '', final  List<String> numeros = const [], this.numeroPendiente = '', this.total = ''}): _numeros = numeros,super._();
  

@override final  int id;
@override@JsonKey() final  String codigo;
 final  List<String> _numeros;
@override@JsonKey() List<String> get numeros {
  if (_numeros is EqualUnmodifiableListView) return _numeros;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_numeros);
}

/// Texto tipeado en el campo de número que aún no se agregó como chip.
@override@JsonKey() final  String numeroPendiente;
/// Solo dígitos (el input aplica `digitsOnly`).
@override@JsonKey() final  String total;

/// Create a copy of ComprobanteDraft
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ComprobanteDraftCopyWith<_ComprobanteDraft> get copyWith => __$ComprobanteDraftCopyWithImpl<_ComprobanteDraft>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ComprobanteDraft&&(identical(other.id, id) || other.id == id)&&(identical(other.codigo, codigo) || other.codigo == codigo)&&const DeepCollectionEquality().equals(other._numeros, _numeros)&&(identical(other.numeroPendiente, numeroPendiente) || other.numeroPendiente == numeroPendiente)&&(identical(other.total, total) || other.total == total));
}


@override
int get hashCode => Object.hash(runtimeType,id,codigo,const DeepCollectionEquality().hash(_numeros),numeroPendiente,total);

@override
String toString() {
  return 'ComprobanteDraft(id: $id, codigo: $codigo, numeros: $numeros, numeroPendiente: $numeroPendiente, total: $total)';
}


}

/// @nodoc
abstract mixin class _$ComprobanteDraftCopyWith<$Res> implements $ComprobanteDraftCopyWith<$Res> {
  factory _$ComprobanteDraftCopyWith(_ComprobanteDraft value, $Res Function(_ComprobanteDraft) _then) = __$ComprobanteDraftCopyWithImpl;
@override @useResult
$Res call({
 int id, String codigo, List<String> numeros, String numeroPendiente, String total
});




}
/// @nodoc
class __$ComprobanteDraftCopyWithImpl<$Res>
    implements _$ComprobanteDraftCopyWith<$Res> {
  __$ComprobanteDraftCopyWithImpl(this._self, this._then);

  final _ComprobanteDraft _self;
  final $Res Function(_ComprobanteDraft) _then;

/// Create a copy of ComprobanteDraft
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? codigo = null,Object? numeros = null,Object? numeroPendiente = null,Object? total = null,}) {
  return _then(_ComprobanteDraft(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,codigo: null == codigo ? _self.codigo : codigo // ignore: cast_nullable_to_non_nullable
as String,numeros: null == numeros ? _self._numeros : numeros // ignore: cast_nullable_to_non_nullable
as List<String>,numeroPendiente: null == numeroPendiente ? _self.numeroPendiente : numeroPendiente // ignore: cast_nullable_to_non_nullable
as String,total: null == total ? _self.total : total // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc
mixin _$ReviewDraftState {

 List<ComprobanteDraft> get comprobantes; String get anotaciones; int get nextId;/// true mientras se edita un registro ya guardado.
 bool get isEditing;/// true tras el primer intento fallido de guardar: activa los errores
/// inline por campo.
 bool get showErrors; bool get isSaving;/// `ImageReviewFailure` (validación) o `Failure` (guardado).
 Object? get saveError;
/// Create a copy of ReviewDraftState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ReviewDraftStateCopyWith<ReviewDraftState> get copyWith => _$ReviewDraftStateCopyWithImpl<ReviewDraftState>(this as ReviewDraftState, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ReviewDraftState&&const DeepCollectionEquality().equals(other.comprobantes, comprobantes)&&(identical(other.anotaciones, anotaciones) || other.anotaciones == anotaciones)&&(identical(other.nextId, nextId) || other.nextId == nextId)&&(identical(other.isEditing, isEditing) || other.isEditing == isEditing)&&(identical(other.showErrors, showErrors) || other.showErrors == showErrors)&&(identical(other.isSaving, isSaving) || other.isSaving == isSaving)&&const DeepCollectionEquality().equals(other.saveError, saveError));
}


@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(comprobantes),anotaciones,nextId,isEditing,showErrors,isSaving,const DeepCollectionEquality().hash(saveError));

@override
String toString() {
  return 'ReviewDraftState(comprobantes: $comprobantes, anotaciones: $anotaciones, nextId: $nextId, isEditing: $isEditing, showErrors: $showErrors, isSaving: $isSaving, saveError: $saveError)';
}


}

/// @nodoc
abstract mixin class $ReviewDraftStateCopyWith<$Res>  {
  factory $ReviewDraftStateCopyWith(ReviewDraftState value, $Res Function(ReviewDraftState) _then) = _$ReviewDraftStateCopyWithImpl;
@useResult
$Res call({
 List<ComprobanteDraft> comprobantes, String anotaciones, int nextId, bool isEditing, bool showErrors, bool isSaving, Object? saveError
});




}
/// @nodoc
class _$ReviewDraftStateCopyWithImpl<$Res>
    implements $ReviewDraftStateCopyWith<$Res> {
  _$ReviewDraftStateCopyWithImpl(this._self, this._then);

  final ReviewDraftState _self;
  final $Res Function(ReviewDraftState) _then;

/// Create a copy of ReviewDraftState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? comprobantes = null,Object? anotaciones = null,Object? nextId = null,Object? isEditing = null,Object? showErrors = null,Object? isSaving = null,Object? saveError = freezed,}) {
  return _then(_self.copyWith(
comprobantes: null == comprobantes ? _self.comprobantes : comprobantes // ignore: cast_nullable_to_non_nullable
as List<ComprobanteDraft>,anotaciones: null == anotaciones ? _self.anotaciones : anotaciones // ignore: cast_nullable_to_non_nullable
as String,nextId: null == nextId ? _self.nextId : nextId // ignore: cast_nullable_to_non_nullable
as int,isEditing: null == isEditing ? _self.isEditing : isEditing // ignore: cast_nullable_to_non_nullable
as bool,showErrors: null == showErrors ? _self.showErrors : showErrors // ignore: cast_nullable_to_non_nullable
as bool,isSaving: null == isSaving ? _self.isSaving : isSaving // ignore: cast_nullable_to_non_nullable
as bool,saveError: freezed == saveError ? _self.saveError : saveError ,
  ));
}

}


/// Adds pattern-matching-related methods to [ReviewDraftState].
extension ReviewDraftStatePatterns on ReviewDraftState {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ReviewDraftState value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ReviewDraftState() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ReviewDraftState value)  $default,){
final _that = this;
switch (_that) {
case _ReviewDraftState():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ReviewDraftState value)?  $default,){
final _that = this;
switch (_that) {
case _ReviewDraftState() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( List<ComprobanteDraft> comprobantes,  String anotaciones,  int nextId,  bool isEditing,  bool showErrors,  bool isSaving,  Object? saveError)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ReviewDraftState() when $default != null:
return $default(_that.comprobantes,_that.anotaciones,_that.nextId,_that.isEditing,_that.showErrors,_that.isSaving,_that.saveError);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( List<ComprobanteDraft> comprobantes,  String anotaciones,  int nextId,  bool isEditing,  bool showErrors,  bool isSaving,  Object? saveError)  $default,) {final _that = this;
switch (_that) {
case _ReviewDraftState():
return $default(_that.comprobantes,_that.anotaciones,_that.nextId,_that.isEditing,_that.showErrors,_that.isSaving,_that.saveError);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( List<ComprobanteDraft> comprobantes,  String anotaciones,  int nextId,  bool isEditing,  bool showErrors,  bool isSaving,  Object? saveError)?  $default,) {final _that = this;
switch (_that) {
case _ReviewDraftState() when $default != null:
return $default(_that.comprobantes,_that.anotaciones,_that.nextId,_that.isEditing,_that.showErrors,_that.isSaving,_that.saveError);case _:
  return null;

}
}

}

/// @nodoc


class _ReviewDraftState extends ReviewDraftState {
  const _ReviewDraftState({required final  List<ComprobanteDraft> comprobantes, this.anotaciones = '', this.nextId = 1, this.isEditing = false, this.showErrors = false, this.isSaving = false, this.saveError}): _comprobantes = comprobantes,super._();
  

 final  List<ComprobanteDraft> _comprobantes;
@override List<ComprobanteDraft> get comprobantes {
  if (_comprobantes is EqualUnmodifiableListView) return _comprobantes;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_comprobantes);
}

@override@JsonKey() final  String anotaciones;
@override@JsonKey() final  int nextId;
/// true mientras se edita un registro ya guardado.
@override@JsonKey() final  bool isEditing;
/// true tras el primer intento fallido de guardar: activa los errores
/// inline por campo.
@override@JsonKey() final  bool showErrors;
@override@JsonKey() final  bool isSaving;
/// `ImageReviewFailure` (validación) o `Failure` (guardado).
@override final  Object? saveError;

/// Create a copy of ReviewDraftState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ReviewDraftStateCopyWith<_ReviewDraftState> get copyWith => __$ReviewDraftStateCopyWithImpl<_ReviewDraftState>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ReviewDraftState&&const DeepCollectionEquality().equals(other._comprobantes, _comprobantes)&&(identical(other.anotaciones, anotaciones) || other.anotaciones == anotaciones)&&(identical(other.nextId, nextId) || other.nextId == nextId)&&(identical(other.isEditing, isEditing) || other.isEditing == isEditing)&&(identical(other.showErrors, showErrors) || other.showErrors == showErrors)&&(identical(other.isSaving, isSaving) || other.isSaving == isSaving)&&const DeepCollectionEquality().equals(other.saveError, saveError));
}


@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_comprobantes),anotaciones,nextId,isEditing,showErrors,isSaving,const DeepCollectionEquality().hash(saveError));

@override
String toString() {
  return 'ReviewDraftState(comprobantes: $comprobantes, anotaciones: $anotaciones, nextId: $nextId, isEditing: $isEditing, showErrors: $showErrors, isSaving: $isSaving, saveError: $saveError)';
}


}

/// @nodoc
abstract mixin class _$ReviewDraftStateCopyWith<$Res> implements $ReviewDraftStateCopyWith<$Res> {
  factory _$ReviewDraftStateCopyWith(_ReviewDraftState value, $Res Function(_ReviewDraftState) _then) = __$ReviewDraftStateCopyWithImpl;
@override @useResult
$Res call({
 List<ComprobanteDraft> comprobantes, String anotaciones, int nextId, bool isEditing, bool showErrors, bool isSaving, Object? saveError
});




}
/// @nodoc
class __$ReviewDraftStateCopyWithImpl<$Res>
    implements _$ReviewDraftStateCopyWith<$Res> {
  __$ReviewDraftStateCopyWithImpl(this._self, this._then);

  final _ReviewDraftState _self;
  final $Res Function(_ReviewDraftState) _then;

/// Create a copy of ReviewDraftState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? comprobantes = null,Object? anotaciones = null,Object? nextId = null,Object? isEditing = null,Object? showErrors = null,Object? isSaving = null,Object? saveError = freezed,}) {
  return _then(_ReviewDraftState(
comprobantes: null == comprobantes ? _self._comprobantes : comprobantes // ignore: cast_nullable_to_non_nullable
as List<ComprobanteDraft>,anotaciones: null == anotaciones ? _self.anotaciones : anotaciones // ignore: cast_nullable_to_non_nullable
as String,nextId: null == nextId ? _self.nextId : nextId // ignore: cast_nullable_to_non_nullable
as int,isEditing: null == isEditing ? _self.isEditing : isEditing // ignore: cast_nullable_to_non_nullable
as bool,showErrors: null == showErrors ? _self.showErrors : showErrors // ignore: cast_nullable_to_non_nullable
as bool,isSaving: null == isSaving ? _self.isSaving : isSaving // ignore: cast_nullable_to_non_nullable
as bool,saveError: freezed == saveError ? _self.saveError : saveError ,
  ));
}


}

// dart format on
