// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'image_review_record.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$ImageReviewRecord {

 String get messageId; String get chatJid; String get shift;/// Rol con el que se diligenció (Revisor o Sumador).
 ReviewRole get rol;/// Referencia de la imagen en Storage (nunca la imagen ni una URL).
 String get storagePath;/// Día de la jornada (`yyyy-MM-dd`): la fecha del mensaje, no la de
/// [registradoEn]. Ver `fechaJornadaDe`.
 String get fechaJornada; ImageReviewForm get form; DateTime get registradoEn;/// Email del usuario autenticado que diligenció el registro.
 String get registradoPor;/// false al crear. Quien re-guarda un registro existente (presentation)
/// lo pone en true; el repositorio no lo decide.
 bool get editado;/// Nace pendiente; al re-guardar vuelve a pendiente (lo decide
/// presentation, igual que [editado]).
 EstadoSync get estadoSync;
/// Create a copy of ImageReviewRecord
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ImageReviewRecordCopyWith<ImageReviewRecord> get copyWith => _$ImageReviewRecordCopyWithImpl<ImageReviewRecord>(this as ImageReviewRecord, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ImageReviewRecord&&(identical(other.messageId, messageId) || other.messageId == messageId)&&(identical(other.chatJid, chatJid) || other.chatJid == chatJid)&&(identical(other.shift, shift) || other.shift == shift)&&(identical(other.rol, rol) || other.rol == rol)&&(identical(other.storagePath, storagePath) || other.storagePath == storagePath)&&(identical(other.fechaJornada, fechaJornada) || other.fechaJornada == fechaJornada)&&(identical(other.form, form) || other.form == form)&&(identical(other.registradoEn, registradoEn) || other.registradoEn == registradoEn)&&(identical(other.registradoPor, registradoPor) || other.registradoPor == registradoPor)&&(identical(other.editado, editado) || other.editado == editado)&&(identical(other.estadoSync, estadoSync) || other.estadoSync == estadoSync));
}


@override
int get hashCode => Object.hash(runtimeType,messageId,chatJid,shift,rol,storagePath,fechaJornada,form,registradoEn,registradoPor,editado,estadoSync);

@override
String toString() {
  return 'ImageReviewRecord(messageId: $messageId, chatJid: $chatJid, shift: $shift, rol: $rol, storagePath: $storagePath, fechaJornada: $fechaJornada, form: $form, registradoEn: $registradoEn, registradoPor: $registradoPor, editado: $editado, estadoSync: $estadoSync)';
}


}

/// @nodoc
abstract mixin class $ImageReviewRecordCopyWith<$Res>  {
  factory $ImageReviewRecordCopyWith(ImageReviewRecord value, $Res Function(ImageReviewRecord) _then) = _$ImageReviewRecordCopyWithImpl;
@useResult
$Res call({
 String messageId, String chatJid, String shift, ReviewRole rol, String storagePath, String fechaJornada, ImageReviewForm form, DateTime registradoEn, String registradoPor, bool editado, EstadoSync estadoSync
});


$ImageReviewFormCopyWith<$Res> get form;

}
/// @nodoc
class _$ImageReviewRecordCopyWithImpl<$Res>
    implements $ImageReviewRecordCopyWith<$Res> {
  _$ImageReviewRecordCopyWithImpl(this._self, this._then);

  final ImageReviewRecord _self;
  final $Res Function(ImageReviewRecord) _then;

/// Create a copy of ImageReviewRecord
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? messageId = null,Object? chatJid = null,Object? shift = null,Object? rol = null,Object? storagePath = null,Object? fechaJornada = null,Object? form = null,Object? registradoEn = null,Object? registradoPor = null,Object? editado = null,Object? estadoSync = null,}) {
  return _then(_self.copyWith(
messageId: null == messageId ? _self.messageId : messageId // ignore: cast_nullable_to_non_nullable
as String,chatJid: null == chatJid ? _self.chatJid : chatJid // ignore: cast_nullable_to_non_nullable
as String,shift: null == shift ? _self.shift : shift // ignore: cast_nullable_to_non_nullable
as String,rol: null == rol ? _self.rol : rol // ignore: cast_nullable_to_non_nullable
as ReviewRole,storagePath: null == storagePath ? _self.storagePath : storagePath // ignore: cast_nullable_to_non_nullable
as String,fechaJornada: null == fechaJornada ? _self.fechaJornada : fechaJornada // ignore: cast_nullable_to_non_nullable
as String,form: null == form ? _self.form : form // ignore: cast_nullable_to_non_nullable
as ImageReviewForm,registradoEn: null == registradoEn ? _self.registradoEn : registradoEn // ignore: cast_nullable_to_non_nullable
as DateTime,registradoPor: null == registradoPor ? _self.registradoPor : registradoPor // ignore: cast_nullable_to_non_nullable
as String,editado: null == editado ? _self.editado : editado // ignore: cast_nullable_to_non_nullable
as bool,estadoSync: null == estadoSync ? _self.estadoSync : estadoSync // ignore: cast_nullable_to_non_nullable
as EstadoSync,
  ));
}
/// Create a copy of ImageReviewRecord
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ImageReviewFormCopyWith<$Res> get form {
  
  return $ImageReviewFormCopyWith<$Res>(_self.form, (value) {
    return _then(_self.copyWith(form: value));
  });
}
}


