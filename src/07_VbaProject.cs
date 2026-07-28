using System;
using System.Collections.Generic;
using System.IO;
using System.Text;

namespace MacroDesk
{
    public enum VbaModuleKind
    {
        Document = 0,
        Form = 1,
        Standard = 2,
        Class = 3
    }

    public sealed class VbaDirModule
    {
        public string Name;
        public string StreamName;
        public uint SourceOffset;
        public ushort TypeId;

        public VbaDirModule()
        {
            Name = string.Empty;
            StreamName = string.Empty;
        }
    }

    public sealed class VbaModule
    {
        public string Name;
        public string StreamName;
        public VbaModuleKind Kind;
        public string Extension;
        public uint SourceOffset;
        public byte[] StreamData;
        public byte[] FullSourceBytes;
        public string FullCode;
        public string AttributeHeader;
        public string Code;
        public Ole2DirectoryEntry StreamEntry;

        public VbaModule()
        {
            Name = string.Empty;
            StreamName = string.Empty;
            Extension = string.Empty;
            StreamData = new byte[0];
            FullSourceBytes = new byte[0];
            FullCode = string.Empty;
            AttributeHeader = string.Empty;
            Code = string.Empty;
        }
    }

    public sealed class VbaProjectData
    {
        public byte[] Ole2Bytes;
        public Ole2File Ole2;
        public int CodePage;
        public Encoding Encoding;
        public byte[] ProjectBytes;
        public string ProjectText;
        public byte[] ProjectWmBytes;
        public List<string> ProjectWmNames;
        public byte[] DirCompressed;
        public byte[] DirDecompressed;
        public int ProjectModulesOffset;
        public Ole2DirectoryEntry ProjectEntry;
        public Ole2DirectoryEntry ProjectWmEntry;
        public Ole2DirectoryEntry DirEntry;
        public Ole2DirectoryEntry VbaStorage;
        public List<VbaModule> Modules;
        public string FilePath;
        public bool IsZip;

        public VbaProjectData()
        {
            Ole2Bytes = new byte[0];
            ProjectBytes = new byte[0];
            ProjectText = string.Empty;
            ProjectWmBytes = new byte[0];
            ProjectWmNames = new List<string>();
            DirCompressed = new byte[0];
            DirDecompressed = new byte[0];
            Modules = new List<VbaModule>();
            FilePath = string.Empty;
        }
    }

    public static class VbaProjectReader
    {
        public static VbaProjectData Read(byte[] ole2Bytes)
        {
            if (ole2Bytes == null)
            {
                throw new ArgumentNullException("ole2Bytes");
            }

            Ole2File ole2 = Ole2File.Parse(ole2Bytes);
            Ole2DirectoryEntry projectEntry = ole2.FindChild(
                ole2.RootEntry,
                "PROJECT",
                2);
            Ole2DirectoryEntry vbaStorage = ole2.FindChild(
                ole2.RootEntry,
                "VBA",
                1);
            Ole2DirectoryEntry projectWmEntry = ole2.FindChild(
                ole2.RootEntry,
                "PROJECTwm",
                2);
            if (projectEntry == null)
            {
                throw new InvalidDataException(
                    "PROJECT stream was not found in the VBA project.");
            }
            if (vbaStorage == null)
            {
                throw new InvalidDataException(
                    "VBA storage was not found in the VBA project.");
            }

            Ole2DirectoryEntry dirEntry = ole2.FindChild(
                vbaStorage,
                "dir",
                2);
            if (dirEntry == null)
            {
                throw new InvalidDataException(
                    "dir stream was not found in the VBA storage.");
            }

            byte[] dirCompressed = ole2.ReadStream(dirEntry);
            byte[] dirDecompressed = VbaCompression.Decompress(dirCompressed);
            int codePage;
            int projectModulesOffset;
            List<VbaDirModule> dirModules = ReadDirModules(
                dirDecompressed,
                out codePage,
                out projectModulesOffset);
            Encoding encoding = GetStrictEncoding(codePage);

            byte[] projectBytes = ole2.ReadStream(projectEntry);
            string projectText = encoding.GetString(projectBytes);
            Dictionary<string, VbaModuleKind> projectTypes =
                ParseProjectTypes(projectText);
            if (projectTypes.Count != dirModules.Count)
            {
                throw new InvalidDataException(
                    "PROJECT and dir module counts do not match.");
            }

            byte[] projectWmBytes = new byte[0];
            List<string> projectWmNames = new List<string>();
            if (projectWmEntry != null)
            {
                projectWmBytes = ole2.ReadStream(projectWmEntry);
                projectWmNames = ReadProjectWmNames(
                    projectWmBytes,
                    encoding);
                if (projectWmNames.Count != dirModules.Count)
                {
                    throw new InvalidDataException(
                        "PROJECTwm and dir module counts do not match.");
                }

                int nameIndex;
                for (nameIndex = 0;
                    nameIndex < dirModules.Count;
                    nameIndex++)
                {
                    if (!string.Equals(
                        projectWmNames[nameIndex],
                        dirModules[nameIndex].Name,
                        StringComparison.Ordinal))
                    {
                        throw new InvalidDataException(
                            "PROJECTwm and dir module names do not match.");
                    }
                }
            }

            VbaProjectData project = new VbaProjectData();
            project.Ole2Bytes = ole2Bytes;
            project.Ole2 = ole2;
            project.CodePage = codePage;
            project.Encoding = encoding;
            project.ProjectBytes = projectBytes;
            project.ProjectText = projectText;
            project.ProjectWmBytes = projectWmBytes;
            project.ProjectWmNames = projectWmNames;
            project.DirCompressed = dirCompressed;
            project.DirDecompressed = dirDecompressed;
            project.ProjectModulesOffset = projectModulesOffset;
            project.ProjectEntry = projectEntry;
            project.ProjectWmEntry = projectWmEntry;
            project.DirEntry = dirEntry;
            project.VbaStorage = vbaStorage;

            HashSet<int> usedStreamIds = new HashSet<int>();
            int index;
            for (index = 0; index < dirModules.Count; index++)
            {
                VbaDirModule record = dirModules[index];
                VbaModuleKind kind;
                if (!projectTypes.TryGetValue(record.Name, out kind))
                {
                    throw new InvalidDataException(
                        "dir module is missing from PROJECT: " +
                        record.Name);
                }

                ValidateModuleType(record, kind);
                Ole2DirectoryEntry streamEntry = ole2.FindChild(
                    vbaStorage,
                    record.StreamName,
                    2);
                if (streamEntry == null)
                {
                    throw new InvalidDataException(
                        "Module stream was not found: logical=" +
                        record.Name +
                        ", stream=" +
                        record.StreamName);
                }
                if (!usedStreamIds.Add(streamEntry.Id))
                {
                    throw new InvalidDataException(
                        "Multiple modules refer to the same stream: " +
                        record.StreamName);
                }

                byte[] streamData = ole2.ReadStream(streamEntry);
                if (record.SourceOffset > int.MaxValue ||
                    record.SourceOffset >= streamData.Length)
                {
                    throw new InvalidDataException(
                        "MODULEOFFSET is outside the module stream: " +
                        record.Name);
                }

                byte[] fullSourceBytes = VbaCompression.Decompress(
                    streamData,
                    (int)record.SourceOffset);
                string fullCode = encoding.GetString(fullSourceBytes);
                string attributeHeader;
                string code;
                SplitAttributeHeader(
                    fullCode,
                    out attributeHeader,
                    out code);

                VbaModule module = new VbaModule();
                module.Name = record.Name;
                module.StreamName = record.StreamName;
                module.Kind = kind;
                module.Extension = GetExtension(kind);
                module.SourceOffset = record.SourceOffset;
                module.StreamData = streamData;
                module.FullSourceBytes = fullSourceBytes;
                module.FullCode = fullCode;
                module.AttributeHeader = attributeHeader;
                module.Code = code;
                module.StreamEntry = streamEntry;
                project.Modules.Add(module);
            }

            project.Modules.Sort(delegate(VbaModule left, VbaModule right)
            {
                int typeResult = ((int)left.Kind).CompareTo((int)right.Kind);
                if (typeResult != 0)
                {
                    return typeResult;
                }

                return StringComparer.OrdinalIgnoreCase.Compare(
                    left.Name,
                    right.Name);
            });

            return project;
        }

