/*
Lanczos approximation to the incomplete-beta function
dbo.IncBeta(@Var_X, @Var_A, @Var_B)

Where @Var_X = Damage Ratio (between 0% and 100%)
      @Var_A = Alpha Parameter
      @Var_B = Beta Parameter)

The function returns a conditional-severity percentile
(probability of non-exceedance, given an occurrence)
*/

Drop Function LnGamma
Drop Function Gamma
Drop Function Beta
Drop Function FractionSumTerm
Drop Function FractionSum
Drop Function IncBeta
Go

Create Function LnGamma(@Var_Z Float)
Returns float
As
Begin
    Declare @Coeff0 Float
    Declare @Coeff1 Float
    Declare @Coeff2 Float
    Declare @Coeff3 Float
    Declare @Coeff4 Float
    Declare @Coeff5 Float
    Declare @Coeff6 Float
    Declare @Ser Float
    Declare @Var_X Float
    Declare @Var_Y Float
    Declare @Tmp Float
    Declare @II Integer
    
    Set @Coeff0 = 2.506628274631
    Set @Coeff1 = 76.1800917294715
    Set @Coeff2 = -86.5053203294168
    Set @Coeff3 = 24.0140982408309
    Set @Coeff4 = -1.23173957245015
    Set @Coeff5 = 1.20865097386618 * power(0.1, 3)
    Set @Coeff6 = -5.395239384953 * power(0.1, 6)
    
    Set @Ser = 1 + 1.90015 * power(0.1, 10)
    
    Set @Var_X = @Var_Z
    Set @Var_Y = @Var_X
    Set @Tmp = @Var_X + 5.5
    Set @Tmp = (@Var_X + 0.5) * Log(@Tmp) - @Tmp

	Set @II = 0

	While @II < 6
		Begin
			Set @II = @II+1
				Set @Var_Y = @Var_Y + 1
				Set @Ser = @Ser
					+ case @II
						  when 1 then @Coeff1
						  when 2 then @Coeff2
						  when 3 then @Coeff3
						  when 4 then @Coeff4
						  when 5 then @Coeff5
						  when 6 then @Coeff6
					  end
					/ @Var_Y
		End

Return @Tmp + Log(@Coeff0) + Log(@Ser) - Log(@Var_X)
End
Go



Create Function Gamma(@Var_Z Float)
Returns Float
As
Begin
Return Exp(dbo.LnGamma(@Var_Z))
End
Go



Create Function Beta(@Var_A Float, @Var_B Float)
Returns Float
As
Begin
Return Exp(dbo.LnGamma(@Var_A) + dbo.LnGamma(@Var_B) - dbo.LnGamma(@Var_A + @Var_B))
End
Go



Create Function FractionSumTerm
  (@Var_X Float, @Var_A Float, @Var_B Float, @Lvl Integer)
Returns Float
As
Begin
    Declare @Mod_M Integer
    Declare @Mult_M Integer
    Declare @Var_D Float
    
    Set @Mod_M = @Lvl % 2
    Set @Mult_M = floor(@Lvl / 2)

    Set @Var_D = 
        Case Abs(Sign(@Mod_M - 1))
            When 0 Then -@Var_X * (@Var_A + @Mult_M) * (@Var_A + @Var_B + @Mult_M) / ((@Var_A + @Lvl - 1) * (@Var_A + @Lvl))
            Else @Var_X * @Mult_M * (@Var_B - @Mult_M) / ((@Var_A + @Lvl - 1) * (@Var_A + @Lvl))
        End
Return
    Case Sign(28-@Lvl)
        When 1 Then @Var_D / (1 + dbo.FractionSumTerm(@Var_X, @Var_A, @Var_B, 1 + @Lvl))
        Else @Var_D
    End
End
Go



Create Function FractionSum (@Var_X Float, @Var_A Float, @Var_B Float)
Returns Float
As
Begin
Return 1 / (1 + dbo.FractionSumTerm(@Var_X, @Var_A, @Var_B, 1))
End
Go



