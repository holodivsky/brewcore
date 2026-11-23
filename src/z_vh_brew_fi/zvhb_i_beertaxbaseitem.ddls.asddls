@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'BrewCore: Beer that left the brewery'
@Metadata.ignorePropagatedAnnotations: true
// FR-FI-02: beer is taxed when it leaves the tax warehouse. Every delivery item of a finished beer whose
// goods issue (movement type 601) is posted counts in the month of the goods issue, in hectoliters.
// Deliveries to customers outside Germany are export and free of German beer tax.
define view entity ZVHB_I_BeerTaxBaseItem
  as select from    zvhb_dlvitm as Item
    inner join      zvhb_dlvhdr as Delivery on Delivery.dlv_uuid = Item.dlv_uuid
    inner join      zvhb_mat    as Material on Material.material = Item.material
    inner join      zvhb_bp     as Customer on Customer.partner = Delivery.customer
    left outer join zvhb_matuom as Liters   on  Liters.material = Item.material
                                            and Liters.alt_unit = 'HL'
{
  key Item.item_uuid                                                          as DeliveryItemUUID,
      Delivery.delivery                                                       as Delivery,
      Delivery.customer                                                       as Customer,
      Customer.country                                                        as Country,
      Item.plant                                                              as Plant,
      Delivery.goods_issue_date                                               as GoodsIssueDate,
      cast( substring( cast( Delivery.goods_issue_date as abap.char(8) ), 1, 4 ) as abap.numc(4) ) as PeriodYear,
      cast( substring( cast( Delivery.goods_issue_date as abap.char(8) ), 5, 2 ) as abap.numc(2) ) as PeriodMonth,
      Item.material                                                           as Material,
      Material.original_extract                                               as OriginalExtract,

      // Tax class: whole degrees Plato, fractions are disregarded (section 2 (1) BierStG)
      cast( floor( Material.original_extract ) as abap.int4 )                as TaxClass,

      cast( case Customer.country when 'DE' then 'TAXD' else 'EXPT' end as zvhb_tax_treatment ) as Treatment,

      // Numerator base units equal denominator hectoliters, e.g. 200 bottles of 0.5 l = 1 hl
      cast( case Item.unit
              when 'HL' then cast( Item.quantity as abap.dec(13,3) )
              else division( cast( Item.quantity as abap.dec(13,3) ) * Liters.denominator, Liters.numerator, 3 )
            end as abap.dec(13,2) )                                           as QuantityHL
}
where
  (
       Delivery.status         = 'GI'
    or Delivery.status         = 'BILL'
  )
  and  Item.item_category      = 'PROD'
  and  Material.material_type  = 'FERT'
  and  Material.original_extract > 0
