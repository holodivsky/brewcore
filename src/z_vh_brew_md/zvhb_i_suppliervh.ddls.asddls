@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Supplier'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.dataCategory: #VALUE_HELP
@ObjectModel.usageType: { serviceQuality: #A, sizeCategory: #M, dataClass: #MASTER }
@Search.searchable: true
// Business partners with the supplier role
define view entity ZVHB_I_SupplierVH
  as select from ZVHB_R_BusinessPartner     as Partner
    inner join   ZVHB_R_BusinessPartnerRole as Role on  Role.PartnerUUID = Partner.PartnerUUID
                                                    and Role.PartnerRole = 'SU'
{
      @ObjectModel.text.element: [ 'SupplierName' ]
      @Search.defaultSearchElement: true
  key Partner.Partner      as Supplier,

      @Semantics.text: true
      @Search.defaultSearchElement: true
      @Search.fuzzinessThreshold: 0.8
      Partner.PartnerName  as SupplierName,

      Partner.City,
      Partner.Country,
      Partner.Currency,
      Partner.PaymentTerms,
      Partner.IsBlocked
}