        public static List<VbaDirModule> ReadDirModules(
            byte[] dirDecompressed,
            out int codePage)
        {
            int projectModulesOffset;
            return ReadDirModules(
                dirDecompressed,
                out codePage,
                out projectModulesOffset);
        }

        private static List<VbaDirModule> ReadDirModules(
            byte[] dirDecompressed,
            out int codePage,
            out int projectModulesOffset)
        {
            if (dirDecompressed == null)
            {
                throw new ArgumentNullException("dirDecompressed");
            }

            List<int> modulesOffsets =
                FindProjectModulesOffsets(dirDecompressed);
            if (modulesOffsets.Count == 0)
            {
                throw new InvalidDataException(
                    "PROJECTMODULES record was not found in dir.");
            }

            int successfulCount = 0;
            int successfulCodePage = 932;
            int successfulModulesOffset = -1;
            List<VbaDirModule> successfulModules = null;
            InvalidDataException lastFailure = null;
            int moduleIndex;
            for (moduleIndex = 0;
                moduleIndex < modulesOffsets.Count;
                moduleIndex++)
            {
                int modulesOffset = modulesOffsets[moduleIndex];
                List<int> codePages =
                    FindCodePageCandidates(
                        dirDecompressed,
                        modulesOffset);
                int codePageIndex;
                for (codePageIndex = 0;
                    codePageIndex < codePages.Count;
                    codePageIndex++)
                {
                    int candidateCodePage = codePages[codePageIndex];
                    try
                    {
                        Encoding encoding =
                            GetStrictEncoding(candidateCodePage);
                        List<VbaDirModule> modules =
                            ParseDirModules(
                                dirDecompressed,
                                modulesOffset,
                                encoding);
                        successfulCount++;
                        if (successfulCount == 1)
                        {
                            successfulCodePage = candidateCodePage;
                            successfulModulesOffset = modulesOffset;
                            successfulModules = modules;
                        }
                    }
                    catch (InvalidDataException ex)
                    {
                        lastFailure = ex;
                    }
                    catch (DecoderFallbackException ex)
                    {
                        lastFailure = new InvalidDataException(
                            "VBA dir text does not match its code page.",
                            ex);
                    }
                }
            }

            if (successfulCount == 1)
            {
                codePage = successfulCodePage;
                projectModulesOffset = successfulModulesOffset;
                return successfulModules;
            }
            if (successfulCount > 1)
            {
                throw new InvalidDataException(
                    "Multiple valid VBA dir record candidates were found.");
            }
            if (modulesOffsets.Count == 1 && lastFailure != null)
            {
                throw lastFailure;
            }

            throw new InvalidDataException(
                "No valid PROJECTMODULES record was found in dir.");
        }

