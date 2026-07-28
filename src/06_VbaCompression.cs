using System;
using System.Collections.Generic;
using System.IO;

namespace MacroDesk
{
    public static class VbaCompression
    {
        public static byte[] Decompress(byte[] data)
        {
            return Decompress(data, 0);
        }

        public static byte[] Decompress(byte[] data, int offset)
        {
            if (data == null)
            {
                throw new ArgumentNullException("data");
            }
            if (offset < 0 || offset >= data.Length)
            {
                throw new InvalidDataException(
                    "VBA compressed container offset is outside the stream.");
            }
            if (data[offset] != 0x01)
            {
                throw new InvalidDataException(
                    "Invalid VBA compressed container signature.");
            }

            List<byte> output = new List<byte>();
            int position = offset + 1;
            while (position < data.Length)
            {
                if (position + 2 > data.Length)
                {
                    throw new InvalidDataException(
                        "Truncated VBA compressed chunk header.");
                }

                int chunkStart = position;
                ushort header = BitConverter.ToUInt16(data, position);
                position += 2;

                int chunkSize = (header & 0x0FFF) + 3;
                int chunkSignature = (header >> 12) & 0x0007;
                bool isCompressed = (header & 0x8000) != 0;
                long chunkEndLong = (long)chunkStart + (long)chunkSize;
                if (chunkSignature != 3)
                {
                    throw new InvalidDataException(
                        "Invalid VBA compressed chunk signature.");
                }
                if (chunkEndLong > data.Length)
                {
                    throw new InvalidDataException(
                        "VBA compressed chunk extends past the stream.");
                }

                int chunkEnd = (int)chunkEndLong;
                int decompressedChunkStart = output.Count;
                if (!isCompressed)
                {
                    if (chunkSize != 4098)
                    {
                        throw new InvalidDataException(
                            "Invalid raw VBA chunk size.");
                    }

                    int index;
                    for (index = 0; index < 4096; index++)
                    {
                        output.Add(data[position + index]);
                    }
                    position = chunkEnd;
                    continue;
                }

                DecompressChunk(
                    data,
                    ref position,
                    chunkEnd,
                    decompressedChunkStart,
                    output);
                if (position != chunkEnd)
                {
                    throw new InvalidDataException(
                        "VBA compressed chunk was not consumed exactly.");
                }
            }

            return output.ToArray();
        }

        public static byte[] Compress(byte[] data)
        {
            if (data == null)
            {
                throw new ArgumentNullException("data");
            }

            using (MemoryStream output = new MemoryStream())
            {
                output.WriteByte(0x01);
                int chunkStart = 0;
                while (chunkStart < data.Length)
                {
                    int chunkLength = Math.Min(
                        4096,
                        data.Length - chunkStart);
                    byte[] compressed = CompressChunk(
                        data,
                        chunkStart,
                        chunkLength);

                    if (compressed.Length > 4096 &&
                        chunkLength < 4096)
                    {
                        // 3640 literals plus 455 flag bytes fit in 4096.
                        chunkLength = Math.Min(chunkLength, 3640);
                        compressed = CompressChunk(
                            data,
                            chunkStart,
                            chunkLength);
                    }

                    if (compressed.Length > 4096)
                    {
                        WriteUInt16(output, 0x3FFF);
                        output.Write(data, chunkStart, chunkLength);
                    }
                    else
                    {
                        int chunkSize = compressed.Length + 2;
                        ushort header = (ushort)(
                            0xB000 | (chunkSize - 3));
                        WriteUInt16(output, header);
                        output.Write(
                            compressed,
                            0,
                            compressed.Length);
                    }

                    chunkStart += chunkLength;
                }

                return output.ToArray();
            }
        }

        private static byte[] CompressChunk(
            byte[] data,
            int chunkStart,
            int chunkLength)
        {
            int chunkEnd = chunkStart + chunkLength;
            using (MemoryStream output = new MemoryStream())
            {
                int position = chunkStart;
                while (position < chunkEnd)
                {
                    long flagPosition = output.Position;
                    output.WriteByte(0);
                    byte flags = 0;

                    int bit;
                    for (bit = 0;
                        bit < 8 && position < chunkEnd;
                        bit++)
                    {
                        int matchLength;
                        int matchOffset;
                        FindMatch(
                            data,
                            chunkStart,
                            chunkEnd,
                            position,
                            out matchLength,
                            out matchOffset);

                        if (matchLength >= 3)
                        {
                            int bitCount = GetOffsetBitCount(
                                position - chunkStart);
                            int token =
                                ((matchOffset - 1) <<
                                    (16 - bitCount)) |
                                (matchLength - 3);
                            flags |= (byte)(1 << bit);
                            WriteUInt16(output, (ushort)token);
                            position += matchLength;
                        }
                        else
                        {
                            output.WriteByte(data[position]);
                            position++;
                        }
                    }

                    long endPosition = output.Position;
                    output.Position = flagPosition;
                    output.WriteByte(flags);
                    output.Position = endPosition;
                }

                return output.ToArray();
            }
        }

