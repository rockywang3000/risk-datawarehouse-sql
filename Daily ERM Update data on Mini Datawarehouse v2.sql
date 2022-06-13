
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED     
SET NOCOUNT ON  

------------GOAL----------------------------------
--update existing dataware if any changes happened

Declare @pStartDate SMALLDATETIME,  
@pEndDate SMALLDATETIME 

Set @pStartDate = '12/1/2012'  
Set @pEndDate = '1/22/2013'


-- 1 Check Identityvalidation for new updates -- update vcustomerkey. lastestidentityvalidationkey, lastattemptvalue, verificationstatustype
drop table pubs.dbo.acct20
select distinct AccountKey 
into pubs.dbo.acct20
from IdentityValidation iv (Nolock) 
join IdentityValidation_Customer ivc (Nolock) on iv.IdentityValidationKey =ivc.IdentityValidationKey
join vCustomer vc (Nolock) on ivc.CustomerKey = vc.CustomerKey
where iv.CreateDate >= @pStartDate
and iv.CreateDate < @pEndDate




--2 Check creditratinghistory -- affect creditratingkey -- update creditraingkey
drop table pubs.dbo.acct21
select distinct AccountKey,vc.CustomerKey
into pubs.dbo.acct21
from creditratinghistory crh  (nolock)  join vCustomer vc (Nolock) on crh.CustomerKey = vc.CustomerKey
where ChangeDate >= @pStartDate  
and ChangeDate <  @pEndDate 

--select * from creditratinghistory crh

-- 3 Check customerstatushistory table -- affect currbalance and creditratingkey
--select * from CustomerStatusHistory

 --select top 10 * from ERM.dbo.ACCT
  
 
drop table pubs.dbo.acct22
select distinct AccountKey
into pubs.dbo.acct22
from CustomerStatusHistory crh  (nolock)  join vCustomer vc (Nolock) on crh.SerialNbr = vc.SerialNbr
where StartDate >= @pStartDate  
and StartDate <  @pEndDate 


-- all the accounts need to be updated (only those changes creditratingkey and currbalance)
/*drop table pubs.dbo.acct23
select accountkey
into pubs.dbo.acct23
from
(
select accountkey from pubs.dbo.acct21
union
select accountkey from pubs.dbo.acct22
) tt
*/
/*
select COUNT(*) from pubs.dbo.acct20 -- cip change
select COUNT(distinct AccountKey) from pubs.dbo.acct20

select COUNT(*) from pubs.dbo.acct21
select COUNT(distinct AccountKey) from pubs.dbo.acct21

select COUNT(*) from pubs.dbo.acct22
select COUNT(distinct AccountKey) from pubs.dbo.acct22

select COUNT(*) from pubs.dbo.acct23
*/



-------------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------
--1. update All these accounts with cip change only -- acct20

--Latest is the last identityvalidationkey; customerkey is the one used for activation
drop table pubs.dbo.acct35
select pubs.dbo.acct20.AccountKey,Latest as LastIdentityValidationKey,VerificationStatusType,LastAttemptValue
 into pubs.dbo.acct35 from pubs.dbo.acct20 (nolock) cross apply pubs.dbo.fcipwithaccountkey (pubs.dbo.acct20.AccountKey) tt

-- update for the CIP change part only
drop table pubs.dbo.acct35_cip
select pubs.dbo.acct35.*,TCustomerkey, TCreditRatingkey,TCurrBalance,PCustomerkey,PCreditRatingkey,PCurrBalance,VCustomerkey,
DOB,CardActivationDate,ProductKey,HomePhone,CellPhone,Email,ResidentialAddress1,ResidentialAddress2,ResidentialCity,ResidentialState,ResidentialZipcode,
Address1,Address2,City,State,ZipCode
into pubs.dbo.acct35_cip
from pubs.dbo.acct35 (nolock) cross apply pubs.dbo.fTempPersowithAccountkey (pubs.dbo.acct35.AccountKey) tt 

--Lets' compare if there is any different before updating




