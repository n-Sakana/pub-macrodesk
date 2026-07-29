param(
    [string]$BookPath
)

$ErrorActionPreference = 'Stop'

if ([string]::IsNullOrEmpty($BookPath)) {
    $BookPath = Join-Path $PSScriptRoot '..\testdata\test_large.xlsm'
}

function Assert-True {
    param(
        [bool]$Condition,
        [string]$Message
    )

    if (-not $Condition) {
        throw $Message
    }
}

function Get-EngineSource {
    $names = @(
        '05_Ole2.cs',
        '06_VbaCompression.cs',
        '07_VbaProject.cs'
    )
    $combined = ($names | ForEach-Object {
        $path = Join-Path (Join-Path $PSScriptRoot '..\src') $_
        [IO.File]::ReadAllText(
            (Resolve-Path -LiteralPath $path),
            [Text.Encoding]::UTF8)
    }) -join "`n"

    $usingPattern = '(?m)^\s*using\s+[\w][\w.]*\s*;'
    $usings = [regex]::Matches($combined, $usingPattern) |
        ForEach-Object { $_.Value.Trim() } |
        Sort-Object -Unique
    $body = $combined -replace $usingPattern, ''
    return ($usings -join "`n") + "`n`n" + $body
}

function Assert-Bytes {
    param(
        [byte[]]$Actual,
        [byte[]]$Expected,
        [string]$Message
    )

    Assert-True ($Actual.Length -eq $Expected.Length) `
        ($Message + ' Length mismatch.')
    for ($index = 0; $index -lt $Expected.Length; $index++) {
        Assert-True ($Actual[$index] -eq $Expected[$index]) `
            ($Message + " Byte mismatch at $index.")
    }
}

function Assert-RoundTrip {
    param(
        [byte[]]$Data,
        [string]$Message
    )

    $compressed = [MacroStudio.VbaCompression]::Compress($Data)
    $actual = [MacroStudio.VbaCompression]::Decompress($compressed)
    Assert-Bytes $actual $Data ($Message + ' roundtrip')
    return $compressed.Length
}

function Assert-InvalidData {
    param(
        [ScriptBlock]$Action,
        [string]$Message
    )

    $threw = $false
    try {
        & $Action
    } catch [IO.InvalidDataException] {
        $threw = $true
    }
    Assert-True $threw $Message
}

function Read-VbaProjectBytes {
    param([string]$Path)

    Add-Type -AssemblyName System.IO.Compression
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $archive = [IO.Compression.ZipFile]::OpenRead($Path)
    try {
        $entry = $archive.Entries |
            Where-Object { $_.Name -eq 'vbaProject.bin' } |
            Select-Object -First 1
        if (-not $entry) {
            throw 'vbaProject.bin was not found.'
        }

        $input = $entry.Open()
        try {
            $memory = New-Object IO.MemoryStream
            try {
                $input.CopyTo($memory)
                return ,$memory.ToArray()
            } finally {
                $memory.Dispose()
            }
        } finally {
            $input.Dispose()
        }
    } finally {
        $archive.Dispose()
    }
}

Add-Type -TypeDefinition (Get-EngineSource) -Language CSharp

[byte[]]$literalContainer = 0x01, 0x03, 0xB0, 0x00, 0x41, 0x42, 0x43
[byte[]]$literalExpected = 0x41, 0x42, 0x43
$literalActual = [MacroStudio.VbaCompression]::Decompress($literalContainer)
Assert-Bytes $literalActual $literalExpected 'Literal chunk'

[byte[]]$copyContainer = `
    0x01, 0x05, 0xB0, 0x08, 0x41, 0x42, 0x43, 0x00, 0x20
[byte[]]$copyExpected = 0x41, 0x42, 0x43, 0x41, 0x42, 0x43
$copyActual = [MacroStudio.VbaCompression]::Decompress($copyContainer)
Assert-Bytes $copyActual $copyExpected 'Copy token'

[byte[]]$rawContainer = New-Object byte[] (1 + 2 + 4096)
$rawContainer[0] = 0x01
$rawContainer[1] = 0xFF
$rawContainer[2] = 0x3F
for ($index = 0; $index -lt 4096; $index++) {
    $rawContainer[3 + $index] = [byte]($index % 251)
}
$rawActual = [MacroStudio.VbaCompression]::Decompress($rawContainer)
Assert-True ($rawActual.Length -eq 4096) 'Raw chunk length mismatch.'
Assert-True ($rawActual[0] -eq 0) 'Raw chunk first byte mismatch.'
Assert-True ($rawActual[4095] -eq [byte](4095 % 251)) `
    'Raw chunk last byte mismatch.'

