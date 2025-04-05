// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'recordings_page.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class RecordingAdapter extends TypeAdapter<Recording> {
  @override
  final int typeId = 0;

  @override
  Recording read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Recording(
      id: fields[3] as String,
      title: fields[0] as String,
      dateTime: fields[1] as DateTime,
      preview: fields[2] as String,
    );
  }

  @override
  void write(BinaryWriter writer, Recording obj) {
    writer
      ..writeByte(4)
      ..writeByte(0)
      ..write(obj.title)
      ..writeByte(1)
      ..write(obj.dateTime)
      ..writeByte(2)
      ..write(obj.preview)
      ..writeByte(3)
      ..write(obj.id);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RecordingAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
