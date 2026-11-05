@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'BrewCore: Business partner role'
@Metadata.ignorePropagatedAnnotations: true
define view entity ZVHB_R_BusinessPartnerRole
  as select from zvhb_bprole

  association to parent ZVHB_R_BusinessPartner as _Partner on $projection.PartnerUUID = _Partner.PartnerUUID
  association [0..1] to ZVHB_I_PartnerRoleVH    as _RoleVH  on $projection.PartnerRole = _RoleVH.PartnerRole
{
  key partner_uuid          as PartnerUUID,

      @ObjectModel.foreignKey.association: '_RoleVH'
  key partner_role          as PartnerRole,

      @Semantics.systemDateTime.localInstanceLastChangedAt: true
      local_last_changed_at as LocalLastChangedAt,

      _Partner,
      _RoleVH
}
