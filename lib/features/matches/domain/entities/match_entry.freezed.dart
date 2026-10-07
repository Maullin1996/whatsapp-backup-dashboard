// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'match_entry.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$MatchEntry {

/// El número tal cual lo anotó el Revisor (conserva ceros a la
/// izquierda; ver `findMatches`).
 String get numero;/// Identificador de la lotería del comprobante donde el Revisor anotó el
/// número (`lib/core/lotteries/lotteries.dart`). Null o fuera de la lista
/// en un registro viejo de texto libre: esa entrada nunca coincide.
 String? get loteria; String get messageId; String get chatJid; String get groupName; String get senderName; String get localTime;/// Referencia de la imagen en Storage (nunca la imagen ni una URL).
 String get storagePath;/// Etiqueta larga en español, igual que `Message.shift`.
 String get shift;/// Día de la jornada (`yyyy-MM-dd`), igual que `Message.fechaJornada`.
 String get fechaJornada;/// Correo del Revisor que registró la imagen; vacío si no se conoce.
 String get revisorEmail;/// Código que el Revisor anotó para la imagen; null en un registro viejo.
 String? get codigo;
/// Create a copy of MatchEntry
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$MatchEntryCopyWith<MatchEntry> get copyWith => _$MatchEntryCopyWithImpl<MatchEntry>(this as MatchEntry, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is MatchEntry&&(identical(other.numero, numero) || other.numero == numero)&&(identical(other.loteria, loteria) || other.loteria == loteria)&&(identical(other.messageId, messageId) || other.messageId == messageId)&&(identical(other.chatJid, chatJid) || other.chatJid == chatJid)&&(identical(other.groupName, groupName) || other.groupName == groupName)&&(identical(other.senderName, senderName) || other.senderName == senderName)&&(identical(other.localTime, localTime) || other.localTime == localTime)&&(identical(other.storagePath, storagePath) || other.storagePath == storagePath)&&(identical(other.shift, shift) || other.shift == shift)&&(identical(other.fechaJornada, fechaJornada) || other.fechaJornada == fechaJornada)&&(identical(other.revisorEmail, revisorEmail) || other.revisorEmail == revisorEmail)&&(identical(other.codigo, codigo) || other.codigo == codigo));
}


@override
int get hashCode => Object.hash(runtimeType,numero,loteria,messageId,chatJid,groupName,senderName,localTime,storagePath,shift,fechaJornada,revisorEmail,codigo);

@override
String toString() {
  return 'MatchEntry(numero: $numero, loteria: $loteria, messageId: $messageId, chatJid: $chatJid, groupName: $groupName, senderName: $senderName, localTime: $localTime, storagePath: $storagePath, shift: $shift, fechaJornada: $fechaJornada, revisorEmail: $revisorEmail, codigo: $codigo)';
}


}

