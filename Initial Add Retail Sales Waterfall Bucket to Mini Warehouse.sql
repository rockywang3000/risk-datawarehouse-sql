
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED     
SET NOCOUNT ON  

drop table pubs.dbo.wr1
select ci.*, c.FirstName,ParentFirstName,c.LastName,ParentLastName,SSN,ParentSSN,ParentDOB,
	DATEDIFF(mm, c.DOB, c.CreateDate)/12.0 CH_Age,	DATEDIFF(mm,c.parentdob, C.CreateDate)/12.0 Parent_Age,
rd.refundreasonkey, refundreason,comment,c.activationstatuskey, c.ActivationSysUserKey, C.SysUserKey,activationstatus
into pubs.dbo.wr1
from ci_dsa.dbo.RPO_ACCT ci (nolock) 
join Customer c (nolock) on ci.VCustomerkey= c.CustomerKey
left join ccdw..ActivationStatus ast  (nolock)on ast.activationstatuskey = c.activationstatuskey 
left join ccdw..Refund rd (nolock) 	on c.customerkey = rd.customerkey
left join ccdw..RefundReason rf (nolock) on rd.refundreasonkey = rf.refundreasonkey
where --ci.CreateDate >= '10/1/2012' and ci.CreateDate < '10/3/2012'
--and  
Channel= 'Retail'



/*
--51864
select count(*) from pubs.dbo.wr1 ac (nolock) 

--51864
select count(distinct AccountKey) from pubs.dbo.wr1 ac (nolock) 
*/

Alter Table pubs.dbo.wr1
Add ACTIVATION_TRACKER varchar(50)



create index ii on pubs.dbo.wr1(lastidentityvalidationkey)
create index ii2 on pubs.dbo.wr1(accountkey)

--GETTING ALL RECORDS THAT HAVE ALL NECCESSARY INFORMATION
drop table pubs.dbo.wr2
Select * 
INTO pubs.dbo.wr2
from pubs.dbo.wr1 (nolock)
WHERE (FirstName is not null or ParentFirstName is not null)
and (LastName is not null or ParentLastName is not null)
and (DOB is not null or ParentDob is not null)
and (SSN is not null or ParentSSN is not null)
and (CellPhone is not null or HomePhone is not null)
and ResidentialAddress1 is not null
and ResidentialZipCode is not null

-------------------------------------------------------------------------------------------------------------------
--Separate Missing_info from Incomplete
----------------------------

--select * from pubs.dbo.wr1

/*Update A1
SET Activation_Tracker = null
from pubs.dbo.wr1 A1

select top 10 * from pubs.dbo.wr1 where activation_tracker is null
*/


Update A1
SET Activation_Tracker = 'Missing_Info'
from pubs.dbo.wr1 A1
where (FirstName is null or LastName is null or DOB is null or SSN is null or (CellPhone is null and HomePhone is null) or ResidentialAddress1 is null or ResidentialZipCode is null)
or
( (ParentFirstName is null or ParentLastName is null or ParentDob is null or ParentSSN is null)
and CH_Age < 18
)

--UPDATING ACTIVATION_TRACKER WITH ALL RECORDS THAT ARE MISSING AT LEAST 1 PART OF KEY INFORMATION
Update A1
SET Activation_Tracker = 'Incomplete'
from pubs.dbo.wr1 A1
where AccountKey not in (select accountkey from pubs.dbo.wr2) and Activation_tracker is null



--22746764
--select COUNT(*) from pubs.dbo.wr1

--select COUNT(*) from CI_DSA.dbo.RPO_ACCT av (nolock) where Activation_Step = 'missing_info'

--select Activation_Step, COUNT(*) from CI_DSA.dbo.RPO_ACCT group by Activation_Step

--select Activation_Step, COUNT(*) from pubs.dbo.wr1 group by Activation_Step

--select * from CI_DSA.dbo.RPO_ACCT

--UPDATING ACTIVATION TRACKER WITH ALL SUCCESSFUL CARD ACTIVATIONS
Update A1
SET Activation_Tracker = 'Approved'
from pubs.dbo.wr1 A1
where verificationstatustype = 'Approved'
and Cardactivationdate is not null
and Activation_tracker is null

--UPDATING ACTIVATION TRACKER WITH RECORDS THAT FAILED NEG_MATCH

Update A1
SET Activation_Tracker = 'Neg_Match'
from pubs.dbo.wr1 A1
where (activationstatuskey in (50,140) or refundreasonkey = 8)
and Activation_Tracker is null

--UPDATING ACTIVATION TRACKER WITH RECORDS THAT FAILED MAX_CARD_LIMIT
Update A1
SET Activation_Tracker = 'Card_Limit'
from pubs.dbo.wr1 A1
where (activationstatuskey in (145) or refundreasonkey = 23)
and Activation_Tracker is null

-------------------------------------------------------------------------------------------------------------------

--UPDATING ACTIVATION TRACKER WITH RECORDS THAT FAILED CIP
Update A1
SET Activation_Tracker = 'Ident_Verify'
from  pubs.dbo.wr1 A1
where VerificationStatusType <> 'Approved' and VerificationStatusType is not null
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




drop table #OOW0
select f.*,quizresultcode, ir.RiskValue
into #OOW0
from pubs.dbo.wr1 f(nolock)
join IdentityValidationOutOfWalletQuiz i WITH (NOLOCK)  on f.LastIdentityValidationKey = i.IdentityValidationKey  
join IdentityValidationRiskAssessment ir (nolock)on ir.IdentityValidationKey= i.IdentityValidationKey
where f.activation_tracker = 'Ident_Verify'


drop table #failedOOW
select *
into #failedoow
from #OOW0 
where QuizResultCode in ('refer_incomplete', 'refer')


--select  * from #failedoow -- Those failed OOW, need to use vcustomerkey


update ac
set   ac.Activation_tracker = 'OOW'
from #failedoow av (nolock) join pubs.dbo.wr1 ac (nolock) 
on ac.AccountKey= av.AccountKey 


--select activation_tracker, COUNT(*) from pubs.dbo.wr1 group by activation_tracker

--select Activation_Step, COUNT(*) from CI_DSA.dbo.RPO_ACCT where channel ='retail' group by Activation_Step

--update to the master table--------------------------------
update av
set   av.Activation_step = ac.Activation_tracker
from pubs.dbo.wr1 ac (nolock) join CI_DSA.dbo.RPO_ACCT av (nolock) 
on ac.AccountKey= av.AccountKey --and AV.Activation_step is null

--select top 1000 * from CI_DSA.dbo.RPO_ACCT av where channel ='retail'

/*


-- only 67 exceptions

drop table #t1
select * into #t1 from CI_DSA.dbo.RPO_ACCT (nolock) where 
VerificationStatusType is null and activation_step ='approved' and CardActivationDate is not null


select * from #t1

*/