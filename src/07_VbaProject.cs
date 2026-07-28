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
        public string ProjectText;
        public byte[] DirCompressed;
        public byte[] DirDecompressed;
        public Ole2DirectoryEntry VbaStorage;
        public List<VbaModule> Modules;
        public string FilePath;
        public bool IsZip;

        public VbaProjectData()
        {
            Ole2Bytes = new byte[0];
            ProjectText = string.Empty;
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
            List<VbaDirModule> dirModules = ReadDirModules(
                dirDecompressed,
                out codePage);
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

            VbaProjectData project = new VbaProjectData();
            project.Ole2Bytes = ole2Bytes;
            project.Ole2 = ole2;
            project.CodePage = codePage;
            project.Encoding = encoding;
            project.ProjectText = projectText;
            project.DirCompressed = dirCompressed;
            project.DirDecompressed = dirDecompressed;
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
            Dictionary<int, byte[]> streamChanges =
                CreateStreamChanges(project, moduleChanges);
            return Ole2Writer.Rebuild(project.Ole2, streamChanges);
        }
    }
}
