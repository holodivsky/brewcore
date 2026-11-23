@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Beer Tax Declaration'
@Metadata.allowExtensions: true
define root view entity ZVHB_C_BeerTaxDeclaration
  provider contract transactional_query
  as projection on ZVHB_R_BeerTaxDeclaration
{
  key DeclarationUUID,
      Declaration,

      @Consumption.valueHelpDefinition: [{ entity: { name: 'ZVHB_I_PlantVH', element: 'Plant' } }]
      @ObjectModel.text.element: [ 'PlantName' ]
      Plant,
      _Plant.PlantName   as PlantName,

      PeriodYear,
      PeriodMonth,

      @Consumption.valueHelpDefinition: [{ entity: { name: 'ZVHB_I_DeclStatusVH', element: 'Status' } }]
      @ObjectModel.text.element: [ 'StatusName' ]
      Status,
      _Status.StatusName as StatusName,

      RatePerDegree,
      TaxableHL,
      ExportHL,
      TaxAmount,
      Currency,
      SubmittedBy,
      SubmittedAt,
      CreatedBy,
      CreatedAt,
      LastChangedBy,
      LastChangedAt,
      LocalLastChangedAt,

      _Item : redirected to composition child ZVHB_C_BeerTaxDeclItem,
      _Plant,
      _Status,
      _Currency
}
