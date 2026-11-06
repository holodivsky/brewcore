@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Material Document Item'
@Metadata.allowExtensions: true
define view entity ZVHB_C_MaterialDocumentItem
  as projection on ZVHB_R_MaterialDocumentItem
{
  key MaterialDocument,

  key Item,

      @ObjectModel.text.element: [ 'MovementTypeName' ]
      MovementType,
      _MovementType.MovementTypeName as MovementTypeName,

      @ObjectModel.text.element: [ 'MaterialName' ]
      Material,
      @EndUserText.label: 'Material Description'
      _Material.MaterialName as MaterialName,

      Plant,
      StorageLocation,
      ReceivingLocation,
      Batch,
      Unit,
      Quantity,
      ReversedItem,
      PurchaseOrder,
      PurchaseOrderItem,

      @EndUserText.label: 'Best Before'
      _Batch.ExpiryDate      as ExpiryDate,

      _MaterialDocument : redirected to parent ZVHB_C_MaterialDocument,
      _Material,
      _MovementType,
      _Batch
}
