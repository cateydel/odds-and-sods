/*
This query series defines circle chains (i.e., clusters) by the maximum distance
in miles (@dist) between any point in the region and the point closest to it.
For example, if @dist=5, then each circle chain is defined such each point
in the region is no more than five miles from the next point.

The key output tables that result from this query series are as follows:
a) latlongpoints:
     Each distinct latitude and longitude point in the EDM,
     and the circle chain to which it has been assigned
b) CircleChains_TIV:
     Each circle chain, its total ground-up TIV,
     and the city that lies at the TIV-weighted centroid of the region

If you want the queries to advise a value for @dist, set @useAdvisedDist=1;
if you want to choose your own value for @dist, set @useAdvisedDist=0.

To apply @dist in kilometres, be sure to change @gcdfScale from 3958.76 to 6371.00.
*/


use Test_EDM

declare @m float, @gcdfScale float, @useAdvisedDist bigint,
  @dist float, @distdeg float, @done bigint, @latlongpointcount float

set @m=pi()/180;            -- ratio of radians to degrees
set @gcdfScale = 3958.76;   -- scale factor in great circle distance formula (3958.76 miles = 6371.00 km)
set @useAdvisedDist=1;      -- run (1) or don't run (0) code to advise a value for @dist 
set @dist=10;               -- the distance to use if not running the advisory code
set @distdeg=@dist/50;      -- the maximum number of lat/long degrees associated with @dist
set @done=0;                -- a flag that will later indicate when certain subroutines are done running



/*
First assign each point to a block (i.e., grid square), such that if any two points are in
the same or adjacent blocks, they must be no more than 2*sqrt(2)*@dist miles away
from each other.
*/

drop table latlongpoints;
create table latlongpoints (
  ID bigint identity(1,1),
  LATITUDE float,
  LONGITUDE float,
  DIST float,
  LATBLOCK bigint,
  LONGBLOCK bigint,
  Region bigint,
  AssignToRegion bigint
);
insert into latlongpoints (
  LATITUDE, LONGITUDE, DIST, LATBLOCK, LONGBLOCK, Region, AssignToRegion
)
select L.LATITUDE, L.LONGITUDE, @dist,
  min(floor(L.LATITUDE/@distdeg)), min(floor(L.LONGITUDE/@distdeg)), -1, 0
from portacct PA, loc L
where PA.PORTINFOID=1           -- change this constraint for the portfolios you want to query
  and PA.ACCGRPID=L.ACCGRPID
  and L.ADDRMATCH in (1, 2)
group by L.LATITUDE, L.LONGITUDE
order by L.LONGITUDE-L.LATITUDE, L.LONGITUDE;




while @useAdvisedDist=1 and @done=0 begin
  select @latlongpointcount=count(*) from latlongpoints;
  
  drop table CircleChains_AdvisedDistance;
  select
      ACOS(SIN(MIN(L.LATITUDE)*@m)*SIN(MAX(L.LATITUDE)*@m)+COS(MIN(L.LATITUDE)*@m)*COS(MAX(L.LATITUDE)*@m))
    *(ACOS(power(SIN(MAX(L.LATITUDE)*@m),2)+power(COS(MAX(L.LATITUDE)*@m),2)*COS((MAX(L.LONGITUDE)-MIN(L.LONGITUDE))*@m))
     +ACOS(power(SIN(MIN(L.LATITUDE)*@m),2)+power(COS(MIN(L.LATITUDE)*@m),2)*COS((MAX(L.LONGITUDE)-MIN(L.LONGITUDE))*@m)))
     *power(@gcdfScale,2)/2 as TrapezoidArea,
    @latlongpointcount as LatLongPointCount,
    convert(float, 0) as MaxAdvisedDistance
  into CircleChains_AdvisedDistance
  from portacct PA, loc L
  where PA.PORTINFOID=1
    and PA.ACCGRPID=L.ACCGRPID
    and L.ADDRMATCH in (1, 2);
  
  update CircleChains_AdvisedDistance
  set MaxAdvisedDistance = power((TrapezoidArea *2 / power(3, 0.5))/LatLongPointCount, 0.5);
  
  select @dist = case
    when MaxAdvisedDistance<0.2 then 0.1
    when MaxAdvisedDistance<0.3 then 0.2
    when MaxAdvisedDistance<0.4 then 0.3
    when MaxAdvisedDistance<0.5 then 0.4
    when MaxAdvisedDistance<1   then 0.5
    when MaxAdvisedDistance<2   then 1
    when MaxAdvisedDistance<3   then 2
    when MaxAdvisedDistance<4   then 3
    when MaxAdvisedDistance<5   then 4
    when MaxAdvisedDistance<10  then 5
    when MaxAdvisedDistance<15  then 10
    when MaxAdvisedDistance<20  then 15
    else 20
    end
  from CircleChains_AdvisedDistance;
  
  set @distdeg=@dist/50;
  
  update latlongpoints
  set DIST=@dist,
    LATBLOCK=floor(LATITUDE/@distdeg),
    LONGBLOCK=floor(LONGITUDE/@distdeg);

  set @done=1;
