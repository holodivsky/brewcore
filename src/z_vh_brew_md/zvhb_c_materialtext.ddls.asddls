@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Material Description'
@Metadata.allowExtensions: true
define view entity ZVHB_C_MaterialText
  as projection on ZVHB_R_MaterialText
{
  key Material,

      @Consumption.valueHelpDefinition: [{ entity: { name: 'I_Language', element: 'Language' } }]
      @EndUserText.label: 'Language'
      @EndUserText.quickInfo: 'Language of the description'
  key Language,

      Description,
      LocalLastChangedAt,

      _Material : redirected to parent ZVHB_C_Material,
      _Language
}