/// @nodoc
abstract mixin class $MatchEntryCopyWith<$Res>  {
  factory $MatchEntryCopyWith(MatchEntry value, $Res Function(MatchEntry) _then) = _$MatchEntryCopyWithImpl;
@useResult
$Res call({
 String numero, String? loteria, String messageId, String chatJid, String groupName, String senderName, String localTime, String storagePath, String shift, String fechaJornada, String revisorEmail, String? codigo
});




}
/// @nodoc
class _$MatchEntryCopyWithImpl<$Res>
    implements $MatchEntryCopyWith<$Res> {
  _$MatchEntryCopyWithImpl(this._self, this._then);

  final MatchEntry _self;
  final $Res Function(MatchEntry) _then;

/// Create a copy of MatchEntry
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? numero = null,Object? loteria = freezed,Object? messageId = null,Object? chatJid = null,Object? groupName = null,Object? senderName = null,Object? localTime = null,Object? storagePath = null,Object? shift = null,Object? fechaJornada = null,Object? revisorEmail = null,Object? codigo = freezed,}) {
  return _then(_self.copyWith(
numero: null == numero ? _self.numero : numero // ignore: cast_nullable_to_non_nullable
as String,loteria: freezed == loteria ? _self.loteria : loteria // ignore: cast_nullable_to_non_nullable
as String?,messageId: null == messageId ? _self.messageId : messageId // ignore: cast_nullable_to_non_nullable
as String,chatJid: null == chatJid ? _self.chatJid : chatJid // ignore: cast_nullable_to_non_nullable
as String,groupName: null == groupName ? _self.groupName : groupName // ignore: cast_nullable_to_non_nullable
as String,senderName: null == senderName ? _self.senderName : senderName // ignore: cast_nullable_to_non_nullable
as String,localTime: null == localTime ? _self.localTime : localTime // ignore: cast_nullable_to_non_nullable
as String,storagePath: null == storagePath ? _self.storagePath : storagePath // ignore: cast_nullable_to_non_nullable
as String,shift: null == shift ? _self.shift : shift // ignore: cast_nullable_to_non_nullable
as String,fechaJornada: null == fechaJornada ? _self.fechaJornada : fechaJornada // ignore: cast_nullable_to_non_nullable
as String,revisorEmail: null == revisorEmail ? _self.revisorEmail : revisorEmail // ignore: cast_nullable_to_non_nullable
as String,codigo: freezed == codigo ? _self.codigo : codigo // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [MatchEntry].
extension MatchEntryPatterns on MatchEntry {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _MatchEntry value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _MatchEntry() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _MatchEntry value)  $default,){
final _that = this;
switch (_that) {
case _MatchEntry():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _MatchEntry value)?  $default,){
final _that = this;
switch (_that) {
case _MatchEntry() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String numero,  String? loteria,  String messageId,  String chatJid,  String groupName,  String senderName,  String localTime,  String storagePath,  String shift,  String fechaJornada,  String revisorEmail,  String? codigo)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _MatchEntry() when $default != null:
return $default(_that.numero,_that.loteria,_that.messageId,_that.chatJid,_that.groupName,_that.senderName,_that.localTime,_that.storagePath,_that.shift,_that.fechaJornada,_that.revisorEmail,_that.codigo);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String numero,  String? loteria,  String messageId,  String chatJid,  String groupName,  String senderName,  String localTime,  String storagePath,  String shift,  String fechaJornada,  String revisorEmail,  String? codigo)  $default,) {final _that = this;
switch (_that) {
case _MatchEntry():
return $default(_that.numero,_that.loteria,_that.messageId,_that.chatJid,_that.groupName,_that.senderName,_that.localTime,_that.storagePath,_that.shift,_that.fechaJornada,_that.revisorEmail,_that.codigo);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String numero,  String? loteria,  String messageId,  String chatJid,  String groupName,  String senderName,  String localTime,  String storagePath,  String shift,  String fechaJornada,  String revisorEmail,  String? codigo)?  $default,) {final _that = this;
switch (_that) {
case _MatchEntry() when $default != null:
return $default(_that.numero,_that.loteria,_that.messageId,_that.chatJid,_that.groupName,_that.senderName,_that.localTime,_that.storagePath,_that.shift,_that.fechaJornada,_that.revisorEmail,_that.codigo);case _:
  return null;

}
}

}

/// @nodoc


class _MatchEntry implements MatchEntry {
  const _MatchEntry({required this.numero, required this.loteria, required this.messageId, required this.chatJid, required this.groupName, required this.senderName, required this.localTime, required this.storagePath, required this.shift, required this.fechaJornada, this.revisorEmail = '', this.codigo});
  

/// El número tal cual lo anotó el Revisor (conserva ceros a la
/// izquierda; ver `findMatches`).
@override final  String numero;
/// Identificador de la lotería del comprobante donde el Revisor anotó el
/// número (`lib/core/lotteries/lotteries.dart`). Null o fuera de la lista
/// en un registro viejo de texto libre: esa entrada nunca coincide.
@override final  String? loteria;
@override final  String messageId;
@override final  String chatJid;
@override final  String groupName;
@override final  String senderName;
@override final  String localTime;
/// Referencia de la imagen en Storage (nunca la imagen ni una URL).
@override final  String storagePath;
/// Etiqueta larga en español, igual que `Message.shift`.
@override final  String shift;
/// Día de la jornada (`yyyy-MM-dd`), igual que `Message.fechaJornada`.
@override final  String fechaJornada;
/// Correo del Revisor que registró la imagen; vacío si no se conoce.
@override@JsonKey() final  String revisorEmail;
/// Código que el Revisor anotó para la imagen; null en un registro viejo.
@override final  String? codigo;

/// Create a copy of MatchEntry
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$MatchEntryCopyWith<_MatchEntry> get copyWith => __$MatchEntryCopyWithImpl<_MatchEntry>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _MatchEntry&&(identical(other.numero, numero) || other.numero == numero)&&(identical(other.loteria, loteria) || other.loteria == loteria)&&(identical(other.messageId, messageId) || other.messageId == messageId)&&(identical(other.chatJid, chatJid) || other.chatJid == chatJid)&&(identical(other.groupName, groupName) || other.groupName == groupName)&&(identical(other.senderName, senderName) || other.senderName == senderName)&&(identical(other.localTime, localTime) || other.localTime == localTime)&&(identical(other.storagePath, storagePath) || other.storagePath == storagePath)&&(identical(other.shift, shift) || other.shift == shift)&&(identical(other.fechaJornada, fechaJornada) || other.fechaJornada == fechaJornada)&&(identical(other.revisorEmail, revisorEmail) || other.revisorEmail == revisorEmail)&&(identical(other.codigo, codigo) || other.codigo == codigo));
}


