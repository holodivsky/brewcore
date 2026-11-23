@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'BrewCore: Beer tax declaration item'
@Metadata.ignorePropagatedAnnotations: true
define view entity ZVHB_R_BeerTaxDeclItem
  as select from zvhb_btdeclitm

  association        to parent ZVHB_R_BeerTaxDeclaration as _Declaration on $projection.DeclarationUUID = _Declaration.DeclarationUUID

  association [0..1] to ZVHB_I_MaterialVH                as _Material    on $projection.Material = _Material.Material
  association [0..1] to ZVHB_I_TaxTreatmentVH            as _Treatment   on $projection.Treatment = _Treatment.Treatment
  association [0..1] to I_Currency                       as _Currency    on $projection.Currency = _Currency.Currency
{
  key item_uuid             as ItemUUID,
      decl_uuid             as DeclarationUUID,

      @EndUserText.label: 'Item'
      item                  as Item,

      @ObjectModel.foreignKey.association: '_Material'
      material              as Material,

      @EndUserText: { label: 'Tax Class (°P)', quickInfo: 'Original extract in whole degrees Plato' }
      tax_class             as TaxClass,

      @ObjectModel.foreignKey.association: '_Treatment'
      treatment             as Treatment,

      @EndUserText.label: 'Quantity (hl)'
      quantity_hl           as QuantityHL,

      @Semantics.amount.currencyCode: 'Currency'
      @EndUserText.label: 'Beer Tax'
      tax_amount            as TaxAmount,

      @ObjectModel.foreignKey.association: '_Currency'
      @EndUserText.label: 'Currency'
      currency              as Currency,

      @Semantics.systemDateTime.localInstanceLastChangedAt: true
      local_last_changed_at as LocalLastChangedAt,

      _Declaration,
      _Material,
      _Treatment,
      _Currency
}
