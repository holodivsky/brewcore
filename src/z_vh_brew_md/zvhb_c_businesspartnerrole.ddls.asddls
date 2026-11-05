@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Business Partner Role'
@Metadata.allowExtensions: true
define view entity ZVHB_C_BusinessPartnerRole
  as projection on ZVHB_R_BusinessPartnerRole
{
  key PartnerUUID,

      @Consumption.valueHelpDefinition: [{ entity: { name: 'ZVHB_I_PartnerRoleVH', element: 'PartnerRole' } }]
      @ObjectModel.text.element: [ 'PartnerRoleName' ]
  key PartnerRole,
      @EndUserText.label: 'Role Name'
      _RoleVH.PartnerRoleName as PartnerRoleName,

      LocalLastChangedAt,

      _Partner : redirected to parent ZVHB_C_BusinessPartner,
      _RoleVH
}