end;
set @done=0;




drop table latlongblocklist;
create table latlongblocklist (
  ID bigint identity(1,1),
  LATBLOCK bigint,
  LONGBLOCK bigint,
  minLAT float,
  minLONG float,
  maxLAT float,
  maxLONG float,
  riskcount bigint
);
insert into latlongblocklist
  (LATBLOCK, LONGBLOCK, minLAT, minLONG, maxLAT, maxLONG, riskcount)
select
  LATBLOCK, LONGBLOCK,
  min(LATITUDE), min(LONGITUDE),
  max(LATITUDE), max(LONGITUDE),
  sum(1)
from latlongpoints
group by LATBLOCK, LONGBLOCK
order by max(LONGITUDE)-max(LATITUDE), max(LONGITUDE);

drop table latlongblockpairs;
create table latlongblockpairs (
  ID bigint identity(1,1),
  ListID0 bigint,
  ListID1 bigint,
  LATBLOCK0 float,
  LONGBLOCK0 float,
  LATBLOCK1 float,
  LONGBLOCK1 float
);
insert into latlongblockpairs (ListID0, ListID1, LATBLOCK0, LONGBLOCK0, LATBLOCK1, LONGBLOCK1)
select B0.ID, B1.ID, B0.LATBLOCK, B0.LONGBLOCK, B1.LATBLOCK, B1.LONGBLOCK
from latlongblocklist B0, latlongblocklist B1
where
     (B1.LATBLOCK=B0.LATBLOCK   and B1.LONGBLOCK=B0.LONGBLOCK)
  or (B1.LATBLOCK=B0.LATBLOCK   and B1.LONGBLOCK=B0.LONGBLOCK+1)
  or (B1.LATBLOCK=B0.LATBLOCK+1 and B1.LONGBLOCK=B0.LONGBLOCK+1)
  or (B1.LATBLOCK=B0.LATBLOCK-1 and B1.LONGBLOCK=B0.LONGBLOCK)
  or (B1.LATBLOCK=B0.LATBLOCK-1 and B1.LONGBLOCK=B0.LONGBLOCK-1)
order by B0.ID, B1.ID;

/*
Now pair off points in adjacent blocks
*/

drop table latlongpointpairs;
create table latlongpointpairs (
  ID bigint identity(1,1),
  PointID0 bigint,
  PointID1 bigint,
  distance float
);
insert into latlongpointpairs (PointID0, PointID1, distance)
select P0.ID as PointID0, P1.ID as PointID1,
  ACOS(SIN(P0.LATITUDE*@m) * SIN(P1.LATITUDE*@m)
  + COS(P0.LATITUDE*@m) * COS(P1.LATITUDE*@m)
  * COS((P1.LONGITUDE-P0.LONGITUDE)*@m)) * @gcdfScale as distance
from latlongpoints P0, latlongpoints P1, latlongblockpairs B
where P0.LATBLOCK = B.LATBLOCK0
  and P0.LONGBLOCK = B.LONGBLOCK0
  and P1.LATBLOCK = B.LATBLOCK1
  and P1.LONGBLOCK = B.LONGBLOCK1
  and not (B.LATBLOCK0=B.LATBLOCK1 and B.LONGBLOCK0=B.LONGBLOCK1 and P0.ID>=P1.ID)
order by P0.ID, P1.ID;

delete from latlongpointpairs where distance > @dist;



/*
Now use the pairings to assign each location to a circle chain.
If the location is more than the target distance away from every other location,
assign it region -1.
*/

update PT
set PT.Region=0
from latlongpoints PT, latlongpointpairs PR
where PT.ID=PR.PointID0 and PT.Region<0;

update PT
set PT.Region=0
from latlongpoints PT, latlongpointpairs PR
where PT.ID=PR.PointID1 and PT.Region<0;

declare @counter bigint, @minUnassigned bigint, @moreToAssign bigint;
set @counter=1;
select @minUnassigned=min(ID) from latlongpoints where Region=0;

while @minUnassigned is not null begin
  update latlongpoints set Region=@counter where ID=@minUnassigned;
  set @moreToAssign=1

  while @moreToAssign is not null begin
    update latlongpoints
    set Region=@counter, AssignToRegion=0 where AssignToRegion>0;

    update PT1
    set PT1.AssignToRegion = 1
    from latlongpoints PT0, latlongpointpairs PR, latlongpoints PT1
    where PT0.Region = @counter
      and PT0.ID = PR.PointID0
      and PR.PointID1 = PT1.ID
      and PT1.Region = 0
      and PT1.AssignToRegion = 0;
    
    update PT1
    set PT1.AssignToRegion = 1
    from latlongpoints PT0, latlongpointpairs PR, latlongpoints PT1
    where PT0.Region = @counter
      and PT0.ID = PR.PointID1
      and PR.PointID0 = PT1.ID
      and PT1.Region = 0
      and PT1.AssignToRegion = 0;

    select @moreToAssign=min(ID) from latlongpoints where AssignToRegion>0;
  end

  select @minUnassigned=min(ID) from latlongpoints where Region=0;
  set @counter=@counter+1
  
  while @counter % 8 = 0 and @done=0 begin
    set @done=1;
    checkpoint;
  end;
  set @done=0;
