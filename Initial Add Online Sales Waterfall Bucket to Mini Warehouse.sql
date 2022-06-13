
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED     
SET NOCOUNT ON  


----Deal with Online Sales-------------------------------------------------------------------------------

--select * from ci_dsa.dbo.RPO_ACCT  where  Channel= 'Online'

drop table #allcust
select * into #allcust from ci_dsa.dbo.RPO_ACCT 
where CreateDate >= '10/1/2012' and CreateDate < '10/25/2012'
and  Channel= 'Online'

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
GO
CREATE TABLE #ActivationActivityTypeOrder
(
            id INT IDENTITY(1, 1) PRIMARY KEY,
            ActivationActivityTypeKey INT,
            ActicationActivityOrder INT,
            IsActive BIT,
            ActivityTypeDesc varchar(100)
)
GO

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
GO


----------------------------ALL Failure--------------------------------------------------------

Create Index IDX_cust On #allcust(vcustomerkey)   

---    ActivationActivityType only has #s for address validation; customer verification and partner limit check, nothing else
drop table #fail
select  month(ActivationActivityCreateDate)*10000 +year(ActivationActivityCreateDate) as Month_Year,
aato.ActicationActivityOrder, aat.ActivationActivityType as activityDesc,aa.customerkey, ct.accountkey
into #fail
from #allcust ct (nolock) 
join ActivationActivity aa (nolock) on ct.VCustomerkey= aa.CustomerKey  -- need to use vcustomerkey, not tcustomerkey              
            join ActivationType at (nolock) on aa.ActivationTypeKey=at.ActivationTypeKey
            join ActivationActivityType aat (nolock) on aa.ActivationActivityTypeKey=aat.ActivationActivityTypeKey
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
join IdentityValidationOutOfWalletQuiz i WITH (NOLOCK)  on f.LastIdentityValidationKey = i.IdentityValidationKey  
join IdentityValidationRiskAssessment ir (nolock)on ir.IdentityValidationKey= i.IdentityValidationKey


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

--select * from CI_DSA.dbo.RPO_ACCT where Activation_step is null

create index kk on #r1 (accountkey)

/*--- fixing negative match

update av
set   av.Activation_step = ac.Activation_Step
from #r1 ac (nolock) join CI_DSA.dbo.RPO_ACCT av (nolock) 
on ac.AccountKey= av.AccountKey --and AV.Activation_step is null


select Activation_Step,count(*) from CI_DSA.dbo.RPO_ACCT 
where channel ='Online'
group by Activation_Step

where Activation_Step like '%neg%' and 
createdate > '9/2/2012'

*/

--update to the master table--------------------------------
update av
set   av.Activation_step = ac.Activation_Step
from #r1 ac (nolock) join CI_DSA.dbo.RPO_ACCT av (nolock) 
on ac.AccountKey= av.AccountKey and AV.Activation_step is null

/*

select * from #r1 where activation_step is null

select * from #allcust where activation_step is not null


select COUNT(*) from #r1 ac (nolock) join CI_DSA.dbo.RPO_ACCT av (nolock) 
on ac.AccountKey= av.AccountKey and AV.Activation_step is null

select TOp 20 * from  CI_DSA.dbo.RPO_ACCT order by activation_step desc

*/

/*
-- approved is less than I thought?
select * from #approved
select COUNT(*) from #approved where BankKey = 2

 failed buckets are pretty consistent
drop table #result
select month_year, ActicationActivityOrder,activitydesc, count(distinct f.AccountKey) as Cnt  
into #result
from #fail2 f join #allcust a on f.AccountKey= a.AccountKey
where BankKey = 2
group by month_year, ActicationActivityOrder, activitydesc

select * from #result
*/

