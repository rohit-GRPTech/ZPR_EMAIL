@EndUserText.label: 'PR notification business user email'
@AccessControl.authorizationCheck: #NOT_REQUIRED

define view entity ZI_PR_Email_User
  as select from I_BusinessUserBasic
{
  key BusinessPartner,
  key UserID,
      _WorkplaceAddress.DefaultEmailAddress as EmailAddress
}