        public static void SplitAttributeHeader(
            string fullCode,
            out string attributeHeader,
            out string code)
        {
            if (fullCode == null)
            {
                throw new ArgumentNullException("fullCode");
            }

            int headerLength = FindAttributeHeaderLength(fullCode);
            attributeHeader = fullCode.Substring(0, headerLength);
            code = fullCode.Substring(headerLength);
        }

        public static List<string> ReadProjectWmNames(
            byte[] data,
            Encoding encoding)
        {
            if (data == null)
            {
                throw new ArgumentNullException("data");
            }
            if (encoding == null)
            {
                throw new ArgumentNullException("encoding");
            }
            if (data.Length < 2 ||
                data[data.Length - 2] != 0 ||
                data[data.Length - 1] != 0)
            {
                throw new InvalidDataException(
                    "PROJECTwm terminator is missing.");
            }

            List<string> result = new List<string>();
            int limit = data.Length - 2;
            int position = 0;
            while (position < limit)
            {
                int ansiStart = position;
                while (position < limit && data[position] != 0)
                {
                    position++;
                }
                if (position == ansiStart || position >= limit)
                {
                    throw new InvalidDataException(
                        "PROJECTwm contains an invalid module name.");
                }

                string ansiName = encoding.GetString(
                    data,
                    ansiStart,
                    position - ansiStart);
                position++;

                int unicodeStart = position;
                while (position + 1 < limit &&
                    (data[position] != 0 ||
                     data[position + 1] != 0))
                {
                    position += 2;
                }
                if (position == unicodeStart ||
                    position + 1 >= limit ||
                    ((position - unicodeStart) & 1) != 0)
                {
                    throw new InvalidDataException(
                        "PROJECTwm contains an invalid Unicode name.");
                }

                string unicodeName = Encoding.Unicode.GetString(
                    data,
                    unicodeStart,
                    position - unicodeStart);
                position += 2;
                if (!string.Equals(
                    ansiName,
                    unicodeName,
                    StringComparison.Ordinal))
                {
                    throw new InvalidDataException(
                        "PROJECTwm module name encodings do not match.");
                }
                result.Add(unicodeName);
            }

            if (position != limit)
            {
                throw new InvalidDataException(
                    "PROJECTwm module names are misaligned.");
            }
            return result;
        }

        private static List<int> FindProjectModulesOffsets(byte[] data)
        {
            List<int> offsets = new List<int>();
            int position;
            for (position = 0; position + 16 <= data.Length; position++)
            {
                if (ReadUInt16(data, position) != 0x000F ||
                    ReadUInt32(data, position + 2) != 2 ||
                    ReadUInt16(data, position + 8) != 0x0013 ||
                    ReadUInt32(data, position + 10) != 2)
                {
                    continue;
                }

                offsets.Add(position);
            }

            return offsets;
        }

        private static List<int> FindCodePageCandidates(
            byte[] data,
            int modulesOffset)
        {
            List<int> codePages = new List<int>();
            int position;
            for (position = 0;
                position + 8 <= modulesOffset;
                position++)
            {
                if (ReadUInt16(data, position) == 0x0003 &&
                    ReadUInt32(data, position + 2) == 2)
                {
                    codePages.Add(
                        ReadUInt16(data, position + 6));
                }
            }

            if (codePages.Count == 0)
            {
                codePages.Add(932);
            }
            else if (codePages.Count == 1)
            {
                try
                {
                    Encoding.GetEncoding(codePages[0]);
                }
                catch (ArgumentException)
                {
                    codePages[0] = 932;
                }
                catch (NotSupportedException)
                {
                    codePages[0] = 932;
                }
            }

            return codePages;
        }

        private static List<VbaDirModule> ParseDirModules(
            byte[] data,
            int modulesOffset,
            Encoding encoding)
        {
            int position = modulesOffset;
            RequireId(data, ref position, 0x000F, "PROJECTMODULES");
            uint size = ReadUInt32AndAdvance(data, ref position);
            if (size != 2)
            {
                throw new InvalidDataException(
                    "Invalid PROJECTMODULES size.");
            }

            ushort count = ReadUInt16AndAdvance(data, ref position);
            RequireId(data, ref position, 0x0013, "PROJECTCOOKIE");
            size = ReadUInt32AndAdvance(data, ref position);
            if (size != 2)
            {
                throw new InvalidDataException("Invalid PROJECTCOOKIE size.");
            }
            ReadUInt16AndAdvance(data, ref position);

            List<VbaDirModule> modules = new List<VbaDirModule>();
            int index;
            for (index = 0; index < count; index++)
            {
                modules.Add(ParseDirModule(data, ref position, encoding));
            }

            RequireId(data, ref position, 0x0010, "PROJECTTERMINATOR");
            ReadUInt32AndAdvance(data, ref position);
            if (position != data.Length)
            {
                throw new InvalidDataException(
                    "Unexpected data after PROJECTTERMINATOR.");
            }

            return modules;
        }

