@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'BrewCore: Inspection lot'
@Metadata.ignorePropagatedAnnotations: true
define root view entity ZVHB_R_InspectionLot
  as select from zvhb_insplot

  composition [0..*] of ZVHB_R_InspectionChar as _Characteristic

  association [0..1] to ZVHB_I_MaterialVH     as _Material on $projection.Material = _Material.Material
  association [0..1] to ZVHB_I_SupplierVH     as _Supplier on $projection.Supplier = _Supplier.Supplier
  association [0..1] to ZVHB_R_Batch          as _Batch    on  $projection.Material = _Batch.Material
                                                           and $projection.Batch    = _Batch.Batch
  association [0..1] to ZVHB_I_LotStatusVH    as _Status   on $projection.Status = _Status.Status
  association [0..1] to ZVHB_I_LotOriginVH    as _Origin   on $projection.Origin = _Origin.Origin
{
  key lot_uuid              as LotUUID,

      inspection_lot        as InspectionLot,

      @ObjectModel.foreignKey.association: '_Origin'
      origin                as Origin,

      @ObjectModel.foreignKey.association: '_Material'
      material              as Material,

      batch                 as Batch,

      plant                 as Plant,

      storage_location      as StorageLocation,

      @EndUserText.label: 'Unit'
      unit                  as Unit,

      @Semantics.quantity.unitOfMeasure: 'Unit'
      @EndUserText.label: 'Lot Quantity'
      quantity              as Quantity,

      material_document     as MaterialDocument,

      document_item         as DocumentItem,

      purchase_order        as PurchaseOrder,

      @ObjectModel.foreignKey.association: '_Supplier'
      @EndUserText.label: 'Supplier'
      supplier              as Supplier,

      brew_order            as BrewOrder,

      @ObjectModel.foreignKey.association: '_Status'
      status                as Status,

      // Lots in inspection are orange, accepted lots green, rejected lots red
      cast( case status when 'ACC' then 3
                        when 'REJ' then 1
                        else 2 end as abap.int1 ) as StatusCriticality,

      @EndUserText.label: 'Usage Decision On'
      decision_date         as DecisionDate,

      @Semantics.user.createdBy: true
      created_by            as CreatedBy,

      @Semantics.systemDateTime.createdAt: true
      created_at            as CreatedAt,

      @Semantics.user.lastChangedBy: true
      last_changed_by       as LastChangedBy,

      @Semantics.systemDateTime.lastChangedAt: true
      last_changed_at       as LastChangedAt,

      @Semantics.systemDateTime.localInstanceLastChangedAt: true
      local_last_changed_at as LocalLastChangedAt,

      _Characteristic,
      _Material,
      _Supplier,
      _Batch,
      _Status,
      _Origin
}