Create Function IncBeta(@Var_X Float, @Var_A Float, @Var_B Float)
Returns Float
As
Begin
	Declare @IB float
	Set @IB =
		Case Sign(@Var_X * (@Var_A + @Var_B + 2) - (@Var_A + 1))
			When -1 Then dbo.FractionSum(@Var_X, @Var_A, @Var_B) * (power(@Var_X, @Var_A) * power(1 - @Var_X, @Var_B)) / (@Var_A * dbo.Beta(@Var_A, @Var_B))
			Else 1 - (dbo.FractionSum(1 - @Var_X, @Var_B, @Var_A) * (power(1 - @Var_X, @Var_B) * power(@Var_X, @Var_A)) / (@Var_B * dbo.Beta(@Var_B, @Var_A)))
		End
Return
	Case @@error
		When 0 Then @IB
		Else (Sign(@Var_X * (@Var_B + @Var_A) - @Var_A) + 1) * Sign(@Var_X * (@Var_B + @Var_A) - @Var_A) / 2
	End
End
Go



/* LEV Functions */

Create Function IncBetaLEV(@Z Float, @A Float, @B Float)
Returns Float
As
Begin
Return dbo.IncBeta(@Z, @A + 1, @B) / (1 + @B / @A)
    + (1 - dbo.IncBeta(@Z, @A, @B)) * @Z
End
Go



Create Function IncBetaLM2(@Z Float, @A Float, @B Float)
Returns Float
As
Begin
Return dbo.IncBeta(@Z, @A + 2, @B) * (@A * (@A + 1) / ((@A + @B) * (@A + @B + 1)))
    + (1 - dbo.IncBeta(@Z, @A, @B)) * power(@Z, 2)
End
Go



Create Function IncBetaLEV_InLayer
  (@A Float, @B Float, @Att Float, @Exh Float, @Exp Float)
Returns Float
As
Begin
    Declare @DR_Att Float
    Declare @DR_Exh Float
    
    Set @DR_Att =
		Case Sign(@Att)
			When -1 Then 0
		Else
			Case Sign(@Att-@Exp)
				When 1 Then 1
			Else @Att / @Exp
			End
		End
    
    Set @DR_Exh =
		Case Sign(@Exh-@Att)
			When -1 Then 0
		Else
			Case Sign(@Exh-@Exp)
				When 1 Then 1
			Else @Exh / @Exp
			End
		End
    
Return @Exp * (dbo.IncBetaLEV(@DR_Exh, @A, @B) - dbo.IncBetaLEV(@DR_Att, @A, @B))
End
Go



Create Function IncBetaLSD_InLayer
  (@A Float, @B Float, @Att Float, @Exh Float, @Exp Float)
Returns Float
As
Begin
    Declare @DR_Att Float
    Declare @DR_Exh Float
    Declare @IBE Float
    Declare @IBA Float
    
    Set @DR_Att =
		Case Sign(@Att)
			When -1 Then 0
		Else
			Case Sign(@Att-@Exp)
				When 1 Then 1
			Else @Att / @Exp
			End
		End
    
    Set @DR_Exh =
		Case Sign(@Exh-@Att)
			When -1 Then 0
		Else
			Case Sign(@Exh-@Exp)
				When 1 Then 1
			Else @Exh / @Exp
			End
		End
    
    Set @IBE = dbo.IncBeta(@DR_Exh, @A, @B)
    Set @IBA = dbo.IncBeta(@DR_Att, @A, @B)
    