        private static VbaDirModule ParseDirModule(
            byte[] data,
            ref int position,
            Encoding encoding)
        {
            byte[] nameBytes = ReadSizedRecord(
                data,
                ref position,
                0x0019,
                "MODULENAME");
            string name = encoding.GetString(nameBytes);
            string unicodeName = string.Empty;
            if (PeekId(data, position) == 0x0047)
            {
                byte[] unicodeNameBytes = ReadSizedRecord(
                    data,
                    ref position,
                    0x0047,
                    "MODULENAMEUNICODE");
                if ((unicodeNameBytes.Length & 1) != 0)
                {
                    throw new InvalidDataException(
                        "MODULENAMEUNICODE has an odd byte length.");
                }
                unicodeName = Encoding.Unicode.GetString(unicodeNameBytes);
            }

            RequireId(data, ref position, 0x001A, "MODULESTREAMNAME");
            byte[] streamNameBytes = ReadLengthPrefixedBytes(
                data,
                ref position,
                "MODULESTREAMNAME");
            string streamName = encoding.GetString(streamNameBytes);
            RequireId(
                data,
                ref position,
                0x0032,
                "MODULESTREAMNAME reserved");
            byte[] unicodeStreamNameBytes = ReadLengthPrefixedBytes(
                data,
                ref position,
                "MODULESTREAMNAMEUNICODE");
            if ((unicodeStreamNameBytes.Length & 1) != 0)
            {
                throw new InvalidDataException(
                    "MODULESTREAMNAMEUNICODE has an odd byte length.");
            }
            string unicodeStreamName = Encoding.Unicode.GetString(
                unicodeStreamNameBytes);

            RequireId(data, ref position, 0x001C, "MODULEDOCSTRING");
            ReadLengthPrefixedBytes(
                data,
                ref position,
                "MODULEDOCSTRING");
            RequireId(
                data,
                ref position,
                0x0048,
                "MODULEDOCSTRING reserved");
            byte[] unicodeDocString = ReadLengthPrefixedBytes(
                data,
                ref position,
                "MODULEDOCSTRINGUNICODE");
            if ((unicodeDocString.Length & 1) != 0)
            {
                throw new InvalidDataException(
                    "MODULEDOCSTRINGUNICODE has an odd byte length.");
            }

            RequireId(data, ref position, 0x0031, "MODULEOFFSET");
            uint offsetSize = ReadUInt32AndAdvance(data, ref position);
            if (offsetSize != 4)
            {
                throw new InvalidDataException("Invalid MODULEOFFSET size.");
            }
            uint sourceOffset = ReadUInt32AndAdvance(data, ref position);

            SkipFixedRecord(
                data,
                ref position,
                0x001E,
                4,
                "MODULEHELPCONTEXT");
            SkipFixedRecord(
                data,
                ref position,
                0x002C,
                2,
                "MODULECOOKIE");

            ushort typeId = ReadUInt16AndAdvance(data, ref position);
            if (typeId != 0x0021 && typeId != 0x0022)
            {
                throw new InvalidDataException("Invalid MODULETYPE record.");
            }
            SkipBytes(data, ref position, 4, "MODULETYPE reserved");

            while (PeekId(data, position) == 0x0025 ||
                PeekId(data, position) == 0x0028)
            {
                ReadUInt16AndAdvance(data, ref position);
                SkipBytes(data, ref position, 4, "module flag reserved");
            }

            RequireId(data, ref position, 0x002B, "MODULETERMINATOR");
            SkipBytes(data, ref position, 4, "MODULETERMINATOR reserved");

            if (name.Length == 0 || streamName.Length == 0)
            {
                throw new InvalidDataException(
                    "A dir module has an empty name.");
            }
            if (unicodeName.Length > 0 &&
                !string.Equals(name, unicodeName, StringComparison.Ordinal))
            {
                throw new InvalidDataException(
                    "MODULENAME and MODULENAMEUNICODE do not match.");
            }
            if (unicodeStreamName.Length > 0 &&
                !string.Equals(
                    streamName,
                    unicodeStreamName,
                    StringComparison.Ordinal))
            {
                throw new InvalidDataException(
                    "MODULESTREAMNAME encodings do not match.");
            }

            VbaDirModule module = new VbaDirModule();
            module.Name = unicodeName.Length > 0 ? unicodeName : name;
            module.StreamName =
                unicodeStreamName.Length > 0 ?
                unicodeStreamName :
                streamName;
            module.SourceOffset = sourceOffset;
            module.TypeId = typeId;
            return module;
        }

        private static Dictionary<string, VbaModuleKind> ParseProjectTypes(
            string projectText)
        {
            Dictionary<string, VbaModuleKind> result =
                new Dictionary<string, VbaModuleKind>(
                    StringComparer.OrdinalIgnoreCase);
            string[] lines = projectText.Split(
                new string[] { "\r\n", "\n", "\r" },
                StringSplitOptions.None);
            int index;
            for (index = 0; index < lines.Length; index++)
            {
                string line = lines[index];
                if (line.StartsWith("Document=", StringComparison.Ordinal))
                {
                    string value = line.Substring("Document=".Length);
                    int slash = value.IndexOf('/');
                    if (slash >= 0)
                    {
                        value = value.Substring(0, slash);
                    }
                    AddProjectType(result, value, VbaModuleKind.Document);
                }
                else if (line.StartsWith(
                    "BaseClass=",
                    StringComparison.Ordinal))
                {
                    AddProjectType(
                        result,
                        line.Substring("BaseClass=".Length),
                        VbaModuleKind.Form);
                }
                else if (line.StartsWith(
                    "Module=",
                    StringComparison.Ordinal))
                {
                    AddProjectType(
                        result,
                        line.Substring("Module=".Length),
                        VbaModuleKind.Standard);
                }
                else if (line.StartsWith(
                    "Class=",
                    StringComparison.Ordinal))
                {
                    AddProjectType(
                        result,
                        line.Substring("Class=".Length),
                        VbaModuleKind.Class);
                }
            }

            return result;
        }