/* this accountkey has 2 perso cards, no temp card.......
select accountkey, COUNT(*) from pubs.dbo.acct35_cip group by accountkey having COUNT(*) > 1
select * from pubs.dbo.acct35_cip where accountkey = 51431176

select * from vCustomer where accountkey = 51431176

select * from pubs.dbo.fTempPersowithAccountkey (51431176) tt

select p.isatm, vc.*,p.* 
from vCustomer vc join vuProduct p on vc.ProductKey= p.productkey where accountkey = 51431176
*/

--3831761
/*
select COUNT(*) from pubs.dbo.acct35
select COUNT(distinct AccountKey) from pubs.dbo.acct35

select COUNT(*) from pubs.dbo.acct35_cip
select COUNT(distinct AccountKey) from pubs.dbo.acct35_cip

select top 3 * from pubs.dbo.acct35_cip where AccountKey = 51434157
select top 3 * from ERM.dbo.ACCT where AccountKey = 51434157 
*/

--- test if information changed
/*
select * from ERM.dbo.ACCT a (nolock) join pubs.dbo.acct35_cip b (nolock) 
on a.accountkey = b.AccountKey
where a.LastIdentityValidationKey != b.LastIdentityValidationKey
*/

-- update these to our master table --- cip related
update a
set a.LastIdentityValidationKey = b.LastIdentityValidationKey,a.VerificationStatusType=b.VerificationStatusType,
a.LastAttemptValue=b.LastAttemptValue,a.TCustomerkey=b.TCustomerkey,a.PCustomerkey=b.PCustomerkey,a.VCustomerkey = b.VCustomerkey,
a.CardActivationDate = b.CardActivationDate
from ERM.dbo.ACCT a (nolock) join pubs.dbo.acct35_cip b (nolock)
on a.accountkey = b.AccountKey


--select * from  pubs.dbo.acct35_cip where accountkey =58023546


-- just rerun this to update info. compare if there is any difference, then update accordingly; run it daily
--creat 3 indices


--------------------------------------------------------------------------------------------------------------------------------------
------------------------------------------when LAST put the compliance block by looking creditratinghistory---------------------------
--2. Get who put the last credit rating
drop table pubs.dbo.acct36
select customerkey,max(changedate) LatestDate
into pubs.dbo.acct36
from creditratinghistory crh  (nolock)  
where 
crh.CustomerKey in (select CustomerKey from pubs.dbo.acct21) ----- only creditratinghistory table has sysuserkey to determine who the the creditratingkey
and crh.creditratingkey in ('B5','P9', 'C5')
--and ChangeDate >=  convert(varchar(10),getdate()-30,101)  
group by customerkey


---select * from creditratinghistory order by changedate desc

drop table pubs.dbo.acct37
select --v.AccountKey,
c.customerkey,crh.ChangeDate, crh.creditratingkey,crh.sysuserkey, fullname
into pubs.dbo.acct37
from pubs.dbo.acct36 c (nolock)
join creditratinghistory crh  (nolock) on c.customerkey = crh.customerkey and crh.changedate = latestdate
join sysuser su  (nolock) on crh.sysuserkey = su.sysuserkey
--join vCustomer v (nolock) on c.CustomerKey= v.CustomerKey
where 
crh.creditratingkey in ('B5','P9', 'B3') or 
(
crh.creditratingkey = 'C5'
and 
crh.sysuserkey in(3227, 2933,989,1884,4561,4562,988,2370,4153,2690,2687,6838,4176,7347,7090,6917,6918)
)


--select * from SysUser where FullName like '%chebe%'


--select * from pubs.dbo.acct39 order by 1


-- Final Result with creditratingkey change user
drop table pubs.dbo.acct38
select f.accountkey, a.*, DENSE_RANK() over (partition by f.accountkey order by a.changedate desc) as attempt
into pubs.dbo.acct38
from pubs.dbo.acct37 a (nolock) join vCustomer f (nolock)  on f.customerkey = a.customerkey and a.CreditRatingKey=f.CreditRatingKey


drop table pubs.dbo.acct39
select a.accountkey, a.CreditRatingKey as BlockCreditratingkey, ChangeDate as BlockDate, FullName as BlockUser
into pubs.dbo.acct39
from pubs.dbo.acct38 a (nolock) where a.attempt = 1

create index ina on pubs.dbo.acct39 (accountkey)

