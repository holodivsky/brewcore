@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Alternative Unit of Measure'
@Metadata.allowExtensions: true
define view entity ZVHB_C_MaterialUnit
  as projection on ZVHB_R_MaterialUnit
{
  key Material,

      @Consumption.valueHelpDefinition: [{ entity: { name: 'I_UnitOfMeasureStdVH', element: 'UnitOfMeasure' } }]
  key AltUnit,

      Numerator,
      Denominator,
      LocalLastChangedAt,

      _Material : redirected to parent ZVHB_C_Material,
      _AltUnit
}
