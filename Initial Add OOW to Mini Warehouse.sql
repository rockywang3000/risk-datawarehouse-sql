
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED     
SET NOCOUNT ON  

drop table pubs.dbo.o1
select f.AccountKey,quizresultcode--, ir.RiskValue
into pubs.dbo.o1
from ci_dsa.dbo.RPO_ACCT f (nolock)
join IdentityValidationOutOfWalletQuiz i WITH (NOLOCK)  on f.LastIdentityValidationKey = i.IdentityValidationKey  
--join IdentityValidationRiskAssessment ir (nolock)on ir.IdentityValidationKey= i.IdentityValidationKey
--where f.CreateDate >= '10/1/2012' and f.CreateDate < '10/3/2012'

create index ii2 on pubs.dbo.o1(accountkey)


--update to the master table--------------------------------
update av
set   av.OOW = ac.QuizResultCode
from pubs.dbo.o1 ac (nolock) join CI_DSA.dbo.RPO_ACCT av (nolock) 
on ac.AccountKey= av.AccountKey --and AV.Activation_step is null