--- test if information changed
/*
select * from ERM.dbo.ACCT a (nolock) join pubs.dbo.acct39 b (nolock) 
on a.accountkey = b.AccountKey
where a.BlockCreditratingkey != b.BlockCreditratingkey
*/


-- update these to our master table
update a
set a.BlockCreditratingkey = b.BlockCreditratingkey,a.BlockDate=b.blockdate,
a.BlockUser=b.BlockUser
from ERM.dbo.ACCT a (nolock) join pubs.dbo.acct39 b (nolock)
on a.accountkey = b.AccountKey

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

-- 3. with accounts that had recent changes, update them with customer table
--update creditratingkey, balance etc
--select * from pubs.dbo.acct22
create index ina22 on pubs.dbo.acct22 (accountkey)

drop table pubs.dbo.acct50
select a.AccountKey,pcustomerkey, tcustomerkey
into pubs.dbo.acct50
from pubs.dbo.acct22 a (nolock) join ERM.dbo.ACCT a2 (nolock) on a.AccountKey=a2.AccountKey

create clustered index ina_50 on pubs.dbo.acct50 (accountkey,pcustomerkey, tcustomerkey)


drop table pubs.dbo.acct51
select a.AccountKey,pcustomerkey, tcustomerkey, v1.CreditRatingKey as Pcreditratingkey, v2.CreditRatingKey as Tcreditratingkey,
v1.currbalance as Pcurrbalance, v2.CurrBalance as Tcurrbalance 
into pubs.dbo.acct51
from pubs.dbo.acct50 a (nolock) 
join vcustomer v1 (nolock) on a.PCustomerkey=v1.CustomerKey
join vcustomer v2 (nolock) on a.TCustomerkey=v2.CustomerKey


create index ina_51 on pubs.dbo.acct51 (accountkey)

--- test if information changed
/*
select * from ERM.dbo.ACCT a (nolock) join pubs.dbo.acct51 b (nolock) 
on a.accountkey = b.AccountKey
where a.PCurrBalance != b.Pcurrbalance
*/



-- update these to our master table
update a
set a.PCreditRatingkey = b.Pcreditratingkey, a.PCurrBalance= b.Pcurrbalance,
a.TCreditRatingkey=b.Tcreditratingkey,a.TCurrBalance=b.Tcurrbalance
from ERM.dbo.ACCT a (nolock) join pubs.dbo.acct51 b (nolock)
on a.accountkey = b.AccountKey



---
--select * from  pubs.dbo.acct51 where accountkey =58023546










---------------------------------------------------------------------------------------------------
--------------------------------------------------------
--------------------------------------------------------
--updating Online Sales with Activation_Step
-----------------------------------------------------------

----Deal with Online Sales-------------------------------------------------------------------------------

--select * from ERM.dbo.ACCT  where activation_step is null

drop table #allcust
select a.* into #allcust 
from ERM.dbo.ACCT a (nolock) join pubs.dbo.acct35_cip b (nolock)
on a.accountkey = b.AccountKey

where --CreateDate >= '10/1/2012' and CreateDate < '10/25/2012'
Channel= 'Online'


-- these went through CIP process
drop table #cust
select * into #cust from #allcust where LastIdentityValidationKey is Not null

/*
--60075

select * from Bank

select count(*) from #allcust 

select * from #allcust order by createdate desc

*/
-- the vcustomerkey and tcustomerkey for online sale are always the same
--select count(*) from #cust where VCustomerkey is null

-----------------------------------------------------------------------
---Find other failed reasons

--temp table for setting the activation activity type order
IF OBJECT_ID('tempdb..#ActivationActivityTypeOrder') is not null DROP TABLE #ActivationActivityTypeOrder
--GO
CREATE TABLE #ActivationActivityTypeOrder
(
            id INT IDENTITY(1, 1) PRIMARY KEY,
            ActivationActivityTypeKey INT,
            ActicationActivityOrder INT,
            IsActive BIT,
            ActivityTypeDesc varchar(100)
)
--GO