        private static void FindMatch(
            byte[] data,
            int chunkStart,
            int chunkEnd,
            int position,
            out int bestLength,
            out int bestOffset)
        {
            bestLength = 0;
            bestOffset = 0;
            int decompressedPosition = position - chunkStart;
            if (decompressedPosition == 0)
            {
                return;
            }

            int bitCount = GetOffsetBitCount(decompressedPosition);
            int maximumOffset = Math.Min(
                1 << bitCount,
                decompressedPosition);
            int maximumLength = Math.Min(
                (0xFFFF >> bitCount) + 3,
                chunkEnd - position);

            int offset;
            for (offset = 1; offset <= maximumOffset; offset++)
            {
                if (data[position - offset] != data[position])
                {
                    continue;
                }

                int length = 1;
                while (length < maximumLength &&
                    data[position - offset + (length % offset)] ==
                        data[position + length])
                {
                    length++;
                }

                if (length >= 3 && length > bestLength)
                {
                    bestLength = length;
                    bestOffset = offset;
                    if (bestLength == maximumLength)
                    {
                        break;
                    }
                }
            }
        }

        private static int GetOffsetBitCount(int decompressedPosition)
        {
            int bitCount = 4;
            while ((1 << bitCount) < decompressedPosition &&
                bitCount < 12)
            {
                bitCount++;
            }

            return bitCount;
        }

        private static void WriteUInt16(
            Stream output,
            ushort value)
        {
            output.WriteByte((byte)(value & 0xFF));
            output.WriteByte((byte)(value >> 8));
        }

        private static void DecompressChunk(
            byte[] data,
            ref int position,
            int chunkEnd,
            int decompressedChunkStart,
            List<byte> output)
        {
            while (position < chunkEnd)
            {
                byte flagByte = data[position];
                position++;

                int bit;
                for (bit = 0; bit < 8 && position < chunkEnd; bit++)
                {
                    bool isCopyToken = (flagByte & (1 << bit)) != 0;
                    if (!isCopyToken)
                    {
                        EnsureChunkCapacity(
                            output.Count - decompressedChunkStart,
                            1);
                        output.Add(data[position]);
                        position++;
                    }
                    else
                    {
                        if (position + 2 > chunkEnd)
                        {
                            throw new InvalidDataException(
                                "Truncated VBA copy token.");
                        }

                        ushort token = BitConverter.ToUInt16(data, position);
                        position += 2;
                        CopyToken(
                            token,
                            decompressedChunkStart,
                            output);
                    }
                }
            }
        }

        private static void CopyToken(
            ushort token,
            int decompressedChunkStart,
            List<byte> output)
        {
            int decompressedPosition =
                output.Count - decompressedChunkStart;
            if (decompressedPosition <= 0)
            {
                throw new InvalidDataException(
                    "VBA copy token has no preceding data.");
            }

            int bitCount = 4;
            while ((1 << bitCount) < decompressedPosition &&
                bitCount < 12)
            {
                bitCount++;
            }

            int lengthMask = 0xFFFF >> bitCount;
            int copyLength = (token & lengthMask) + 3;
            int copyOffset = (token >> (16 - bitCount)) + 1;
            if (copyOffset > decompressedPosition)
            {
                throw new InvalidDataException(
                    "VBA copy token points before the chunk.");
            }

            EnsureChunkCapacity(decompressedPosition, copyLength);
            int index;
            for (index = 0; index < copyLength; index++)
            {
                int sourceIndex = output.Count - copyOffset;
                output.Add(output[sourceIndex]);
            }
        }

        private static void EnsureChunkCapacity(
            int decompressedPosition,
            int additionalLength)
        {
            if (decompressedPosition < 0 ||
                additionalLength < 0 ||
                decompressedPosition + additionalLength > 4096)
            {
                throw new InvalidDataException(
                    "VBA decompressed chunk exceeds 4096 bytes.");
            }
        }
    }
}
