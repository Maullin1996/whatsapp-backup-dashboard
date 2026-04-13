// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'admin_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$AdminState {

 List<AppUser> get users; List<Group> get groups; bool get isLoadingUsers; bool get isLoadingGroups; bool get isSubmitting; AdminFailure? get error; String? get successMessage;
/// Create a copy of AdminState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AdminStateCopyWith<AdminState> get copyWith => _$AdminStateCopyWithImpl<AdminState>(this as AdminState, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AdminState&&const DeepCollectionEquality().equals(other.users, users)&&const DeepCollectionEquality().equals(other.groups, groups)&&(identical(other.isLoadingUsers, isLoadingUsers) || other.isLoadingUsers == isLoadingUsers)&&(identical(other.isLoadingGroups, isLoadingGroups) || other.isLoadingGroups == isLoadingGroups)&&(identical(other.isSubmitting, isSubmitting) || other.isSubmitting == isSubmitting)&&(identical(other.error, error) || other.error == error)&&(identical(other.successMessage, successMessage) || other.successMessage == successMessage));
}


@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(users),const DeepCollectionEquality().hash(groups),isLoadingUsers,isLoadingGroups,isSubmitting,error,successMessage);

@override
String toString() {
  return 'AdminState(users: $users, groups: $groups, isLoadingUsers: $isLoadingUsers, isLoadingGroups: $isLoadingGroups, isSubmitting: $isSubmitting, error: $error, successMessage: $successMessage)';
}


}

/// @nodoc
abstract mixin class $AdminStateCopyWith<$Res>  {
  factory $AdminStateCopyWith(AdminState value, $Res Function(AdminState) _then) = _$AdminStateCopyWithImpl;
@useResult
$Res call({
 List<AppUser> users, List<Group> groups, bool isLoadingUsers, bool isLoadingGroups, bool isSubmitting, AdminFailure? error, String? successMessage
});


$AdminFailureCopyWith<$Res>? get error;

}
/// @nodoc
class _$AdminStateCopyWithImpl<$Res>
    implements $AdminStateCopyWith<$Res> {
  _$AdminStateCopyWithImpl(this._self, this._then);

  final AdminState _self;
  final $Res Function(AdminState) _then;

/// Create a copy of AdminState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? users = null,Object? groups = null,Object? isLoadingUsers = null,Object? isLoadingGroups = null,Object? isSubmitting = null,Object? error = freezed,Object? successMessage = freezed,}) {
  return _then(_self.copyWith(
users: null == users ? _self.users : users // ignore: cast_nullable_to_non_nullable
as List<AppUser>,groups: null == groups ? _self.groups : groups // ignore: cast_nullable_to_non_nullable
as List<Group>,isLoadingUsers: null == isLoadingUsers ? _self.isLoadingUsers : isLoadingUsers // ignore: cast_nullable_to_non_nullable
as bool,isLoadingGroups: null == isLoadingGroups ? _self.isLoadingGroups : isLoadingGroups // ignore: cast_nullable_to_non_nullable
as bool,isSubmitting: null == isSubmitting ? _self.isSubmitting : isSubmitting // ignore: cast_nullable_to_non_nullable
as bool,error: freezed == error ? _self.error : error // ignore: cast_nullable_to_non_nullable
as AdminFailure?,successMessage: freezed == successMessage ? _self.successMessage : successMessage // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}
/// Create a copy of AdminState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$AdminFailureCopyWith<$Res>? get error {
    if (_self.error == null) {
    return null;
  }

  return $AdminFailureCopyWith<$Res>(_self.error!, (value) {
    return _then(_self.copyWith(error: value));
  });
}
}


/// Adds pattern-matching-related methods to [AdminState].
extension AdminStatePatterns on AdminState {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _AdminState value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _AdminState() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _AdminState value)  $default,){
final _that = this;
switch (_that) {
case _AdminState():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _AdminState value)?  $default,){
final _that = this;
switch (_that) {
case _AdminState() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( List<AppUser> users,  List<Group> groups,  bool isLoadingUsers,  bool isLoadingGroups,  bool isSubmitting,  AdminFailure? error,  String? successMessage)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _AdminState() when $default != null:
return $default(_that.users,_that.groups,_that.isLoadingUsers,_that.isLoadingGroups,_that.isSubmitting,_that.error,_that.successMessage);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( List<AppUser> users,  List<Group> groups,  bool isLoadingUsers,  bool isLoadingGroups,  bool isSubmitting,  AdminFailure? error,  String? successMessage)  $default,) {final _that = this;
switch (_that) {
case _AdminState():
return $default(_that.users,_that.groups,_that.isLoadingUsers,_that.isLoadingGroups,_that.isSubmitting,_that.error,_that.successMessage);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( List<AppUser> users,  List<Group> groups,  bool isLoadingUsers,  bool isLoadingGroups,  bool isSubmitting,  AdminFailure? error,  String? successMessage)?  $default,) {final _that = this;
switch (_that) {
case _AdminState() when $default != null:
return $default(_that.users,_that.groups,_that.isLoadingUsers,_that.isLoadingGroups,_that.isSubmitting,_that.error,_that.successMessage);case _:
  return null;

}
}

}

/// @nodoc


class _AdminState implements AdminState {
  const _AdminState({final  List<AppUser> users = const [], final  List<Group> groups = const [], this.isLoadingUsers = false, this.isLoadingGroups = false, this.isSubmitting = false, this.error, this.successMessage}): _users = users,_groups = groups;
  

 final  List<AppUser> _users;
@override@JsonKey() List<AppUser> get users {
  if (_users is EqualUnmodifiableListView) return _users;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_users);
}

 final  List<Group> _groups;
@override@JsonKey() List<Group> get groups {
  if (_groups is EqualUnmodifiableListView) return _groups;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_groups);
}

