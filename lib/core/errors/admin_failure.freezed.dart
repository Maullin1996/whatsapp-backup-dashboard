// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'admin_failure.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$AdminFailure {





@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AdminFailure);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'AdminFailure()';
}


}

/// @nodoc
class $AdminFailureCopyWith<$Res>  {
$AdminFailureCopyWith(AdminFailure _, $Res Function(AdminFailure) __);
}


/// Adds pattern-matching-related methods to [AdminFailure].
extension AdminFailurePatterns on AdminFailure {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( _PermissionDenied value)?  permissionDenied,TResult Function( _InvalidArgument value)?  invalidArgument,TResult Function( _EmailAlreadyExists value)?  emailAlreadyExists,TResult Function( _Unknown value)?  unknown,required TResult orElse(),}){
final _that = this;
switch (_that) {
case _PermissionDenied() when permissionDenied != null:
return permissionDenied(_that);case _InvalidArgument() when invalidArgument != null:
return invalidArgument(_that);case _EmailAlreadyExists() when emailAlreadyExists != null:
return emailAlreadyExists(_that);case _Unknown() when unknown != null:
return unknown(_that);case _:
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

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( _PermissionDenied value)  permissionDenied,required TResult Function( _InvalidArgument value)  invalidArgument,required TResult Function( _EmailAlreadyExists value)  emailAlreadyExists,required TResult Function( _Unknown value)  unknown,}){
final _that = this;
switch (_that) {
case _PermissionDenied():
return permissionDenied(_that);case _InvalidArgument():
return invalidArgument(_that);case _EmailAlreadyExists():
return emailAlreadyExists(_that);case _Unknown():
return unknown(_that);case _:
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( _PermissionDenied value)?  permissionDenied,TResult? Function( _InvalidArgument value)?  invalidArgument,TResult? Function( _EmailAlreadyExists value)?  emailAlreadyExists,TResult? Function( _Unknown value)?  unknown,}){
final _that = this;
switch (_that) {
case _PermissionDenied() when permissionDenied != null:
return permissionDenied(_that);case _InvalidArgument() when invalidArgument != null:
return invalidArgument(_that);case _EmailAlreadyExists() when emailAlreadyExists != null:
return emailAlreadyExists(_that);case _Unknown() when unknown != null:
return unknown(_that);case _:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function()?  permissionDenied,TResult Function()?  invalidArgument,TResult Function()?  emailAlreadyExists,TResult Function( String message)?  unknown,required TResult orElse(),}) {final _that = this;
switch (_that) {
case _PermissionDenied() when permissionDenied != null:
return permissionDenied();case _InvalidArgument() when invalidArgument != null:
return invalidArgument();case _EmailAlreadyExists() when emailAlreadyExists != null:
return emailAlreadyExists();case _Unknown() when unknown != null:
return unknown(_that.message);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function()  permissionDenied,required TResult Function()  invalidArgument,required TResult Function()  emailAlreadyExists,required TResult Function( String message)  unknown,}) {final _that = this;
switch (_that) {
case _PermissionDenied():
return permissionDenied();case _InvalidArgument():
return invalidArgument();case _EmailAlreadyExists():
return emailAlreadyExists();case _Unknown():
return unknown(_that.message);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function()?  permissionDenied,TResult? Function()?  invalidArgument,TResult? Function()?  emailAlreadyExists,TResult? Function( String message)?  unknown,}) {final _that = this;
switch (_that) {
case _PermissionDenied() when permissionDenied != null:
return permissionDenied();case _InvalidArgument() when invalidArgument != null:
return invalidArgument();case _EmailAlreadyExists() when emailAlreadyExists != null:
return emailAlreadyExists();case _Unknown() when unknown != null:
return unknown(_that.message);case _:
  return null;

}
}

}

/// @nodoc


class _PermissionDenied implements AdminFailure {
  const _PermissionDenied();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _PermissionDenied);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'AdminFailure.permissionDenied()';
}


}




/// @nodoc


class _InvalidArgument implements AdminFailure {
  const _InvalidArgument();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _InvalidArgument);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'AdminFailure.invalidArgument()';
}


}




/// @nodoc


class _EmailAlreadyExists implements AdminFailure {
  const _EmailAlreadyExists();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _EmailAlreadyExists);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'AdminFailure.emailAlreadyExists()';
}


}




/// @nodoc


class _Unknown implements AdminFailure {
  const _Unknown(this.message);
  

 final  String message;

/// Create a copy of AdminFailure
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$UnknownCopyWith<_Unknown> get copyWith => __$UnknownCopyWithImpl<_Unknown>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Unknown&&(identical(other.message, message) || other.message == message));
}


@override
int get hashCode => Object.hash(runtimeType,message);

@override
String toString() {
  return 'AdminFailure.unknown(message: $message)';
}


}

/// @nodoc
abstract mixin class _$UnknownCopyWith<$Res> implements $AdminFailureCopyWith<$Res> {
  factory _$UnknownCopyWith(_Unknown value, $Res Function(_Unknown) _then) = __$UnknownCopyWithImpl;
@useResult
$Res call({
 String message
});




}
/// @nodoc
class __$UnknownCopyWithImpl<$Res>
    implements _$UnknownCopyWith<$Res> {
  __$UnknownCopyWithImpl(this._self, this._then);

  final _Unknown _self;
  final $Res Function(_Unknown) _then;

/// Create a copy of AdminFailure
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? message = null,}) {
  return _then(_Unknown(
null == message ? _self.message : message // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

// dart format on