        private static void AddProjectType(
            Dictionary<string, VbaModuleKind> types,
            string name,
            VbaModuleKind kind)
        {
            if (name.Length == 0)
            {
                throw new InvalidDataException(
                    "PROJECT contains an empty module name.");
            }
            if (types.ContainsKey(name))
            {
                throw new InvalidDataException(
                    "PROJECT contains a duplicate module: " + name);
            }

            types.Add(name, kind);
        }

        private static void ValidateModuleType(
            VbaDirModule record,
            VbaModuleKind kind)
        {
            ushort expectedType =
                kind == VbaModuleKind.Standard ?
                (ushort)0x0021 :
                (ushort)0x0022;
            if (record.TypeId != expectedType)
            {
                throw new InvalidDataException(
                    "PROJECT and dir module types do not match: " +
                    record.Name);
            }
        }

        private static string GetExtension(VbaModuleKind kind)
        {
            if (kind == VbaModuleKind.Standard)
            {
                return "bas";
            }
            if (kind == VbaModuleKind.Form)
            {
                return "frm";
            }

            return "cls";
        }

        private static int FindAttributeHeaderLength(string text)
        {
            int position = 0;
            int headerEnd = 0;
            while (position < text.Length)
            {
                int contentEnd = position;
                while (contentEnd < text.Length &&
                    text[contentEnd] != '\r' &&
                    text[contentEnd] != '\n')
                {
                    contentEnd++;
                }

                string line = text.Substring(
                    position,
                    contentEnd - position);
                if (!IsAttributeLine(line))
                {
                    break;
                }

                int next = contentEnd;
                if (next < text.Length && text[next] == '\r')
                {
                    next++;
                    if (next < text.Length && text[next] == '\n')
                    {
                        next++;
                    }
                }
                else if (next < text.Length && text[next] == '\n')
                {
                    next++;
                }

                headerEnd = next;
                position = next;
            }

            return headerEnd;
        }

        private static bool IsAttributeLine(string line)
        {
            int position = 0;
            while (position < line.Length &&
                (line[position] == ' ' || line[position] == '\t'))
            {
                position++;
            }

            return line.IndexOf(
                "Attribute VB_",
                position,
                StringComparison.OrdinalIgnoreCase) == position;
        }

        private static Encoding GetStrictEncoding(int codePage)
        {
            try
            {
                return Encoding.GetEncoding(
                    codePage,
                    EncoderFallback.ExceptionFallback,
                    DecoderFallback.ExceptionFallback);
            }
            catch (ArgumentException)
            {
                throw new InvalidDataException(
                    "Unsupported VBA project code page: " + codePage);
            }
            catch (NotSupportedException)
            {
                throw new InvalidDataException(
                    "Unsupported VBA project code page: " + codePage);
            }
        }

        private static byte[] ReadSizedRecord(
            byte[] data,
            ref int position,
            ushort id,
            string label)
        {
            RequireId(data, ref position, id, label);
            return ReadLengthPrefixedBytes(data, ref position, label);
        }

        private static byte[] ReadLengthPrefixedBytes(
            byte[] data,
            ref int position,
            string label)
        {
            uint length = ReadUInt32AndAdvance(data, ref position);
            if (length > int.MaxValue)
            {
                throw new InvalidDataException(label + " is too large.");
            }

            int byteLength = (int)length;
            RequireRange(data, position, byteLength, label);
            byte[] result = new byte[byteLength];
            if (byteLength > 0)
            {
                Buffer.BlockCopy(
                    data,
                    position,
                    result,
                    0,
                    byteLength);
            }
            position += byteLength;
            return result;
        }

        private static void SkipFixedRecord(
            byte[] data,
            ref int position,
            ushort id,
            uint expectedSize,
            string label)
        {
            RequireId(data, ref position, id, label);
            uint size = ReadUInt32AndAdvance(data, ref position);
            if (size != expectedSize)
            {
                throw new InvalidDataException(
                    "Invalid " + label + " size.");
            }
            SkipBytes(data, ref position, (int)size, label);
        }

        private static void RequireId(
            byte[] data,
            ref int position,
            ushort expected,
            string label)
        {
            ushort actual = ReadUInt16AndAdvance(data, ref position);
            if (actual != expected)
            {
                throw new InvalidDataException(
                    "Expected " +
                    label +
                    " record 0x" +
                    expected.ToString("X4") +
                    ", found 0x" +
                    actual.ToString("X4") +
                    ".");
            }
        }

        private static ushort PeekId(byte[] data, int position)
        {
            RequireRange(data, position, 2, "dir record ID");
            return ReadUInt16(data, position);
        }

        private static ushort ReadUInt16AndAdvance(
            byte[] data,
            ref int position)
        {
            ushort value = ReadUInt16(data, position);
            position += 2;
            return value;
        }

        private static uint ReadUInt32AndAdvance(
            byte[] data,
            ref int position)
        {
            uint value = ReadUInt32(data, position);
            position += 4;
            return value;
        }

        private static ushort ReadUInt16(byte[] data, int position)
        {
            RequireRange(data, position, 2, "dir data");
            return BitConverter.ToUInt16(data, position);
        }

        private static uint ReadUInt32(byte[] data, int position)
        {
            RequireRange(data, position, 4, "dir data");
            return BitConverter.ToUInt32(data, position);
        }

