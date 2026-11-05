@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'BrewCore: Material document item'
@Metadata.ignorePropagatedAnnotations: true
define view entity ZVHB_R_MaterialDocumentItem
  as select from zvhb_mdocitm

  association        to parent ZVHB_R_MaterialDocument as _MaterialDocument on  $projection.MaterialDocument = _MaterialDocument.MaterialDocument

  association [0..1] to ZVHB_I_MaterialVH              as _Material         on  $projection.Material = _Material.Material
  association [0..1] to ZVHB_I_MovementTypeVH          as _MovementType     on  $projection.MovementType = _MovementType.MovementType
  association [0..1] to ZVHB_R_Batch                   as _Batch            on  $projection.Material = _Batch.Material
                                                                            and $projection.Batch    = _Batch.Batch
{
  key material_document  as MaterialDocument,

  key item               as Item,

      @ObjectModel.foreignKey.association: '_MovementType'
      movement_type      as MovementType,

      @ObjectModel.foreignKey.association: '_Material'
      material           as Material,

      plant              as Plant,

      storage_location   as StorageLocation,

      @EndUserText.label: 'Receiving Storage Location'
      receiving_location as ReceivingLocation,

      batch              as Batch,

      @EndUserText.label: 'Unit'
      unit               as Unit,

      @Semantics.quantity.unitOfMeasure: 'Unit'
      @EndUserText.label: 'Quantity'
      quantity           as Quantity,

      @EndUserText.label: 'Reverses Item'
      reversed_item      as ReversedItem,

      _MaterialDocument,
      _Material,
      _MovementType,
      _Batch
}
