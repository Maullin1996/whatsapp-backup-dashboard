// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'review_shift.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$ReviewShift {

 String get chatJid; Shift get shift;
/// Create a copy of ReviewShift
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ReviewShiftCopyWith<ReviewShift> get copyWith => _$ReviewShiftCopyWithImpl<ReviewShift>(this as ReviewShift, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ReviewShift&&(identical(other.chatJid, chatJid) || other.chatJid == chatJid)&&(identical(other.shift, shift) || other.shift == shift));
}


@override
int get hashCode => Object.hash(runtimeType,chatJid,shift);

@override
String toString() {
  return 'ReviewShift(chatJid: $chatJid, shift: $shift)';
}


}

/// @nodoc
abstract mixin class $ReviewShiftCopyWith<$Res>  {
  factory $ReviewShiftCopyWith(ReviewShift value, $Res Function(ReviewShift) _then) = _$ReviewShiftCopyWithImpl;
@useResult
$Res call({
 String chatJid, Shift shift
});




}
/// @nodoc
class _$ReviewShiftCopyWithImpl<$Res>
    implements $ReviewShiftCopyWith<$Res> {
  _$ReviewShiftCopyWithImpl(this._self, this._then);

  final ReviewShift _self;
  final $Res Function(ReviewShift) _then;

/// Create a copy of ReviewShift
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? chatJid = null,Object? shift = null,}) {
  return _then(_self.copyWith(
chatJid: null == chatJid ? _self.chatJid : chatJid // ignore: cast_nullable_to_non_nullable
as String,shift: null == shift ? _self.shift : shift // ignore: cast_nullable_to_non_nullable
as Shift,
  ));
}

}


/// Adds pattern-matching-related methods to [ReviewShift].
extension ReviewShiftPatterns on ReviewShift {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ReviewShift value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ReviewShift() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ReviewShift value)  $default,){
final _that = this;
switch (_that) {
case _ReviewShift():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ReviewShift value)?  $default,){
final _that = this;
switch (_that) {
case _ReviewShift() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String chatJid,  Shift shift)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ReviewShift() when $default != null:
return $default(_that.chatJid,_that.shift);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String chatJid,  Shift shift)  $default,) {final _that = this;
switch (_that) {
case _ReviewShift():
return $default(_that.chatJid,_that.shift);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String chatJid,  Shift shift)?  $default,) {final _that = this;
switch (_that) {
case _ReviewShift() when $default != null:
return $default(_that.chatJid,_that.shift);case _:
  return null;

}
}

}

/// @nodoc


class _ReviewShift implements ReviewShift {
  const _ReviewShift({required this.chatJid, required this.shift});
  

@override final  String chatJid;
@override final  Shift shift;

/// Create a copy of ReviewShift
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ReviewShiftCopyWith<_ReviewShift> get copyWith => __$ReviewShiftCopyWithImpl<_ReviewShift>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ReviewShift&&(identical(other.chatJid, chatJid) || other.chatJid == chatJid)&&(identical(other.shift, shift) || other.shift == shift));
}


@override
int get hashCode => Object.hash(runtimeType,chatJid,shift);

@override
String toString() {
  return 'ReviewShift(chatJid: $chatJid, shift: $shift)';
}


}

/// @nodoc
abstract mixin class _$ReviewShiftCopyWith<$Res> implements $ReviewShiftCopyWith<$Res> {
  factory _$ReviewShiftCopyWith(_ReviewShift value, $Res Function(_ReviewShift) _then) = __$ReviewShiftCopyWithImpl;
@override @useResult
$Res call({
 String chatJid, Shift shift
});




}
/// @nodoc
class __$ReviewShiftCopyWithImpl<$Res>
    implements _$ReviewShiftCopyWith<$Res> {
  __$ReviewShiftCopyWithImpl(this._self, this._then);

  final _ReviewShift _self;
  final $Res Function(_ReviewShift) _then;

/// Create a copy of ReviewShift
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? chatJid = null,Object? shift = null,}) {
  return _then(_ReviewShift(
chatJid: null == chatJid ? _self.chatJid : chatJid // ignore: cast_nullable_to_non_nullable
as String,shift: null == shift ? _self.shift : shift // ignore: cast_nullable_to_non_nullable
as Shift,
  ));
}


}

// dart format on