        private static void SkipBytes(
            byte[] data,
            ref int position,
            int count,
            string label)
        {
            RequireRange(data, position, count, label);
            position += count;
        }

        private static void RequireRange(
            byte[] data,
            int position,
            int count,
            string label)
        {
            if (position < 0 ||
                count < 0 ||
                (long)position + (long)count > data.Length)
            {
                throw new InvalidDataException(
                    "Unexpected end of " + label + ".");
            }
        }
    }

    public sealed class VbaModuleAddition
    {
        public string Name;
        public string Code;

        public VbaModuleAddition(string name, string code)
        {
            Name = name;
            Code = code;
        }
    }

    public static class VbaProjectWriter
    {
        public static Dictionary<int, byte[]> CreateStreamChanges(
            VbaProjectData project,
            IDictionary<string, string> moduleChanges)
        {
            if (project == null)
            {
                throw new ArgumentNullException("project");
            }
            if (moduleChanges == null)
            {
                throw new ArgumentNullException("moduleChanges");
            }

            Dictionary<string, VbaModule> modules =
                new Dictionary<string, VbaModule>(
                    StringComparer.OrdinalIgnoreCase);
            int index;
            for (index = 0; index < project.Modules.Count; index++)
            {
                VbaModule module = project.Modules[index];
                if (modules.ContainsKey(module.Name))
                {
                    throw new InvalidDataException(
                        "Duplicate VBA module name: " + module.Name);
                }
                modules.Add(module.Name, module);
            }

            Dictionary<int, byte[]> result =
                new Dictionary<int, byte[]>();
            foreach (KeyValuePair<string, string> change in moduleChanges)
            {
                VbaModule module;
                if (!modules.TryGetValue(change.Key, out module))
                {
                    throw new InvalidDataException(
                        "VBA module was not found: " + change.Key);
                }
                if (change.Value == null)
                {
                    throw new ArgumentException(
                        "A VBA module change is null.",
                        "moduleChanges");
                }
                if (module.StreamEntry == null ||
                    module.StreamEntry.ObjectType != 2)
                {
                    throw new InvalidDataException(
                        "VBA module stream entry is invalid: " +
                        module.Name);
                }
                if (result.ContainsKey(module.StreamEntry.Id))
                {
                    throw new InvalidDataException(
                        "Multiple VBA modules refer to one stream.");
                }

                result.Add(
                    module.StreamEntry.Id,
                    CreateModuleStream(
                        project,
                        module,
                        change.Value));
            }

            return result;
        }

        public static byte[] CreateModuleStream(
            VbaProjectData project,
            VbaModule module,
            string fullCode)
        {
            if (project == null)
            {
                throw new ArgumentNullException("project");
            }
            if (module == null)
            {
                throw new ArgumentNullException("module");
            }
            if (fullCode == null)
            {
                throw new ArgumentNullException("fullCode");
            }
            if (project.Encoding == null)
            {
                throw new InvalidDataException(
                    "The VBA project encoding is missing.");
            }
            if (module.StreamData == null)
            {
                throw new InvalidDataException(
                    "The VBA module stream data is missing.");
            }
            if (module.SourceOffset > int.MaxValue ||
                module.SourceOffset >= module.StreamData.Length)
            {
                throw new InvalidDataException(
                    "MODULEOFFSET is outside the module stream: " +
                    module.Name);
            }

            byte[] sourceBytes = project.Encoding.GetBytes(fullCode);
            byte[] compressed = VbaCompression.Compress(sourceBytes);
            int prefixLength = (int)module.SourceOffset;
            int outputLength;
            try
            {
                outputLength = checked(
                    prefixLength + compressed.Length);
            }
            catch (OverflowException)
            {
                throw new InvalidDataException(
                    "The rebuilt VBA module stream is too large.");
            }

            byte[] result = new byte[outputLength];
            Buffer.BlockCopy(
                module.StreamData,
                0,
                result,
                0,
                prefixLength);
            Buffer.BlockCopy(
                compressed,
                0,
                result,
                prefixLength,
                compressed.Length);
            return result;
        }

        public static byte[] RebuildProject(
            VbaProjectData project,
            IDictionary<string, string> moduleChanges)
        {
            return RebuildProject(
                project,
                moduleChanges,
                new List<VbaModuleAddition>());
        }

