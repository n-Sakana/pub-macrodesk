Option Explicit

'============================================================
' 月次売上集計マクロ  業務規則
'
' 返品の扱い、大口の判定、達成率の判定をまとめた…はずのモジュール。
' 実際には集計側にも同じ判定が書いてあります。
'============================================================

' 分類の並び。集計表の列順です。
' ※ BranchReport 側にも同じ並びが書いてあります。直すときは両方。
Public Function CategoryList() As Variant
    CategoryList = Array("文具", "事務機器", "消耗品", "家具", "未分類")
End Function

Public Function CategoryCount() As Long
    CategoryCount = 5
End Function

' 区分の表記ゆれを吸収します。
Public Function IsHenpin(ByVal kubun As String) As Boolean
    Dim s As String

    s = Trim(kubun)
    If s = "返品" Then
        IsHenpin = True
    ElseIf s = "返 品" Then
        IsHenpin = True
    ElseIf s = "RETURN" Then
        IsHenpin = True
    Else
        IsHenpin = False
    End If
End Function

' 大口かどうか。設定シートの金額を見ます。
Public Function IsOoguchi(ByVal kingaku As Double) As Boolean
    If g_LargeAmount > 0 Then
        If kingaku >= g_LargeAmount Then
            IsOoguchi = True
        Else
            IsOoguchi = False
        End If
    Else
        If kingaku >= 300000 Then
            IsOoguchi = True
        Else
            IsOoguchi = False
        End If
    End If
End Function

' 支店別レポート側から呼ばれている大口判定。上とほぼ同じですが
' 設定シートを見ずに 300000 を直書きしています。
Public Function IsBigAmount(ByVal kingaku As Double) As Boolean
    If kingaku >= 300000 Then
        IsBigAmount = True
    Else
        IsBigAmount = False
    End If
End Function

' 明細 1 行の判定文字列。売上明細の I 列に書きます。
Public Function JudgeMeisai(ByVal kubun As String, ByVal kingaku As Double) As String
    Dim s As String

    s = ""
    If IsHenpin(kubun) = True Then
        s = "返品"
    Else
        If IsOoguchi(kingaku) = True Then
            s = "大口"
        Else
            If kingaku >= 100000 Then
                s = "通常"
            Else
                If kingaku > 0 Then
                    s = "通常"
                Else
                    s = "要確認"
                End If
            End If
        End If
    End If
    JudgeMeisai = s
End Function

' 達成率。目標が 0 のときは 0 を返します。
Public Function Tasseiritsu(ByVal jun As Double, ByVal mokuhyo As Double) As Double
    If mokuhyo = 0 Then
        Tasseiritsu = 0
    Else
        Tasseiritsu = jun / mokuhyo
    End If
End Function

' 達成率の判定。閾値は設定シートにもありますが、ここは直書きのままです。
Public Function TasseiHantei(ByVal ritsu As Double) As String
    Dim s As String

    If ritsu >= 1 Then
        s = "達成"
    Else
        If ritsu >= 0.9 Then
            s = "あと少し"
        Else
            If ritsu >= 0.7 Then
                s = "未達"
            Else
                s = "要対策"
            End If
        End If
    End If
    TasseiHantei = s
End Function

' 分類名を集計表の列番号へ。1 始まりです。
Public Function CategoryIndex(ByVal bunrui As String) As Long
    Dim cats As Variant
    Dim i As Long
    Dim s As String

    cats = CategoryList()
    s = Trim(bunrui)
    CategoryIndex = 5
    For i = 0 To UBound(cats)
        If cats(i) = s Then
            CategoryIndex = i + 1
            Exit For
        End If
    Next i
End Function

' 明細行が対象年月かどうか。
Public Function IsTargetMonth(ByVal keijobi As Variant) As Boolean
    Dim ym As String

    ym = ToYm(keijobi)
    If ym = "" Then
        IsTargetMonth = False
    ElseIf ym = g_TargetYm Then
        IsTargetMonth = True
    Else
        IsTargetMonth = False
    End If
End Function