Return
	@Exp * power(
		(dbo.IncBetaLM2(@DR_Exh, @A, @B) - power(@DR_Exh, 2) * (1 - @IBE)
            - 2 * @DR_Att * (dbo.IncBetaLEV(@DR_Exh, @A, @B) - @DR_Exh * (1 - @IBE))
            + power(@DR_Att, 2) * @IBE
        - (dbo.IncBetaLM2(@DR_Att, @A, @B) - power(@DR_Att, 2) * (1 - @IBA)
            - 2 * @DR_Att * (dbo.IncBetaLEV(@DR_Att, @A, @B) - @DR_Att * (1 - @IBA))
            + power(@DR_Att, 2) * @IBA)
        + power(@DR_Exh - @DR_Att, 2) * (1 - @IBE)
        - power(dbo.IncBetaLEV_InLayer(@A, @B, @Att / @Exp, @Exh / @Exp, 1), 2)), 0.5)
End
Go



Create Function IB_Alpha(@Mean Float, @StdI Float, @StdC Float, @Max Float)
Returns Float
As
Begin
Return (1 - @Mean / @Max) / power((@StdI + @StdC) / @Mean, 2) - @Mean / @Max
End
Go



Create Function IB_Beta(@Mean Float, @StdI Float, @StdC Float, @Max Float)
Returns Float
As
Begin
Return dbo.IB_Alpha(@Mean, @StdI, @StdC, @Max) * (@Max / @Mean - 1)
End
Go






/*
Event table setup, with calculation of incomplete-beta parameters
*/

use Test_RDM

drop table IncBetaTest_DistPars
select p.EVENTID, e.RATE, p.PERSPVALUE, p.STDDEVI, p.STDDEVC, p.EXPVALUE,
  (1-p.PERSPVALUE/p.EXPVALUE) / power((p.STDDEVI+p.STDDEVC)/p.PERSPVALUE, 2) - p.PERSPVALUE/p.EXPVALUE as Alpha,
  convert(float, 0) as Beta
into IncBetaTest_DistPars
from rdm_anlsevent e, rdm_port p
where e.ANLSID=p.ANLSID and e.EVENTID=p.EVENTID
  and p.ANLSID=23 and p.PERSPCODE='GR'           -- change to the analyses and loss perspectives of your choice
  and p.PERSPVALUE>0 and p.EXPVALUE>0
order by p.EVENTID;

update IncBetaTest_DistPars
set Beta = Alpha * (EXPVALUE/PERSPVALUE - 1);



drop table IncBetaTest_MaxExp select max(EXPVALUE) as MaxExp into IncBetaTest_MaxExp from IncBetaTest_DistPars;


drop table IncBetaTest_EPLosses
create table IncBetaTest_EPLosses (
  ID int identity(1,1) primary key,
  Loss float
)

insert into IncBetaTest_EPLosses (Loss) select 0;
insert into IncBetaTest_EPLosses (Loss) select 0;
insert into IncBetaTest_EPLosses (Loss) select 0;
insert into IncBetaTest_EPLosses (Loss) select Loss from IncBetaTest_EPLosses;
insert into IncBetaTest_EPLosses (Loss) select Loss from IncBetaTest_EPLosses;
insert into IncBetaTest_EPLosses (Loss) select Loss from IncBetaTest_EPLosses;
insert into IncBetaTest_EPLosses (Loss) select Loss from IncBetaTest_EPLosses;
insert into IncBetaTest_EPLosses (Loss) select Loss from IncBetaTest_EPLosses;
insert into IncBetaTest_EPLosses (Loss) select Loss from IncBetaTest_EPLosses;
insert into IncBetaTest_EPLosses (Loss) select Loss from IncBetaTest_EPLosses;

update c set c.Loss = 0.5 * e.MaxExp * (c.ID - 1) / 383 from IncBetaTest_EPLosses c, IncBetaTest_MaxExp e;



/*
EP calculation (takes 6 minutes on a 2,700-event set)
*/
drop table IncBetaTest_EPCurve
select c.Loss, 1-exp(-sum(p.RATE * (1-dbo.IncBeta(c.Loss/p.EXPVALUE, p.Alpha, p.Beta)))) as EP
into IncBetaTest_EPCurve
from IncBetaTest_DistPars p, IncBetaTest_EPLosses c
where c.Loss<p.EXPVALUE
group by c.Loss;