/// Adds pattern-matching-related methods to [ImageReviewRecord].
extension ImageReviewRecordPatterns on ImageReviewRecord {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ImageReviewRecord value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ImageReviewRecord() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ImageReviewRecord value)  $default,){
final _that = this;
switch (_that) {
case _ImageReviewRecord():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ImageReviewRecord value)?  $default,){
final _that = this;
switch (_that) {
case _ImageReviewRecord() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String messageId,  String chatJid,  String shift,  ReviewRole rol,  String storagePath,  String fechaJornada,  ImageReviewForm form,  DateTime registradoEn,  String registradoPor,  bool editado,  EstadoSync estadoSync)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ImageReviewRecord() when $default != null:
return $default(_that.messageId,_that.chatJid,_that.shift,_that.rol,_that.storagePath,_that.fechaJornada,_that.form,_that.registradoEn,_that.registradoPor,_that.editado,_that.estadoSync);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String messageId,  String chatJid,  String shift,  ReviewRole rol,  String storagePath,  String fechaJornada,  ImageReviewForm form,  DateTime registradoEn,  String registradoPor,  bool editado,  EstadoSync estadoSync)  $default,) {final _that = this;
switch (_that) {
case _ImageReviewRecord():
return $default(_that.messageId,_that.chatJid,_that.shift,_that.rol,_that.storagePath,_that.fechaJornada,_that.form,_that.registradoEn,_that.registradoPor,_that.editado,_that.estadoSync);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String messageId,  String chatJid,  String shift,  ReviewRole rol,  String storagePath,  String fechaJornada,  ImageReviewForm form,  DateTime registradoEn,  String registradoPor,  bool editado,  EstadoSync estadoSync)?  $default,) {final _that = this;
switch (_that) {
case _ImageReviewRecord() when $default != null:
return $default(_that.messageId,_that.chatJid,_that.shift,_that.rol,_that.storagePath,_that.fechaJornada,_that.form,_that.registradoEn,_that.registradoPor,_that.editado,_that.estadoSync);case _:
  return null;

}
}

}

/// @nodoc


class _ImageReviewRecord implements ImageReviewRecord {
  const _ImageReviewRecord({required this.messageId, required this.chatJid, required this.shift, required this.rol, required this.storagePath, required this.fechaJornada, required this.form, required this.registradoEn, required this.registradoPor, this.editado = false, this.estadoSync = EstadoSync.pendiente});
  

@override final  String messageId;
@override final  String chatJid;
@override final  String shift;
/// Rol con el que se diligenció (Revisor o Sumador).
@override final  ReviewRole rol;
/// Referencia de la imagen en Storage (nunca la imagen ni una URL).
@override final  String storagePath;
/// Día de la jornada (`yyyy-MM-dd`): la fecha del mensaje, no la de
/// [registradoEn]. Ver `fechaJornadaDe`.
@override final  String fechaJornada;
@override final  ImageReviewForm form;
@override final  DateTime registradoEn;
/// Email del usuario autenticado que diligenció el registro.
@override final  String registradoPor;
/// false al crear. Quien re-guarda un registro existente (presentation)
/// lo pone en true; el repositorio no lo decide.
@override@JsonKey() final  bool editado;
/// Nace pendiente; al re-guardar vuelve a pendiente (lo decide
/// presentation, igual que [editado]).
@override@JsonKey() final  EstadoSync estadoSync;

/// Create a copy of ImageReviewRecord
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ImageReviewRecordCopyWith<_ImageReviewRecord> get copyWith => __$ImageReviewRecordCopyWithImpl<_ImageReviewRecord>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ImageReviewRecord&&(identical(other.messageId, messageId) || other.messageId == messageId)&&(identical(other.chatJid, chatJid) || other.chatJid == chatJid)&&(identical(other.shift, shift) || other.shift == shift)&&(identical(other.rol, rol) || other.rol == rol)&&(identical(other.storagePath, storagePath) || other.storagePath == storagePath)&&(identical(other.fechaJornada, fechaJornada) || other.fechaJornada == fechaJornada)&&(identical(other.form, form) || other.form == form)&&(identical(other.registradoEn, registradoEn) || other.registradoEn == registradoEn)&&(identical(other.registradoPor, registradoPor) || other.registradoPor == registradoPor)&&(identical(other.editado, editado) || other.editado == editado)&&(identical(other.estadoSync, estadoSync) || other.estadoSync == estadoSync));
}