-- cant change the description here
insert into #ActivationActivityTypeOrder (ActivationActivityTypeKey,ActicationActivityOrder,IsActive,ActivityTypeDesc) values (9, 1, 1, 'IP Validation')
insert into #ActivationActivityTypeOrder (ActivationActivityTypeKey,ActicationActivityOrder,IsActive,ActivityTypeDesc) values (3, 2, 1, 'Age Verification')  
insert into #ActivationActivityTypeOrder (ActivationActivityTypeKey,ActicationActivityOrder,IsActive,ActivityTypeDesc) values (20, 3, 1, 'Address Validation')
insert into #ActivationActivityTypeOrder (ActivationActivityTypeKey,ActicationActivityOrder,IsActive,ActivityTypeDesc) values (5, 5, 1, 'Partner Card Limit')
insert into #ActivationActivityTypeOrder (ActivationActivityTypeKey,ActicationActivityOrder,IsActive,ActivityTypeDesc) values (2, 6, 1, 'Customer Verification and Incomplete Customer Activation')
insert into #ActivationActivityTypeOrder (ActivationActivityTypeKey,ActicationActivityOrder,IsActive,ActivityTypeDesc) values (12,7, 1, 'Activation Error (General Exception)')
--Negative match is included in Customer Verification
insert into #ActivationActivityTypeOrder (ActivationActivityTypeKey,ActicationActivityOrder,IsActive,ActivityTypeDesc) values (8,8, 1, 'Fraud Check')
insert into #ActivationActivityTypeOrder (ActivationActivityTypeKey,ActicationActivityOrder,IsActive,ActivityTypeDesc) values (10000,9, 1, 'OOW Declined')
--GO


----------------------------ALL Failure--------------------------------------------------------

Create Index IDX_cust On #allcust(vcustomerkey)   

---    ActivationActivityType only has #s for address validation; customer verification and partner limit check, nothing else
drop table #fail
select  month(ActivationActivityCreateDate)*10000 +year(ActivationActivityCreateDate) as Month_Year,
aato.ActicationActivityOrder, aat.ActivationActivityType as activityDesc,aa.customerkey, ct.accountkey
into #fail
from #allcust ct (nolock) 
join ccdw.dbo.ActivationActivity aa (nolock) on ct.VCustomerkey= aa.CustomerKey  -- need to use vcustomerkey, not tcustomerkey              
            join ccdw.dbo.ActivationType at (nolock) on aa.ActivationTypeKey=at.ActivationTypeKey
            join ccdw.dbo.ActivationActivityType aat (nolock) on aa.ActivationActivityTypeKey=aat.ActivationActivityTypeKey
			left join #ActivationActivityTypeOrder aato (nolock)  on aa.ActivationActivityTypeKey=aato.ActivationActivityTypeKey
where 
--aa.ActivationActivityCreateDate>=  @pstartdate
--and aa.ActivationActivityCreateDate < @penddate
aa.ActivationTypeKey=2--online sales
and aa.IsConfirmed=0   -- all failure

-- find out customerkey=58561500 failed first, then approved later
--select * from ActivationActivity where customerkey =58561500

/* select * from ActivationActivityType
select count(*) from #fail 


select * from #ActivationActivityTypeOrder

after august 31; 8 -- fraud check --- it is really negative match


select * from #fail where activitydesc = 'fraud check' order by 1


order by 1

--select * from #cust where AccountKey not in (select AccountKey from #fail)

		select * from #fail (nolock) where activitydesc = 'customer verification' 
		and accountkey not in (select accountkey from #cust)


select * from #fail

		
*/


