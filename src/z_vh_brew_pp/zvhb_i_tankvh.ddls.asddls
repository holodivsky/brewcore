@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Fermentation Tank'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.dataCategory: #VALUE_HELP
@Search.searchable: true
define view entity ZVHB_I_TankVH
  as select from ZVHB_R_FermentationTank
{
      @ObjectModel.text.element: [ 'Description' ]
      @Search.defaultSearchElement: true
      @EndUserText.label: 'Tank'
  key Tank,

      @Search.defaultSearchElement: true
      @EndUserText.label: 'Description'
      Description,

      @EndUserText.label: 'Plant'
      Plant,

      @EndUserText.label: 'Unit'
      CapacityUnit,

      @Semantics.quantity.unitOfMeasure: 'CapacityUnit'
      @EndUserText.label: 'Capacity'
      Capacity,

      @ObjectModel.text.element: [ 'StatusName' ]
      @EndUserText.label: 'Status'
      Status,

      @EndUserText.label: 'Status'
      _Status.StatusName as StatusName
}
