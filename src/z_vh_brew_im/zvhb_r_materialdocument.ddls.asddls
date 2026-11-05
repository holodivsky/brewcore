@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'BrewCore: Material document'
@Metadata.ignorePropagatedAnnotations: true
define root view entity ZVHB_R_MaterialDocument
  as select from zvhb_mdochdr

  composition [1..*] of ZVHB_R_MaterialDocumentItem as _Item

  association [0..1] to ZVHB_R_MaterialDocument     as _Reversal on $projection.MaterialDocument = _Reversal.ReversedDocument
{
  key material_document as MaterialDocument,

      @EndUserText.label: 'Posting Date'
      posting_date      as PostingDate,

      @EndUserText.label: 'Text'
      header_text       as HeaderText,

      @EndUserText.label: 'Reverses Document'
      reversed_document as ReversedDocument,

      @Semantics.user.createdBy: true
      created_by        as CreatedBy,

      @Semantics.systemDateTime.createdAt: true
      created_at        as CreatedAt,

      _Item,
      _Reversal
}