@override
int get hashCode => Object.hash(runtimeType,messageId,chatJid,shift,rol,storagePath,fechaJornada,form,registradoEn,registradoPor,editado,estadoSync);

@override
String toString() {
  return 'ImageReviewRecord(messageId: $messageId, chatJid: $chatJid, shift: $shift, rol: $rol, storagePath: $storagePath, fechaJornada: $fechaJornada, form: $form, registradoEn: $registradoEn, registradoPor: $registradoPor, editado: $editado, estadoSync: $estadoSync)';
}


}

/// @nodoc
abstract mixin class _$ImageReviewRecordCopyWith<$Res> implements $ImageReviewRecordCopyWith<$Res> {
  factory _$ImageReviewRecordCopyWith(_ImageReviewRecord value, $Res Function(_ImageReviewRecord) _then) = __$ImageReviewRecordCopyWithImpl;
@override @useResult
$Res call({
 String messageId, String chatJid, String shift, ReviewRole rol, String storagePath, String fechaJornada, ImageReviewForm form, DateTime registradoEn, String registradoPor, bool editado, EstadoSync estadoSync
});


@override $ImageReviewFormCopyWith<$Res> get form;

}
/// @nodoc
class __$ImageReviewRecordCopyWithImpl<$Res>
    implements _$ImageReviewRecordCopyWith<$Res> {
  __$ImageReviewRecordCopyWithImpl(this._self, this._then);

  final _ImageReviewRecord _self;
  final $Res Function(_ImageReviewRecord) _then;

/// Create a copy of ImageReviewRecord
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? messageId = null,Object? chatJid = null,Object? shift = null,Object? rol = null,Object? storagePath = null,Object? fechaJornada = null,Object? form = null,Object? registradoEn = null,Object? registradoPor = null,Object? editado = null,Object? estadoSync = null,}) {
  return _then(_ImageReviewRecord(
messageId: null == messageId ? _self.messageId : messageId // ignore: cast_nullable_to_non_nullable
as String,chatJid: null == chatJid ? _self.chatJid : chatJid // ignore: cast_nullable_to_non_nullable
as String,shift: null == shift ? _self.shift : shift // ignore: cast_nullable_to_non_nullable
as String,rol: null == rol ? _self.rol : rol // ignore: cast_nullable_to_non_nullable
as ReviewRole,storagePath: null == storagePath ? _self.storagePath : storagePath // ignore: cast_nullable_to_non_nullable
as String,fechaJornada: null == fechaJornada ? _self.fechaJornada : fechaJornada // ignore: cast_nullable_to_non_nullable
as String,form: null == form ? _self.form : form // ignore: cast_nullable_to_non_nullable
as ImageReviewForm,registradoEn: null == registradoEn ? _self.registradoEn : registradoEn // ignore: cast_nullable_to_non_nullable
as DateTime,registradoPor: null == registradoPor ? _self.registradoPor : registradoPor // ignore: cast_nullable_to_non_nullable
as String,editado: null == editado ? _self.editado : editado // ignore: cast_nullable_to_non_nullable
as bool,estadoSync: null == estadoSync ? _self.estadoSync : estadoSync // ignore: cast_nullable_to_non_nullable
as EstadoSync,
  ));
}

/// Create a copy of ImageReviewRecord
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ImageReviewFormCopyWith<$Res> get form {
  
  return $ImageReviewFormCopyWith<$Res>(_self.form, (value) {
    return _then(_self.copyWith(form: value));
  });
}
}

// dart format on