@override
int get hashCode => Object.hash(runtimeType,numero,loteria,messageId,chatJid,groupName,senderName,localTime,storagePath,shift,fechaJornada,revisorEmail,codigo);

@override
String toString() {
  return 'MatchEntry(numero: $numero, loteria: $loteria, messageId: $messageId, chatJid: $chatJid, groupName: $groupName, senderName: $senderName, localTime: $localTime, storagePath: $storagePath, shift: $shift, fechaJornada: $fechaJornada, revisorEmail: $revisorEmail, codigo: $codigo)';
}


}

/// @nodoc
abstract mixin class _$MatchEntryCopyWith<$Res> implements $MatchEntryCopyWith<$Res> {
  factory _$MatchEntryCopyWith(_MatchEntry value, $Res Function(_MatchEntry) _then) = __$MatchEntryCopyWithImpl;
@override @useResult
$Res call({
 String numero, String? loteria, String messageId, String chatJid, String groupName, String senderName, String localTime, String storagePath, String shift, String fechaJornada, String revisorEmail, String? codigo
});




}
/// @nodoc
class __$MatchEntryCopyWithImpl<$Res>
    implements _$MatchEntryCopyWith<$Res> {
  __$MatchEntryCopyWithImpl(this._self, this._then);

  final _MatchEntry _self;
  final $Res Function(_MatchEntry) _then;

/// Create a copy of MatchEntry
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? numero = null,Object? loteria = freezed,Object? messageId = null,Object? chatJid = null,Object? groupName = null,Object? senderName = null,Object? localTime = null,Object? storagePath = null,Object? shift = null,Object? fechaJornada = null,Object? revisorEmail = null,Object? codigo = freezed,}) {
  return _then(_MatchEntry(
numero: null == numero ? _self.numero : numero // ignore: cast_nullable_to_non_nullable
as String,loteria: freezed == loteria ? _self.loteria : loteria // ignore: cast_nullable_to_non_nullable
as String?,messageId: null == messageId ? _self.messageId : messageId // ignore: cast_nullable_to_non_nullable
as String,chatJid: null == chatJid ? _self.chatJid : chatJid // ignore: cast_nullable_to_non_nullable
as String,groupName: null == groupName ? _self.groupName : groupName // ignore: cast_nullable_to_non_nullable
as String,senderName: null == senderName ? _self.senderName : senderName // ignore: cast_nullable_to_non_nullable
as String,localTime: null == localTime ? _self.localTime : localTime // ignore: cast_nullable_to_non_nullable
as String,storagePath: null == storagePath ? _self.storagePath : storagePath // ignore: cast_nullable_to_non_nullable
as String,shift: null == shift ? _self.shift : shift // ignore: cast_nullable_to_non_nullable
as String,fechaJornada: null == fechaJornada ? _self.fechaJornada : fechaJornada // ignore: cast_nullable_to_non_nullable
as String,revisorEmail: null == revisorEmail ? _self.revisorEmail : revisorEmail // ignore: cast_nullable_to_non_nullable
as String,codigo: freezed == codigo ? _self.codigo : codigo // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