        public static byte[] RebuildProject(
            VbaProjectData project,
            IDictionary<string, string> moduleChanges,
            IList<VbaModuleAddition> newModules)
        {
            if (project == null)
            {
                throw new ArgumentNullException("project");
            }
            if (moduleChanges == null)
            {
                throw new ArgumentNullException("moduleChanges");
            }
            if (newModules == null)
            {
                throw new ArgumentNullException("newModules");
            }

            Dictionary<int, byte[]> streamChanges =
                CreateStreamChanges(project, moduleChanges);
            if (newModules.Count == 0)
            {
                return Ole2Writer.Rebuild(
                    project.Ole2,
                    streamChanges);
            }
            if (project.Ole2 == null ||
                project.Encoding == null ||
                project.VbaStorage == null ||
                project.ProjectEntry == null ||
                project.ProjectWmEntry == null ||
                project.DirEntry == null)
            {
                throw new InvalidDataException(
                    "The VBA project addition streams are missing.");
            }

            HashSet<string> names = new HashSet<string>(
                StringComparer.OrdinalIgnoreCase);
            int index;
            for (index = 0; index < project.Modules.Count; index++)
            {
                names.Add(project.Modules[index].Name);
            }

            byte[] dirBytes = project.DirDecompressed;
            string projectText = project.ProjectText;
            byte[] projectWmBytes = project.ProjectWmBytes;
            List<Ole2StreamAddition> streamAdditions =
                new List<Ole2StreamAddition>();
            for (index = 0; index < newModules.Count; index++)
            {
                VbaModuleAddition addition = newModules[index];
                if (addition == null)
                {
                    throw new ArgumentException(
                        "A VBA module addition is null.",
                        "newModules");
                }
                ValidateNewModuleName(addition.Name);
                if (addition.Code == null)
                {
                    throw new ArgumentException(
                        "A VBA module addition code is null.",
                        "newModules");
                }
                if (!names.Add(addition.Name) ||
                    project.Ole2.FindChild(
                        project.VbaStorage,
                        addition.Name,
                        0) != null)
                {
                    throw new InvalidDataException(
                        "Duplicate VBA module name: " +
                        addition.Name);
                }

                streamAdditions.Add(
                    new Ole2StreamAddition(
                        project.VbaStorage.Id,
                        addition.Name,
                        CreateNewModuleStream(
                            project,
                            addition.Name,
                            addition.Code)));
                dirBytes = AddDirModule(
                    project,
                    dirBytes,
                    addition.Name,
                    project.Modules.Count + index);
                projectText = AddProjectModuleLine(
                    projectText,
                    addition.Name);
                projectWmBytes = AddProjectWmName(
                    project,
                    projectWmBytes,
                    addition.Name);
            }

            streamChanges.Add(
                project.DirEntry.Id,
                VbaCompression.Compress(dirBytes));
            streamChanges.Add(
                project.ProjectEntry.Id,
                project.Encoding.GetBytes(projectText));
            streamChanges.Add(
                project.ProjectWmEntry.Id,
                projectWmBytes);
            return Ole2Writer.Rebuild(
                project.Ole2,
                streamChanges,
                streamAdditions);
        }

        public static void ValidateNewModuleName(string name)
        {
            if (string.IsNullOrEmpty(name) ||
                name.Length > 31 ||
                !char.IsLetter(name[0]))
            {
                throw new InvalidDataException(
                    "The VBA module name is not a valid identifier.");
            }

            int index;
            for (index = 1; index < name.Length; index++)
            {
                if (!char.IsLetterOrDigit(name[index]) &&
                    name[index] != '_')
                {
                    throw new InvalidDataException(
                        "The VBA module name is not a valid identifier.");
                }
            }
        }

        public static string CreateNewModuleFullCode(
            string name,
            string code)
        {
            ValidateNewModuleName(name);
            if (code == null)
            {
                throw new ArgumentNullException("code");
            }
            return "Attribute VB_Name = \"" +
                name +
                "\"\r\n" +
                code;
        }

        public static byte[] CreateNewModuleStream(
            VbaProjectData project,
            string name,
            string code)
        {
            if (project == null)
            {
                throw new ArgumentNullException("project");
            }
            if (project.Encoding == null)
            {
                throw new InvalidDataException(
                    "The VBA project encoding is missing.");
            }

            string fullCode = CreateNewModuleFullCode(name, code);
            byte[] sourceBytes =
                project.Encoding.GetBytes(fullCode);
            return VbaCompression.Compress(sourceBytes);
        }

        private static byte[] AddDirModule(
            VbaProjectData project,
            byte[] source,
            string name,
            int expectedCount)
        {
            if (source == null ||
                project.ProjectModulesOffset < 0 ||
                project.ProjectModulesOffset + 8 > source.Length)
            {
                throw new InvalidDataException(
                    "The PROJECTMODULES record is missing.");
            }

            int countOffset =
                project.ProjectModulesOffset + 6;
            ushort count = BitConverter.ToUInt16(
                source,
                countOffset);
            if (count != expectedCount)
            {
                throw new InvalidDataException(
                    "The PROJECTMODULES count is inconsistent.");
            }
            if (count == ushort.MaxValue)
            {
                throw new InvalidDataException(
                    "The VBA project has too many modules.");
            }

            int terminatorOffset = source.Length - 6;
            if (terminatorOffset < 0 ||
                BitConverter.ToUInt16(
                    source,
                    terminatorOffset) != 0x0010)
            {
                throw new InvalidDataException(
                    "The PROJECTTERMINATOR record is missing.");
            }

            byte[] record = CreateDirModuleRecord(
                project.Encoding,
                name);
            byte[] result = new byte[
                source.Length + record.Length];
            Buffer.BlockCopy(
                source,
                0,
                result,
                0,
                terminatorOffset);
            Buffer.BlockCopy(
                record,
                0,
                result,
                terminatorOffset,
                record.Length);
            Buffer.BlockCopy(
                source,
                terminatorOffset,
                result,
                terminatorOffset + record.Length,
                6);
            WriteUInt16(
                result,
                countOffset,
                (ushort)(count + 1));
            return result;
        }

