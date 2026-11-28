// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class UserAdapter extends TypeAdapter<User> {
  @override
  final typeId = 1;

  @override
  User read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return User(
      id: (fields[0] as num).toInt(),
      token: (fields[1] as num).toInt(),
      email: fields[2] as String,
      name: fields[3] as String,
      roleId: (fields[4] as num).toInt(),
      picture: fields[5] as String?,
      gender: (fields[6] as num?)?.toInt(),
      ageRange: (fields[7] as num?)?.toInt(),
      mobile: fields[8] as String?,
      country: fields[9] as String?,
      state: fields[10] as String?,
      city: fields[11] as String?,
      language: (fields[12] as num?)?.toInt(),
      zip: fields[13] as String?,
      sendupdates: fields[14] as String?,
      unsubscribe: fields[15] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, User obj) {
    writer
      ..writeByte(16)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.token)
      ..writeByte(2)
      ..write(obj.email)
      ..writeByte(3)
      ..write(obj.name)
      ..writeByte(4)
      ..write(obj.roleId)
      ..writeByte(5)
      ..write(obj.picture)
      ..writeByte(6)
      ..write(obj.gender)
      ..writeByte(7)
      ..write(obj.ageRange)
      ..writeByte(8)
      ..write(obj.mobile)
      ..writeByte(9)
      ..write(obj.country)
      ..writeByte(10)
      ..write(obj.state)
      ..writeByte(11)
      ..write(obj.city)
      ..writeByte(12)
      ..write(obj.language)
      ..writeByte(13)
      ..write(obj.zip)
      ..writeByte(14)
      ..write(obj.sendupdates)
      ..writeByte(15)
      ..write(obj.unsubscribe);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