-- those in "customer verification" bucket, but didn't go through CIP process should be in "negative match" bucket
-- #fail table is subset of #allcust table ( which contains the Online Sale customers including missing information)
-- #cust table is a subset of #allcust. #cust only contains those went through CIP
		update #fail
		set acticationactivityorder = 4, activitydesc = 'Negative Match'	
		from #fail (nolock) 
		where activitydesc = 'fraud check'
		or(activitydesc = 'customer verification' and accountkey not in (select accountkey from #cust))
		
	Create Index IDX_customerke On #fail(customerkey)   
	
	--select * from #fail where activitydesc = 'fraud check'


-----------------------------OOW-----------------------------------------------------------------------------------
--select * from IdentityValidationOutOfWalletQuiz i

drop table #OOW0
select f.*,quizresultcode, ir.RiskValue
into #OOW0
from #cust f(nolock)
join ccdw.dbo.IdentityValidationOutOfWalletQuiz i WITH (NOLOCK)  on f.LastIdentityValidationKey = i.IdentityValidationKey  
join ccdw.dbo.IdentityValidationRiskAssessment ir (nolock)on ir.IdentityValidationKey= i.IdentityValidationKey


drop table #failedOOW
select *
into #failedoow
from #OOW0 
where QuizResultCode in ('refer_incomplete', 'refer')


--union OOW with others, the "customer verification" may also have some failed OOWs in it as well. make sure no duplicates in #fail2

-- #failed table have all these failed buckets including OOW bucket
drop table #fail2
select * into #fail2 from
(
select * from #fail where AccountKey not in (select AccountKey from #failedoow) -- Those failed buckets excluding OOW if some are mixed in
union
(
select  month(CreateDate)*10000 + year(CreateDate), 10000,'OOW Declined',vcustomerkey, AccountKey from #failedoow -- Those failed OOW, need to use vcustomerkey
)
) tt


--select * from #fail2

--select activitydesc,month_year, count(*) from #fail2 group by activitydesc, month_year

drop table #approved
select * into #approved
from #allcust
where verificationstatustype = 'Approved' and cardactivationdate is not null



-- *** a customer coud fail first, then approved later, so need to remove those failed from the failed buckets
--select f.*,a.* from #approved a join #fail2 f on a.AccountKey= f.AccountKey


-- The string too long to be updated to the temp table
drop table #r1
create table #r1
(
accountkey int,
Activation_Step varchar(20)
)


-- approved
insert into #r1 (accountkey, Activation_Step)
select ac.AccountKey,case when av.accountkey is not null then 'Approved' else '' end
from #allcust ac (nolock) left join #approved av (nolock) on ac.AccountKey= av.AccountKey


--select * from #r1
--187664
--select COUNT(distinct accountkey) from #r1 where Activation_Step ='Approved'
--187664
--select COUNT(distinct AccountKey) from #approved
/*
-- column: Activation_step
--Naming:
Approved
Incomplete 
Addr_Verify
Neg_Match
Card_Limit
OOW
Ident_Verify
*/




-- declined
update ac
set   ac.Activation_step = 'Ident_Verify'
from #r1 ac (nolock) join #fail2 av (nolock) 
on ac.AccountKey= av.AccountKey and ac.Activation_step ='' and av.activityDesc='Customer Verification'

update ac
set   ac.Activation_step = 'Addr_Verify'
from #r1 ac (nolock) join #fail2 av (nolock) 
on ac.AccountKey= av.AccountKey and ac.Activation_step ='' and av.activityDesc='Address VAlidation'

update ac
set   ac.Activation_step = 'Card_Limit'
from #r1 ac (nolock) join #fail2 av (nolock) 
on ac.AccountKey= av.AccountKey and ac.Activation_step ='' and av.activityDesc like '%Partner%'


update ac
set   ac.Activation_step = 'OOW'
from #r1 ac (nolock) join #fail2 av (nolock) 
on ac.AccountKey= av.AccountKey and ac.Activation_step ='' and av.activityDesc like '%oow%'


update ac
set   ac.Activation_step = 'Neg_Match'
from #r1 ac (nolock) join #fail2 av (nolock) 
on ac.AccountKey= av.AccountKey and ac.Activation_step ='' and av.activityDesc like '%negative%'

/*
select * from #r1 ac (nolock) join #fail2 av (nolock) 
on ac.AccountKey= av.AccountKey and ac.Activation_step ='' and av.activityDesc like '%oow%'

select distinct activityDesc from #fail2
*/


--select Activation_Step, COUNT(*) from #r1 group by Activation_Step
--select activityDesc, COUNT(*) from #fail2 group by activityDesc

-----------------------------------------------

/*
-- check if incomplete IS incomplete
--3316
select Activation_Step,COUNT(*) from #r1 where Activation_Step ='' group by Activation_Step

drop table #test
select a.* into #test from #r1 r (nolock) join #allcust a (nolock) on r.accountkey= a.AccountKey
where Activation_Step ='' 

-- gather information or declined for similar reasons
select * from 
ActivationActivity aa (nolock)               
            join ActivationType at (nolock) on aa.ActivationTypeKey=at.ActivationTypeKey
            join ActivationActivityType aat (nolock) on aa.ActivationActivityTypeKey=aat.ActivationActivityTypeKey
			left join #ActivationActivityTypeOrder aato (nolock)  on aa.ActivationActivityTypeKey=aato.ActivationActivityTypeKey
where CustomerKey in 
(select vcustomerkey from #test
)
and aa.ActivationTypeKey=2--online sales
and aa.IsConfirmed=0   -- all failure
*/

update ac
set   ac.Activation_step = 'Incomplete'
from #r1 ac (nolock) where ac.Activation_step ='' 

--select Activation_Step,COUNT(*) from #r1 group by Activation_Step



--select count(*) from #r1

--select * from ERM.dbo.ACCT where Activation_step is null

create index kk on #r1 (accountkey)


--select * from #r1  where accountkey=  58053482



update av
set   av.Activation_step = ac.Activation_Step
from #r1 ac (nolock) join ERM.dbo.ACCT av (nolock) 
on ac.AccountKey= av.AccountKey 


-------------------------------


--------------------------------------------------------
--------------------------------------------------------
--updating Retail Sales with Activation_Step
--------------------------------------------------------------------------------------------------------


drop table pubs.dbo.wr1_u
select ci.*, c.FirstName,ParentFirstName,c.LastName,ParentLastName,SSN,ParentSSN,ParentDOB,
	DATEDIFF(mm, c.DOB, c.CreateDate)/12.0 CH_Age,	DATEDIFF(mm,c.parentdob, C.CreateDate)/12.0 Parent_Age,
rd.refundreasonkey, refundreason,comment,c.activationstatuskey, c.ActivationSysUserKey, C.SysUserKey,activationstatus
into pubs.dbo.wr1_u
from pubs.dbo.acct35_cip b (nolock) 
join ERM.dbo.ACCT ci (nolock) on ci.accountkey = b.AccountKey
join ccdw.dbo.Customer c (nolock) on ci.VCustomerkey= c.CustomerKey
left join ccdw..ActivationStatus ast  (nolock)on ast.activationstatuskey = c.activationstatuskey 
left join ccdw..Refund rd (nolock) 	on c.customerkey = rd.customerkey
left join ccdw..RefundReason rf (nolock) on rd.refundreasonkey = rf.refundreasonkey
where  Channel= 'Retail'



/*
--51864
select count(*) from pubs.dbo.wr1 ac (nolock) 

--51864
select count(distinct AccountKey) from pubs.dbo.wr1 ac (nolock) 
*/

Alter Table pubs.dbo.wr1_u
Add ACTIVATION_TRACKER varchar(50)


create index ii on pubs.dbo.wr1_u(lastidentityvalidationkey)
create index ii2 on pubs.dbo.wr1_u(accountkey)

--GETTING ALL RECORDS THAT HAVE ALL NECCESSARY INFORMATION
drop table pubs.dbo.wr2_u
Select * 
INTO pubs.dbo.wr2_u
from pubs.dbo.wr1_u (nolock)
WHERE (FirstName is not null or ParentFirstName is not null)
and (LastName is not null or ParentLastName is not null)
and (DOB is not null or ParentDob is not null)
and (SSN is not null or ParentSSN is not null)
and (CellPhone is not null or HomePhone is not null)
and ResidentialAddress1 is not null
and ResidentialZipCode is not null

-------------------------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------------------------
--Separate Missing_info from Incomplete
----------------------------

--select * from pubs.dbo.wr2

Update A1
SET Activation_Tracker = 'Missing_Info'
from pubs.dbo.wr1_u A1
where (FirstName is null or LastName is null or DOB is null or SSN is null or (CellPhone is null and HomePhone is null) or ResidentialAddress1 is null or ResidentialZipCode is null)
or
( (ParentFirstName is null or ParentLastName is null or ParentDob is null or ParentSSN is null)
and CH_Age < 18
)

--UPDATING ACTIVATION_TRACKER WITH ALL RECORDS THAT ARE MISSING AT LEAST 1 PART OF KEY INFORMATION
Update A1
SET Activation_Tracker = 'Incomplete'
from pubs.dbo.wr1_u A1
where AccountKey not in (select accountkey from pubs.dbo.wr2_u) and Activation_tracker is null


--select * from ERM.dbo.ACCT

--UPDATING ACTIVATION TRACKER WITH ALL SUCCESSFUL CARD ACTIVATIONS
Update A1
SET Activation_Tracker = 'Approved'
from pubs.dbo.wr1_u A1
where verificationstatustype = 'Approved'
and Cardactivationdate is not null
and Activation_tracker is null

--UPDATING ACTIVATION TRACKER WITH RECORDS THAT FAILED NEG_MATCH

Update A1
SET Activation_Tracker = 'Neg_Match'
from pubs.dbo.wr1_u A1
where (activationstatuskey in (50,140) or refundreasonkey = 8)
and Activation_Tracker is null

--UPDATING ACTIVATION TRACKER WITH RECORDS THAT FAILED MAX_CARD_LIMIT
Update A1
SET Activation_Tracker = 'Card_Limit'
from pubs.dbo.wr1_u A1
where (activationstatuskey in (145) or refundreasonkey = 23)
and Activation_Tracker is null

-------------------------------------------------------------------------------------------------------------------

--UPDATING ACTIVATION TRACKER WITH RECORDS THAT FAILED CIP
Update A1
SET Activation_Tracker = 'Ident_Verify'
from  pubs.dbo.wr1_u A1
where VerificationStatusType <> 'Approved'
and Activation_Tracker is null

---------------------------------

/*
			drop table #cust1
				select CC.*, 
				ar.MatchLevel as [QAS 1],
				ar2.MatchLevel as [QAS 2],
				Case when ar.MatchLevel = 'Verified' and  ar2.MatchLevel = 'Verified' then 'VERIFIED'
					when ar.MatchLevel = 'Verified' and  ar2.MatchLevel is null then 'VERIFIED'
					when ar.MatchLevel is null and  ar2.MatchLevel = 'Verified' then 'VERIFIED'
					when ar.MatchLevel is null and  ar2.MatchLevel is null then 'VERIFIED' end as QAS						
				into #cust1  
				 from pubs.dbo.wr1 cc WITH (NOLOCK)
				left join AccountAddress aa(nolock) on cc.AccountKey = aa.AccountKey and aa.addressTypekey=2
				left join AddressStandardizationResult ar(nolock) on ar.AddressStandardizationResultKey=aa.AddressStandardizationResultKey
				left join AccountAddress aa2(nolock) on cc.AccountKey = aa2.AccountKey and aa2.addressTypekey=1
				left join AddressStandardizationResult ar2(nolock) on ar2.AddressStandardizationResultKey=aa2.AddressStandardizationResultKey
				where ACTIVATION_TRACKER is null

select * from #cust1

				Select 
				CustomerKey, Address1, City, State, ZipCode, ResidentialAddress1, ResidentialZipCOde, sysuserkey, [QAS 1],QAS1_CreateDate, [QAS 2] ,  QAS2_CreateDate,
				DATEDIFF(hour, QAS1_CreateDate, QAS2_CreateDate)
				from #cust1
				where [QAS 2] = 'verified'
				and ([QAS 1] is not null and [QAS 1] <> 'Verified')
				
		*/		


-- those are not in the buckets above will be NULL
--select * from pubs.dbo.wr1 where activation_tracker is null


-----------------------------OOW-----------------------------------------------------------------------------------
--select * from IdentityValidationOutOfWalletQuiz i




drop table #OOW00
select f.*,quizresultcode, ir.RiskValue
into #OOW00
from pubs.dbo.wr1_u f(nolock)
join ccdw.dbo.IdentityValidationOutOfWalletQuiz i (NOLOCK)  on f.LastIdentityValidationKey = i.IdentityValidationKey  
join ccdw.dbo.IdentityValidationRiskAssessment ir (nolock)on ir.IdentityValidationKey= i.IdentityValidationKey
where f.activation_tracker = 'Ident_Verify'


drop table #failedOOW0
select *
into #failedoow0
from #OOW00 
where QuizResultCode in ('refer_incomplete', 'refer')


--select  * from #failedoow0 -- Those failed OOW, need to use vcustomerkey


update ac
set   ac.Activation_tracker = 'OOW'
from #failedoow0 av (nolock) join pubs.dbo.wr1_u ac (nolock) 
on ac.AccountKey= av.AccountKey 


--select activation_tracker, COUNT(*) from pubs.dbo.wr1 (nolock) group by activation_tracker
-- select top 10 * from pubs.dbo.wr1

--update to the master table--------------------------------
update av
set   av.Activation_step = ac.Activation_tracker
from pubs.dbo.wr1_u ac (nolock) join ERM.dbo.ACCT av (nolock) 
on ac.AccountKey= av.AccountKey --and AV.Activation_step is null


----end of Retail Sales Activation_step update

-----------------------------------------------------


--------- add OOW column---------------------------------------------------------------------------------------------------------

/*
Alter Table ERM.dbo.ACCT
Add OOW varchar(45)

select * from ERM.dbo.ACCT
*/

drop table pubs.dbo.o1_u
select f.AccountKey,quizresultcode--, ir.RiskValue
into pubs.dbo.o1_u
from pubs.dbo.acct35_cip f (nolock) 
join ccdw.dbo.IdentityValidationOutOfWalletQuiz i WITH (NOLOCK)  on f.LastIdentityValidationKey = i.IdentityValidationKey  
--join IdentityValidationRiskAssessment ir (nolock)on ir.IdentityValidationKey= i.IdentityValidationKey
--where f.CreateDate >= '10/1/2012' and f.CreateDate < '10/3/2012'

create index ii2 on pubs.dbo.o1_u(accountkey)


--update to the master table--------------------------------
update av
set   av.OOW = ac.QuizResultCode
from pubs.dbo.o1_u ac (nolock) join ERM.dbo.ACCT av (nolock) 
on ac.AccountKey= av.AccountKey --and AV.Activation_step is null

--select * from pubs.dbo.o1



------------------------------------------------------------------------------------
--- Internal Lookup update LastAttemptvalue column with 'Int'

----select top 100 * from ERM.dbo.ACCT

drop table pubs.dbo.i1_u
select a.* into pubs.dbo.i1_u 
from pubs.dbo.acct35_cip f (nolock) 
join erm.dbo.ACCT a (nolock) on f.AccountKey= a.AccountKey
where a.activation_step = 'approved' and a.LastAttemptValue is null 

create index ii2 on pubs.dbo.i1_u(accountkey)
create index ii3 on pubs.dbo.i1_u(lastidentityvalidationkey)

--2226872
--select COUNT(*) from pubs.dbo.i1

drop table pubs.dbo.i2_u
select 
b.CreateDate as identityCreateDate,b.ValidationResultCode,
b.IdentityValidationStatusTypeKey,IdentityValidationStatusType,
b.IdentityValidationVendorKey,IdentityValidationVendor, a.*
into pubs.dbo.i2_u
from pubs.dbo.i1_u a (nolock) 
join ccdw.dbo.identityValidationStatus b (nolock) on a.LastIdentityValidationKey = b.IdentityValidationKey 
join ccdw.dbo.identityValidationStatusType i (nolock) on i.IdentityValidationStatusTypeKey =b.IdentityValidationStatusTypeKey
join ccdw.dbo.identityValidationVendor v (nolock) on v.IdentityValidationVendorKey =b.IdentityValidationVendorKey


create index ii4 on pubs.dbo.i2_u(accountkey)


-- internal lookup
drop table #i3
select * into #i3 from pubs.dbo.i2_u (nolock) 
where  identityvalidationvendorkey = 4 and identityvalidationstatustypekey = 1 and VerificationStatusType ='Approved'

--select COUNT(*) from pubs.dbo.i2
---2226840
--select COUNT(*) from #i3

--select top 5 * from pubs.dbo.i2 a (nolock) left join #i3 b (nolock) on a.AccountKey= b.AccountKey where  b.AccountKey is null

-- verificationstatus is null, have perso card
--select * from ERM.dbo.ACCT where accountkey in (44778718)


--select * from #i3

--update to the master table--------------------------------
update av
set   av.LastAttemptValue = 'Int'
from #i3 ac (nolock) join ERM.dbo.ACCT av (nolock) 
on ac.AccountKey= av.AccountKey --and AV.LastAttemptValue is null