@override@JsonKey() final  bool isLoadingUsers;
@override@JsonKey() final  bool isLoadingGroups;
@override@JsonKey() final  bool isSubmitting;
@override final  AdminFailure? error;
@override final  String? successMessage;

/// Create a copy of AdminState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$AdminStateCopyWith<_AdminState> get copyWith => __$AdminStateCopyWithImpl<_AdminState>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _AdminState&&const DeepCollectionEquality().equals(other._users, _users)&&const DeepCollectionEquality().equals(other._groups, _groups)&&(identical(other.isLoadingUsers, isLoadingUsers) || other.isLoadingUsers == isLoadingUsers)&&(identical(other.isLoadingGroups, isLoadingGroups) || other.isLoadingGroups == isLoadingGroups)&&(identical(other.isSubmitting, isSubmitting) || other.isSubmitting == isSubmitting)&&(identical(other.error, error) || other.error == error)&&(identical(other.successMessage, successMessage) || other.successMessage == successMessage));
}


@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_users),const DeepCollectionEquality().hash(_groups),isLoadingUsers,isLoadingGroups,isSubmitting,error,successMessage);

@override
String toString() {
  return 'AdminState(users: $users, groups: $groups, isLoadingUsers: $isLoadingUsers, isLoadingGroups: $isLoadingGroups, isSubmitting: $isSubmitting, error: $error, successMessage: $successMessage)';
}


}

/// @nodoc
abstract mixin class _$AdminStateCopyWith<$Res> implements $AdminStateCopyWith<$Res> {
  factory _$AdminStateCopyWith(_AdminState value, $Res Function(_AdminState) _then) = __$AdminStateCopyWithImpl;
@override @useResult
$Res call({
 List<AppUser> users, List<Group> groups, bool isLoadingUsers, bool isLoadingGroups, bool isSubmitting, AdminFailure? error, String? successMessage
});


@override $AdminFailureCopyWith<$Res>? get error;

}
/// @nodoc
class __$AdminStateCopyWithImpl<$Res>
    implements _$AdminStateCopyWith<$Res> {
  __$AdminStateCopyWithImpl(this._self, this._then);

  final _AdminState _self;
  final $Res Function(_AdminState) _then;

/// Create a copy of AdminState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? users = null,Object? groups = null,Object? isLoadingUsers = null,Object? isLoadingGroups = null,Object? isSubmitting = null,Object? error = freezed,Object? successMessage = freezed,}) {
  return _then(_AdminState(
users: null == users ? _self._users : users // ignore: cast_nullable_to_non_nullable
as List<AppUser>,groups: null == groups ? _self._groups : groups // ignore: cast_nullable_to_non_nullable
as List<Group>,isLoadingUsers: null == isLoadingUsers ? _self.isLoadingUsers : isLoadingUsers // ignore: cast_nullable_to_non_nullable
as bool,isLoadingGroups: null == isLoadingGroups ? _self.isLoadingGroups : isLoadingGroups // ignore: cast_nullable_to_non_nullable
as bool,isSubmitting: null == isSubmitting ? _self.isSubmitting : isSubmitting // ignore: cast_nullable_to_non_nullable
as bool,error: freezed == error ? _self.error : error // ignore: cast_nullable_to_non_nullable
as AdminFailure?,successMessage: freezed == successMessage ? _self.successMessage : successMessage // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

/// Create a copy of AdminState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$AdminFailureCopyWith<$Res>? get error {
    if (_self.error == null) {
    return null;
  }

  return $AdminFailureCopyWith<$Res>(_self.error!, (value) {
    return _then(_self.copyWith(error: value));
  });
}
}

// dart format on