        private static byte[] CreateDirModuleRecord(
            Encoding encoding,
            string name)
        {
            byte[] ansiName = encoding.GetBytes(name);
            byte[] unicodeName = Encoding.Unicode.GetBytes(name);
            using (MemoryStream output = new MemoryStream())
            {
                WriteSizedRecord(
                    output,
                    0x0019,
                    ansiName);
                WriteSizedRecord(
                    output,
                    0x0047,
                    unicodeName);
                WriteSizedRecord(
                    output,
                    0x001A,
                    ansiName);
                WriteSizedRecord(
                    output,
                    0x0032,
                    unicodeName);
                WriteSizedRecord(
                    output,
                    0x001C,
                    new byte[0]);
                WriteSizedRecord(
                    output,
                    0x0048,
                    new byte[0]);
                WriteUInt16(output, 0x0031);
                WriteUInt32(output, 4);
                WriteUInt32(output, 0);
                WriteUInt16(output, 0x001E);
                WriteUInt32(output, 4);
                WriteUInt32(output, 0);
                WriteUInt16(output, 0x002C);
                WriteUInt32(output, 2);
                WriteUInt16(output, 0xFFFF);
                WriteUInt16(output, 0x0021);
                WriteUInt32(output, 0);
                WriteUInt16(output, 0x002B);
                WriteUInt32(output, 0);
                return output.ToArray();
            }
        }

        private static string AddProjectModuleLine(
            string source,
            string name)
        {
            string newLine = FindProjectNewLine(source);
            int position = 0;
            int lastModuleEnd = -1;
            int lastDeclarationEnd = -1;
            while (position < source.Length)
            {
                int contentEnd = position;
                while (contentEnd < source.Length &&
                    source[contentEnd] != '\r' &&
                    source[contentEnd] != '\n')
                {
                    contentEnd++;
                }

                int next = contentEnd;
                if (next < source.Length && source[next] == '\r')
                {
                    next++;
                    if (next < source.Length &&
                        source[next] == '\n')
                    {
                        next++;
                    }
                }
                else if (next < source.Length &&
                    source[next] == '\n')
                {
                    next++;
                }

                string line = source.Substring(
                    position,
                    contentEnd - position);
                if (line.StartsWith(
                    "Module=",
                    StringComparison.Ordinal))
                {
                    lastModuleEnd = next;
                }
                if (IsProjectModuleDeclaration(line))
                {
                    lastDeclarationEnd = next;
                }
                position = next;
            }

            int insertion = lastModuleEnd >= 0 ?
                lastModuleEnd :
                lastDeclarationEnd;
            if (insertion < 0)
            {
                throw new InvalidDataException(
                    "PROJECT contains no module declarations.");
            }

            string lineToAdd =
                "Module=" + name + newLine;
            if (insertion > 0 &&
                source[insertion - 1] != '\r' &&
                source[insertion - 1] != '\n')
            {
                lineToAdd = newLine + lineToAdd;
            }
            return source.Insert(insertion, lineToAdd);
        }

        private static bool IsProjectModuleDeclaration(
            string line)
        {
            return line.StartsWith(
                "Document=",
                StringComparison.Ordinal) ||
                line.StartsWith(
                    "BaseClass=",
                    StringComparison.Ordinal) ||
                line.StartsWith(
                    "Module=",
                    StringComparison.Ordinal) ||
                line.StartsWith(
                    "Class=",
                    StringComparison.Ordinal);
        }

        private static string FindProjectNewLine(string source)
        {
            int index;
            for (index = 0; index < source.Length; index++)
            {
                if (source[index] == '\r')
                {
                    return index + 1 < source.Length &&
                        source[index + 1] == '\n' ?
                        "\r\n" :
                        "\r";
                }
                if (source[index] == '\n')
                {
                    return "\n";
                }
            }
            return "\r\n";
        }

        private static byte[] AddProjectWmName(
            VbaProjectData project,
            byte[] source,
            string name)
        {
            if (source == null ||
                source.Length < 2 ||
                source[source.Length - 2] != 0 ||
                source[source.Length - 1] != 0)
            {
                throw new InvalidDataException(
                    "PROJECTwm terminator is missing.");
            }

            byte[] ansiName =
                project.Encoding.GetBytes(name);
            byte[] unicodeName =
                Encoding.Unicode.GetBytes(name);
            int mapLength = ansiName.Length +
                1 +
                unicodeName.Length +
                2;
            byte[] result = new byte[
                source.Length + mapLength];
            int insertion = source.Length - 2;
            Buffer.BlockCopy(
                source,
                0,
                result,
                0,
                insertion);
            Buffer.BlockCopy(
                ansiName,
                0,
                result,
                insertion,
                ansiName.Length);
            int position = insertion + ansiName.Length + 1;
            Buffer.BlockCopy(
                unicodeName,
                0,
                result,
                position,
                unicodeName.Length);
            Buffer.BlockCopy(
                source,
                insertion,
                result,
                insertion + mapLength,
                2);
            return result;
        }

        private static void WriteSizedRecord(
            Stream output,
            ushort id,
            byte[] data)
        {
            WriteUInt16(output, id);
            WriteUInt32(output, (uint)data.Length);
            output.Write(data, 0, data.Length);
        }

        private static void WriteUInt16(
            Stream output,
            ushort value)
        {
            output.WriteByte((byte)(value & 0xFF));
            output.WriteByte((byte)((value >> 8) & 0xFF));
        }

        private static void WriteUInt32(
            Stream output,
            uint value)
        {
            output.WriteByte((byte)(value & 0xFF));
            output.WriteByte((byte)((value >> 8) & 0xFF));
            output.WriteByte((byte)((value >> 16) & 0xFF));
            output.WriteByte((byte)((value >> 24) & 0xFF));
        }

        private static void WriteUInt16(
            byte[] output,
            int offset,
            ushort value)
        {
            output[offset] = (byte)(value & 0xFF);
            output[offset + 1] =
                (byte)((value >> 8) & 0xFF);
        }
    }
}
