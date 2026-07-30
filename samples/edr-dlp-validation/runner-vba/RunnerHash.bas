Attribute VB_Name = "RunnerHash"
Option Explicit
Option Private Module

Private Const TWO_TO_32 As Double = 4294967296#

Public Function Sha256HexBytes( _
    ByRef bytes() As Byte, _
    ByVal byteCount As Long) As String

    Dim a As Long
    Dim b As Long
    Dim blockOffset As Long
    Dim c As Long
    Dim d As Long
    Dim e As Long
    Dim f As Long
    Dim g As Long
    Dim h As Long
    Dim hash0 As Long
    Dim hash1 As Long
    Dim hash2 As Long
    Dim hash3 As Long
    Dim hash4 As Long
    Dim hash5 As Long
    Dim hash6 As Long
    Dim hash7 As Long
    Dim index As Long
    Dim constants(0 To 63) As Long
    Dim padded() As Byte
    Dim paddedLength As Long
    Dim remainingBits As Double
    Dim temp1 As Long
    Dim temp2 As Long
    Dim work(0 To 63) As Long

    If byteCount < 0 Then
        Err.Raise vbObjectError + 2660, _
            "MacroStudioValidation", _
            "A negative byte count cannot be hashed."
    End If

    paddedLength = ((byteCount + 9 + 63) \ 64) * 64
    ReDim padded(0 To paddedLength - 1)
    For index = 0 To byteCount - 1
        padded(index) = bytes(index)
    Next index
    padded(byteCount) = &H80

    remainingBits = CDbl(byteCount) * 8#
    For index = 0 To 7
        padded(paddedLength - 1 - index) = _
            CByte(remainingBits - Fix(remainingBits / 256#) * 256#)
        remainingBits = Fix(remainingBits / 256#)
    Next index

    InitializeConstants constants
    hash0 = &H6A09E667
    hash1 = &HBB67AE85
    hash2 = &H3C6EF372
    hash3 = &HA54FF53A
    hash4 = &H510E527F
    hash5 = &H9B05688C
    hash6 = &H1F83D9AB
    hash7 = &H5BE0CD19

    For blockOffset = 0 To paddedLength - 1 Step 64
        For index = 0 To 15
            work(index) = SignedLong( _
                CDbl(padded(blockOffset + index * 4)) * 16777216# + _
                CDbl(padded(blockOffset + index * 4 + 1)) * 65536# + _
                CDbl(padded(blockOffset + index * 4 + 2)) * 256# + _
                CDbl(padded(blockOffset + index * 4 + 3)))
        Next index

        For index = 16 To 63
            work(index) = Add32Four( _
                SmallSigma1(work(index - 2)), _
                work(index - 7), _
                SmallSigma0(work(index - 15)), _
                work(index - 16))
        Next index

        a = hash0
        b = hash1
        c = hash2
        d = hash3
        e = hash4
        f = hash5
        g = hash6
        h = hash7

        For index = 0 To 63
            temp1 = Add32Five( _
                h, BigSigma1(e), ChooseBits(e, f, g), _
                constants(index), work(index))
            temp2 = Add32(BigSigma0(a), MajorityBits(a, b, c))
            h = g
            g = f
            f = e
            e = Add32(d, temp1)
            d = c
            c = b
            b = a
            a = Add32(temp1, temp2)
        Next index

        hash0 = Add32(hash0, a)
        hash1 = Add32(hash1, b)
        hash2 = Add32(hash2, c)
        hash3 = Add32(hash3, d)
        hash4 = Add32(hash4, e)
        hash5 = Add32(hash5, f)
        hash6 = Add32(hash6, g)
        hash7 = Add32(hash7, h)
    Next blockOffset

    Sha256HexBytes = _
        WordHex(hash0) & WordHex(hash1) & _
        WordHex(hash2) & WordHex(hash3) & _
        WordHex(hash4) & WordHex(hash5) & _
        WordHex(hash6) & WordHex(hash7)
End Function

Public Function Sha256SelfTest() As Boolean
    Dim emptyBytes(0 To 0) As Byte
    Dim sampleBytes(0 To 2) As Byte

    sampleBytes(0) = 97
    sampleBytes(1) = 98
    sampleBytes(2) = 99

    Sha256SelfTest = _
        (Sha256HexBytes(emptyBytes, 0) = _
            "E3B0C44298FC1C149AFBF4C8996FB924" & _
            "27AE41E4649B934CA495991B7852B855") And _
        (Sha256HexBytes(sampleBytes, 3) = _
            "BA7816BF8F01CFEA414140DE5DAE2223" & _
            "B00361A396177A9CB410FF61F20015AD")
End Function

Private Function Add32( _
    ByVal leftValue As Long, _
    ByVal rightValue As Long) As Long

    Add32 = SignedLong( _
        UnsignedDouble(leftValue) + UnsignedDouble(rightValue))
End Function

Private Function Add32Four( _
    ByVal value1 As Long, _
    ByVal value2 As Long, _
    ByVal value3 As Long, _
    ByVal value4 As Long) As Long

    Add32Four = Add32( _
        Add32(value1, value2), _
        Add32(value3, value4))
End Function

Private Function Add32Five( _
    ByVal value1 As Long, _
    ByVal value2 As Long, _
    ByVal value3 As Long, _
    ByVal value4 As Long, _
    ByVal value5 As Long) As Long

    Add32Five = Add32( _
        Add32Four(value1, value2, value3, value4), _
        value5)
End Function

Private Function BigSigma0(ByVal value As Long) As Long
    BigSigma0 = _
        RotateRight(value, 2) Xor _
        RotateRight(value, 13) Xor _
        RotateRight(value, 22)
End Function

Private Function BigSigma1(ByVal value As Long) As Long
    BigSigma1 = _
        RotateRight(value, 6) Xor _
        RotateRight(value, 11) Xor _
        RotateRight(value, 25)
End Function

Private Function ChooseBits( _
    ByVal value1 As Long, _
    ByVal value2 As Long, _
    ByVal value3 As Long) As Long

    ChooseBits = _
        (value1 And value2) Xor _
        ((Not value1) And value3)
End Function

Private Sub InitializeConstants(ByRef constants() As Long)
    constants(0) = &H428A2F98
    constants(1) = &H71374491
    constants(2) = &HB5C0FBCF
    constants(3) = &HE9B5DBA5
    constants(4) = &H3956C25B
    constants(5) = &H59F111F1
    constants(6) = &H923F82A4
    constants(7) = &HAB1C5ED5
    constants(8) = &HD807AA98
    constants(9) = &H12835B01
    constants(10) = &H243185BE
    constants(11) = &H550C7DC3
    constants(12) = &H72BE5D74
    constants(13) = &H80DEB1FE
    constants(14) = &H9BDC06A7
    constants(15) = &HC19BF174
    constants(16) = &HE49B69C1
    constants(17) = &HEFBE4786
    constants(18) = &HFC19DC6
    constants(19) = &H240CA1CC
    constants(20) = &H2DE92C6F
    constants(21) = &H4A7484AA
    constants(22) = &H5CB0A9DC
    constants(23) = &H76F988DA
    constants(24) = &H983E5152
    constants(25) = &HA831C66D
    constants(26) = &HB00327C8
    constants(27) = &HBF597FC7
    constants(28) = &HC6E00BF3
    constants(29) = &HD5A79147
    constants(30) = &H6CA6351
    constants(31) = &H14292967
    constants(32) = &H27B70A85
    constants(33) = &H2E1B2138
    constants(34) = &H4D2C6DFC
    constants(35) = &H53380D13
    constants(36) = &H650A7354
    constants(37) = &H766A0ABB
    constants(38) = &H81C2C92E
    constants(39) = &H92722C85
    constants(40) = &HA2BFE8A1
    constants(41) = &HA81A664B
    constants(42) = &HC24B8B70
    constants(43) = &HC76C51A3
    constants(44) = &HD192E819
    constants(45) = &HD6990624
    constants(46) = &HF40E3585
    constants(47) = &H106AA070
    constants(48) = &H19A4C116
    constants(49) = &H1E376C08
    constants(50) = &H2748774C
    constants(51) = &H34B0BCB5
    constants(52) = &H391C0CB3
    constants(53) = &H4ED8AA4A
    constants(54) = &H5B9CCA4F
    constants(55) = &H682E6FF3
    constants(56) = &H748F82EE
    constants(57) = &H78A5636F
    constants(58) = &H84C87814
    constants(59) = &H8CC70208
    constants(60) = &H90BEFFFA
    constants(61) = &HA4506CEB
    constants(62) = &HBEF9A3F7
    constants(63) = &HC67178F2
End Sub

Private Function MajorityBits( _
    ByVal value1 As Long, _
    ByVal value2 As Long, _
    ByVal value3 As Long) As Long

    MajorityBits = _
        (value1 And value2) Xor _
        (value1 And value3) Xor _
        (value2 And value3)
End Function

Private Function RotateRight( _
    ByVal value As Long, _
    ByVal bitCount As Long) As Long

    RotateRight = _
        UnsignedRightShift(value, bitCount) Or _
        ShiftLeft32(value, 32 - bitCount)
End Function

Private Function ShiftLeft32( _
    ByVal value As Long, _
    ByVal bitCount As Long) As Long

    Dim index As Long
    Dim result As Long

    result = value
    For index = 1 To bitCount
        result = Add32(result, result)
    Next index
    ShiftLeft32 = result
End Function

Private Function SignedLong(ByVal value As Double) As Long
    value = value - Fix(value / TWO_TO_32) * TWO_TO_32
    If value < 0 Then
        value = value + TWO_TO_32
    End If

    If value >= 2147483648# Then
        SignedLong = CLng(value - TWO_TO_32)
    Else
        SignedLong = CLng(value)
    End If
End Function

Private Function SmallSigma0(ByVal value As Long) As Long
    SmallSigma0 = _
        RotateRight(value, 7) Xor _
        RotateRight(value, 18) Xor _
        UnsignedRightShift(value, 3)
End Function

Private Function SmallSigma1(ByVal value As Long) As Long
    SmallSigma1 = _
        RotateRight(value, 17) Xor _
        RotateRight(value, 19) Xor _
        UnsignedRightShift(value, 10)
End Function

Private Function UnsignedDouble(ByVal value As Long) As Double
    If value < 0 Then
        UnsignedDouble = CDbl(value) + TWO_TO_32
    Else
        UnsignedDouble = CDbl(value)
    End If
End Function

Private Function UnsignedRightShift( _
    ByVal value As Long, _
    ByVal bitCount As Long) As Long

    Dim result As Long

    If bitCount = 0 Then
        UnsignedRightShift = value
        Exit Function
    End If

    result = _
        (value And &H7FFFFFFF) \ CLng(2# ^ bitCount)
    If value < 0 Then
        result = result Or CLng(2# ^ (31 - bitCount))
    End If
    UnsignedRightShift = result
End Function

Private Function WordHex(ByVal value As Long) As String
    WordHex = Right$("00000000" & Hex$(value), 8)
End Function
