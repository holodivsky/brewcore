@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Beer Tax Declaration Item'
@Metadata.allowExtensions: true
define view entity ZVHB_C_BeerTaxDeclItem
  as projection on ZVHB_R_BeerTaxDeclItem
{
  key ItemUUID,
      DeclarationUUID,
      Item,

      @ObjectModel.text.element: [ 'MaterialName' ]
      Material,
      _Material.MaterialName       as MaterialName,

      TaxClass,

      @ObjectModel.text.element: [ 'TreatmentName' ]
      Treatment,
      _Treatment.TreatmentName     as TreatmentName,

      QuantityHL,
      TaxAmount,
      Currency,
      LocalLastChangedAt,

      _Declaration : redirected to parent ZVHB_C_BeerTaxDeclaration,
      _Material,
      _Treatment,
      _Currency
}
