Option Explicit

'============================================================
' 支店別レポートの 1 行分
'
' 2022/03  支店ごとに配列を 4 本も持つのがつらくなったので、
'          この 1 行だけクラスにしました。商品側は配列のままです。
'
' 合計や達成率の計算は、書き出しのときに毎回ここへ聞きます。
'============================================================

Private mCode As String
Private mBranchName As String
Private mArea As String
Private mSale As Double
Private mReturn As Double
Private mTarget As Double

Public Property Get Code() As String
    Code = mCode
End Property

Public Property Let Code(ByVal v As String)
    mCode = v
End Property

Public Property Get BranchName() As String
    BranchName = mBranchName
End Property

Public Property Let BranchName(ByVal v As String)
    mBranchName = v
End Property

Public Property Get Area() As String
    Area = mArea
End Property

Public Property Let Area(ByVal v As String)
    mArea = v
End Property

Public Property Get Target() As Double
    Target = mTarget
End Property

Public Property Let Target(ByVal v As Double)
    mTarget = v
End Property

' 売上・返品は足し込みだけです。Let は付けていません。
Public Property Get Sale() As Double
    Sale = mSale
End Property

Public Property Get ReturnAmount() As Double
    ReturnAmount = mReturn
End Property

Public Sub AddSale(ByVal amount As Double)
    mSale = mSale + amount
End Sub

Public Sub AddReturn(ByVal amount As Double)
    mReturn = mReturn + amount
End Sub

Public Property Get NetAmount() As Double
    NetAmount = mSale - mReturn
End Property

' 達成率と判定は業務規則側の関数に投げています。
Public Property Get Rate() As Double
    Rate = Tasseiritsu(NetAmount, mTarget)
End Property

Public Property Get Judgement() As String
    Judgement = TasseiHantei(Rate)
End Property

' 進捗表示に使っている整形用。
Public Function Describe() As String
    Describe = mBranchName & "(" & mArea & ")"
End Function
