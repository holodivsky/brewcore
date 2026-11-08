@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Goods Movement of Brew Order'
@Metadata.ignorePropagatedAnnotations: true
@Metadata.allowExtensions: true
// Material documents posted for a brew order: raw material issues (261) and the beer receipt (101)
define view entity ZVHB_C_BrewOrderMovement
  as select from ZVHB_R_MaterialDocumentItem as Item
    inner join   ZVHB_R_MaterialDocument     as Document on Document.MaterialDocument = Item.MaterialDocument
{
      @EndUserText.label: 'Material Document'
  key Item.MaterialDocument,

      @EndUserText.label: 'Item'
  key Item.Item,

      @EndUserText.label: 'Brew Order'
      Item.BrewOrder,

      @EndUserText.label: 'Posting Date'
      Document.PostingDate,

      @ObjectModel.text.element: [ 'MovementTypeName' ]
      @EndUserText.label: 'Movement Type'
      Item.MovementType,

      @EndUserText.label: 'Movement Type'
      Item._MovementType.MovementTypeName as MovementTypeName,

      @ObjectModel.text.element: [ 'MaterialName' ]
      @EndUserText.label: 'Material'
      Item.Material,

      @EndUserText.label: 'Material Description'
      Item._Material.MaterialName       as MaterialName,

      @EndUserText.label: 'Storage Location'
      Item.StorageLocation,

      @EndUserText.label: 'Batch'
      Item.Batch,

      @EndUserText.label: 'Unit'
      Item.Unit,

      @Semantics.quantity.unitOfMeasure: 'Unit'
      @EndUserText.label: 'Quantity'
      Item.Quantity
}
where
  Item.BrewOrder <> ''