end;




drop table CircleChains_TIV
create table CircleChains_TIV (
  ID bigint identity(1,1),
  Region bigint,
  MaxDist float,
  TIV float,
  ctrSTATECODE nvarchar(2),
  ctrCOUNTY nvarchar(40),
  ctrCITY nvarchar(40),
  ctrPOSTALCODE nvarchar(12)
);
insert into CircleChains_TIV
  (Region, MaxDist, TIV, ctrSTATECODE, ctrCOUNTY, ctrCITY, ctrPOSTALCODE)
SELECT P.Region, max(P.DIST), SUM(LC.VALUEAMT), '', '', '', ''
FROM loccvg AS LC INNER JOIN
  loc AS L ON LC.LOCID = L.LOCID INNER JOIN
  latlongpoints AS P ON L.LATITUDE = P.LATITUDE AND L.LONGITUDE = P.LONGITUDE
where L.ADDRMATCH in (1,2)
GROUP BY P.Region
ORDER BY -SUM(LC.VALUEAMT);



drop table CircleChains_AvgCoord
SELECT P.Region,
  SUM(P.LATITUDE * LC.VALUEAMT) / SUM(LC.VALUEAMT) AS avgLATITUDE,
  SUM(P.LONGITUDE * LC.VALUEAMT) / SUM(LC.VALUEAMT) 
  AS avgLONGITUDE
into CircleChains_AvgCoord
FROM loccvg AS LC INNER JOIN
  loc AS L ON LC.LOCID = L.LOCID INNER JOIN
  latlongpoints AS P ON L.LATITUDE = P.LATITUDE AND L.LONGITUDE = P.LONGITUDE
WHERE (L.ADDRMATCH IN (1, 2))
GROUP BY P.Region;

drop table CircleChains_DistFromCtr;
create table CircleChains_DistFromCtr (
  ID bigint identity(1,1),
  Region bigint,
  avgLATITUDE float,
  avgLONGITUDE float,
  LOCID bigint,
  LATITUDE float,
  LONGITUDE float,
  STATECODE nvarchar(2),
  COUNTY nvarchar(40),
  CITY nvarchar(40),
  POSTALCODE nvarchar(12),
  DistFromCtr float
);
insert into CircleChains_DistFromCtr (
  Region, avgLATITUDE, avgLONGITUDE, LOCID, LATITUDE, LONGITUDE,
  STATECODE, COUNTY, CITY, POSTALCODE, DistFromCtr
)
SELECT P.Region, AC.avgLATITUDE, AC.avgLONGITUDE,
  L.LOCID, L.LATITUDE, L.LONGITUDE, L.STATECODE,
  replace(replace(L.COUNTY, ' COUNTY', ''), ' PARISH', ''),
  L.CITY, L.POSTALCODE, 
    ACOS(SIN(AC.avgLATITUDE*@m) * SIN(L.LATITUDE*@m)
  + COS(AC.avgLATITUDE*@m) * COS(L.LATITUDE*@m)
  * COS((L.LONGITUDE-AC.avgLONGITUDE)*@m)) * @gcdfScale AS DistFromCtr
FROM loc AS L INNER JOIN
  latlongpoints AS P ON L.LATITUDE = P.LATITUDE AND L.LONGITUDE = P.LONGITUDE INNER JOIN
  CircleChains_AvgCoord AS AC ON P.Region = AC.Region
WHERE (L.ADDRMATCH IN (1, 2)) AND (P.Region > 0)
ORDER BY P.Region,
  ACOS(SIN(AC.avgLATITUDE*@m) * SIN(L.LATITUDE*@m)
  + COS(AC.avgLATITUDE*@m) * COS(L.LATITUDE*@m)
  * COS((L.LONGITUDE-AC.avgLONGITUDE)*@m)), LOCID

drop table CircleChains_DistFromCtr_Min;
select Region, min(ID) as minID
into CircleChains_DistFromCtr_Min
from CircleChains_DistFromCtr
group by Region
order by Region;

update T
SET
  T.ctrSTATECODE = DC.STATECODE,
  T.ctrCOUNTY = DC.COUNTY,
  T.ctrCITY = DC.CITY,
  T.ctrPOSTALCODE = DC.POSTALCODE
FROM CircleChains_TIV AS T INNER JOIN
  CircleChains_DistFromCtr AS DC ON T.Region = DC.Region INNER JOIN
  CircleChains_DistFromCtr_Min AS DCM ON DC.ID = DCM.minID;

select * from CircleChains_TIV;
