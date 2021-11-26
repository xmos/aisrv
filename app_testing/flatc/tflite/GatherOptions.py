# automatically generated by the FlatBuffers compiler, do not modify

# namespace: tflite

import flatbuffers
from flatbuffers.compat import import_numpy
np = import_numpy()

class GatherOptions(object):
    __slots__ = ['_tab']

    @classmethod
    def GetRootAs(cls, buf, offset=0):
        n = flatbuffers.encode.Get(flatbuffers.packer.uoffset, buf, offset)
        x = GatherOptions()
        x.Init(buf, n + offset)
        return x

    @classmethod
    def GetRootAsGatherOptions(cls, buf, offset=0):
        """This method is deprecated. Please switch to GetRootAs."""
        return cls.GetRootAs(buf, offset)
    @classmethod
    def GatherOptionsBufferHasIdentifier(cls, buf, offset, size_prefixed=False):
        return flatbuffers.util.BufferHasIdentifier(buf, offset, b"\x54\x46\x4C\x33", size_prefixed=size_prefixed)

    # GatherOptions
    def Init(self, buf, pos):
        self._tab = flatbuffers.table.Table(buf, pos)

    # GatherOptions
    def Axis(self):
        o = flatbuffers.number_types.UOffsetTFlags.py_type(self._tab.Offset(4))
        if o != 0:
            return self._tab.Get(flatbuffers.number_types.Int32Flags, o + self._tab.Pos)
        return 0

def GatherOptionsStart(builder): builder.StartObject(1)
def Start(builder):
    return GatherOptionsStart(builder)
def GatherOptionsAddAxis(builder, axis): builder.PrependInt32Slot(0, axis, 0)
def AddAxis(builder, axis):
    return GatherOptionsAddAxis(builder, axis)
def GatherOptionsEnd(builder): return builder.EndObject()
def End(builder):
    return GatherOptionsEnd(builder)