[byte[]]$badSignature = 0x00, 0x03, 0xB0, 0x00, 0x41, 0x42, 0x43
Assert-InvalidData {
    [MacroStudio.VbaCompression]::Decompress($badSignature)
} 'Invalid container signature was accepted.'

[byte[]]$badCopy = 0x01, 0x02, 0xB0, 0x01, 0x00, 0x00
Assert-InvalidData {
    [MacroStudio.VbaCompression]::Decompress($badCopy)
} 'Copy token without preceding data was accepted.'

[byte[]]$emptyBytes = @()
$emptyLength = Assert-RoundTrip $emptyBytes 'Empty input'
Assert-True ($emptyLength -eq 1) 'Empty container length mismatch.'

[byte[]]$shortBytes = [Text.Encoding]::ASCII.GetBytes('ABCABCABCABC')
$shortLength = Assert-RoundTrip $shortBytes 'Short repeated input'
Assert-True ($shortLength -lt ($shortBytes.Length + 3)) `
    'Short repeated input was not compressed.'

[byte[]]$randomBytes = New-Object byte[] 4096
$random = New-Object Random 123456
$random.NextBytes($randomBytes)
$randomLength = Assert-RoundTrip $randomBytes 'Raw chunk input'
Assert-True ($randomLength -eq 4099) 'Raw chunk container length mismatch.'
$randomCompressed = [MacroStudio.VbaCompression]::Compress($randomBytes)
Assert-True (
    $randomCompressed[1] -eq 0xFF -and
    $randomCompressed[2] -eq 0x3F) `
    'Raw chunk header mismatch.'

[byte[]]$partialRandomBytes = New-Object byte[] 3000
$random.NextBytes($partialRandomBytes)
$partialLength = Assert-RoundTrip $partialRandomBytes `
    'Partial random chunk input'
Assert-True ($partialLength -gt 1) `
    'Partial random container was empty.'

[byte[]]$largePartialRandomBytes = New-Object byte[] 3800
$largePartialRandom = New-Object Random 789012
$largePartialRandom.NextBytes($largePartialRandomBytes)
$largePartialLength = Assert-RoundTrip $largePartialRandomBytes `
    'Large incompressible partial chunk input'
Assert-True ($largePartialLength -gt 1) `
    'Large partial random container was empty.'

[byte[]]$multipleChunkBytes = New-Object byte[] 10000
for ($index = 0; $index -lt $multipleChunkBytes.Length; $index++) {
    $multipleChunkBytes[$index] = [byte](
        ([int][Math]::Floor($index / 37) + $index) % 251)
}
$multipleLength = Assert-RoundTrip $multipleChunkBytes `
    'Multiple chunk input'
Assert-True ($multipleLength -gt 1) `
    'Multiple chunk container was empty.'

if (-not (Test-Path -LiteralPath $BookPath -PathType Leaf)) {
    throw "Workbook fixture was not found: $BookPath"
}

$vbaBytes = Read-VbaProjectBytes (Resolve-Path -LiteralPath $BookPath)
$ole2 = [MacroStudio.Ole2File]::Parse($vbaBytes)
$vbaStorage = $ole2.FindChild($ole2.RootEntry, 'VBA', 1)
$dirEntry = $ole2.FindChild($vbaStorage, 'dir', 2)
$dirCompressed = $ole2.ReadStream($dirEntry)
$dirDecompressed = [MacroStudio.VbaCompression]::Decompress($dirCompressed)
Assert-True ($dirDecompressed.Length -gt 0) 'Decompressed dir was empty.'
Assert-True ([BitConverter]::ToUInt16($dirDecompressed, 0) -eq 0x0001) `
    'Decompressed dir does not start with PROJECTSYSKIND.'
$dirRoundTripLength = Assert-RoundTrip $dirDecompressed `
    'Real dir stream'

$project = [MacroStudio.VbaProjectReader]::Read($vbaBytes)
foreach ($module in $project.Modules) {
    [void](Assert-RoundTrip $module.FullSourceBytes `
        ('Real module ' + $module.Name))
}

Write-Output 'test-compression: PASS'
Write-Output (
    'dir: original={0}, rebuilt={1}, decompressed={2}' -f `
    $dirCompressed.Length,
    $dirRoundTripLength,
    $dirDecompressed.Length)
Write-Output (
    'synthetic: raw={0}, partial={1}, large-partial={2}, multiple={3}' -f `
    $randomLength,
    $partialLength,
    $largePartialLength,
    $multipleLength)
